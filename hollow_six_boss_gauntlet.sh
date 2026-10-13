#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
from datetime import datetime
import os, re, sys, shutil

root = Path.cwd()
if not (root / 'project.godot').is_file():
    raise SystemExit('ERROR: Run in the Godot project root alongside project.godot. Nothing changed.')

required = [
    'scenes/main.tscn',
    'scenes/enemies/boss.tscn',
    'scripts/managers/run_manager.gd',
    'scripts/ui/boss_bar.gd',
    'scripts/ui/hud.gd',
    'scripts/ui/end_screen.gd',
    'scripts/systems/spawn_director.gd',
    'scripts/actors/boss.gd',
]
for rel in required:
    if not (root / rel).is_file():
        raise SystemExit(f'ERROR: Missing {rel}. Install previous milestones first. Nothing changed.')

original = {rel: (root / rel).read_text(encoding='utf-8') for rel in required}
rm = 'scripts/managers/run_manager.gd'
scene_path = 'scenes/enemies/boss.tscn'
boss_script_path = 'scripts/actors/boss_gauntlet.gd'

if 'HOLLOW_M7_GAUNTLET' in original[rm]:
    if (root / boss_script_path).is_file() and 'boss_gauntlet.gd' in original[scene_path]:
        print('Milestone 7 already installed; no files changed.')
        sys.exit(0)
    raise SystemExit('ERROR: Partial Milestone 7 installation detected; restore its backup first. Nothing changed.')
if (root / boss_script_path).exists() or 'boss_gauntlet.gd' in original[scene_path]:
    raise SystemExit('ERROR: Gauntlet files already exist; nothing changed. Inspect your project before retrying.')

# Refuse to patch a different/custom boss system rather than clobbering it.
checks = {
    rm: ['const BOSS_TIME: float = 420.0', 'func _start_boss_encounter()',
         'func _on_boss_defeated()', 'func _process(delta: float)', 'func _finish_run',
         'func _m5_boss_entrance', 'const SHOP_TIMES :=', 'KEY_K:', 'KEY_J:'],
    scene_path: ['type="Script" path="res://scripts/actors/boss.gd"',
                 '[node name="HollowGuardian"'],
    'scripts/ui/boss_bar.gd': ['func _process(_delta: float)', 'boss_name.text'],
    'scripts/ui/hud.gd': ['func _process(_delta: float)', 'wave_label.text'],
    'scripts/ui/end_screen.gd': ['func show_result', 'subheading.text ='],
}
for rel, markers in checks.items():
    for marker in markers:
        if marker not in original[rel]:
            raise SystemExit(f'ERROR: {rel} differs from the expected M6 version ({marker!r} missing). Nothing changed. Share that file to adapt safely.')

staged = dict(original)

def replace_one(rel: str, before: str, after: str) -> None:
    count = staged[rel].count(before)
    if count != 1:
        raise SystemExit(f'ERROR: Cannot safely patch {rel}; found {count} copies of {before[:68]!r}. Nothing changed.')
    staged[rel] = staged[rel].replace(before, after, 1)

def swap_func(rel: str, name: str, replacement: str) -> None:
    pattern = re.compile(r'(?ms)^func ' + re.escape(name) + r'\(.*?(?=^func |\Z)')
    result, count = pattern.subn(lambda m: replacement.rstrip() + '\n\n', staged[rel])
    if count != 1:
        raise SystemExit(f'ERROR: Cannot safely replace {name} in {rel} (found {count}). Nothing changed.')
    staged[rel] = result

replace_one(rm, 'const SHOP_TIMES := [120.0, 240.0, 360.0]\nconst BOSS_TIME: float = 420.0', '''# HOLLOW_M7_GAUNTLET: a six-minute survival clock plus six escalating bosses.
# Four regular checkpoints are 90 seconds apart; two extra encounters fill gaps.
const SHOP_TIMES := [120.0, 240.0, 330.0]
const RUN_LENGTH: float = 360.0
const BOSS_SCHEDULE := [
    {"time": 90.0, "title": "THE ASH WARDEN"},
    {"time": 135.0, "title": "THE VEIL STALKER"},
    {"time": 180.0, "title": "THE THORN ORACLE"},
    {"time": 270.0, "title": "THE RIFT COLOSSUS"},
    {"time": 315.0, "title": "THE MIRROR SERAPH"},
    {"time": 360.0, "title": "THE HOLLOW SOVEREIGN"},
]''')
replace_one(rm, 'var boss: Node2D = null', '''var boss: Node2D = null
var next_boss_index: int = 0
var active_boss_index: int = -1
var bosses_defeated: int = 0
var pending_boss_experience: int = 0''')

swap_func(rm, '_process', '''func _process(delta: float) -> void:
    if game_over or get_tree().paused:
        return
    _m5_tick_surge(delta)
    # The 6:00 clock stops here during the final fight, not at 7:00.
    elapsed_seconds = minf(RUN_LENGTH, elapsed_seconds + delta)
    var whole_seconds: int = int(elapsed_seconds)
    if whole_seconds > scored_seconds:
        score += (whole_seconds - scored_seconds) * 2
        scored_seconds = whole_seconds

    # Grant boss rewards only after Void Lightning and modal pauses end.
    if pending_boss_experience > 0:
        var xp_reward: int = pending_boss_experience
        pending_boss_experience = 0
        gain_experience(xp_reward)
        if get_tree().paused:
            return

    if boss_active or level_up_active or shop_active:
        return

    # Shop visits postponed by boss fights happen before the NEXT boss.
    if next_shop_index < SHOP_TIMES.size() \\
            and elapsed_seconds >= float(SHOP_TIMES[next_shop_index]):
        _open_shop(false)
        return

    # If a previous boss ran long, its next checkpoint waits in the queue.
    if next_boss_index < BOSS_SCHEDULE.size() \\
            and elapsed_seconds >= float(BOSS_SCHEDULE[next_boss_index]["time"]):
        _start_boss_encounter()
''')

replace_one(rm, 'func seconds_to_next_shop() -> int:', '''func seconds_to_next_boss() -> int:
    if boss_active or next_boss_index >= BOSS_SCHEDULE.size():
        return -1
    return maxi(0, ceili(float(BOSS_SCHEDULE[next_boss_index]["time"]) - elapsed_seconds))

func seconds_to_next_shop() -> int:''')

swap_func(rm, '_start_boss_encounter', '''func _start_boss_encounter() -> void:
    if game_over or boss_active or level_up_active or shop_active or get_tree().paused:
        return
    if next_boss_index >= BOSS_SCHEDULE.size():
        return
    active_boss_index = next_boss_index
    next_boss_index += 1
    boss_active = true
    spawn_director.set("phase_name", String(BOSS_SCHEDULE[active_boss_index]["title"]))

    # Only one boss at a time, and never alongside the normal enemy swarm.
    for enemy in enemies.get_children():
        enemy.queue_free()
    for projectile in player_projectiles.get_children():
        projectile.queue_free()

    var guardian: CharacterBody2D = BOSS_SCENE.instantiate() as CharacterBody2D
    if guardian == null:
        push_error("Cannot instantiate Gauntlet boss scene")
        boss_active = false
        return
    guardian.call("configure_boss", active_boss_index)
    enemies.add_child(guardian)
    boss = guardian
    boss.global_position = _boss_spawn_position()
    guardian.connect("defeated", Callable(self, "_on_boss_defeated"))
    _m5_boss_entrance()
''')

swap_func(rm, '_on_boss_defeated', '''func _on_boss_defeated() -> void:
    if game_over or not boss_active:
        return
    var stage: int = active_boss_index
    var origin: Vector2 = boss.global_position if is_instance_valid(boss) else player.global_position
    boss_active = false
    boss = null  # Prevent stale/freed object references in the HUD.
    bosses_defeated += 1
    kills += 1
    score += [220, 350, 550, 750, 1100, 1800][stage]
    enemy_killed.emit(origin, true)
    _m5_gain_charge(true)

    # Remove leftover hostile projectiles before resuming the swarm.
    for projectile in player_projectiles.get_children():
        if projectile.is_in_group("boss_projectile") or projectile.get_script() == preload("res://scripts/systems/boss_bolt.gd"):
            projectile.queue_free()

    if bosses_defeated >= BOSS_SCHEDULE.size():
        _finish_run(true)
        return
    gold += 6 + stage * 3
    player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + 12))
    pending_boss_experience += 14 + stage * 7
    spawn_director.set("phase_name", "THE HOLLOW STIRS")
''')

# The previous `K` debug shortcut now summons the NEXT boss.
replace_one(rm, '''        KEY_J:
            if boss_active and is_instance_valid(boss):
                debug_modified = true
                boss.call("take_damage", 400)
''', '''        KEY_J:
            if boss_active and is_instance_valid(boss):
                debug_modified = true
                boss.call("take_damage", 400)
        KEY_O:
            if boss_active and is_instance_valid(boss):
                debug_modified = true
                boss.call("take_damage", int(boss.get("health")) * 3)
''')

# Keep the full scene, UID, and all art nodes; only swap the Script resource path.
replace_one(scene_path,
    'type="Script" path="res://scripts/actors/boss.gd"',
    'type="Script" path="res://scripts/actors/boss_gauntlet.gd"')

replace_one('scripts/ui/boss_bar.gd', '''    show()
    health_bar.max_value = float(guardian.get("max_health"))''', '''    show()
    var boss_num: int = int(run_manager.get("active_boss_index")) + 1
    var boss_title: String = String(guardian.get("display_name"))
    var exposed: bool = int(guardian.get("state")) == 4 and boss_num >= 3
    boss_name.text = "%d/6  %s%s" % [boss_num, boss_title, "  [EXPOSED]" if exposed else ""]
    health_bar.max_value = float(guardian.get("max_health"))''')

replace_one('scripts/ui/hud.gd', '''    wave_label.text = "WAVE: %s     |     %s" % [String(spawn_director.get("phase_name")), shop_text]''', '''    var boss_info: String = ""
    if bool(run_manager.get("boss_active")):
        boss_info = "BOSS %d/6 - %s" % [
            int(run_manager.get("active_boss_index")) + 1,
            String(spawn_director.get("phase_name"))
        ]
    else:
        var till_boss: int = int(run_manager.call("seconds_to_next_boss"))
        if till_boss >= 0:
            boss_info = "NEXT BOSS %02d:%02d   |   %d/6 defeated" % [
                int(till_boss / 60.0), till_boss % 60, int(run_manager.get("bosses_defeated"))]
        else:
            boss_info = "FINAL SHOWDOWN"
    wave_label.text = "%s     |     %s" % [boss_info, shop_text]''')

replace_one('scripts/ui/end_screen.gd', '''    subheading.text = "The Guardian has been defeated." if did_win else "Your vessel has been shattered."''', '''    var defeated_count: int = int(get_node("../../RunManager").get("bosses_defeated"))
    subheading.text = "All six Guardians have fallen. The Hollow is silent." if did_win else \\
        "Your vessel shattered after defeating %d/6 Guardians." % defeated_count''')

# Additional unit tests on the staged files before any backup/writes.
assert 'next_shop_index = SHOP_TIMES.size()' not in staged[rm]
assert 'elapsed_seconds >= BOSS_TIME' not in staged[rm]
assert 'boss = null' in staged[rm]
assert 'HOLLOW_M7_GAUNTLET' in staged[rm]
assert 'boss_gauntlet.gd' in staged[scene_path]
assert len(re.findall(r'(?m)^func _start_boss_encounter\(', staged[rm])) == 1
assert len(re.findall(r'(?m)^func _on_boss_defeated\(', staged[rm])) == 1

boss_source = r'''extends CharacterBody2D

# HOLLOW M7: six bosses use the same scene, collision and spell target group,
# but each has a separate attack script, timings, appearance tint and armor.
signal defeated

const BOLT_SCENE := preload("res://scenes/spells/boss_bolt.tscn")
const MIN_ARENA: float = 62.0
const MAX_ARENA: float = 3138.0

const SPECS := [
    {"name": "THE ASH WARDEN", "health": 365, "speed": 66.0, "color": Color(0.95, 0.68, 0.56), "reward": 220},
    {"name": "THE VEIL STALKER", "health": 530, "speed": 106.0, "color": Color(0.63, 0.92, 1.0), "reward": 350},
    {"name": "THE THORN ORACLE", "health": 755, "speed": 77.0, "color": Color(0.87, 0.67, 1.0), "reward": 550},
    {"name": "THE RIFT COLOSSUS", "health": 1050, "speed": 52.0, "color": Color(1.0, 0.68, 0.86), "reward": 750},
    {"name": "THE MIRROR SERAPH", "health": 1360, "speed": 99.0, "color": Color(0.64, 0.96, 0.93), "reward": 1100},
    {"name": "THE HOLLOW SOVEREIGN", "health": 1980, "speed": 93.0, "color": Color(0.90, 0.61, 1.0), "reward": 1800},
]

enum State { INTRO, WALK, WARNING, DASH, RECOVERY }

@export var max_health: int = 365
var health: int = 365
var variant_index: int = 0
var display_name: String = "THE ASH WARDEN"
var walking_speed: float = 66.0
var state: State = State.INTRO
var state_timer: float = 0.8
var attack_step: int = 0
var attack_kind: String = "fan"
var warning_total: float = 0.9
var hit_flash: float = 0.0
var impact_flash_remaining: float = 0.0
var impact_flash_kind: String = ""
var aimed_direction: Vector2 = Vector2.RIGHT
var ring_gap_angle: float = 0.0
var slam_spots: Array[Vector2] = []
var slam_radius: float = 90.0
var cross_center: Vector2 = Vector2.ZERO
var cross_directions: Array[Vector2] = []

@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player") as CharacterBody2D
@onready var projectile_container: Node2D = get_node("../../../Projectiles") as Node2D
@onready var art: Sprite2D = get_node_or_null("HollowArt") as Sprite2D

func configure_boss(index: int) -> void:
    variant_index = clampi(index, 0, SPECS.size() - 1)
    var spec: Dictionary = SPECS[variant_index]
    display_name = String(spec["name"])
    max_health = int(spec["health"])
    health = max_health
    walking_speed = float(spec["speed"])

func _ready() -> void:
    add_to_group("enemies")
    add_to_group("boss")
    health = max_health
    state = State.INTRO
    state_timer = 0.85
    if art != null:
        art.modulate = SPECS[variant_index]["color"]
        if variant_index == 3:
            art.scale *= 1.15
        elif variant_index == 1:
            art.scale *= 0.80
        elif variant_index == 5:
            art.scale *= 1.12
    queue_redraw()

func _physics_process(delta: float) -> void:
    if health <= 0 or not is_instance_valid(player):
        return
    state_timer -= delta
    hit_flash = maxf(0.0, hit_flash - delta)
    if impact_flash_remaining > 0.0:
        impact_flash_remaining = maxf(0.0, impact_flash_remaining - delta)
        queue_redraw()
    if art != null:
        art.modulate = Color.WHITE if hit_flash > 0.0 else SPECS[variant_index]["color"]

    match state:
        State.INTRO:
            velocity = Vector2.ZERO
            if state_timer <= 0.0:
                _start_walk()
        State.WALK:
            var to_player: Vector2 = player.global_position - global_position
            velocity = to_player.normalized() * walking_speed if to_player.length() > 115.0 else Vector2.ZERO
            move_and_slide()
            _contact_hit(7 + 2 * variant_index)
            if state_timer <= 0.0:
                _begin_attack()
        State.WARNING:
            velocity = Vector2.ZERO
            queue_redraw()
            if state_timer <= 0.0:
                _execute_attack()
        State.DASH:
            var faster: float = 495.0 + 35.0 * float(variant_index)
            velocity = aimed_direction * faster
            move_and_slide()
            global_position = _clamp_pos(global_position)
            _contact_hit(14 + 3 * variant_index)
            if state_timer <= 0.0:
                _start_recovery()
        State.RECOVERY:
            velocity = Vector2.ZERO
            if state_timer <= 0.0:
                _start_walk()

func _clamp_pos(point: Vector2) -> Vector2:
    return Vector2(clampf(point.x, MIN_ARENA, MAX_ARENA), clampf(point.y, MIN_ARENA, MAX_ARENA))

func _start_walk() -> void:
    state = State.WALK
    var pace: float = 1.60 - 0.08 * float(variant_index)
    if variant_index == 5 and float(health) < float(max_health) * 0.5:
        pace *= 0.78
    state_timer = maxf(0.70, pace)
    queue_redraw()

func _start_recovery() -> void:
    state = State.RECOVERY
    state_timer = 0.75 if variant_index < 3 else 1.10
    if variant_index == 5 and float(health) < float(max_health) * 0.5:
        state_timer = 0.80
    queue_redraw()

func _begin_attack() -> void:
    attack_step += 1
    match variant_index:
        0: attack_kind = "fan"
        1: attack_kind = "dash"
        2: attack_kind = "ring"
        3: attack_kind = "slam"
        4: attack_kind = "cross"
        5:
            var cycle := ["ring", "slam", "cross", "dash"]
            attack_kind = cycle[(attack_step - 1) % cycle.size()]

    state = State.WARNING
    warning_total = 0.90
    match attack_kind:
        "fan":
            warning_total = 1.0
            aimed_direction = (player.global_position - global_position).normalized()
            if aimed_direction.length_squared() < 0.01:
                aimed_direction = Vector2.RIGHT
        "dash":
            warning_total = 0.90 if variant_index == 1 else 0.70
            if variant_index == 1:
                # A sudden flank, followed by a highly visible straight warning.
                var side: float = -1.0 if attack_step % 2 == 0 else 1.0
                global_position = _clamp_pos(player.global_position + Vector2(225.0 * side, -110.0))
            aimed_direction = (player.global_position - global_position).normalized()
            if aimed_direction.length_squared() < 0.01:
                aimed_direction = Vector2.RIGHT
        "ring":
            warning_total = 0.95 if variant_index == 2 else 0.75
            ring_gap_angle = (player.global_position - global_position).angle()
        "slam":
            warning_total = 1.15 if variant_index == 3 else 0.90
            slam_spots.clear()
            slam_spots.append(player.global_position)
            var move_direction: Vector2 = player.velocity.normalized()
            if move_direction == Vector2.ZERO:
                move_direction = Vector2.RIGHT
            slam_spots.append(_clamp_pos(player.global_position + move_direction * 155.0))
            if variant_index == 5:
                slam_spots.append(_clamp_pos(player.global_position - move_direction * 150.0))
        "cross":
            warning_total = 1.10 if variant_index == 4 else 0.82
            cross_center = player.global_position
            cross_directions.clear()
            var rotation_angle: float = float(attack_step) * 0.48
            cross_directions.append(Vector2.RIGHT.rotated(rotation_angle))
            cross_directions.append(Vector2.UP.rotated(rotation_angle))
            if variant_index == 5:
                cross_directions.append(Vector2(1, 1).normalized().rotated(rotation_angle))

    if variant_index == 5 and float(health) < float(max_health) * 0.5:
        warning_total *= 0.84
    state_timer = warning_total
    queue_redraw()

func _execute_attack() -> void:
    match attack_kind:
        "fan":
            _fire_fan()
            _start_recovery()
        "dash":
            state = State.DASH
            state_timer = 0.46 if variant_index == 1 else 0.56
            queue_redraw()
        "ring":
            _fire_ring()
            _start_recovery()
        "slam":
            _hit_slam()
            impact_flash_kind = "slam"
            impact_flash_remaining = 0.20
            _shake_camera(5.0)
            _start_recovery()
        "cross":
            _hit_cross()
            impact_flash_kind = "cross"
            impact_flash_remaining = 0.19
            _shake_camera(6.5)
            _start_recovery()

func _fire_bolt(direction: Vector2, power: int, speed: float) -> void:
    if not is_instance_valid(projectile_container):
        return
    var bolt: Area2D = BOLT_SCENE.instantiate() as Area2D
    if bolt == null:
        return
    projectile_container.add_child(bolt)
    bolt.global_position = global_position + direction * 51.0
    bolt.call("setup", direction, power)
    bolt.set("speed", speed)
    bolt.modulate = SPECS[variant_index]["color"]

func _fire_fan() -> void:
    var base_angle: float = aimed_direction.angle()
    for i in range(5):
        var offset: float = (float(i) - 2.0) * 0.19
        _fire_bolt(Vector2.RIGHT.rotated(base_angle + offset), 10, 310.0)

func _fire_ring() -> void:
    var count: int = 14 if variant_index == 2 else 18
    var gap_width: float = TAU * (3.0 if variant_index == 2 else 2.0) / float(count)
    for i in range(count):
        var angle: float = ring_gap_angle + TAU * float(i) / float(count)
        if absf(wrapf(angle - ring_gap_angle, -PI, PI)) < gap_width * 0.5:
            continue
        _fire_bolt(Vector2.RIGHT.rotated(angle), 11 + variant_index * 2, 280.0 + float(variant_index) * 18.0)

func _hit_slam() -> void:
    var radius: float = 87.0 if variant_index == 3 else 94.0
    for spot in slam_spots:
        if player.global_position.distance_squared_to(spot) <= radius * radius:
            player.call("take_damage", 17 + 2 * variant_index)
            break

func _shake_camera(strength: float) -> void:
    var camera: Node = player.get_node_or_null("Camera2D")
    if camera != null and camera.has_method("kick"):
        camera.call("kick", strength)

func _hit_cross() -> void:
    for direction in cross_directions:
        var delta_to_player: Vector2 = player.global_position - cross_center
        if absf(delta_to_player.cross(direction)) <= 31.0 and absf(delta_to_player.dot(direction)) <= 900.0:
            player.call("take_damage", 18 + variant_index * 2)
            break

func _contact_hit(amount: int) -> void:
    if is_instance_valid(player) and global_position.distance_squared_to(player.global_position) <= 52.0 * 52.0:
        player.call("take_damage", amount)

func take_damage(amount: int) -> void:
    if health <= 0 or amount <= 0:
        return
    var multiplier: float = 1.0
    if variant_index >= 2:
        if state == State.RECOVERY:
            multiplier = [1.0, 1.0, 1.35, 1.6, 1.65, 1.9][variant_index]
        else:
            multiplier = [1.0, 1.0, 0.80, 0.62, 0.55, 0.50][variant_index]
    var dealt: int = maxi(1, roundi(float(amount) * multiplier))
    var fx: Node = get_tree().get_first_node_in_group("combat_fx")
    if fx != null:
        fx.call("show_hit", global_position, dealt, health <= dealt, true)
    health = maxi(0, health - dealt)
    hit_flash = 0.13
    if health == 0:
        defeated.emit()
        queue_free()

func _draw() -> void:
    var tint: Color = SPECS[variant_index]["color"]
    draw_circle(Vector2(0, 18), 48.0, Color(tint.r, tint.g, tint.b, 0.09))
    draw_arc(Vector2.ZERO, 45.0, 0.0, TAU, 50, Color(tint.r, tint.g, tint.b, 0.7), 2.0)
    if impact_flash_remaining > 0.0:
        var impact_alpha: float = clampf(impact_flash_remaining / 0.20, 0.0, 1.0)
        if impact_flash_kind == "slam":
            for spot in slam_spots:
                draw_circle(to_local(spot), 87.0 if variant_index == 3 else 94.0,
                    Color(0.94, 0.48, 0.94, 0.32 * impact_alpha))
        elif impact_flash_kind == "cross":
            var center: Vector2 = to_local(cross_center)
            for direction in cross_directions:
                draw_line(center - direction * 900.0, center + direction * 900.0,
                    Color(1.0, 0.88, 0.98, impact_alpha), 16.0)
    if state != State.WARNING:
        return
    var phase: float = 1.0 - clampf(state_timer / warning_total, 0.0, 1.0)
    var warning_color: Color = Color(1.0, 0.28, 0.45, 0.65 + phase * 0.30)
    match attack_kind:
        "fan":
            var base_angle: float = aimed_direction.angle()
            for i in range(5):
                var angle: float = base_angle + (float(i) - 2.0) * 0.19
                draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle) * 480.0, warning_color, 2.0)
        "dash":
            draw_line(Vector2.ZERO, aimed_direction * 850.0, warning_color, 12.0)
            draw_line(Vector2.ZERO, aimed_direction * 850.0, Color(1.0, 0.84, 0.87), 2.0)
        "ring":
            var count: float = 14.0 if variant_index == 2 else 18.0
            var gap: float = TAU * (3.0 if variant_index == 2 else 2.0) / count
            draw_arc(Vector2.ZERO, 105.0 + phase * 15.0, ring_gap_angle + gap * 0.5,
                ring_gap_angle + TAU - gap * 0.5, 70, Color(0.85, 0.42, 1.0, 0.85), 5.0)
        "slam":
            var radius: float = 87.0 if variant_index == 3 else 94.0
            for spot in slam_spots:
                var local: Vector2 = to_local(spot)
                draw_circle(local, radius, Color(1.0, 0.25, 0.43, 0.10 + phase * 0.13))
                draw_arc(local, radius, 0.0, TAU, 60, warning_color, 4.0)
        "cross":
            var local_center: Vector2 = to_local(cross_center)
            for direction in cross_directions:
                draw_line(local_center - direction * 900.0, local_center + direction * 900.0,
                    warning_color, 62.0)
                draw_line(local_center - direction * 900.0, local_center + direction * 900.0,
                    Color(1.0, 0.84, 0.89, 0.86), 2.5)
'''

notes = '''# HOLLOW - Milestone 7: Six-Boss Gauntlet

**Duration:** six minutes of timed survival. The clock freezes at 06:00 for
final battle, so actual elapsed real-world time can be a bit longer.

**Boss schedule:**

1. **01:30 Ash Warden** (main checkpoint) - telegraphed fan of five aimed bolts;
   always vulnerable. 365 HP.
2. **02:15 Veil Stalker** (interlude) - quick flank teleport and red-line dash;
   move sideways. 530 HP.
3. **03:00 Thorn Oracle** (main checkpoint) - dense purple ring with a safe gap;
   bonus damage when recovering. 755 HP.
4. **04:30 Rift Colossus** (main checkpoint) - two marked ground slams; armored
   except during recovery. 1050 HP.
5. **05:15 Mirror Seraph** (interlude) - crossing energy beams that rotate each
   use; more armor between attacks. 1360 HP.
6. **06:00 Hollow Sovereign** (final checkpoint) - rotates between gap-rings,
   triple slams, three crossing beams, and a fast charge; accelerates below
   half health. Heavy armor between attacks; exposed after attacking. 1980 HP.

There are four 90-second checkpoint bosses (01:30/03:00/04:30/06:00),
plus two interlude bosses to deliver six total. Only one boss can exist at once.
If you take longer to defeat one, the next encounter is queued rather than
spawned on top of you. The 6:00 clock stays fixed for the final boss.

**Shops:** 02:00, 04:00, 05:30. A shop delayed by a boss appears after the
boss is defeated and before another encounter. Spell and relic systems remain
unchanged. Non-final bosses provide gold, XP, a small heal, and score.

**Debug commands (editor builds only):**
- `K`: summon the next boss now (one at a time)
- `O`: defeat the current boss instantly
- `J`: 400 damage to the boss
- `N`: advance the clock 60 seconds
- `G`: force level-up / `H`: add gold / `B`: open shop
- `Q`: Void Lightning when charged / `L`: debug-fill its charge
- `V`: Hollow Surge

Debug actions prevent record saving. Use K then O six times for a quick
end-to-end smoke test, then play a full normal run.

**Compatibility/safety:** Previous boss.gd preserved. New logic lives in
`scripts/actors/boss_gauntlet.gd`; the boss.tscn Script reference is changed.
The installer backs up every changed file, preserves Godot-generated UIDs,
and does not duplicate its changes if run twice. No need for new sprites yet:
all six bosses reuse the existing Guardian artwork with different tints/sizes.

If a manual project customization has changed a required script anchor, the
installer will stop before modifying files; send us the relevant file rather
than deleting it or reverting your changes.
'''

backup = root / ('.hollow_backup_m7_' + datetime.now().strftime('%Y%m%d_%H%M%S') + '_' + str(os.getpid()))
backup.mkdir(parents=True, exist_ok=False)
for rel in staged:
    if staged[rel] == original[rel]:
        continue
    target = backup / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / rel, target)

for rel in staged:
    if staged[rel] != original[rel]:
        (root / rel).write_text(staged[rel], encoding='utf-8')
new_script = root / boss_script_path
new_script.parent.mkdir(parents=True, exist_ok=True)
new_script.write_text(boss_source, encoding='utf-8')
(root / 'MILESTONE_7_NOTES.md').write_text(notes, encoding='utf-8')

print('HOLLOW six-boss gauntlet installed!')
print('Saved originals in: ' + str(backup))
print('Bosses at 1:30, 2:15, 3:00, 4:30, 5:15, 6:00.')
print('Run Godot, press F5. Debug test: K then O, repeated six times.')

PY
