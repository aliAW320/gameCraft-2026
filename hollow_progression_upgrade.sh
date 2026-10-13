#!/usr/bin/env bash
set -euo pipefail

# HOLLOW: progression patch for the original hollow_first_playable.sh prototype.
# Run from the project directory that contains project.godot.
if [[ ! -f project.godot ]]; then
  echo 'ERROR: run this from the Godot project root (where project.godot is).' >&2
  exit 1
fi

python3 - <<'PY'
from pathlib import Path
main = Path('scenes/main.tscn')
spawn = Path('scripts/systems/spawn_director.gd')
if not main.is_file() or not spawn.is_file():
    raise SystemExit('ERROR: the first playable prototype was not found. Run hollow_first_playable.sh first.')
a = main.read_text()
b = spawn.read_text()
if not all(k in a for k in ['id="5_run"', '[node name="RunManager"', '[node name="HUD"']):
    raise SystemExit('ERROR: main scene differs from the first prototype; no files have been changed.')
if 'on_enemy_defeated' not in b:
    raise SystemExit('ERROR: enemy defeat hookup not found; no files have been changed.')
PY

BACKUP=".hollow_backup_progression_$(date +%Y%m%d_%H%M%S)_$$"
mkdir -p "$BACKUP"
FILES=(
  scenes/main.tscn
  scenes/ui/hud.tscn
  scenes/ui/level_up_panel.tscn
  scenes/pickups/pickup.tscn
  scripts/systems/spawn_director.gd
  scripts/systems/spell_manager.gd
  scripts/systems/pickup.gd
  scripts/managers/run_manager.gd
  scripts/managers/upgrade_manager.gd
  scripts/ui/hud.gd
  scripts/ui/level_up_panel.gd
)
for file in "${FILES[@]}"; do
  if [[ -f "$file" ]]; then
    cp --parents -- "$file" "$BACKUP"
  fi
done
mkdir -p scenes/{pickups,ui} scripts/{systems,managers,ui}

# ------------------------------------
# XP PICKUP: collect by touch or magnet
# ------------------------------------
cat > scripts/systems/pickup.gd <<'GD'
extends Area2D

signal collected(amount: int)

@export var xp_amount: int = 1
@export var magnet_speed: float = 350.0

var player: Node2D
var already_collected: bool = false

@onready var run_manager: Node = get_node("../../../RunManager")

func _ready() -> void:
    player = get_tree().get_first_node_in_group("player") as Node2D
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    if already_collected or not is_instance_valid(player):
        return

    var distance := global_position.distance_to(player.global_position)
    if distance <= 23.0:
        _collect()
        return

    var magnet_radius: float = float(run_manager.get("pickup_radius"))
    if distance <= magnet_radius:
        global_position = global_position.move_toward(
            player.global_position, magnet_speed * delta
        )

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        _collect()

func _collect() -> void:
    if already_collected:
        return
    already_collected = true
    collected.emit(xp_amount)
    queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 13.0, Color(0.21, 0.75, 1.0, 0.16))
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -10.0), Vector2(6.0, -2.0),
            Vector2(0.0, 9.0), Vector2(-6.0, -2.0)
        ]),
        Color(0.27, 0.77, 1.0)
    )
    draw_line(Vector2(0.0, -8.0), Vector2(0.0, 7.0), Color(0.77, 0.97, 1.0), 1.5)
GD

cat > scenes/pickups/pickup.tscn <<'TSCN'
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/systems/pickup.gd" id="1_pickup"]

[sub_resource type="CircleShape2D" id="CircleShape2D_pickup"]
radius = 12.0

[node name="XPCrystal" type="Area2D"]
collision_layer = 0
collision_mask = 1
monitoring = true
script = ExtResource("1_pickup")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_pickup")
TSCN

# ------------------------------------
# SPELLS: Soul Needle, Void Pulse, Shade
# ------------------------------------
cat > scripts/systems/spell_manager.gd <<'GD'
extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/spells/projectile.tscn")

@export var target_range: float = 460.0

var needle_level: int = 1
var pulse_level: int = 0
var shade_level: int = 0
var damage_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0

var needle_timer: float = 0.15
var pulse_timer: float = 0.2
var pulse_visual_time: float = 0.0
var shade_angle: float = 0.0
var active_seconds: float = 0.0
var shade_hit_times: Dictionary = {}

@onready var projectiles: Node2D = get_node("../../../Projectiles") as Node2D

func _physics_process(delta: float) -> void:
    active_seconds += delta

    needle_timer -= delta
    if needle_timer <= 0.0:
        var targets := _find_needle_targets(2 if needle_level >= 2 else 1)
        if not targets.is_empty():
            for target in targets:
                _fire_needle(target)
            needle_timer = (0.55 if needle_level >= 4 else 0.70) * cooldown_multiplier

    if pulse_level > 0:
        pulse_timer -= delta
        if pulse_timer <= 0.0:
            _cast_void_pulse()
            pulse_timer = (2.2 if pulse_level >= 4 else 3.0) * cooldown_multiplier

    if shade_level > 0:
        shade_angle += delta * 3.2
        _update_shade_hits()
        queue_redraw()

    if pulse_visual_time > 0.0:
        pulse_visual_time = maxf(0.0, pulse_visual_time - delta)
        queue_redraw()

func upgrade_spell(spell_id: String) -> void:
    match spell_id:
        "needle":
            needle_level = mini(4, needle_level + 1)
        "pulse":
            if pulse_level == 0:
                pulse_timer = 0.15
            pulse_level = mini(4, pulse_level + 1)
        "shade":
            shade_level = mini(4, shade_level + 1)
    queue_redraw()

func multiply_damage(multiplier: float) -> void:
    damage_multiplier *= multiplier

func multiply_cooldown(multiplier: float) -> void:
    cooldown_multiplier *= multiplier

func _find_needle_targets(count: int) -> Array[Node2D]:
    var first: Node2D = null
    var second: Node2D = null
    var first_distance := target_range * target_range
    var second_distance := target_range * target_range

    for node in get_tree().get_nodes_in_group("enemies"):
        var enemy := node as Node2D
        if enemy == null or enemy.is_queued_for_deletion():
            continue
        var d := global_position.distance_squared_to(enemy.global_position)
        if d < first_distance:
            second = first
            second_distance = first_distance
            first = enemy
            first_distance = d
        elif d < second_distance:
            second = enemy
            second_distance = d

    var result: Array[Node2D] = []
    if first != null:
        result.append(first)
        if count >= 2:
            # If there is one enemy, both needles hit that enemy.
            result.append(second if second != null else first)
    return result

func _fire_needle(target: Node2D) -> void:
    if not is_instance_valid(target) or target.is_queued_for_deletion():
        return
    var projectile = PROJECTILE_SCENE.instantiate()
    projectile.set("damage", roundi((21.0 if needle_level >= 3 else 14.0) * damage_multiplier))
    projectiles.add_child(projectile)
    projectile.global_position = global_position
    projectile.call("setup", (target.global_position - global_position).normalized())

func _pulse_radius() -> float:
    return 140.0 if pulse_level >= 2 else 105.0

func _cast_void_pulse() -> void:
    var radius_squared := _pulse_radius() * _pulse_radius()
    var damage := roundi((34.0 if pulse_level >= 3 else 22.0) * damage_multiplier)
    for node in get_tree().get_nodes_in_group("enemies"):
        var enemy := node as Node2D
        if enemy == null or enemy.is_queued_for_deletion():
            continue
        if global_position.distance_squared_to(enemy.global_position) <= radius_squared:
            enemy.call("take_damage", damage)
    pulse_visual_time = 0.24
    queue_redraw()

func _shade_positions() -> Array[Vector2]:
    var result: Array[Vector2] = []
    var orb_count := 2 if shade_level >= 2 else 1
    var radius := 100.0 if shade_level >= 4 else 70.0
    for i in range(orb_count):
        var angle := shade_angle + TAU * float(i) / float(orb_count)
        result.append(global_position + Vector2.RIGHT.rotated(angle) * radius)
    return result

func _update_shade_hits() -> void:
    var positions := _shade_positions()
    var damage := roundi((11.0 if shade_level >= 3 else 7.0) * damage_multiplier)
    for node in get_tree().get_nodes_in_group("enemies"):
        var enemy := node as Node2D
        if enemy == null or enemy.is_queued_for_deletion():
            continue
        var enemy_id := enemy.get_instance_id()
        if active_seconds < float(shade_hit_times.get(enemy_id, -1.0)):
            continue
        for orb_position in positions:
            if enemy.global_position.distance_squared_to(orb_position) <= 22.0 * 22.0:
                shade_hit_times[enemy_id] = active_seconds + 0.65
                enemy.call("take_damage", damage)
                break

func _draw() -> void:
    if pulse_visual_time > 0.0:
        var opacity := pulse_visual_time / 0.24
        draw_circle(Vector2.ZERO, _pulse_radius(), Color(0.44, 0.23, 0.83, 0.12 * opacity))
        draw_arc(
            Vector2.ZERO, _pulse_radius(), 0.0, TAU, 72,
            Color(0.73, 0.48, 1.0, 0.9 * opacity), 5.0
        )

    if shade_level > 0:
        for world_pos in _shade_positions():
            var local_pos := to_local(world_pos)
            draw_circle(local_pos, 16.0, Color(0.62, 0.28, 0.92, 0.24))
            draw_circle(local_pos, 8.0, Color(0.73, 0.56, 1.0))
            draw_circle(local_pos + Vector2(-2.0, -2.0), 3.0, Color(0.95, 0.9, 1.0))
GD

# ------------------------------------
# UPGRADE POOL: 3 unique random choices
# ------------------------------------
cat > scripts/managers/upgrade_manager.gd <<'GD'
extends Node

var passive_levels: Dictionary = {
    "focus": 0,
    "quickening": 0,
    "heart": 0,
    "swift": 0,
    "magnet": 0
}

@onready var player: CharacterBody2D = get_node("../World/Actors/Player") as CharacterBody2D
@onready var spells: Node = get_node("../World/Actors/Player/SpellManager")
@onready var run_manager: Node = get_node("../RunManager")

func get_choices(amount: int = 3) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []

    var needle := int(spells.get("needle_level"))
    if needle < 4:
        var needle_text := "Fire two needles at once."
        if needle == 2:
            needle_text = "Increase Soul Needle damage from 14 to 21."
        elif needle == 3:
            needle_text = "Reduce Soul Needle cooldown from 0.70s to 0.55s."
        pool.append(_card("needle", "SOUL NEEDLE Lv.%d" % (needle + 1), needle_text))

    var pulse := int(spells.get("pulse_level"))
    if pulse < 4:
        var pulse_text := "Unlock an area blast every 3 seconds."
        if pulse == 1:
            pulse_text = "Increase Void Pulse radius to 140px."
        elif pulse == 2:
            pulse_text = "Increase Void Pulse damage to 34."
        elif pulse == 3:
            pulse_text = "Reduce Void Pulse cooldown to 2.2s."
        pool.append(_card("pulse", "VOID PULSE Lv.%d" % (pulse + 1), pulse_text))

    var shade := int(spells.get("shade_level"))
    if shade < 4:
        var shade_text := "Unlock a damaging orb that circles you."
        if shade == 1:
            shade_text = "Create a second orbiting shade."
        elif shade == 2:
            shade_text = "Increase shade damage from 7 to 11."
        elif shade == 3:
            shade_text = "Increase the orbit radius to 100px."
        pool.append(_card("shade", "ORBITING SHADE Lv.%d" % (shade + 1), shade_text))

    if int(passive_levels["focus"]) < 3:
        pool.append(_card("focus", "VOID FOCUS", "+10% damage for every spell."))
    if int(passive_levels["quickening"]) < 3:
        pool.append(_card("quickening", "QUICKENING", "Spells cast 8% more frequently."))
    if int(passive_levels["heart"]) < 2:
        pool.append(_card("heart", "IRON HEART", "+15 maximum HP and heal 15 HP."))
    if int(passive_levels["swift"]) < 2:
        pool.append(_card("swift", "SWIFT STEP", "+10% movement speed."))
    if int(passive_levels["magnet"]) < 3:
        pool.append(_card("magnet", "SOUL MAGNET", "+25px XP crystal attraction radius."))

    # Infinite fallbacks only enter the pool when ordinary upgrades are exhausted.
    if pool.size() < amount:
        pool.append(_card("mending", "SOUL MENDING", "Restore up to 25 HP."))
        pool.append(_card("resilience", "RESILIENCE", "+5 maximum HP and heal 5 HP."))
        pool.append(_card("hunger", "SOUL HUNGER", "+5% damage for every spell."))

    pool.shuffle()
    var result: Array[Dictionary] = []
    for i in range(mini(amount, pool.size())):
        result.append(pool[i])
    return result

func apply_upgrade(upgrade_id: String) -> void:
    match upgrade_id:
        "needle", "pulse", "shade":
            spells.call("upgrade_spell", upgrade_id)
        "focus":
            spells.call("multiply_damage", 1.10)
        "quickening":
            spells.call("multiply_cooldown", 0.92)
        "heart":
            _increase_health(15)
        "swift":
            player.set("speed", float(player.get("speed")) * 1.10)
        "magnet":
            run_manager.set("pickup_radius", float(run_manager.get("pickup_radius")) + 25.0)
        "mending":
            player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + 25))
        "resilience":
            _increase_health(5)
        "hunger":
            spells.call("multiply_damage", 1.05)
        _:
            push_warning("Unknown upgrade: " + upgrade_id)
            return

    if passive_levels.has(upgrade_id):
        passive_levels[upgrade_id] = int(passive_levels[upgrade_id]) + 1

func _increase_health(amount: int) -> void:
    player.set("max_health", int(player.get("max_health")) + amount)
    player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + amount))

func _card(id: String, title: String, description: String) -> Dictionary:
    return {"id": id, "title": title, "description": description}
GD

# ------------------------------------
# UI: upgrade selection pauses the world
# ------------------------------------
cat > scripts/ui/level_up_panel.gd <<'GD'
extends Control

signal upgrade_selected(upgrade_id: String)

var available_cards: Array[Dictionary] = []
var buttons: Array[Button] = []
var title_label: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_interface()
    hide()

func show_choices(choices: Array[Dictionary], player_level: int) -> void:
    available_cards = choices
    title_label.text = "HOLLOW AWAKENING  |  LEVEL %d" % player_level
    for i in range(buttons.size()):
        var button := buttons[i]
        button.visible = i < choices.size()
        if button.visible:
            var card: Dictionary = choices[i]
            button.text = "%d  ·  %s\n\n%s" % [
                i + 1, String(card["title"]), String(card["description"])
            ]
    show()
    if not buttons.is_empty():
        buttons[0].grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
    if not visible or not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    var choice := -1
    match key_event.keycode:
        KEY_1:
            choice = 0
        KEY_2:
            choice = 1
        KEY_3:
            choice = 2
    if choice >= 0 and choice < available_cards.size():
        get_viewport().set_input_as_handled()
        _select_card(choice)

func _select_card(index: int) -> void:
    if not visible or index < 0 or index >= available_cards.size():
        return
    upgrade_selected.emit(String(available_cards[index]["id"]))

func _build_interface() -> void:
    var overlay := ColorRect.new()
    overlay.color = Color(0.01, 0.015, 0.035, 0.85)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var centering := CenterContainer.new()
    centering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centering)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(870.0, 338.0)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.10, 0.10, 0.16)
    panel_style.border_color = Color(0.44, 0.33, 0.63)
    panel_style.set_border_width_all(3)
    panel_style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel", panel_style)
    centering.add_child(panel)

    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 22)
    margins.add_theme_constant_override("margin_right", 22)
    margins.add_theme_constant_override("margin_top", 22)
    margins.add_theme_constant_override("margin_bottom", 22)
    panel.add_child(margins)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 18)
    margins.add_child(content)

    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 28)
    title_label.add_theme_color_override("font_color", Color(0.86, 0.79, 1.0))
    content.add_child(title_label)

    var subtitle := Label.new()
    subtitle.text = "Choose one upgrade to carry deeper into the Hollow"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 17)
    content.add_child(subtitle)

    var cards := HBoxContainer.new()
    cards.add_theme_constant_override("separation", 14)
    content.add_child(cards)

    for i in range(3):
        var button := Button.new()
        button.custom_minimum_size = Vector2(260.0, 176.0)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.add_theme_font_size_override("font_size", 17)
        button.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
        button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.72))
        button.pressed.connect(_select_card.bind(i))
        cards.add_child(button)
        buttons.append(button)

    var hint := Label.new()
    hint.text = "Click a card, or press 1 / 2 / 3"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.64, 0.68, 0.77))
    content.add_child(hint)
GD

cat > scenes/ui/level_up_panel.tscn <<'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/level_up_panel.gd" id="1_panel"]

[node name="LevelUpPanel" type="Control"]
visible = false
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
process_mode = 3
script = ExtResource("1_panel")
TSCN

# ------------------------------------
# RUN MANAGER: XP, levels, score, game over
# ------------------------------------
cat > scripts/managers/run_manager.gd <<'GD'
extends Node

const XP_PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")

var elapsed_seconds: float = 0.0
var score: int = 0
var kills: int = 0
var game_over: bool = false
var scored_seconds: int = 0

var level: int = 1
var experience: int = 0
var pickup_radius: float = 75.0
var level_up_active: bool = false

@onready var player: Node = get_node("../World/Actors/Player")
@onready var pickups: Node2D = get_node("../World/Pickups") as Node2D
@onready var upgrade_manager: Node = get_node("../UpgradeManager")
@onready var level_up_panel: Control = get_node("../UI/LevelUpPanel") as Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("run_manager")
    player.connect("died", Callable(self, "_on_player_died"))
    level_up_panel.connect("upgrade_selected", Callable(self, "_on_upgrade_selected"))

func _process(delta: float) -> void:
    # The game timer and score must not increase while selecting an upgrade.
    if game_over or get_tree().paused:
        return
    elapsed_seconds += delta
    var whole_seconds := int(elapsed_seconds)
    if whole_seconds > scored_seconds:
        score += (whole_seconds - scored_seconds) * 2
        scored_seconds = whole_seconds

func experience_needed() -> int:
    return 10 + 5 * (level - 1)

func on_enemy_defeated(points: int, defeated_enemy: Node2D) -> void:
    if game_over:
        return
    kills += 1
    score += points
    if not is_instance_valid(defeated_enemy):
        return

    # Defer adding physics objects: a defeat can occur during a collision callback.
    _spawn_xp_crystal.call_deferred(defeated_enemy.global_position)

func _spawn_xp_crystal(world_position: Vector2) -> void:
    if game_over:
        return
    var crystal = XP_PICKUP_SCENE.instantiate()
    crystal.set("xp_amount", 1)
    pickups.add_child(crystal)
    crystal.global_position = world_position
    crystal.connect("collected", Callable(self, "gain_experience"))

func gain_experience(amount: int) -> void:
    if game_over:
        return
    experience += amount
    _try_level_up()

func _try_level_up() -> void:
    if game_over or level_up_active or experience < experience_needed():
        return

    var cost := experience_needed()
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
    # If one large pickup earned several levels, offer them one at a time.
    call_deferred("_try_level_up")

func _on_player_died() -> void:
    game_over = true
    get_tree().paused = true

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if game_over and key_event.keycode == KEY_R:
        get_tree().paused = false
        get_tree().reload_current_scene()
    elif not game_over and not get_tree().paused and OS.is_debug_build() and key_event.keycode == KEY_G:
        # Quick manual test: G grants precisely enough XP to trigger a level-up.
        gain_experience(maxi(1, experience_needed() - experience))
GD

# ------------------------------------
# HUD: visible level, XP bar, spell levels
# ------------------------------------
cat > scripts/ui/hud.gd <<'GD'
extends Control

@onready var player = get_node("../../World/Actors/Player")
@onready var run_manager = get_node("../../RunManager")
@onready var spells = get_node("../../World/Actors/Player/SpellManager")
@onready var stats_label: Label = $Stats
@onready var xp_label: Label = $XPInfo
@onready var xp_bar: ProgressBar = $XPBar
@onready var spells_label: Label = $Spells
@onready var end_label: Label = $EndMessage

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    end_label.visible = false

func _process(_delta: float) -> void:
    var total_seconds := int(run_manager.elapsed_seconds)
    stats_label.text = "HP %d/%d    Kills %d    Score %d    %02d:%02d" % [
        player.health, player.max_health, run_manager.kills, run_manager.score,
        int(total_seconds / 60.0), total_seconds % 60
    ]
    var needed: int = run_manager.experience_needed()
    xp_label.text = "LEVEL %d    XP %d / %d" % [
        run_manager.level, run_manager.experience, needed
    ]
    xp_bar.max_value = needed
    xp_bar.value = run_manager.experience
    spells_label.text = "Soul Needle %d   |   Void Pulse %d   |   Orbiting Shade %d" % [
        spells.needle_level, spells.pulse_level, spells.shade_level
    ]
    end_label.visible = run_manager.game_over
GD

cat > scenes/ui/hud.tscn <<'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1_hud"]

[node name="HUD" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_hud")

[node name="Stats" type="Label" parent="."]
layout_mode = 0
offset_left = 22.0
offset_top = 14.0
offset_right = 1080.0
offset_bottom = 45.0
theme_override_colors/font_color = Color(0.88, 0.95, 1.0, 1)
theme_override_font_sizes/font_size = 22
text = "HP 100/100    Kills 0    Score 0    00:00"

[node name="XPBar" type="ProgressBar" parent="."]
layout_mode = 0
offset_left = 22.0
offset_top = 52.0
offset_right = 360.0
offset_bottom = 72.0
show_percentage = false
max_value = 10.0
value = 0.0

[node name="XPInfo" type="Label" parent="."]
layout_mode = 0
offset_left = 22.0
offset_top = 77.0
offset_right = 410.0
offset_bottom = 103.0
theme_override_colors/font_color = Color(0.62, 0.87, 1.0, 1)
theme_override_font_sizes/font_size = 16
text = "LEVEL 1    XP 0 / 10"

[node name="Spells" type="Label" parent="."]
layout_mode = 0
offset_left = 22.0
offset_top = 109.0
offset_right = 850.0
offset_bottom = 136.0
theme_override_colors/font_color = Color(0.75, 0.65, 0.98, 1)
theme_override_font_sizes/font_size = 16
text = "Soul Needle 1   |   Void Pulse 0   |   Orbiting Shade 0"

[node name="Help" type="Label" parent="."]
layout_mode = 1
anchors_preset = 12
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -36.0
offset_bottom = -8.0
grow_horizontal = 2
grow_vertical = 0
theme_override_colors/font_color = Color(0.7, 0.75, 0.86, 1)
theme_override_font_sizes/font_size = 17
text = "WASD / arrows: move   |   Collect blue XP   |   G: debug level-up (editor)"
horizontal_alignment = 1

[node name="EndMessage" type="Label" parent="."]
visible = false
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -260.0
offset_top = -70.0
offset_right = 260.0
offset_bottom = 70.0
grow_horizontal = 2
grow_vertical = 2
theme_override_colors/font_color = Color(1.0, 0.72, 0.78, 1)
theme_override_font_sizes/font_size = 35
text = "YOU FELL INTO THE HOLLOW\nPress R to restart"
horizontal_alignment = 1
vertical_alignment = 1
TSCN

# Patch the original working spawn system to pass the enemy with its defeat signal.
# Also register the new upgrade manager and selection panel in the main scene.
python3 - <<'PY'
from pathlib import Path

spawner = Path('scripts/systems/spawn_director.gd')
s = spawner.read_text()
old = 'enemy.defeated.connect(Callable(run_manager, "on_enemy_defeated"))'
new = 'enemy.defeated.connect(Callable(run_manager, "on_enemy_defeated").bind(enemy))'
if old in s:
    spawner.write_text(s.replace(old, new, 1))
elif new not in s:
    raise SystemExit('ERROR: could not find enemy signal hookup. Restore from backup and inspect the scene.')

main = Path('scenes/main.tscn')
s = main.read_text()
if 'id="6_upgrade"' not in s:
    s = s.replace(
        '[gd_scene load_steps=6 format=3]',
        '[gd_scene load_steps=8 format=3]', 1
    )
    before = '[node name="Main" type="Node2D"]'
    extra = (
        '[ext_resource type="Script" path="res://scripts/managers/upgrade_manager.gd" id="6_upgrade"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/ui/level_up_panel.tscn" id="7_level_ui"]\n\n'
    )
    if before not in s:
        raise SystemExit('ERROR: main scene node declaration missing.')
    s = s.replace(before, extra + before, 1)
    after = '[node name="UI" type="CanvasLayer" parent="."]'
    manager = '[node name="UpgradeManager" type="Node" parent="."]\nscript = ExtResource("6_upgrade")\n\n'
    if after not in s:
        raise SystemExit('ERROR: UI canvas missing from main scene.')
    s = s.replace(after, manager + after, 1)
    hud = '[node name="HUD" parent="UI" instance=ExtResource("2_hud")]'
    if hud not in s:
        raise SystemExit('ERROR: HUD node missing from main scene.')
    s = s.replace(hud, hud + '\n\n[node name="LevelUpPanel" parent="UI" instance=ExtResource("7_level_ui")]\nvisible = false', 1)
    main.write_text(s)

print('Installed HOLLOW progression and upgrades.')
PY

printf '\nSUCCESS! Backups saved in: %s\n' "$BACKUP"
echo 'Open Godot and press F5. Kill enemies, collect crystals, and choose upgrades with 1/2/3 or a click.'
