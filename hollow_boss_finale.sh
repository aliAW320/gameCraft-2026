#!/usr/bin/env bash
set -euo pipefail

# HOLLOW Milestone 4: Seven-minute boss encounter, two telegraphed attacks,
# boss HP bar, victory/death screen, local high score, debug testing shortcuts.
# Install on top of Milestones 1-3 from the directory containing project.godot.

if [[ ! -f project.godot ]]; then
    echo 'ERROR: Run this inside the Godot project root containing project.godot.' >&2
    exit 1
fi

python3 - <<'PY'
from pathlib import Path
requirements = {
    'scenes/main.tscn': ['name="RunManager"', 'name="SpawnDirector"', 'name="ShopManager"', 'name="ShopPanel"', 'name="LevelUpPanel"'],
    'scripts/managers/run_manager.gd': ['const LOOT_SCENE', 'const SHOP_TIMES', 'func _open_shop', 'func _try_level_up', 'func _on_player_died'],
    'scripts/systems/spawn_director.gd': ['func _physics_process', 'func _spawn_enemy', 'phase_name'],
    'scripts/ui/hud.gd': ['func _process', 'end_label.visible', 'wave_label.text'],
    'scripts/systems/spell_manager.gd': ['get_nodes_in_group("enemies")', 'func _cast_void_pulse'],
    'scenes/enemies/enemy.tscn': ['collision_layer = 2', 'collision_mask = 4'],
}
for path, markers in requirements.items():
    file = Path(path)
    if not file.is_file():
        raise SystemExit(f'ERROR: Missing {path}. Install Milestones 1, 2, and 3 first. No files changed.')
    content = file.read_text()
    for marker in markers:
        if marker not in content:
            raise SystemExit(f'ERROR: Unexpected {path}; missing {marker!r}. No files changed.')
PY

BACKUP=".hollow_backup_milestone4_$(date +%Y%m%d_%H%M%S)_$$"
mkdir -p "$BACKUP"
FILES=(
    scenes/main.tscn
    scenes/enemies/boss.tscn
    scenes/spells/boss_bolt.tscn
    scenes/ui/boss_bar.tscn
    scenes/ui/end_screen.tscn
    scenes/ui/hud.tscn
    scripts/actors/boss.gd
    scripts/systems/boss_bolt.gd
    scripts/systems/spawn_director.gd
    scripts/managers/run_manager.gd
    scripts/ui/hud.gd
    scripts/ui/boss_bar.gd
    scripts/ui/end_screen.gd
)
for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP/$(dirname "$file")"
        cp -- "$file" "$BACKUP/$file"
    fi
done
mkdir -p scenes/{enemies,spells,ui} scripts/{actors,systems,managers,ui}

# -----------------------------------------------------------------------------
# Boss: this is an "enemies"-group CharacterBody2D so ALL three existing
# player spells and the existing projectile collision logic work unchanged.
# -----------------------------------------------------------------------------
cat > scripts/actors/boss.gd <<'GD'
extends CharacterBody2D

signal defeated

const BOLT_SCENE := preload("res://scenes/spells/boss_bolt.tscn")
const ARENA_MIN := 44.0
const ARENA_MAX := 3156.0

enum State { INTRO, CHASE, BARRAGE_WARNING, CHARGE_WARNING, DASH, RECOVERY }

@export var max_health: int = 1500
@export var walking_speed: float = 73.0
@export var dash_speed: float = 500.0

var health: int = 1500
var state: State = State.INTRO
var state_timer: float = 0.85
var attacks_performed: int = 0
var hit_flash: float = 0.0
var charge_direction: Vector2 = Vector2.RIGHT
var charge_target: Vector2 = Vector2.ZERO

@onready var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
@onready var projectile_container: Node2D = get_node("../../../Projectiles") as Node2D

func _ready() -> void:
    add_to_group("enemies")
    add_to_group("boss")
    health = max_health
    queue_redraw()

func _physics_process(delta: float) -> void:
    if health <= 0 or not is_instance_valid(player):
        return

    state_timer -= delta
    if hit_flash > 0.0:
        hit_flash = maxf(0.0, hit_flash - delta)
        queue_redraw()

    match state:
        State.INTRO:
            velocity = Vector2.ZERO
            if state_timer <= 0.0:
                _enter_state(State.CHASE, 1.7)
        State.CHASE:
            var towards: Vector2 = player.global_position - global_position
            if towards.length_squared() > 145.0 * 145.0:
                velocity = towards.normalized() * walking_speed
            else:
                velocity = Vector2.ZERO
            move_and_slide()
            _deal_contact_damage(12)
            if state_timer <= 0.0:
                if attacks_performed % 2 == 0:
                    _enter_state(State.BARRAGE_WARNING, 0.65)
                else:
                    charge_target = player.global_position
                    charge_direction = (charge_target - global_position).normalized()
                    if charge_direction == Vector2.ZERO:
                        charge_direction = Vector2.RIGHT
                    _enter_state(State.CHARGE_WARNING, 0.80)
                attacks_performed += 1
        State.BARRAGE_WARNING:
            velocity = Vector2.ZERO
            queue_redraw()
            if state_timer <= 0.0:
                _fire_barrage()
                _enter_state(State.RECOVERY, 0.45)
        State.CHARGE_WARNING:
            velocity = Vector2.ZERO
            queue_redraw()
            if state_timer <= 0.0:
                _enter_state(State.DASH, 0.42)
        State.DASH:
            velocity = charge_direction * dash_speed
            move_and_slide()
            global_position = Vector2(
                clampf(global_position.x, ARENA_MIN, ARENA_MAX),
                clampf(global_position.y, ARENA_MIN, ARENA_MAX)
            )
            _deal_contact_damage(20)
            if state_timer <= 0.0:
                _enter_state(State.RECOVERY, 0.55)
        State.RECOVERY:
            velocity = Vector2.ZERO
            if state_timer <= 0.0:
                _enter_state(State.CHASE, 1.9)

func _enter_state(new_state: State, seconds: float) -> void:
    state = new_state
    state_timer = seconds
    queue_redraw()

func _deal_contact_damage(amount: int) -> void:
    if global_position.distance_squared_to(player.global_position) <= 56.0 * 56.0:
        player.call("take_damage", amount)

func _fire_barrage() -> void:
    if not is_instance_valid(projectile_container):
        return
    var aim_angle: float = (player.global_position - global_position).angle()
    for i in range(10):
        var direction: Vector2 = Vector2.RIGHT.rotated(aim_angle + TAU * float(i) / 10.0)
        var bolt = BOLT_SCENE.instantiate()
        projectile_container.add_child(bolt)
        bolt.global_position = global_position + direction * 45.0
        bolt.call("setup", direction, 12)

func take_damage(amount: int) -> void:
    if health <= 0 or amount <= 0:
        return
    health = maxi(0, health - amount)
    hit_flash = 0.14
    queue_redraw()
    if health == 0:
        defeated.emit()
        queue_free()

func _draw() -> void:
    # Temporary boss artwork: the body and eye remain legible on a dark arena.
    var body_color: Color = Color(0.93, 0.68, 0.91) if hit_flash > 0.0 else Color(0.24, 0.16, 0.32)
    draw_circle(Vector2(0.0, 23.0), 41.0, Color(0.0, 0.0, 0.0, 0.32))
    draw_circle(Vector2.ZERO, 41.0, Color(0.50, 0.22, 0.76, 0.17))
    draw_colored_polygon(PackedVector2Array([
        Vector2(-33, -17), Vector2(-17, -37), Vector2(16, -37),
        Vector2(34, -17), Vector2(37, 23), Vector2(0, 40), Vector2(-37, 23)
    ]), body_color)
    draw_colored_polygon(PackedVector2Array([
        Vector2(-25, -32), Vector2(-8, -51), Vector2(0, -34),
        Vector2(8, -51), Vector2(25, -32)
    ]), Color(0.61, 0.40, 0.78))
    draw_circle(Vector2(-13, -9), 5.0, Color(0.70, 0.89, 1.0))
    draw_circle(Vector2(13, -9), 5.0, Color(0.70, 0.89, 1.0))
    draw_line(Vector2(-7, 5), Vector2(6, 22), Color(0.70, 0.35, 0.95), 4.0)
    draw_line(Vector2(6, 22), Vector2(16, 5), Color(0.70, 0.35, 0.95), 4.0)

    if state == State.BARRAGE_WARNING:
        var progress: float = 1.0 - clampf(state_timer / 0.65, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 62.0 + progress * 27.0, 0.0, TAU, 52,
            Color(0.93, 0.37, 0.74, 0.85), 4.0)
        for i in range(10):
            var angle: float = TAU * float(i) / 10.0
            draw_line(Vector2.RIGHT.rotated(angle) * 48.0,
                Vector2.RIGHT.rotated(angle) * 75.0,
                Color(0.95, 0.44, 0.76, 0.65), 2.0)

    if state == State.CHARGE_WARNING:
        var end_point: Vector2 = to_local(charge_target)
        var direction: Vector2 = charge_direction
        draw_line(direction * 27.0, end_point + direction * 120.0,
            Color(1.0, 0.30, 0.43, 0.75), 9.0)
        draw_line(direction * 30.0, end_point + direction * 120.0,
            Color(1.0, 0.75, 0.82, 0.93), 2.0)
    elif state == State.DASH:
        draw_arc(Vector2.ZERO, 50.0, 0.0, TAU, 48,
            Color(1.0, 0.32, 0.49, 0.8), 4.0)
GD

cat > scenes/enemies/boss.tscn <<'TSCN'
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/actors/boss.gd" id="1_boss"]

[sub_resource type="CircleShape2D" id="CircleShape2D_boss"]
radius = 36.0

[node name="HollowGuardian" type="CharacterBody2D"]
collision_layer = 2
collision_mask = 4
motion_mode = 1
script = ExtResource("1_boss")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_boss")
TSCN

# -----------------------------------------------------------------------------
# Boss projectiles: use player body collision (layer 1). These are independent
# of player projectiles (which collide with enemies on layer 2).
# -----------------------------------------------------------------------------
cat > scripts/systems/boss_bolt.gd <<'GD'
extends Area2D

@export var speed: float = 260.0
@export var lifetime: float = 3.25

var direction: Vector2 = Vector2.RIGHT
var damage: int = 12

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func setup(travel_direction: Vector2, hit_damage: int = 12) -> void:
    direction = travel_direction.normalized()
    damage = hit_damage

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node2D) -> void:
    if is_queued_for_deletion():
        return
    if body.is_in_group("player"):
        body.call("take_damage", damage)
        queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.18, 0.56, 0.20))
    draw_circle(Vector2.ZERO, 6.0, Color(0.96, 0.49, 0.83))
    draw_circle(Vector2(-1.0, -1.0), 2.0, Color(1.0, 0.91, 0.97))
GD

cat > scenes/spells/boss_bolt.tscn <<'TSCN'
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/systems/boss_bolt.gd" id="1_bolt"]

[sub_resource type="CircleShape2D" id="CircleShape2D_bolt"]
radius = 7.0

[node name="BossBolt" type="Area2D"]
collision_layer = 0
collision_mask = 1
monitoring = true
script = ExtResource("1_bolt")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_bolt")
TSCN

# -----------------------------------------------------------------------------
# Run Manager: retains all existing XP, kill, shop, upgrade, and debug handling;
# adds boss progression, end screens, and safe persistent record tracking.
# -----------------------------------------------------------------------------
cat > scripts/managers/run_manager.gd <<'GD'
extends Node

const XP_PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")
const LOOT_SCENE := preload("res://scenes/pickups/loot.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/boss.tscn")
const SHOP_TIMES := [120.0, 240.0, 360.0]
const BOSS_TIME: float = 420.0
const RECORD_PATH := "user://hollow_best_score.cfg"

var elapsed_seconds: float = 0.0
var score: int = 0
var kills: int = 0
var game_over: bool = false
var scored_seconds: int = 0

var level: int = 1
var experience: int = 0
var pickup_radius: float = 75.0
var level_up_active: bool = false

var gold: int = 0
var shop_active: bool = false
var next_shop_index: int = 0
var current_shop_ids: Array[String] = []

var boss_active: bool = false
var boss: Node2D = null
var victory: bool = false
var best_score: int = 0
var debug_modified: bool = false

@onready var player: Node = get_node("../World/Actors/Player")
@onready var enemies: Node2D = get_node("../World/Actors/Enemies") as Node2D
@onready var pickups: Node2D = get_node("../World/Pickups") as Node2D
@onready var player_projectiles: Node2D = get_node("../World/Projectiles") as Node2D
@onready var spawn_director: Node = get_node("../SpawnDirector")
@onready var upgrade_manager: Node = get_node("../UpgradeManager")
@onready var shop_manager: Node = get_node("../ShopManager")
@onready var level_up_panel: Control = get_node("../UI/LevelUpPanel") as Control
@onready var shop_panel: Control = get_node("../UI/ShopPanel") as Control
@onready var end_screen: Control = get_node("../UI/EndScreen") as Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("run_manager")
    _load_best_score()
    player.connect("died", Callable(self, "_on_player_died"))
    level_up_panel.connect("upgrade_selected", Callable(self, "_on_upgrade_selected"))
    shop_panel.connect("item_requested", Callable(self, "_on_item_requested"))
    shop_panel.connect("shop_skipped", Callable(self, "_on_shop_skipped"))
    end_screen.connect("restart_requested", Callable(self, "_restart_run"))
    end_screen.connect("quit_requested", Callable(self, "_quit_game"))

func _process(delta: float) -> void:
    # Pause must freeze the run clock, boss threshold and merchant visits.
    if game_over or get_tree().paused:
        return
    elapsed_seconds += delta
    var whole_seconds: int = int(elapsed_seconds)
    if whole_seconds > scored_seconds:
        score += (whole_seconds - scored_seconds) * 2
        scored_seconds = whole_seconds

    if not boss_active and elapsed_seconds >= BOSS_TIME:
        _start_boss_encounter()
        return

    if not boss_active and next_shop_index < SHOP_TIMES.size() \
            and elapsed_seconds >= float(SHOP_TIMES[next_shop_index]) \
            and not level_up_active and not shop_active:
        _open_shop(false)

func experience_needed() -> int:
    return 10 + 5 * (level - 1)

func seconds_to_next_shop() -> int:
    if boss_active or next_shop_index >= SHOP_TIMES.size():
        return -1
    return maxi(0, ceili(float(SHOP_TIMES[next_shop_index]) - elapsed_seconds))

func on_enemy_defeated(points: int, defeated_enemy: Node2D) -> void:
    if game_over or boss_active:
        return
    kills += 1
    score += points
    if not is_instance_valid(defeated_enemy):
        return
    var origin: Vector2 = defeated_enemy.global_position
    var xp_amount: int = int(defeated_enemy.get("xp_reward"))
    var elite: bool = bool(defeated_enemy.get("fractured"))
    _spawn_rewards.call_deferred(origin, xp_amount, elite)

func _spawn_rewards(origin: Vector2, xp_amount: int, elite: bool) -> void:
    if game_over or boss_active:
        return
    _spawn_xp_crystal(origin, xp_amount)
    if elite:
        _spawn_loot(origin + Vector2(14, -8), "cache", 1)
    elif randf() < 0.25:
        _spawn_loot(origin + Vector2(10, -6), "gold", 1)
    if randf() < 0.01:
        _spawn_loot(origin + Vector2(-10, -6), "heart", 20)

func _spawn_xp_crystal(world_position: Vector2, amount: int) -> void:
    if game_over or boss_active:
        return
    var crystal = XP_PICKUP_SCENE.instantiate()
    crystal.set("xp_amount", amount)
    pickups.add_child(crystal)
    crystal.global_position = world_position
    crystal.connect("collected", Callable(self, "gain_experience"))

func _spawn_loot(world_position: Vector2, kind: String, amount: int) -> void:
    if game_over or boss_active:
        return
    var loot = LOOT_SCENE.instantiate()
    loot.set("kind", kind)
    loot.set("amount", amount)
    pickups.add_child(loot)
    loot.global_position = world_position
    loot.connect("collected", Callable(self, "on_loot_collected"))

func on_loot_collected(kind: String, amount: int) -> void:
    if game_over:
        return
    match kind:
        "gold":
            gold += amount
        "heart":
            player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + amount))
        "cache":
            gold += 8
            gain_experience(8)

func gain_experience(amount: int) -> void:
    if game_over:
        return
    experience += amount
    _try_level_up()

func _try_level_up() -> void:
    if game_over or level_up_active or shop_active or experience < experience_needed():
        return
    var cost: int = experience_needed()
    experience -= cost
    level += 1
    level_up_active = true
    var choices: Array[Dictionary] = upgrade_manager.call("get_choices", 3)
    level_up_panel.call("show_choices", choices, level)
    get_tree().paused = true

func _on_upgrade_selected(upgrade_id: String) -> void:
    if not level_up_active or game_over:
        return
    upgrade_manager.call("apply_upgrade", upgrade_id)
    level_up_panel.hide()
    level_up_active = false
    get_tree().paused = false
    call_deferred("_try_level_up")

func _open_shop(is_debug: bool) -> void:
    if game_over or boss_active or get_tree().paused or level_up_active or shop_active:
        return
    var choices: Array[Dictionary] = shop_manager.call("get_offers", 3)
    if choices.is_empty():
        if not is_debug:
            next_shop_index += 1
        return
    current_shop_ids.clear()
    for choice in choices:
        current_shop_ids.append(String(choice["id"]))
    shop_active = true
    var visit_number: int = 0
    if not is_debug:
        next_shop_index += 1
        visit_number = next_shop_index
    shop_panel.call("show_offers", choices, gold, visit_number)
    get_tree().paused = true

func _on_item_requested(item_id: String) -> void:
    if not shop_active or not current_shop_ids.has(item_id) or game_over:
        return
    var price: int = int(shop_manager.call("purchase_item", item_id, gold))
    if price < 0:
        return
    gold -= price
    _close_shop()

func _on_shop_skipped() -> void:
    if shop_active:
        _close_shop()

func _close_shop() -> void:
    shop_panel.hide()
    shop_active = false
    current_shop_ids.clear()
    get_tree().paused = false
    call_deferred("_try_level_up")

func _start_boss_encounter() -> void:
    if game_over or boss_active or level_up_active or shop_active:
        return
    boss_active = true
    next_shop_index = SHOP_TIMES.size()
    spawn_director.set("phase_name", "THE HOLLOW GUARDIAN")

    # Stop the swarm and its projectiles; the boss becomes the sole target.
    for enemy in enemies.get_children():
        enemy.queue_free()
    for projectile in player_projectiles.get_children():
        projectile.queue_free()

    var guardian = BOSS_SCENE.instantiate()
    enemies.add_child(guardian)
    boss = guardian as Node2D
    boss.global_position = _boss_spawn_position()
    guardian.connect("defeated", Callable(self, "_on_boss_defeated"))

func _boss_spawn_position() -> Vector2:
    var candidate_directions: Array[Vector2] = [
        Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP
    ]
    candidate_directions.shuffle()
    for direction in candidate_directions:
        var candidate: Vector2 = player.global_position + direction * 325.0
        if candidate.x >= 90.0 and candidate.x <= 3110.0 \
                and candidate.y >= 90.0 and candidate.y <= 3110.0:
            return candidate
    return Vector2(
        clampf(player.global_position.x + 260.0, 90.0, 3110.0),
        clampf(player.global_position.y, 90.0, 3110.0)
    )

func _on_boss_defeated() -> void:
    if game_over or not boss_active:
        return
    kills += 1
    score += 1500
    _finish_run(true)

func _on_player_died() -> void:
    _finish_run(false)

func _finish_run(did_win: bool) -> void:
    if game_over:
        return
    game_over = true
    victory = did_win
    var new_record: bool = false
    if not debug_modified and score > best_score:
        best_score = score
        new_record = true
        _save_best_score()
    end_screen.call("show_result", did_win, score, best_score, kills,
        level, int(elapsed_seconds), gold, debug_modified, new_record)
    get_tree().paused = true

func _load_best_score() -> void:
    var config := ConfigFile.new()
    if config.load(RECORD_PATH) == OK:
        best_score = maxi(0, int(config.get_value("records", "high_score", 0)))

func _save_best_score() -> void:
    var config := ConfigFile.new()
    config.set_value("records", "high_score", best_score)
    var err: Error = config.save(RECORD_PATH)
    if err != OK:
        push_warning("Could not save HOLLOW record (error %d)" % err)

func _restart_run() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()

func _quit_game() -> void:
    get_tree().paused = false
    get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if game_over:
        if key_event.keycode == KEY_R:
            get_viewport().set_input_as_handled()
            _restart_run()
        return
    if get_tree().paused or not OS.is_debug_build():
        return
    match key_event.keycode:
        KEY_G:
            debug_modified = true
            gain_experience(maxi(1, experience_needed() - experience))
        KEY_H:
            debug_modified = true
            gold += 30
        KEY_B:
            debug_modified = true
            _open_shop(true)
        KEY_N:
            debug_modified = true
            elapsed_seconds += 60.0
            scored_seconds = int(elapsed_seconds)
        KEY_K:
            debug_modified = true
            _start_boss_encounter()
        KEY_J:
            if boss_active and is_instance_valid(boss):
                debug_modified = true
                boss.call("take_damage", 400)
        KEY_M:
            debug_modified = true
            player.set("health", 0)
            _finish_run(false)
GD

# -----------------------------------------------------------------------------
# Boss health bar: its own scene so the existing Milestone 3 HUD is unchanged.
# -----------------------------------------------------------------------------
cat > scripts/ui/boss_bar.gd <<'GD'
extends Control

@onready var run_manager: Node = get_node("../../RunManager")
@onready var health_bar: ProgressBar = $Life
@onready var boss_name: Label = $BossName

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_name.text = "THE HOLLOW GUARDIAN"
    hide()

func _process(_delta: float) -> void:
    var guardian: Node2D = run_manager.get("boss") as Node2D
    if not bool(run_manager.get("boss_active")) or not is_instance_valid(guardian) \
            or guardian.is_queued_for_deletion() or bool(run_manager.get("game_over")):
        hide()
        return
    show()
    health_bar.max_value = float(guardian.get("max_health"))
    health_bar.value = float(guardian.get("health"))
GD

cat > scenes/ui/boss_bar.tscn <<'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/boss_bar.gd" id="1_bar"]

[node name="BossBar" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_bar")

[node name="BossName" type="Label" parent="."]
layout_mode = 1
anchor_left = 0.5
anchor_right = 0.5
offset_left = -230.0
offset_top = 50.0
offset_right = 230.0
offset_bottom = 77.0
mouse_filter = 2
theme_override_colors/font_color = Color(0.96, 0.68, 0.87, 1)
theme_override_font_sizes/font_size = 21
text = "THE HOLLOW GUARDIAN"
horizontal_alignment = 1

[node name="Life" type="ProgressBar" parent="."]
layout_mode = 1
anchor_left = 0.5
anchor_right = 0.5
offset_left = -245.0
offset_top = 83.0
offset_right = 245.0
offset_bottom = 107.0
mouse_filter = 2
show_percentage = false
max_value = 1500.0
value = 1500.0
TSCN

# -----------------------------------------------------------------------------
# End screen: usable while the SceneTree is paused. Results and restart/quit
# buttons work on defeat and victory; pressing R is handled by RunManager.
# -----------------------------------------------------------------------------
cat > scripts/ui/end_screen.gd <<'GD'
extends Control

signal restart_requested
signal quit_requested

var heading: Label
var subheading: Label
var stats: Label
var record: Label
var debug_label: Label
var restart_button: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_interface()
    hide()

func show_result(did_win: bool, total_score: int, best_score: int, total_kills: int,
        player_level: int, total_seconds: int, final_gold: int,
        debug_run: bool, new_record: bool) -> void:
    heading.text = "THE HOLLOW FALLS" if did_win else "CONSUMED BY THE HOLLOW"
    heading.add_theme_color_override("font_color",
        Color(0.70, 0.94, 1.0) if did_win else Color(1.0, 0.60, 0.70))
    subheading.text = "The Guardian has been defeated." if did_win else "Your vessel has been shattered."
    stats.text = "SCORE   %d\nSURVIVED   %02d:%02d\nENEMIES DEFEATED   %d\nLEVEL REACHED   %d\nGOLD LEFT   %d" % [
        total_score, int(total_seconds / 60.0), total_seconds % 60,
        total_kills, player_level, final_gold
    ]
    record.text = "BEST SCORE  %d%s" % [
        best_score, "  -  NEW RECORD!" if new_record else ""
    ]
    debug_label.visible = debug_run
    show()
    restart_button.grab_focus()

func _build_interface() -> void:
    var shade := ColorRect.new()
    shade.color = Color(0.009, 0.012, 0.027, 0.93)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)

    var centering := CenterContainer.new()
    centering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centering)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(625.0, 520.0)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.10, 0.09, 0.16)
    panel_style.border_color = Color(0.54, 0.41, 0.72)
    panel_style.set_border_width_all(3)
    panel_style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel", panel_style)
    centering.add_child(panel)

    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 25)
    panel.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 15)
    margin.add_child(column)

    heading = Label.new()
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 30)
    column.add_child(heading)

    subheading = Label.new()
    subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subheading.add_theme_font_size_override("font_size", 17)
    subheading.add_theme_color_override("font_color", Color(0.78, 0.76, 0.86))
    column.add_child(subheading)

    column.add_child(HSeparator.new())

    stats = Label.new()
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.add_theme_font_size_override("font_size", 20)
    stats.add_theme_color_override("font_color", Color(0.89, 0.90, 1.0))
    column.add_child(stats)

    record = Label.new()
    record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    record.add_theme_font_size_override("font_size", 21)
    record.add_theme_color_override("font_color", Color(0.98, 0.80, 0.53))
    column.add_child(record)

    debug_label = Label.new()
    debug_label.text = "DEBUG RUN - score is not saved"
    debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    debug_label.add_theme_font_size_override("font_size", 15)
    debug_label.add_theme_color_override("font_color", Color(1.0, 0.60, 0.60))
    column.add_child(debug_label)

    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 14)
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(buttons)

    restart_button = Button.new()
    restart_button.text = "RESTART RUN  (R)"
    restart_button.custom_minimum_size = Vector2(215.0, 48.0)
    restart_button.pressed.connect(func(): restart_requested.emit())
    buttons.add_child(restart_button)

    var quit_button := Button.new()
    quit_button.text = "QUIT GAME"
    quit_button.custom_minimum_size = Vector2(180.0, 48.0)
    quit_button.pressed.connect(func(): quit_requested.emit())
    buttons.add_child(quit_button)
GD

cat > scenes/ui/end_screen.tscn <<'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/end_screen.gd" id="1_end"]

[node name="EndScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
script = ExtResource("1_end")
TSCN

# -----------------------------------------------------------------------------
# Patch the existing scene and spawn/hud code *surgically* to preserve all
# previously working nodes and avoid duplicating entries on reinstall.
# -----------------------------------------------------------------------------
python3 - <<'PY'
from pathlib import Path
import re

main_file = Path('scenes/main.tscn')
main = main_file.read_text()
resources = (
    ('10_bossbar', 'res://scenes/ui/boss_bar.tscn'),
    ('11_end', 'res://scenes/ui/end_screen.tscn'),
)
new_resources = []
for resource_id, resource_path in resources:
    if f'path="{resource_path}"' not in main:
        new_resources.append(f'[ext_resource type="PackedScene" path="{resource_path}" id="{resource_id}"]')
if new_resources:
    if '[node name="Main"' not in main:
        raise SystemExit('ERROR: Unexpected Main scene root.')
    main = main.replace('[node name="Main"', '\n'.join(new_resources) + '\n\n[node name="Main"', 1)

new_nodes = (
    ('BossBar', '10_bossbar'),
    ('EndScreen', '11_end'),
)
for node_name, resource_id in new_nodes:
    if f'[node name="{node_name}" parent="UI"' not in main:
        main += f'\n[node name="{node_name}" parent="UI" instance=ExtResource("{resource_id}")]\n'
        if node_name == 'EndScreen':
            main += 'visible = false\n'

# Godot's load_steps includes external resources + 1, as in previous milestones.
external_count = len(re.findall(r'^\[ext_resource\b', main, flags=re.M))
sub_count = len(re.findall(r'^\[sub_resource\b', main, flags=re.M))
main = re.sub(r'\[gd_scene\s+load_steps=\d+\s+format=3\]',
              f'[gd_scene load_steps={external_count + sub_count + 1} format=3]', main, count=1)
main_file.write_text(main)

spawn_file = Path('scripts/systems/spawn_director.gd')
spawn = spawn_file.read_text()
original = 'if bool(run_manager.get("game_over")):'
patched = 'if bool(run_manager.get("game_over")) or bool(run_manager.get("boss_active")):'
if patched not in spawn:
    if original not in spawn:
        raise SystemExit('ERROR: Cannot patch SpawnDirector boss guard.')
    spawn = spawn.replace(original, patched, 1)
spawn_file.write_text(spawn)

hud_file = Path('scripts/ui/hud.gd')
hud = hud_file.read_text()
hud = hud.replace('end_label.visible = bool(run_manager.get("game_over"))',
                  'end_label.visible = false  # Milestone 4 uses EndScreen.')
hud_file.write_text(hud)

# Show the extra test keys in the existing HUD without touching its scene file.
hud_scene = Path('scenes/ui/hud.tscn')
hud_scene_text = hud_scene.read_text()
hud_scene_text = hud_scene_text.replace(
    'G: level up  H: +30 gold  B: test shop  N: +1 minute (debug only)',
    'G: XP  H: gold  B: shop  N: +1 min  K: boss  J: boss damage  M: lose (debug)'
)
if hud_scene_text != hud_scene.read_text():
    hud_scene.write_text(hud_scene_text)
PY

cat > MILESTONE_4_NOTES.md <<'MD'
# HOLLOW - Milestone 4: Final Boss and Complete Run

## Included

- A seven-minute boss trigger using gameplay time, not wall-clock time.
- Hollow Guardian with two alternating attacks (telegraphed radial barrage and telegraphed dash).
- The boss counts as an `enemies`-group target; all three existing spells damage it.
- A boss health bar at the top of the screen.
- Fully functional victory/defeat overlay with restart and quit buttons.
- Local high score stored in Godot's `user://hollow_best_score.cfg` using ConfigFile.
- Results include score, time, normal enemy kills, level, and gold remaining.
- Debug runs never overwrite the real high score.

## Controls

- WASD / arrow keys: move.
- R on end screen: restart.
- G (debug): gain XP for next level.
- H (debug): gain 30 gold.
- B (debug): open shop.
- N (debug): add one minute to run clock.
- K (debug): start boss encounter immediately.
- J (debug): damage current boss by 400 (four presses to win from full HP).
- M (debug): finish run with defeat immediately.

## Recommended tests

1. F5: verify normal survival, XP and merchant still work.
2. K: enemies should disappear and the purple Guardian should spawn near the player.
3. Watch for the circular barrage telegraph and directional charge line.
4. The boss should receive damage from Soul Needle, Void Pulse and Orbiting Shade.
5. J x4: boss should die; victory overlay, score bonus and restart should work.
6. M on a different run: defeat overlay should work.
7. Test a normal non-debug run to completion. Its high score should persist after restarting.

## Notes

- The Godot editor must be closed when installing.
- Modified files are copied into a `.hollow_backup_milestone4_*` folder.
- The HUD bottom debug hint is updated to include K/J/M.
- Rendering uses placeholder polygons and colored circles. Art and audio come later.
- The boss enters at 07:00 on the run clock. A win may take 30-90 seconds afterwards.
MD

echo
printf 'HOLLOW Milestone 4 installation complete.\n'
printf 'Backup of replaced files: %s\n' "$BACKUP"
printf 'Open scenes/main.tscn and press F5. Use K to summon the boss, J to damage, M to test defeat.\n'
