#!/usr/bin/env bash
set -euo pipefail

# HOLLOW Milestone 3: enemy evolution, gold/loot, three timed shop visits.
# Installs on top of hollow_first_playable.sh + hollow_progression_upgrade.sh.
# Run from the directory containing project.godot.
if [[ ! -f project.godot ]]; then
    echo 'ERROR: Run this inside your Godot project root (contains project.godot).' >&2
    exit 1
fi

python3 - <<'PY'
from pathlib import Path
required = {
    'scenes/main.tscn': ['id="6_upgrade"', 'name="UpgradeManager"', 'name="LevelUpPanel"', 'name="SpawnDirector"'],
    'scripts/managers/run_manager.gd': ['XP_PICKUP_SCENE', 'func on_enemy_defeated', 'func _try_level_up', 'func _on_upgrade_selected'],
    'scripts/actors/player.gd': ['var invulnerable_for:', 'health = maxi(0, health - amount)'],
    'scripts/systems/spell_manager.gd': ['func upgrade_spell', 'func multiply_damage', 'func multiply_cooldown'],
    'scripts/ui/hud.gd': ['xp_bar', 'spells_label'],
}
for filename, tokens in required.items():
    path = Path(filename)
    if not path.is_file():
        raise SystemExit(f'ERROR: Missing {filename}. Install Milestones 1 and 2 first.')
    s = path.read_text()
    if filename.endswith('player.gd') and 'damage_taken_multiplier' in s:
        tokens = [v for v in tokens if v != 'health = maxi(0, health - amount)']
    for token in tokens:
        if token not in s:
            raise SystemExit(f'ERROR: Unexpected content in {filename}: missing {token!r}. No files were changed.')
PY

BACKUP=".hollow_backup_milestone3_$(date +%Y%m%d_%H%M%S)_$$"
mkdir -p "$BACKUP"
FILES=(
  scenes/main.tscn scenes/enemies/enemy.tscn scenes/ui/hud.tscn
  scenes/ui/shop_panel.tscn scenes/pickups/loot.tscn
  scripts/actors/enemy.gd scripts/actors/player.gd
  scripts/systems/spawn_director.gd scripts/systems/loot_pickup.gd
  scripts/managers/run_manager.gd scripts/managers/shop_manager.gd
  scripts/ui/hud.gd scripts/ui/shop_panel.gd
)
for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP/$(dirname "$file")"
        cp -- "$file" "$BACKUP/$file"
    fi
done
mkdir -p scenes/{enemies,pickups,ui} scripts/{actors,systems,managers,ui}

# -----------------------------------------------------------------------------
# ENEMY: one reusable scene, three behavior/stat archetypes + Fractured modifier.
# The existing defeated(points) signal is preserved for compatibility.
# -----------------------------------------------------------------------------
cat > scripts/actors/enemy.gd <<'GD'
extends CharacterBody2D

signal defeated(points: int)

@export var speed: float = 65.0
@export var max_health: int = 24
@export var contact_damage: int = 8

var health: int = 24
var hit_flash: float = 0.0
var player: Node2D

var enemy_kind: String = "husk"
var fractured: bool = false
var xp_reward: int = 1
var score_reward: int = 10

func configure(kind: String, is_fractured: bool, elapsed_seconds: float) -> void:
    enemy_kind = kind
    fractured = is_fractured

    var base_hp: int = 24
    var base_speed: float = 65.0
    var base_damage: int = 8
    var base_xp: int = 1
    var base_score: int = 10
    match enemy_kind:
        "skitter":
            base_hp = 14
            base_speed = 115.0
            base_damage = 5
            base_xp = 1
            base_score = 15
        "brute":
            base_hp = 80
            base_speed = 43.0
            base_damage = 14
            base_xp = 3
            base_score = 35
        _:
            enemy_kind = "husk"

    var minutes: float = elapsed_seconds / 60.0
    var health_scale: float = 1.0 + 0.12 * minutes
    var damage_scale: float = 1.0 + 0.07 * minutes
    var elite_hp_scale: float = 1.7 if fractured else 1.0
    var elite_speed_scale: float = 1.15 if fractured else 1.0

    max_health = maxi(1, roundi(float(base_hp) * health_scale * elite_hp_scale))
    health = max_health
    speed = base_speed * elite_speed_scale
    contact_damage = maxi(1, roundi(float(base_damage) * damage_scale))
    xp_reward = base_xp * (2 if fractured else 1)
    score_reward = base_score + (100 if fractured else 0)

    var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collider != null:
        var hit_shape := CircleShape2D.new()
        hit_shape.radius = 21.0 if enemy_kind == "brute" else (10.0 if enemy_kind == "skitter" else 13.0)
        collider.shape = hit_shape

func _ready() -> void:
    add_to_group("enemies")
    health = max_health
    player = get_tree().get_first_node_in_group("player") as Node2D

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player) or health <= 0:
        return
    if hit_flash > 0.0:
        hit_flash = maxf(0.0, hit_flash - delta)
        queue_redraw()

    var towards_player: Vector2 = player.global_position - global_position
    velocity = towards_player.normalized() * speed
    move_and_slide()
    var contact_radius: float = 35.0 if enemy_kind == "brute" else (24.0 if enemy_kind == "skitter" else 29.0)
    if global_position.distance_squared_to(player.global_position) <= contact_radius * contact_radius:
        player.call("take_damage", contact_damage)

func take_damage(amount: int) -> void:
    if health <= 0:
        return
    health -= amount
    if health <= 0:
        defeated.emit(score_reward)
        queue_free()
    else:
        hit_flash = 0.12
        queue_redraw()

func _draw() -> void:
    var damaged: bool = hit_flash > 0.0
    draw_circle(Vector2(0.0, 7.0), 16.0 if enemy_kind == "brute" else 11.0, Color(0.0, 0.0, 0.0, 0.30))
    match enemy_kind:
        "skitter":
            var skitter_color := Color(1.0, 0.72, 0.79) if damaged else Color(0.65, 0.27, 0.45)
            for side in [-1, 1]:
                for i in range(3):
                    var dy: float = float(i - 1) * 6.0
                    draw_line(Vector2(4.0 * side, dy), Vector2(15.0 * side, dy + 4.0), skitter_color, 2.0)
            draw_circle(Vector2.ZERO, 10.0, skitter_color)
            draw_circle(Vector2(-4.0, -2.0), 1.8, Color(0.99, 0.9, 1.0))
            draw_circle(Vector2(4.0, -2.0), 1.8, Color(0.99, 0.9, 1.0))
        "brute":
            var brute_color := Color(1.0, 0.75, 0.83) if damaged else Color(0.37, 0.34, 0.48)
            draw_colored_polygon(PackedVector2Array([
                Vector2(-21, -14), Vector2(0, -20), Vector2(20, -15),
                Vector2(23, 11), Vector2(0, 21), Vector2(-23, 12)
            ]), brute_color)
            draw_line(Vector2(-8, -10), Vector2(-1, 8), Color(0.6, 0.34, 0.85), 3.0)
            draw_line(Vector2(-1, 8), Vector2(9, 3), Color(0.6, 0.34, 0.85), 3.0)
            draw_circle(Vector2(-6, -4), 2.5, Color(0.95, 0.72, 1.0))
            draw_circle(Vector2(6, -4), 2.5, Color(0.95, 0.72, 1.0))
        _:
            var husk_color := Color(1.0, 0.66, 0.75) if damaged else Color(0.46, 0.22, 0.34)
            draw_colored_polygon(PackedVector2Array([
                Vector2(0, -16), Vector2(-13, -6), Vector2(-12, 11),
                Vector2(0, 15), Vector2(12, 11), Vector2(13, -6)
            ]), husk_color)
            draw_circle(Vector2(-4, -3), 2.0, Color(1.0, 0.84, 0.91))
            draw_circle(Vector2(4, -3), 2.0, Color(1.0, 0.84, 0.91))

    if fractured:
        draw_arc(Vector2.ZERO, 24.0 if enemy_kind == "brute" else 17.0,
            0.0, TAU, 40, Color(0.75, 0.38, 1.0, 0.87), 3.0)
        draw_circle(Vector2(0, -20), 4.0, Color(0.82, 0.57, 1.0, 0.75))
GD

# Enemy collision remains isolated from other enemy bodies, as in Milestone 1.
# Its scene does not need to change.

# -----------------------------------------------------------------------------
# SPAWN DIRECTOR: weighted stages, enemy caps, timed guaranteed elites,
# a chance of randomly Fractured enemies starting at minute four.
# -----------------------------------------------------------------------------
cat > scripts/systems/spawn_director.gd <<'GD'
extends Node

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const ARENA_MIN: float = 32.0
const ARENA_MAX: float = 3168.0
const GUARANTEED_ELITES := [100.0, 280.0]

const STAGES := [
    {"start": 0.0,   "interval": 1.25,  "cap": 18, "weights": [100, 0, 0],   "name": "THE AWAKENING"},
    {"start": 90.0,  "interval": 0.833, "cap": 30, "weights": [65, 35, 0],   "name": "GATHERING SHADOWS"},
    {"start": 180.0, "interval": 0.556, "cap": 45, "weights": [40, 35, 25],  "name": "DEEPER INTO THE HOLLOW"},
    {"start": 300.0, "interval": 0.417, "cap": 65, "weights": [25, 40, 35],  "name": "THE FRACTURE"},
]

var countdown: float = 0.5
var next_elite_index: int = 0
var phase_name: String = "THE AWAKENING"

@onready var player: Node2D = get_node("../World/Actors/Player") as Node2D
@onready var container: Node2D = get_node("../World/Actors/Enemies") as Node2D
@onready var run_manager: Node = get_node("../RunManager")

func _physics_process(delta: float) -> void:
    if bool(run_manager.get("game_over")):
        return

    var elapsed: float = float(run_manager.get("elapsed_seconds"))
    var stage: Dictionary = _current_stage(elapsed)
    phase_name = String(stage["name"])
    var living_cap: int = int(stage["cap"])

    if next_elite_index < GUARANTEED_ELITES.size() \
            and elapsed >= float(GUARANTEED_ELITES[next_elite_index]) \
            and container.get_child_count() < living_cap:
        if _spawn_enemy(_pick_kind(stage), true, elapsed):
            next_elite_index += 1

    countdown -= delta
    if countdown > 0.0:
        return
    countdown = float(stage["interval"])
    if container.get_child_count() >= living_cap:
        return

    var is_fractured: bool = elapsed >= 240.0 and randf() < 0.08
    _spawn_enemy(_pick_kind(stage), is_fractured, elapsed)

func _current_stage(elapsed: float) -> Dictionary:
    var stage: Dictionary = STAGES[0]
    for candidate in STAGES:
        if elapsed >= float(candidate["start"]):
            stage = candidate
    return stage

func _pick_kind(stage: Dictionary) -> String:
    var weights: Array = stage["weights"]
    var roll: int = randi_range(1, 100)
    if roll <= int(weights[0]):
        return "husk"
    if roll <= int(weights[0]) + int(weights[1]):
        return "skitter"
    return "brute"

func _spawn_enemy(kind: String, elite: bool, elapsed: float) -> bool:
    var position_candidate: Vector2 = _find_offscreen_position()
    if position_candidate.x < 0.0:
        return false

    var enemy = ENEMY_SCENE.instantiate()
    enemy.call("configure", kind, elite, elapsed)
    container.add_child(enemy)
    enemy.global_position = position_candidate
    enemy.defeated.connect(Callable(run_manager, "on_enemy_defeated").bind(enemy))
    return true

func _find_offscreen_position() -> Vector2:
    var camera: Camera2D = player.get_node("Camera2D") as Camera2D
    var center: Vector2 = camera.get_screen_center_position()
    var half_size: Vector2 = get_viewport().get_visible_rect().size * 0.5 / camera.zoom
    var padding: float = 75.0

    for attempt in range(48):
        var p := Vector2.ZERO
        match randi_range(0, 3):
            0:
                p = center + Vector2(-half_size.x - padding, randf_range(-half_size.y, half_size.y))
            1:
                p = center + Vector2(half_size.x + padding, randf_range(-half_size.y, half_size.y))
            2:
                p = center + Vector2(randf_range(-half_size.x, half_size.x), -half_size.y - padding)
            3:
                p = center + Vector2(randf_range(-half_size.x, half_size.x), half_size.y + padding)
        if p.x >= ARENA_MIN and p.x <= ARENA_MAX \
                and p.y >= ARENA_MIN and p.y <= ARENA_MAX:
            return p
    return Vector2(-1.0, -1.0)
GD

# -----------------------------------------------------------------------------
# LOOT PICKUP: gold, healing heart, and elite Soul Cache (8 gold + 8 XP).
# Inherits the radius upgraded by Soul Magnet / Grasping Eye.
# -----------------------------------------------------------------------------
cat > scripts/systems/loot_pickup.gd <<'GD'
extends Area2D

signal collected(kind: String, amount: int)

@export_enum("gold", "heart", "cache") var kind: String = "gold"
@export var amount: int = 1
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
    var distance: float = global_position.distance_to(player.global_position)
    if distance <= 23.0:
        _collect()
        return
    var magnet_radius: float = float(run_manager.get("pickup_radius"))
    if distance <= magnet_radius:
        global_position = global_position.move_toward(player.global_position, magnet_speed * delta)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        _collect()

func _collect() -> void:
    if already_collected:
        return
    already_collected = true
    collected.emit(kind, amount)
    queue_free()

func _draw() -> void:
    match kind:
        "heart":
            draw_circle(Vector2.ZERO, 13.0, Color(0.9, 0.18, 0.3, 0.18))
            draw_circle(Vector2(-4, -3), 5.5, Color(0.95, 0.27, 0.35))
            draw_circle(Vector2(4, -3), 5.5, Color(0.95, 0.27, 0.35))
            draw_colored_polygon(PackedVector2Array([
                Vector2(-9, -1), Vector2(9, -1), Vector2(0, 10)
            ]), Color(0.95, 0.27, 0.35))
        "cache":
            draw_circle(Vector2.ZERO, 18.0, Color(0.58, 0.31, 0.97, 0.21))
            draw_colored_polygon(PackedVector2Array([
                Vector2(0, -15), Vector2(12, 0), Vector2(0, 14), Vector2(-12, 0)
            ]), Color(0.69, 0.41, 0.95))
            draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.89, 0.6))
        _:
            draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.76, 0.29, 0.20))
            draw_circle(Vector2.ZERO, 8.0, Color(0.95, 0.72, 0.25))
            draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.92, 0.55))
GD

cat > scenes/pickups/loot.tscn <<'TSCN'
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/systems/loot_pickup.gd" id="1_loot"]

[sub_resource type="CircleShape2D" id="CircleShape2D_loot"]
radius = 13.0

[node name="Loot" type="Area2D"]
collision_layer = 0
collision_mask = 1
monitoring = true
script = ExtResource("1_loot")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_loot")
TSCN

# -----------------------------------------------------------------------------
# SHOP MANAGER: data-driven offers, purchase caps, and applied player/spell stats.
# -----------------------------------------------------------------------------
cat > scripts/managers/shop_manager.gd <<'GD'
extends Node

const ITEMS = [
    {"id": "vessel",  "title": "CRACKED VESSEL",  "description": "+20 maximum HP and heal 20 HP",        "price": 12},
    {"id": "eye",     "title": "GRASPING EYE",    "description": "+50px pickup and magnet radius",     "price": 12},
    {"id": "boots",   "title": "FLEET BOOTS",     "description": "+12% movement speed",                 "price": 15},
    {"id": "charm",   "title": "SHATTERED CHARM", "description": "+20% damage for all spells",         "price": 18},
    {"id": "clock",   "title": "CLOCKBONE",       "description": "Spells cast 15% more frequently",   "price": 20},
    {"id": "shell",   "title": "VOID SHELL",      "description": "Take 15% less incoming damage",     "price": 22},
]

const MAX_COPIES_PER_ITEM: int = 2

var purchases: Dictionary = {}

@onready var player: Node = get_node("../World/Actors/Player")
@onready var spells: Node = get_node("../World/Actors/Player/SpellManager")
@onready var run_manager: Node = get_node("../RunManager")

func get_offers(count: int = 3) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []
    for item in ITEMS:
        var item_id: String = String(item["id"])
        if int(purchases.get(item_id, 0)) < MAX_COPIES_PER_ITEM:
            pool.append(item.duplicate(true))
    pool.shuffle()
    var selected: Array[Dictionary] = []
    for i in range(mini(count, pool.size())):
        selected.append(pool[i])
    return selected

func purchase_item(item_id: String, gold_available: int) -> int:
    # Return amount spent, or -1 if rejected. Caller checks selected offers.
    if int(purchases.get(item_id, 0)) >= MAX_COPIES_PER_ITEM:
        return -1
    var item: Dictionary = {}
    for option in ITEMS:
        if String(option["id"]) == item_id:
            item = option
            break
    if item.is_empty():
        return -1
    var price: int = int(item["price"])
    if gold_available < price:
        return -1

    match item_id:
        "vessel":
            player.set("max_health", int(player.get("max_health")) + 20)
            player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + 20))
        "eye":
            run_manager.set("pickup_radius", float(run_manager.get("pickup_radius")) + 50.0)
        "boots":
            player.set("speed", float(player.get("speed")) * 1.12)
        "charm":
            spells.call("multiply_damage", 1.20)
        "clock":
            spells.call("multiply_cooldown", 0.85)
        "shell":
            player.set("damage_taken_multiplier", float(player.get("damage_taken_multiplier")) * 0.85)
        _:
            return -1

    purchases[item_id] = int(purchases.get(item_id, 0)) + 1
    return price
GD

# -----------------------------------------------------------------------------
# SHOP UI: three random offer cards, clickable and keyboard accessible,
# clear disabled states for unaffordable choices, always allows a free skip.
# -----------------------------------------------------------------------------
cat > scripts/ui/shop_panel.gd <<'GD'
extends Control

signal item_requested(item_id: String)
signal shop_skipped

var available_offers: Array[Dictionary] = []
var buttons: Array[Button] = []
var title_label: Label
var gold_label: Label
var skip_button: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_interface()
    hide()

func show_offers(offers: Array[Dictionary], available_gold: int, visit_number: int) -> void:
    available_offers = offers
    title_label.text = "THE HOLLOW MERCHANT  |  VISIT %d / 3" % visit_number if visit_number > 0 else "THE HOLLOW MERCHANT  |  DEBUG VISIT"
    gold_label.text = "YOUR GOLD: %d  -  Buy ONE item or leave" % available_gold
    for i in range(buttons.size()):
        var button: Button = buttons[i]
        button.visible = i < available_offers.size()
        if not button.visible:
            continue
        var offer: Dictionary = available_offers[i]
        var price: int = int(offer["price"])
        var affordable: bool = available_gold >= price
        button.disabled = not affordable
        button.text = "%d  |  %s\n\n%s\n\n%d GOLD%s" % [
            i + 1, String(offer["title"]), String(offer["description"]),
            price, "" if affordable else "  (NOT ENOUGH)"
        ]
    show()
    var got_focus: bool = false
    for button in buttons:
        if button.visible and not button.disabled:
            button.grab_focus()
            got_focus = true
            break
    if not got_focus:
        skip_button.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
    if not visible or not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    var choice: int = -1
    match key_event.keycode:
        KEY_1:
            choice = 0
        KEY_2:
            choice = 1
        KEY_3:
            choice = 2
        KEY_0, KEY_ESCAPE:
            get_viewport().set_input_as_handled()
            _skip_shop()
            return
    if choice >= 0 and choice < available_offers.size():
        get_viewport().set_input_as_handled()
        _select_card(choice)

func _select_card(index: int) -> void:
    if not visible or index < 0 or index >= available_offers.size():
        return
    if buttons[index].disabled:
        return
    item_requested.emit(String(available_offers[index]["id"]))

func _skip_shop() -> void:
    if visible:
        shop_skipped.emit()

func _build_interface() -> void:
    var overlay := ColorRect.new()
    overlay.color = Color(0.01, 0.01, 0.035, 0.88)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var centering := CenterContainer.new()
    centering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centering)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(930.0, 365.0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.105, 0.09, 0.14)
    style.border_color = Color(0.72, 0.53, 0.22)
    style.set_border_width_all(3)
    style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel", style)
    centering.add_child(panel)

    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 22)
    margins.add_theme_constant_override("margin_right", 22)
    margins.add_theme_constant_override("margin_top", 20)
    margins.add_theme_constant_override("margin_bottom", 20)
    panel.add_child(margins)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 14)
    margins.add_child(content)

    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 27)
    title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.49))
    content.add_child(title_label)

    gold_label = Label.new()
    gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gold_label.add_theme_font_size_override("font_size", 17)
    gold_label.add_theme_color_override("font_color", Color(0.94, 0.89, 0.78))
    content.add_child(gold_label)

    var cards := HBoxContainer.new()
    cards.add_theme_constant_override("separation", 14)
    content.add_child(cards)

    for i in range(3):
        var button := Button.new()
        button.custom_minimum_size = Vector2(280.0, 185.0)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.add_theme_font_size_override("font_size", 16)
        button.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
        button.pressed.connect(_select_card.bind(i))
        cards.add_child(button)
        buttons.append(button)

    var hint := Label.new()
    hint.text = "Click a card or press 1 / 2 / 3  |  Escape / 0 skips the shop"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.72, 0.70, 0.81))
    content.add_child(hint)

    skip_button = Button.new()
    skip_button.name = "SkipButton"
    skip_button.text = "LEAVE MERCHANT  (FREE)"
    skip_button.custom_minimum_size = Vector2(260.0, 39.0)
    skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    skip_button.pressed.connect(_skip_shop)
    content.add_child(skip_button)
GD

cat > scenes/ui/shop_panel.tscn <<'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/shop_panel.gd" id="1_shop_ui"]

[node name="ShopPanel" type="Control"]
visible = false
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 0
process_mode = 3
script = ExtResource("1_shop_ui")
TSCN

# -----------------------------------------------------------------------------
# PLAYER: add the armor multiplier without replacing the working movement code.
# -----------------------------------------------------------------------------
python3 - <<'PY'
from pathlib import Path
p = Path('scripts/actors/player.gd')
s = p.read_text()
if 'var damage_taken_multiplier:' not in s:
    needle = 'var invulnerable_for: float = 0.0'
    if needle not in s:
        raise SystemExit('ERROR: could not patch player.gd: missing invulnerability variable.')
    s = s.replace(needle, needle + '\nvar damage_taken_multiplier: float = 1.0', 1)
if 'var adjusted_damage :=' not in s:
    needle = '    health = maxi(0, health - amount)'
    if needle not in s:
        raise SystemExit('ERROR: could not patch player.gd: missing damage line.')
    s = s.replace(needle,
        '    var adjusted_damage := maxi(1, roundi(float(amount) * damage_taken_multiplier))\n'
        '    health = maxi(0, health - adjusted_damage)', 1)
p.write_text(s)
PY

# -----------------------------------------------------------------------------
# RUN MANAGER: XP + loot, gold, schedule, modal coordination, debug controls.
# Keep all progression calls and the existing G hotkey.
# -----------------------------------------------------------------------------
cat > scripts/managers/run_manager.gd <<'GD'
extends Node

const XP_PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")
const LOOT_SCENE := preload("res://scenes/pickups/loot.tscn")
const SHOP_TIMES := [120.0, 240.0, 360.0]

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

@onready var player: Node = get_node("../World/Actors/Player")
@onready var pickups: Node2D = get_node("../World/Pickups") as Node2D
@onready var upgrade_manager: Node = get_node("../UpgradeManager")
@onready var shop_manager: Node = get_node("../ShopManager")
@onready var level_up_panel: Control = get_node("../UI/LevelUpPanel") as Control
@onready var shop_panel: Control = get_node("../UI/ShopPanel") as Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("run_manager")
    player.connect("died", Callable(self, "_on_player_died"))
    level_up_panel.connect("upgrade_selected", Callable(self, "_on_upgrade_selected"))
    shop_panel.connect("item_requested", Callable(self, "_on_item_requested"))
    shop_panel.connect("shop_skipped", Callable(self, "_on_shop_skipped"))

func _process(delta: float) -> void:
    # Actual gameplay time: it does not progress while leveling or shopping.
    if game_over or get_tree().paused:
        return
    elapsed_seconds += delta
    var whole_seconds: int = int(elapsed_seconds)
    if whole_seconds > scored_seconds:
        score += (whole_seconds - scored_seconds) * 2
        scored_seconds = whole_seconds
    if next_shop_index < SHOP_TIMES.size() \
            and elapsed_seconds >= float(SHOP_TIMES[next_shop_index]) \
            and not level_up_active and not shop_active:
        _open_shop(false)

func experience_needed() -> int:
    return 10 + 5 * (level - 1)

func seconds_to_next_shop() -> int:
    if next_shop_index >= SHOP_TIMES.size():
        return -1
    return maxi(0, ceili(float(SHOP_TIMES[next_shop_index]) - elapsed_seconds))

func on_enemy_defeated(points: int, defeated_enemy: Node2D) -> void:
    if game_over:
        return
    kills += 1
    score += points
    if not is_instance_valid(defeated_enemy):
        return

    # Capture all data now because the enemy is queue_free()'d after its signal.
    var origin: Vector2 = defeated_enemy.global_position
    var xp_amount: int = int(defeated_enemy.get("xp_reward"))
    var elite: bool = bool(defeated_enemy.get("fractured"))
    _spawn_rewards.call_deferred(origin, xp_amount, elite)

func _spawn_rewards(origin: Vector2, xp_amount: int, elite: bool) -> void:
    if game_over:
        return
    _spawn_xp_crystal(origin, xp_amount)

    if elite:
        # One guaranteed cache for every Fractured enemy: +8 gold and +8 XP.
        _spawn_loot(origin + Vector2(14, -8), "cache", 1)
    elif randf() < 0.25:
        _spawn_loot(origin + Vector2(10, -6), "gold", 1)
    if randf() < 0.01:
        _spawn_loot(origin + Vector2(-10, -6), "heart", 20)

func _spawn_xp_crystal(world_position: Vector2, amount: int) -> void:
    if game_over:
        return
    var crystal = XP_PICKUP_SCENE.instantiate()
    crystal.set("xp_amount", amount)
    pickups.add_child(crystal)
    crystal.global_position = world_position
    crystal.connect("collected", Callable(self, "gain_experience"))

func _spawn_loot(world_position: Vector2, kind: String, amount: int) -> void:
    if game_over:
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
    if game_over or get_tree().paused or level_up_active or shop_active:
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
    elif not game_over and not get_tree().paused and OS.is_debug_build():
        match key_event.keycode:
            KEY_G:
                gain_experience(maxi(1, experience_needed() - experience))
            KEY_H:
                gold += 30
            KEY_B:
                _open_shop(true)
GD

# -----------------------------------------------------------------------------
# HUD: gold, stage, and time remaining until the next merchant visit.
# -----------------------------------------------------------------------------
cat > scripts/ui/hud.gd <<'GD'
extends Control

@onready var player: Node = get_node("../../World/Actors/Player")
@onready var run_manager: Node = get_node("../../RunManager")
@onready var spawn_director: Node = get_node("../../SpawnDirector")
@onready var spells: Node = get_node("../../World/Actors/Player/SpellManager")
@onready var stats_label: Label = $Stats
@onready var xp_label: Label = $XPInfo
@onready var xp_bar: ProgressBar = $XPBar
@onready var spells_label: Label = $Spells
@onready var wave_label: Label = $WaveInfo
@onready var end_label: Label = $EndMessage

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    end_label.visible = false

func _process(_delta: float) -> void:
    var total_seconds: int = int(run_manager.get("elapsed_seconds"))
    stats_label.text = "HP %d/%d    GOLD %d    KILLS %d    SCORE %d    %02d:%02d" % [
        int(player.get("health")), int(player.get("max_health")),
        int(run_manager.get("gold")), int(run_manager.get("kills")),
        int(run_manager.get("score")), int(total_seconds / 60.0), total_seconds % 60
    ]
    var needed: int = int(run_manager.call("experience_needed"))
    xp_label.text = "LEVEL %d    XP %d / %d" % [
        int(run_manager.get("level")), int(run_manager.get("experience")), needed
    ]
    xp_bar.max_value = needed
    xp_bar.value = int(run_manager.get("experience"))
    spells_label.text = "Soul Needle %d   |   Void Pulse %d   |   Orbiting Shade %d" % [
        int(spells.get("needle_level")), int(spells.get("pulse_level")),
        int(spells.get("shade_level"))
    ]
    var remaining: int = int(run_manager.call("seconds_to_next_shop"))
    var shop_text: String = "No more merchant visits"
    if remaining >= 0:
        shop_text = "Merchant in %02d:%02d" % [int(remaining / 60.0), remaining % 60]
    wave_label.text = "WAVE: %s     |     %s" % [String(spawn_director.get("phase_name")), shop_text]
    end_label.visible = bool(run_manager.get("game_over"))
GD

python3 - <<'PY'
from pathlib import Path

p = Path('scenes/ui/hud.tscn')
s = p.read_text()
# Keep the level and XP UI introduced in Milestone 2 intact.
s = s.replace('offset_right = 1080.0\noffset_bottom = 45.0',
              'offset_right = 1260.0\noffset_bottom = 45.0', 1)
s = s.replace('theme_override_font_sizes/font_size = 22\ntext = "HP 100/100',
              'theme_override_font_sizes/font_size = 20\ntext = "HP 100/100', 1)
s = s.replace('text = "HP 100/100    Kills 0    Score 0    00:00"',
              'text = "HP 100/100    GOLD 0    KILLS 0    SCORE 0    00:00"', 1)
s = s.replace('text = "WASD / arrows: move   |   Collect blue XP   |   G: debug level-up (editor)"',
              'text = "WASD: move  |  G: level up  H: +30 gold  B: test shop  N: +1 minute (debug only)"', 1)
if '[node name="WaveInfo" type="Label" parent="."]' not in s:
    s += '''\n\n[node name="WaveInfo" type="Label" parent="."]
layout_mode = 0
offset_left = 22.0
offset_top = 142.0
offset_right = 1100.0
offset_bottom = 170.0
theme_override_colors/font_color = Color(0.93, 0.77, 0.51, 1)
theme_override_font_sizes/font_size = 17
text = "WAVE: THE AWAKENING     |     Merchant in 02:00"
'''
p.write_text(s)

# Main scene: append shop manager / UI without disturbing existing nodes.
p = Path('scenes/main.tscn')
s = p.read_text()
if 'id="8_shop_manager"' not in s:
    import re
    match = re.search(r'^\[gd_scene load_steps=(\d+) format=3\]', s, re.M)
    if not match:
        raise SystemExit('ERROR: main scene header is unexpected. Original saved in backup.')
    s = s.replace(match.group(0), f'[gd_scene load_steps={int(match.group(1)) + 2} format=3]', 1)
    resources = (
        '[ext_resource type="Script" path="res://scripts/managers/shop_manager.gd" id="8_shop_manager"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/ui/shop_panel.tscn" id="9_shop_ui"]\n\n'
    )
    marker = '[node name="Main" type="Node2D"]'
    if marker not in s:
        raise SystemExit('ERROR: could not locate Main node.')
    s = s.replace(marker, resources + marker, 1)
    marker = '[node name="UI" type="CanvasLayer" parent="."]'
    if marker not in s:
        raise SystemExit('ERROR: could not locate the UI CanvasLayer.')
    s = s.replace(marker,
        '[node name="ShopManager" type="Node" parent="."]\n'
        'script = ExtResource("8_shop_manager")\n\n' + marker, 1)
    s = s.rstrip() + '\n\n[node name="ShopPanel" parent="UI" instance=ExtResource("9_shop_ui")]\nvisible = false\n'
    p.write_text(s)

# A compact local guide for teammates.
Path('MILESTONE_3_NOTES.md').write_text("""# HOLLOW - Milestone 3

Adds three enemy archetypes, scaled enemy waves, Fractured elites,
gold/heart/cache drops, and a merchant shop.

## During play
- Move: WASD / arrow keys.
- Every enemy drops XP; normal enemies also have a 25% chance of gold and 1% chance of a heart.
- Fractured elites have purple auras and drop a guaranteed 8 XP + 8 gold cache.
- Merchant visits: 02:00, 04:00, and 06:00 (unpaused gameplay time).
- Buy one of three randomly chosen items or skip. Each item can be purchased twice per run.

## Debug shortcuts (editor / debug builds only)
- G: grant enough XP for a level-up.
- H: grant 30 gold.
- B: open a test merchant without consuming a scheduled visit.
- N: advance the clock by one minute for shop/spawn testing.
- R: restart after death.

## Source files
- scripts/actors/enemy.gd: three enemy types and Fractured modifiers.
- scripts/systems/spawn_director.gd: timed/weighted spawns and elite encounters.
- scripts/systems/loot_pickup.gd: gold/heart/cache pickups.
- scripts/managers/run_manager.gd: gold, XP, scheduled shop interactions.
- scripts/managers/shop_manager.gd: item options and their effects.
- scripts/ui/shop_panel.gd: shop UI and buttons.
""")
print('HOLLOW Milestone 3 scene references and HUD installed.')
PY

# Fast forward in editor for checking wave progression; never available in
# release mode, and avoid granting survival points for skipped time.
python3 - <<'PY'
from pathlib import Path
p = Path('scripts/managers/run_manager.gd')
s = p.read_text()
old = '''            KEY_B:
                _open_shop(true)
'''
new = '''            KEY_B:
                _open_shop(true)
            KEY_N:
                elapsed_seconds += 60.0
                scored_seconds = int(elapsed_seconds)
'''
if old not in s:
    raise SystemExit('ERROR: could not add debug clock shortcut.')
p.write_text(s.replace(old, new, 1))
PY

printf '\nSUCCESS: HOLLOW Milestone 3 installed.\n'
printf 'Original files backed up in: %s\n' "$BACKUP"
echo 'Launch Godot, press F5, and test G (XP), H (+30 gold), B (shop), N (+1 minute).'
echo 'Merchant visits at 02:00, 04:00 and 06:00 of unpaused gameplay.'
echo 'Read MILESTONE_3_NOTES.md for team handoff.'
