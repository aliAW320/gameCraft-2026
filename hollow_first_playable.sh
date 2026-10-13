#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f project.godot ]]; then
  echo 'Error: run this script inside your Godot project root (contains project.godot).' >&2
  exit 1
fi

# This installer replaces starter placeholders, so preserve the original files.
BACKUP=".hollow_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"
FILES=(
  project.godot
  scenes/main.tscn
  scenes/player/player.tscn
  scenes/enemies/enemy.tscn
  scenes/spells/projectile.tscn
  scenes/ui/hud.tscn
  scripts/actors/player.gd
  scripts/actors/enemy.gd
  scripts/systems/arena.gd
  scripts/systems/spawn_director.gd
  scripts/systems/spell_manager.gd
  scripts/systems/projectile.gd
  scripts/managers/run_manager.gd
  scripts/ui/hud.gd
)
for file in "${FILES[@]}"; do
  if [[ -f "$file" ]]; then
    cp --parents -- "$file" "$BACKUP"
  fi
done
mkdir -p scenes/{player,enemies,spells,ui} scripts/{actors,systems,managers,ui}

cat > scripts/systems/arena.gd <<'GD'
extends Node2D

const ARENA_SIZE := Vector2(3200.0, 3200.0)
const TILE_SIZE := 128

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.08, 0.09, 0.13))
    for x in range(0, int(ARENA_SIZE.x), TILE_SIZE):
        for y in range(0, int(ARENA_SIZE.y), TILE_SIZE):
            var even_tile := ((x / TILE_SIZE) + (y / TILE_SIZE)) % 2 == 0
            var shade := Color(0.115, 0.12, 0.18) if even_tile else Color(0.10, 0.105, 0.16)
            var tile := Rect2(float(x), float(y), float(TILE_SIZE), float(TILE_SIZE))
            draw_rect(tile, shade)
            draw_rect(tile, Color(0.22, 0.20, 0.30, 0.18), false, 1.0)

    draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.48, 0.32, 0.64), false, 20.0)
    var center := ARENA_SIZE / 2.0
    draw_arc(center, 156.0, 0.0, TAU, 80, Color(0.48, 0.28, 0.72, 0.5), 3.0)
    draw_arc(center, 90.0, 0.0, TAU, 64, Color(0.27, 0.59, 0.67, 0.4), 2.0)
    for i in range(32):
        var p := Vector2(float(160 + (i * 719) % 2860), float(160 + (i * 1009) % 2860))
        draw_line(p + Vector2(-11.0, -5.0), p + Vector2(12.0, 7.0), Color(0.38, 0.25, 0.51, 0.42), 2.0)
        draw_line(p + Vector2(12.0, 7.0), p + Vector2(5.0, 14.0), Color(0.38, 0.25, 0.51, 0.42), 2.0)
GD

cat > scripts/actors/player.gd <<'GD'
extends CharacterBody2D

signal died

@export var speed: float = 185.0
@export var max_health: int = 100

var health: int = 100
var invulnerable_for: float = 0.0

func _ready() -> void:
    add_to_group("player")
    health = max_health

func _physics_process(delta: float) -> void:
    if health <= 0:
        return

    invulnerable_for = maxf(0.0, invulnerable_for - delta)
    var horizontal := 0.0
    var vertical := 0.0
    if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
        horizontal -= 1.0
    if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
        horizontal += 1.0
    if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
        vertical -= 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
        vertical += 1.0

    velocity = Vector2(horizontal, vertical).normalized() * speed
    move_and_slide()
    global_position = Vector2(
        clampf(global_position.x, 20.0, 3180.0),
        clampf(global_position.y, 20.0, 3180.0)
    )
    if invulnerable_for > 0.0:
        queue_redraw()

func take_damage(amount: int) -> void:
    if health <= 0 or invulnerable_for > 0.0:
        return
    health = maxi(0, health - amount)
    invulnerable_for = 0.75
    queue_redraw()
    if health == 0:
        died.emit()

func _draw() -> void:
    draw_circle(Vector2(0.0, 11.0), 17.0, Color(0.0, 0.0, 0.0, 0.35))
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -18.0), Vector2(-15.0, 9.0),
            Vector2(-9.0, 18.0), Vector2(9.0, 18.0), Vector2(15.0, 9.0)
        ]),
        Color(0.20, 0.24, 0.36)
    )
    draw_circle(Vector2(0.0, -6.0), 11.0, Color(0.09, 0.11, 0.20))
    draw_circle(Vector2(-4.0, -7.0), 2.0, Color(0.45, 0.91, 1.0))
    draw_circle(Vector2(4.0, -7.0), 2.0, Color(0.45, 0.91, 1.0))
    if invulnerable_for > 0.0:
        draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 36, Color(0.40, 0.82, 1.0, 0.65), 2.0)
GD

cat > scripts/actors/enemy.gd <<'GD'
extends CharacterBody2D

signal defeated(points: int)

@export var speed: float = 72.0
@export var max_health: int = 28
@export var contact_damage: int = 8

var health: int = 28
var hit_flash: float = 0.0
var player: Node2D

func _ready() -> void:
    add_to_group("enemies")
    health = max_health
    player = get_tree().get_first_node_in_group("player") as Node2D

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    if hit_flash > 0.0:
        hit_flash = maxf(0.0, hit_flash - delta)
        queue_redraw()

    var to_player := player.global_position - global_position
    velocity = to_player.normalized() * speed
    move_and_slide()
    if global_position.distance_squared_to(player.global_position) <= 29.0 * 29.0:
        player.call("take_damage", contact_damage)

func take_damage(amount: int) -> void:
    if health <= 0:
        return
    health -= amount
    if health <= 0:
        defeated.emit(10)
        queue_free()
    else:
        hit_flash = 0.12
        queue_redraw()

func _draw() -> void:
    var body_color := Color(1.0, 0.66, 0.75) if hit_flash > 0.0 else Color(0.46, 0.22, 0.34)
    draw_circle(Vector2(0.0, 6.0), 14.0, Color(0.0, 0.0, 0.0, 0.22))
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -16.0), Vector2(-13.0, -6.0), Vector2(-12.0, 11.0),
            Vector2(0.0, 15.0), Vector2(12.0, 11.0), Vector2(13.0, -6.0)
        ]),
        body_color
    )
    draw_circle(Vector2(-4.0, -3.0), 2.0, Color(1.0, 0.84, 0.91))
    draw_circle(Vector2(4.0, -3.0), 2.0, Color(1.0, 0.84, 0.91))
GD

cat > scripts/systems/projectile.gd <<'GD'
extends Area2D

@export var speed: float = 580.0
@export var damage: int = 14
@export var lifetime: float = 1.15

var direction := Vector2.RIGHT

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func setup(shot_direction: Vector2) -> void:
    direction = shot_direction.normalized()

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node2D) -> void:
    if is_queued_for_deletion():
        return
    if body.is_in_group("enemies"):
        body.call("take_damage", damage)
        queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 9.0, Color(0.33, 0.77, 1.0, 0.25))
    draw_circle(Vector2.ZERO, 5.0, Color(0.64, 0.94, 1.0))
GD

cat > scripts/systems/spell_manager.gd <<'GD'
extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/spells/projectile.tscn")

@export var cast_interval: float = 0.70
@export var target_range: float = 460.0

var time_until_cast: float = 0.15
@onready var projectiles: Node2D = get_node("../../../Projectiles") as Node2D

func _physics_process(delta: float) -> void:
    time_until_cast -= delta
    if time_until_cast > 0.0:
        return
    var target := _find_nearest_enemy()
    if target == null:
        return

    var projectile = PROJECTILE_SCENE.instantiate()
    projectiles.add_child(projectile)
    projectile.global_position = global_position
    projectile.call("setup", (target.global_position - global_position).normalized())
    time_until_cast = cast_interval

func _find_nearest_enemy() -> Node2D:
    var closest: Node2D = null
    var best_distance_sq := target_range * target_range
    for node in get_tree().get_nodes_in_group("enemies"):
        if node.is_queued_for_deletion():
            continue
        var enemy := node as Node2D
        if enemy == null:
            continue
        var distance_sq := global_position.distance_squared_to(enemy.global_position)
        if distance_sq < best_distance_sq:
            best_distance_sq = distance_sq
            closest = enemy
    return closest
GD

cat > scripts/systems/spawn_director.gd <<'GD'
extends Node

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const ARENA_MIN := 32.0
const ARENA_MAX := 3168.0

@export var seconds_between_spawns: float = 1.0
@export var maximum_enemies: int = 24

var countdown: float = 0.5
@onready var player: Node2D = get_node("../World/Actors/Player") as Node2D
@onready var container: Node2D = get_node("../World/Actors/Enemies") as Node2D
@onready var run_manager = get_node("../RunManager")

func _physics_process(delta: float) -> void:
    countdown -= delta
    if countdown > 0.0:
        return
    countdown = seconds_between_spawns
    if container.get_child_count() >= maximum_enemies:
        return
    _spawn_enemy()

func _spawn_enemy() -> void:
    var camera: Camera2D = player.get_node("Camera2D") as Camera2D
    var center := camera.get_screen_center_position()
    var half_size := get_viewport().get_visible_rect().size * 0.5 / camera.zoom
    var spawn_pos := Vector2.ZERO
    var valid_spawn := false

    for _attempt in range(20):
        match randi_range(0, 3):
            0:
                spawn_pos = center + Vector2(-half_size.x - 65.0, randf_range(-half_size.y, half_size.y))
            1:
                spawn_pos = center + Vector2(half_size.x + 65.0, randf_range(-half_size.y, half_size.y))
            2:
                spawn_pos = center + Vector2(randf_range(-half_size.x, half_size.x), -half_size.y - 65.0)
            3:
                spawn_pos = center + Vector2(randf_range(-half_size.x, half_size.x), half_size.y + 65.0)
        if spawn_pos.x >= ARENA_MIN and spawn_pos.x <= ARENA_MAX \
                and spawn_pos.y >= ARENA_MIN and spawn_pos.y <= ARENA_MAX:
            valid_spawn = true
            break

    if not valid_spawn:
        return

    var enemy = ENEMY_SCENE.instantiate()
    container.add_child(enemy)
    enemy.global_position = spawn_pos
    enemy.defeated.connect(Callable(run_manager, "on_enemy_defeated"))
GD

cat > scripts/managers/run_manager.gd <<'GD'
extends Node

var elapsed_seconds: float = 0.0
var score: int = 0
var kills: int = 0
var game_over: bool = false
var scored_seconds: int = 0

@onready var player = get_node("../World/Actors/Player")

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    player.died.connect(_on_player_died)

func _process(delta: float) -> void:
    if game_over:
        return
    elapsed_seconds += delta
    var whole_seconds := int(elapsed_seconds)
    if whole_seconds > scored_seconds:
        score += (whole_seconds - scored_seconds) * 2
        scored_seconds = whole_seconds

func on_enemy_defeated(points: int) -> void:
    if game_over:
        return
    kills += 1
    score += points

func _on_player_died() -> void:
    game_over = true
    get_tree().paused = true

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and game_over and event.pressed and not event.echo and event.keycode == KEY_R:
        get_tree().paused = false
        get_tree().reload_current_scene()
GD

cat > scripts/ui/hud.gd <<'GD'
extends Control

@onready var player = get_node("../../World/Actors/Player")
@onready var run_manager = get_node("../../RunManager")
@onready var stats_label: Label = $Stats
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
    end_label.visible = run_manager.game_over
GD

cat > scenes/player/player.tscn <<'TSCN'
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/actors/player.gd" id="1_player"]
[ext_resource type="Script" path="res://scripts/systems/spell_manager.gd" id="2_spell"]

[sub_resource type="CircleShape2D" id="CircleShape2D_player"]
radius = 14.0

[node name="Player" type="CharacterBody2D"]
collision_layer = 1
collision_mask = 4
motion_mode = 1
script = ExtResource("1_player")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_player")

[node name="SpellManager" type="Node2D" parent="."]
script = ExtResource("2_spell")

[node name="Camera2D" type="Camera2D" parent="."]
current = true
limit_left = 0
limit_top = 0
limit_right = 3200
limit_bottom = 3200
position_smoothing_enabled = true
position_smoothing_speed = 8.0
TSCN

cat > scenes/enemies/enemy.tscn <<'TSCN'
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/actors/enemy.gd" id="1_enemy"]

[sub_resource type="CircleShape2D" id="CircleShape2D_enemy"]
radius = 13.0

[node name="Enemy" type="CharacterBody2D"]
collision_layer = 2
collision_mask = 4
motion_mode = 1
script = ExtResource("1_enemy")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_enemy")
TSCN

cat > scenes/spells/projectile.tscn <<'TSCN'
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/systems/projectile.gd" id="1_projectile"]

[sub_resource type="CircleShape2D" id="CircleShape2D_projectile"]
radius = 6.0

[node name="Projectile" type="Area2D"]
collision_layer = 0
collision_mask = 2
monitoring = true
script = ExtResource("1_projectile")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_projectile")
TSCN

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
offset_right = 1060.0
offset_bottom = 48.0
theme_override_colors/font_color = Color(0.88, 0.95, 1.0, 1)
theme_override_font_sizes/font_size = 22
text = "HP 100/100    Kills 0    Score 0    00:00"

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
text = "WASD / arrows: move     |     Soul Needle: fires automatically"
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

cat > scenes/main.tscn <<'TSCN'
[gd_scene load_steps=6 format=3]

[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="1_player"]
[ext_resource type="PackedScene" path="res://scenes/ui/hud.tscn" id="2_hud"]
[ext_resource type="Script" path="res://scripts/systems/arena.gd" id="3_arena"]
[ext_resource type="Script" path="res://scripts/systems/spawn_director.gd" id="4_spawner"]
[ext_resource type="Script" path="res://scripts/managers/run_manager.gd" id="5_run"]

[node name="Main" type="Node2D"]

[node name="World" type="Node2D" parent="."]

[node name="ArenaVisual" type="Node2D" parent="World"]
script = ExtResource("3_arena")

[node name="Ground" type="TileMapLayer" parent="World"]

[node name="GroundDecorations" type="Node2D" parent="World"]

[node name="Actors" type="Node2D" parent="World"]
y_sort_enabled = true

[node name="Player" parent="World/Actors" instance=ExtResource("1_player")]
position = Vector2(1600, 1600)

[node name="Enemies" type="Node2D" parent="World/Actors"]

[node name="Obstacles" type="Node2D" parent="World/Actors"]

[node name="Projectiles" type="Node2D" parent="World"]

[node name="Pickups" type="Node2D" parent="World"]

[node name="ArenaBoundaries" type="StaticBody2D" parent="World"]

[node name="SpawnDirector" type="Node" parent="."]
script = ExtResource("4_spawner")

[node name="RunManager" type="Node" parent="."]
script = ExtResource("5_run")

[node name="UI" type="CanvasLayer" parent="."]

[node name="HUD" parent="UI" instance=ExtResource("2_hud")]
TSCN

# Set the main scene without disturbing other project settings.
python3 - <<'PY'
from pathlib import Path
import re
p = Path('project.godot')
s = p.read_text()
setting = 'run/main_scene="res://scenes/main.tscn"'
if re.search(r'(?m)^run/main_scene\s*=.*$', s):
    s = re.sub(r'(?m)^run/main_scene\s*=.*$', setting, s, count=1)
elif '[application]' in s:
    s = s.replace('[application]', '[application]\n' + setting, 1)
else:
    s += '\n[application]\n' + setting + '\n'
p.write_text(s)
PY

echo
printf 'HOLLOW playable slice installed. Backups: %s\n' "$BACKUP"
echo 'Open Godot, open scenes/main.tscn, press F5, use WASD/arrow keys.'
echo 'Enemies chase, Soul Needle fires automatically, and R restarts after defeat.'
