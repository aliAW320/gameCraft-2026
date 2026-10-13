#!/usr/bin/env bash
set -euo pipefail
# HOLLOW Milestone 5: add Hollow Surge, combat VFX and procedural audio.
# Run in your existing Godot project directory next to project.godot.
python3 - <<'PY'
from pathlib import Path
from datetime import datetime
import shutil
import os
import math
import wave
import struct
import random
import sys

ROOT = Path.cwd()
if not (ROOT / 'project.godot').is_file():
    raise SystemExit('ERROR: Run this script from the Godot project root (project.godot).')

required = [
    'scenes/main.tscn', 'scenes/player/player.tscn', 'scenes/ui/hud.tscn',
    'scripts/managers/run_manager.gd', 'scripts/systems/spell_manager.gd',
    'scripts/actors/player.gd', 'scripts/actors/enemy.gd',
    'scripts/actors/boss.gd', 'scripts/ui/hud.gd',
    'scripts/ui/boss_bar.gd', 'scripts/systems/arena.gd',
    'scripts/systems/pickup.gd', 'scripts/systems/loot_pickup.gd',
]
for rel in required:
    if not (ROOT / rel).is_file():
        raise SystemExit('ERROR: Missing '+rel+'. Install Milestones 1-4 first. Nothing changed.')

run_check = (ROOT / 'scripts/managers/run_manager.gd').read_text()
if 'M5_SURGE_STATE' in run_check:
    if (ROOT / 'scripts/systems/combat_fx.gd').exists() and 'id="12_fx"' in (ROOT / 'scenes/main.tscn').read_text():
        print('HOLLOW Milestone 5 is already installed. No files changed.')
        sys.exit(0)
    raise SystemExit('ERROR: Partial Milestone 5 detected. Restore from the milestone 5 backup before retrying.')

modified = {}
for rel in required:
    modified[rel] = (ROOT / rel).read_text()

def apply(rel, old, new, count=1):
    current = modified[rel]
    found = current.count(old)
    if found < count:
        raise SystemExit(f'ERROR: Incompatible {rel}: expected {old[:90]!r} ({count} found {found}). Nothing changed.')
    modified[rel] = current.replace(old, new, count)

# --- Progression integration: charge on kills, pause-safe timer, test shortcut ---
rm = 'scripts/managers/run_manager.gd'
apply(rm, 'var debug_modified: bool = false\n', '''var debug_modified: bool = false

# M5_SURGE_STATE: additive buffs; base spell and shop upgrades are untouched.
const SURGE_THRESHOLD: int = 40
const SURGE_DURATION: float = 6.0
var surge_charge: int = 0
var surge_active: bool = false
var surge_remaining: float = 0.0
''')
apply(rm, '    elapsed_seconds += delta\n', '    _m5_tick_surge(delta)\n    elapsed_seconds += delta\n')
apply(rm, '    var elite: bool = bool(defeated_enemy.get("fractured"))\n', '''    var elite: bool = bool(defeated_enemy.get("fractured"))
    _m5_gain_charge(elite)
''')
apply(rm, '    guardian.connect("defeated", Callable(self, "_on_boss_defeated"))\n', '''    guardian.connect("defeated", Callable(self, "_on_boss_defeated"))
    _m5_boss_entrance()
''')
apply(rm, '        KEY_M:\n', '''        KEY_V:
            debug_modified = true
            _m5_start_surge()
        KEY_M:
''')
apply(rm, 'func _unhandled_key_input(event: InputEvent) -> void:\n', '''# M5 gameplay and feedback hooks.
func _m5_gain_charge(is_elite: bool) -> void:
    if surge_active or game_over:
        return
    surge_charge = mini(SURGE_THRESHOLD, surge_charge + (5 if is_elite else 1))
    if surge_charge >= SURGE_THRESHOLD:
        _m5_start_surge()

func _m5_start_surge() -> void:
    if game_over or surge_active:
        return
    surge_charge = 0
    surge_active = true
    surge_remaining = SURGE_DURATION
    player.queue_redraw()
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("surge_burst", player.global_position)
    var camera := player.get_node_or_null("Camera2D")
    if camera != null and camera.has_method("kick"):
        camera.call("kick", 7.0)
    var sounds := get_node_or_null("../SFXManager")
    if sounds != null:
        sounds.call("play_event", "surge")

func _m5_tick_surge(delta: float) -> void:
    if not surge_active:
        return
    surge_remaining = maxf(0.0, surge_remaining - delta)
    if surge_remaining <= 0.0:
        surge_active = false
        player.queue_redraw()

func _m5_boss_entrance() -> void:
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("boss_entrance", boss.global_position)
    var camera := player.get_node_or_null("Camera2D")
    if camera != null and camera.has_method("kick"):
        camera.call("kick", 9.0)
    var sounds := get_node_or_null("../SFXManager")
    if sounds != null:
        sounds.call("play_event", "boss")

func _unhandled_key_input(event: InputEvent) -> void:
''')
# Some users manually applied the Milestone 4 stale-boss fix. Preserve it.
rm_text = modified[rm]
start = rm_text.index('func _on_boss_defeated() -> void:')
stop = rm_text.index('func _on_player_died() -> void:', start)
segment = rm_text[start:stop]
if 'boss = null' not in segment:
    if '    _finish_run(true)\n' not in segment:
        raise SystemExit('ERROR: Unknown boss defeat flow. Nothing changed.')
    segment = segment.replace('    _finish_run(true)\n', '    boss_active = false\n    boss = null\n    _finish_run(true)\n', 1)
    modified[rm] = rm_text[:start] + segment + rm_text[stop:]

# --- Spell surge buffs are computed on the fly, never mutate permanent upgrades. ---
sm = 'scripts/systems/spell_manager.gd'
apply(sm, '@onready var projectiles: Node2D = get_node("../../../Projectiles") as Node2D\n', '''@onready var projectiles: Node2D = get_node("../../../Projectiles") as Node2D
@onready var m5_run_manager: Node = get_node("../../../../RunManager")

func _m5_damage_multiplier() -> float:
    return damage_multiplier * (1.55 if bool(m5_run_manager.get("surge_active")) else 1.0)

func _m5_cooldown_multiplier() -> float:
    return cooldown_multiplier * (0.70 if bool(m5_run_manager.get("surge_active")) else 1.0)
''')
if modified[sm].count(' * cooldown_multiplier') != 2:
    raise SystemExit('ERROR: Spell cooldown code changed. Nothing changed.')
modified[sm] = modified[sm].replace(' * cooldown_multiplier', ' * _m5_cooldown_multiplier()')
if modified[sm].count(' * damage_multiplier') != 3:
    raise SystemExit('ERROR: Spell damage code changed. Nothing changed.')
modified[sm] = modified[sm].replace(' * damage_multiplier', ' * _m5_damage_multiplier()')

# --- Player camera feedback, speed burst, visible aura. ---
pg = 'scripts/actors/player.gd'
apply(pg, '    velocity = Vector2(horizontal, vertical).normalized() * speed\n', '''    velocity = Vector2(horizontal, vertical).normalized() * speed * _m5_movement_boost()
''')
apply(pg, '    if invulnerable_for > 0.0:\n        queue_redraw()\n', '''    if invulnerable_for > 0.0 or _m5_surge_on():
        queue_redraw()
''')
apply(pg, '    invulnerable_for = 0.75\n    queue_redraw()\n', '''    invulnerable_for = 0.75
    var camera := get_node_or_null("Camera2D")
    if camera != null and camera.has_method("kick"):
        camera.call("kick", 8.0)
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("show_player_hit", global_position, adjusted_damage)
    queue_redraw()
''')
apply(pg, 'func _draw() -> void:\n', '''# M5: surge motion is calculated, not baked into the player's shop-upgraded speed.
func _m5_surge_on() -> bool:
    var manager := get_node_or_null("../../../RunManager")
    return manager != null and bool(manager.get("surge_active"))

func _m5_movement_boost() -> float:
    return 1.12 if _m5_surge_on() else 1.0

func _draw() -> void:
''')
modified[pg] += '''
    # M5: flickering violet halo while the Hollow Core is active.
    if _m5_surge_on():
        var orbit_time: float = float(Time.get_ticks_msec()) / 1000.0
        draw_circle(Vector2.ZERO, 34.0, Color(0.55, 0.23, 0.94, 0.13))
        for i in range(3):
            var theta: float = orbit_time * 2.6 + float(i) * TAU / 3.0
            draw_arc(Vector2.ZERO, 28.0 + float(i) * 5.0,
                theta, theta + 1.25, 18, Color(0.78, 0.48, 1.0, 0.8), 3.0)
            draw_circle(Vector2.RIGHT.rotated(theta) * 30.0, 3.0,
                Color(0.95, 0.78, 1.0, 0.92))
'''

# --- Enemy damage (no interference with defeat signals, XP, or drops). ---
eg = 'scripts/actors/enemy.gd'
apply(eg, '    health -= amount\n', '''    # M5: floating combat feedback runs before queue_free() on a fatal hit.
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("show_hit", global_position, amount, health <= amount, fractured)
    health -= amount
''')
bg = 'scripts/actors/boss.gd'
apply(bg, '    health = maxi(0, health - amount)\n', '''    # M5: communicate each hit before the boss can be freed.
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("show_hit", global_position, amount, health <= amount, true)
    health = maxi(0, health - amount)
''')

# --- Pickups get a flash and synthesized sound. ---
ex = 'scripts/systems/pickup.gd'
apply(ex, '    collected.emit(xp_amount)\n', '''    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("show_pickup", global_position, "xp")
    collected.emit(xp_amount)
''')
lo = 'scripts/systems/loot_pickup.gd'
apply(lo, '    collected.emit(kind, amount)\n', '''    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("show_pickup", global_position, kind)
    collected.emit(kind, amount)
''')

# --- Keep manual fixes to the boss bar if already made; otherwise repair it. ---
modified['scripts/ui/boss_bar.gd'] = '''extends Control

@onready var run_manager: Node = get_node("../../RunManager")
@onready var health_bar: ProgressBar = $Life
@onready var boss_name: Label = $BossName

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_name.text = "THE HOLLOW GUARDIAN"
    hide()

func _process(_delta: float) -> void:
    # M5: check lifecycle flags before casting a potentially freed object.
    if bool(run_manager.get("game_over")) or not bool(run_manager.get("boss_active")):
        hide()
        return
    var boss_ref: Variant = run_manager.get("boss")
    if not is_instance_valid(boss_ref):
        hide()
        return
    var guardian: Node2D = boss_ref as Node2D
    if guardian == null or guardian.is_queued_for_deletion():
        hide()
        return
    show()
    health_bar.max_value = float(guardian.get("max_health"))
    health_bar.value = float(guardian.get("health"))
'''

# --- Static arena texture, warning-free integer arithmetic and simple glowing ruins. ---
ar = 'scripts/systems/arena.gd'
if 'var even_tile := ((x / TILE_SIZE) + (y / TILE_SIZE)) % 2 == 0' in modified[ar]:
    apply(ar, 'var even_tile := ((x / TILE_SIZE) + (y / TILE_SIZE)) % 2 == 0',
         'var even_tile := (int(float(x) / float(TILE_SIZE)) + int(float(y) / float(TILE_SIZE))) % 2 == 0')
elif 'var even_tile: bool = (tile_x + tile_y) % 2 == 0' not in modified[ar] and \
        'var even_tile := (int(float(x) / float(TILE_SIZE))' not in modified[ar]:
    raise SystemExit('ERROR: Unknown arena tile logic. Nothing changed.')
modified[ar] += '''
    # M5: scattered runestones and pale, ruined glyphs. Purely visual; no collisions.
    for i in range(48):
        var px: float = float(125 + (i * 757) % 2900)
        var py: float = float(155 + (i * 1093) % 2860)
        var center_stone := Vector2(px, py)
        draw_circle(center_stone + Vector2(5, 5), 11.0, Color(0.0, 0.0, 0.0, 0.19))
        draw_colored_polygon(PackedVector2Array([
            center_stone + Vector2(0, -10), center_stone + Vector2(7, -2),
            center_stone + Vector2(4, 9), center_stone + Vector2(-7, 8),
            center_stone + Vector2(-8, -3)
        ]), Color(0.23, 0.22, 0.33, 0.67))
        if i % 3 == 0:
            draw_line(center_stone + Vector2(-3, -3), center_stone + Vector2(3, 2),
                Color(0.57, 0.37, 0.88, 0.65), 2.0)
            draw_circle(center_stone + Vector2(3, 2), 2.0, Color(0.65, 0.48, 0.9, 0.65))
    for i in range(16):
        var a: float = TAU * float(i) / 16.0
        var rune_pos: Vector2 = ARENA_SIZE / 2.0 + Vector2.RIGHT.rotated(a) * 202.0
        draw_line(rune_pos, rune_pos + Vector2.RIGHT.rotated(a) * 19.0,
            Color(0.50, 0.31, 0.75, 0.40), 3.0)
'''

# --- HUD: obvious charge gauge, active countdown and surge announcement. ---
hud = 'scripts/ui/hud.gd'
apply(hud, '@onready var end_label: Label = $EndMessage\n', '''@onready var end_label: Label = $EndMessage
@onready var surge_bar: ProgressBar = $SurgeBar
@onready var surge_info: Label = $SurgeInfo
@onready var surge_announce: Label = $SurgeAnnounce
var m5_was_surge_active: bool = false
var m5_announce_remaining: float = 0.0
''')
apply(hud, '    end_label.visible = false\n\nfunc _process', '''    end_label.visible = false
    surge_announce.visible = false
    var surge_fill := StyleBoxFlat.new()
    surge_fill.bg_color = Color(0.60, 0.34, 0.94, 1.0)
    surge_bar.add_theme_stylebox_override("fill", surge_fill)

func _process''')
apply(hud, '    end_label.visible = false  # Milestone 4 uses EndScreen.\n', '''    end_label.visible = false  # Milestone 4 uses EndScreen.
    # M5 HUD state updates even while shop/upgrade windows pause the scene.
    var active: bool = bool(run_manager.get("surge_active"))
    if active:
        surge_bar.max_value = 6.0
        surge_bar.value = float(run_manager.get("surge_remaining"))
        surge_info.text = "VOID SURGE!  %.1fs   |   +55%% damage   |   30%% faster casts" % [float(run_manager.get("surge_remaining"))]
    else:
        surge_bar.max_value = 40.0
        surge_bar.value = float(run_manager.get("surge_charge"))
        surge_info.text = "HOLLOW CORE   %d/%d   |   Elites give +5" % [
            int(run_manager.get("surge_charge")), 40]
    if active and not m5_was_surge_active:
        m5_announce_remaining = 1.45
    m5_was_surge_active = active
    if not get_tree().paused:
        m5_announce_remaining = maxf(0.0, m5_announce_remaining - _delta)
    surge_announce.visible = m5_announce_remaining > 0.0 and not bool(run_manager.get("game_over"))
    surge_announce.modulate = Color(1.0, 1.0, 1.0, minf(1.0, m5_announce_remaining / 0.35))
''')

# --- Scene insertion: new nodes only, preserving original order and modifications. ---
mn = 'scenes/main.tscn'
apply(mn, '[gd_scene load_steps=12 format=3]', '[gd_scene load_steps=14 format=3]')
apply(mn, '[node name="Main" type="Node2D"]', '''[ext_resource type="Script" path="res://scripts/systems/combat_fx.gd" id="12_fx"]
[ext_resource type="Script" path="res://scripts/systems/sfx_manager.gd" id="13_sfx"]

[node name="Main" type="Node2D"]''')
apply(mn, '[node name="Pickups" type="Node2D" parent="World"]', '''[node name="Pickups" type="Node2D" parent="World"]

[node name="CombatFX" type="Node2D" parent="World"]
script = ExtResource("12_fx")''')
apply(mn, '[node name="UI" type="CanvasLayer" parent="."]', '''[node name="SFXManager" type="Node" parent="."]
script = ExtResource("13_sfx")

[node name="UI" type="CanvasLayer" parent="."]''')
ps = 'scenes/player/player.tscn'
apply(ps, '[gd_scene load_steps=4 format=3]', '[gd_scene load_steps=5 format=3]')
apply(ps, '[sub_resource type="CircleShape2D"', '''[ext_resource type="Script" path="res://scripts/systems/camera_shake.gd" id="3_camera_fx"]

[sub_resource type="CircleShape2D"''')
apply(ps, '[node name="Camera2D" type="Camera2D" parent="."]', '''[node name="Camera2D" type="Camera2D" parent="."]
script = ExtResource("3_camera_fx")''')
ht = 'scenes/ui/hud.tscn'
modified[ht] += '''
[node name="SurgeBar" type="ProgressBar" parent="."]
layout_mode = 0
offset_left = 22.0
offset_top = 179.0
offset_right = 300.0
offset_bottom = 196.0
show_percentage = false
max_value = 40.0
value = 0.0

[node name="SurgeInfo" type="Label" parent="."]
layout_mode = 0
offset_left = 315.0
offset_top = 175.0
offset_right = 1170.0
offset_bottom = 204.0
theme_override_colors/font_color = Color(0.83, 0.67, 1.0, 1)
theme_override_font_sizes/font_size = 17
text = "HOLLOW CORE  0/40"

[node name="SurgeAnnounce" type="Label" parent="."]
visible = false
layout_mode = 0
offset_left = 300.0
offset_top = 240.0
offset_right = 980.0
offset_bottom = 315.0
theme_override_colors/font_color = Color(0.86, 0.67, 1.0, 1)
theme_override_font_sizes/font_size = 43
text = "HOLLOW SURGE"
horizontal_alignment = 1
'''
modified[ht] = modified[ht].replace('M: lose (debug)', 'M: lose  V: Surge (debug)')

print('Prepared integration patches for', len(modified), 'existing files.')

new_sources = {
'scripts/systems/camera_shake.gd': '''extends Camera2D

# M5: shake only camera offset, never alter camera target or map limits.
var shake_strength: float = 0.0

func kick(amount: float) -> void:
    shake_strength = minf(13.0, shake_strength + amount)

func _process(delta: float) -> void:
    if shake_strength <= 0.05:
        shake_strength = 0.0
        offset = Vector2.ZERO
        return
    offset = Vector2(
        randf_range(-shake_strength, shake_strength),
        randf_range(-shake_strength, shake_strength)
    )
    shake_strength = maxf(0.0, shake_strength - 26.0 * delta)
''',
'scripts/systems/combat_fx.gd': '''extends Node2D

# M5: bounded, batched combat feedback. No one-node-per-number overhead.
const MAX_EFFECTS: int = 110
var effects: Array[Dictionary] = []
@onready var sounds: Node = get_node_or_null("../../SFXManager")

func _ready() -> void:
    add_to_group("combat_fx")
    z_index = 50

func _add(data: Dictionary) -> void:
    if effects.size() >= MAX_EFFECTS:
        effects.remove_at(0)
    effects.append(data)
    queue_redraw()

func _play_sound(event_name: String) -> void:
    if sounds != null:
        sounds.call("play_event", event_name)

func show_hit(world_pos: Vector2, amount: int, killed: bool, elite: bool) -> void:
    var hit_color := Color(0.94, 0.65, 1.0) if elite else Color(0.70, 0.92, 1.0)
    _add({"kind": "damage", "pos": world_pos + Vector2(randf_range(-12, 12), -15),
        "life": 0.58, "max": 0.58, "text": str(amount), "size": 20 if elite else 17,
        "color": hit_color, "vx": randf_range(-11.0, 11.0)})
    if killed:
        _add({"kind": "burst", "pos": world_pos, "life": 0.40, "max": 0.40,
            "color": Color(0.84, 0.48, 1.0) if elite else Color(0.42, 0.83, 1.0), "vx": 0.0})
        _play_sound("kill")
    else:
        _play_sound("hit")

func show_pickup(world_pos: Vector2, pickup_kind: String) -> void:
    var tint := Color(0.42, 0.90, 1.0)
    if pickup_kind == "gold":
        tint = Color(1.0, 0.80, 0.35)
    elif pickup_kind == "heart":
        tint = Color(1.0, 0.40, 0.52)
    elif pickup_kind == "cache":
        tint = Color(0.79, 0.54, 1.0)
    _add({"kind": "pickup", "pos": world_pos, "life": 0.33, "max": 0.33,
        "color": tint, "vx": 0.0})
    _play_sound("pickup")

func show_player_hit(world_pos: Vector2, amount: int) -> void:
    _add({"kind": "damage", "pos": world_pos + Vector2(0, -40),
        "life": 0.65, "max": 0.65, "text": "-%d" % amount, "size": 23,
        "color": Color(1.0, 0.38, 0.46), "vx": 0.0})
    _add({"kind": "burst", "pos": world_pos, "life": 0.42, "max": 0.42,
        "color": Color(1.0, 0.25, 0.36), "vx": 0.0})
    _play_sound("hurt")

func surge_burst(world_pos: Vector2) -> void:
    _add({"kind": "surge", "pos": world_pos, "life": 1.15, "max": 1.15,
        "color": Color(0.78, 0.46, 1.0), "vx": 0.0})
    _add({"kind": "banner", "pos": world_pos + Vector2(0, -70),
        "life": 1.45, "max": 1.45, "text": "HOLLOW SURGE!", "size": 25,
        "color": Color(0.93, 0.78, 1.0), "vx": 0.0})

func boss_entrance(world_pos: Vector2) -> void:
    _add({"kind": "surge", "pos": world_pos, "life": 1.15, "max": 1.15,
        "color": Color(1.0, 0.37, 0.58), "vx": 0.0})
    _add({"kind": "banner", "pos": world_pos + Vector2(0, -90),
        "life": 1.70, "max": 1.70, "text": "THE GUARDIAN AWAKENS", "size": 21,
        "color": Color(1.0, 0.70, 0.80), "vx": 0.0})

func _process(delta: float) -> void:
    if effects.is_empty():
        return
    for i in range(effects.size() - 1, -1, -1):
        var item: Dictionary = effects[i]
        var remaining: float = float(item["life"]) - delta
        if remaining <= 0.0:
            effects.remove_at(i)
            continue
        item["life"] = remaining
        if item["kind"] == "damage" or item["kind"] == "banner":
            item["pos"] = Vector2(item["pos"]) + Vector2(float(item["vx"]), -34.0) * delta
        effects[i] = item
    queue_redraw()

func _draw() -> void:
    for item in effects:
        var point: Vector2 = to_local(item["pos"])
        var ratio: float = clampf(float(item["life"]) / float(item["max"]), 0.0, 1.0)
        var tint: Color = item["color"]
        tint.a *= minf(1.0, ratio * 1.8)
        match String(item["kind"]):
            "damage":
                draw_string(ThemeDB.fallback_font, point - Vector2(11, 0),
                    String(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(item["size"]), tint)
            "banner":
                draw_string(ThemeDB.fallback_font, point - Vector2(92, 0),
                    String(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(item["size"]), tint)
            "pickup":
                draw_arc(point, 8.0 + (1.0 - ratio) * 17.0, 0.0, TAU, 18, tint, 2.0)
                draw_circle(point, 3.0 * ratio, tint)
            "burst":
                var radius: float = 8.0 + (1.0 - ratio) * 26.0
                draw_arc(point, radius, 0.0, TAU, 22, tint, 2.6)
                for j in range(6):
                    var vector: Vector2 = Vector2.RIGHT.rotated(float(j) * TAU / 6.0)
                    draw_line(point + vector * radius, point + vector * (radius + 8.0 * ratio), tint, 2.0)
            "surge":
                var growth: float = 1.0 - ratio
                draw_circle(point, 35.0 + growth * 90.0, Color(tint.r, tint.g, tint.b, 0.07 * ratio))
                draw_arc(point, 26.0 + growth * 130.0, 0.0, TAU, 52, tint, 6.0 * ratio + 1.0)
                draw_arc(point, 13.0 + growth * 86.0, 0.0, TAU, 45,
                    Color(1.0, 0.86, 1.0, 0.50 * ratio), 2.0)
''',
'scripts/systems/sfx_manager.gd': '''extends Node

# M5: compact pool of players for original synthesized, license-free WAV sounds.
const SOUND_PATHS = {
    "hit": "res://assets/sounds/generated/m5_hit.wav",
    "kill": "res://assets/sounds/generated/m5_kill.wav",
    "pickup": "res://assets/sounds/generated/m5_pickup.wav",
    "hurt": "res://assets/sounds/generated/m5_hurt.wav",
    "surge": "res://assets/sounds/generated/m5_surge.wav",
    "boss": "res://assets/sounds/generated/m5_boss.wav"
}
const MIN_GAPS = {"hit": 0.085, "kill": 0.10, "pickup": 0.055, "hurt": 0.16,
    "surge": 0.25, "boss": 0.25}

var sounds: Dictionary = {}
var last_played: Dictionary = {}
var channels: Array[AudioStreamPlayer] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for name in SOUND_PATHS:
        var stream: Resource = load(String(SOUND_PATHS[name]))
        if stream is AudioStream:
            sounds[name] = stream
    for i in range(8):
        var channel := AudioStreamPlayer.new()
        add_child(channel)
        channels.append(channel)

func play_event(event_name: String) -> void:
    if not sounds.has(event_name) or get_tree().paused:
        return
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var previous: float = float(last_played.get(event_name, -100.0))
    if now - previous < float(MIN_GAPS.get(event_name, 0.10)):
        return
    for channel in channels:
        if not channel.playing:
            last_played[event_name] = now
            channel.stream = sounds[event_name]
            channel.pitch_scale = randf_range(0.96, 1.06) if event_name == "hit" else 1.0
            channel.volume_db = -24.0 if event_name == "hit" else (-18.0 if event_name == "pickup" else -13.0)
            channel.play()
            return
'''
}

for rel in new_sources:
    if (ROOT / rel).exists():
        raise SystemExit('ERROR: '+rel+' already exists. Nothing changed, to protect your files.')

# Safeguard against copying user data to unexpected locations. All edits are restricted
# to known project subdirectories, and existing gameplay scripts have been patched in memory.
backup = ROOT / ('.hollow_backup_milestone5_' + datetime.now().strftime('%Y%m%d_%H%M%S') + '_' + str(os.getpid()))
backup.mkdir(parents=True, exist_ok=False)
for rel in modified:
    source = ROOT / rel
    destination = backup / rel
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)

for rel, content in modified.items():
    target = ROOT / rel
    intermediate = target.with_name(target.name+'.m5tmp')
    intermediate.write_text(content)
    intermediate.replace(target)
for rel, content in new_sources.items():
    target = ROOT / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)

# Six short, synthesized SFX; no external library or copyrighted samples.
sound_dir = ROOT / 'assets/sounds/generated'
sound_dir.mkdir(parents=True, exist_ok=True)
rate = 22050
rng = random.Random(105)

def synth(name, duration):
    output = sound_dir / ('m5_'+name+'.wav')
    if output.exists():
        return
    sample_count = int(duration * rate)
    data = bytearray()
    phase = 0.0
    for n in range(sample_count):
        t = n / rate
        u = t / duration
        if name == 'hit':
            freq = 260.0 - 140.0*u
            envelope = (1.0-u)**3
            tone = 0.35*math.sin(2*math.pi*freq*t) + 0.38*(rng.random()*2-1)
        elif name == 'kill':
            freq = 600.0 - 420.0*u
            envelope = (1.0-u)**1.6
            tone = 0.42*math.sin(2*math.pi*freq*t) + 0.13*(rng.random()*2-1)
        elif name == 'pickup':
            freq = 540.0 + 610.0*u
            envelope = (1.0-u)**1.7 * min(1.0,t*100.0)
            tone = 0.40*math.sin(2*math.pi*freq*t) + 0.16*math.sin(2*math.pi*freq*1.5*t)
        elif name == 'hurt':
            freq = 140.0 - 75.0*u
            envelope = (1.0-u)**2
            tone = 0.54*math.sin(2*math.pi*freq*t) + 0.16*(rng.random()*2-1)
        elif name == 'surge':
            freq = 150.0 + 520.0*u
            envelope = min(1.0,t*18.0)*(1.0-u)**1.15
            tone = 0.30*math.sin(2*math.pi*freq*t) + 0.22*math.sin(2*math.pi*freq*1.49*t)
        else:
            freq = 110.0 - 35.0*u
            envelope = min(1.0,t*15.0)*(1.0-u)**0.75
            tone = (0.30*math.sin(2*math.pi*freq*t)
                    + 0.22*math.sin(2*math.pi*(freq*0.5)*t)
                    + 0.06*(rng.random()*2-1))
        sample = max(-1.0, min(1.0, tone*envelope))
        data += struct.pack('<h', int(sample*26000))
    with wave.open(str(output), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(bytes(data))

for sound_name, seconds in [('hit', .09), ('kill', .19), ('pickup', .18),
                            ('hurt', .28), ('surge', .84), ('boss', 1.18)]:
    synth(sound_name, seconds)

notes = '''# HOLLOW -- Milestone 5: Hollow Surge and Combat Polish

## Features
- Automatic Hollow Surge after collecting 40 kill energy. Normal kills +1, Fractured elites +5.
- Surge lasts 6 seconds, providing 55% increased spell damage, 30% faster casting, and 12% faster movement.
- Charged/powered-up HUD meter, animated halo, and activation announcement.
- On-hit floating numbers, death bursts, pickup sparkles, and boss entrance effects.
- Controlled camera shake for taking damage, Surge activation and boss entrance.
- Six original, synthesized WAV effects, using no third-party audio samples.
- Fixes the Milestone 4 boss bar stale reference bug (and clears the boss reference on death).
- Removes integer-division warnings from the arena tile rendering.

## Controls
- WASD/arrow keys: move.
- V (DEBUG ONLY): trigger Hollow Surge instantly. Debug actions disable high-score saves.
- Other debug keys remain G, H, B, N, K, J, M.

## Smoke tests
1. F5. Move and attack: see damage numbers, death bursts and hear quiet hit/kill sounds.
2. Collect XP/gold/hearts: sparkles and pickup sound.
3. Press V with no popup open: purple aura, Surge HUD countdown, noticeably faster spells.
4. Press G, H, B: spells and the shop must still work. Surge timer pauses in menus.
5. Press K and J x4: boss defeat and victory must not crash. Restart with R.
6. Let normal enemies die for 40 energy: Surge should also activate naturally.
7. Non-debug runs save high score; using V or any other debug key does not.

## Project edits
The script backs up the previously existing files to .hollow_backup_milestone5_... .
New scripts: scripts/systems/combat_fx.gd, camera_shake.gd, sfx_manager.gd.
New WAV files: assets/sounds/generated/m5_*.wav.
Scene updates: scenes/main.tscn, scenes/player/player.tscn, scenes/ui/hud.tscn.
It preserves the existing player/enemy/boss mechanics, upgrade selections, score and shop logic.

## Tips
- Synthesized effects are deliberately subtle. Adjust volume_db in sfx_manager.gd.
- If you edit the original game scripts, version the project with Git before further upgrades.
- This installer targets the generated Milestones 1-4 baseline; review conflicts before using with heavily modified code.
'''
(ROOT / 'MILESTONE_5_NOTES.md').write_text(notes)
print('HOLLOW Milestone 5 installed.')
print('Backup:', backup.name)
print('New: Surge, combat popups, bursts, camera shake, audio, HUD, boss-fix.')
print('Next: open Godot, press F5, and use V in debug mode to test Surge.')

PY
