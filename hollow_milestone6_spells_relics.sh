#!/usr/bin/env bash
set -euo pipefail

# HOLLOW Milestone 6: two new spells, a strict four-spell cap, and unique shop relics.
# Run from the directory containing project.godot. Requires Milestones 1-5.
python3 - <<'PY'
from pathlib import Path
from datetime import datetime
import os
import re
import shutil
import sys

ROOT = Path.cwd()
if not (ROOT / 'project.godot').is_file():
    raise SystemExit('ERROR: Run in your HOLLOW project root, next to project.godot. Nothing changed.')

required = [
    'scenes/main.tscn',
    'scripts/systems/spell_manager.gd',
    'scripts/managers/upgrade_manager.gd',
    'scripts/managers/shop_manager.gd',
    'scripts/managers/run_manager.gd',
    'scripts/actors/player.gd',
    'scripts/actors/enemy.gd',
    'scripts/ui/hud.gd',
    'scripts/ui/shop_panel.gd',
    'scripts/ui/level_up_panel.gd',
]
for rel in required:
    if not (ROOT / rel).is_file():
        raise SystemExit(f'ERROR: Missing {rel}. Nothing changed.')

scene_src = (ROOT / 'scenes/main.tscn').read_text(encoding='utf-8')
spell_src = (ROOT / 'scripts/systems/spell_manager.gd').read_text(encoding='utf-8')
installed = '# HOLLOW_M6_SPELLS' in spell_src
if installed:
    complete = all((ROOT / x).is_file() for x in [
        'scripts/systems/abyssal_spear.gd',
        'scripts/systems/death_bloom_fx.gd',
        'scripts/systems/shop_relics.gd',
        'scenes/spells/abyssal_spear.tscn',
        'scenes/spells/death_bloom_fx.tscn',
    ]) and 'res://scripts/systems/shop_relics.gd' in scene_src
    if complete:
        print('Milestone 6 is already installed. Nothing changed.')
        sys.exit(0)
    raise SystemExit('ERROR: Partial Milestone 6 install detected. Restore from its backup before retrying.')
if any((ROOT / f).exists() for f in ['scripts/systems/shop_relics.gd', 'scenes/spells/abyssal_spear.tscn']):
    raise SystemExit('ERROR: Files belonging to the new spells/relics already exist. Nothing changed.')

staged = {rel: (ROOT / rel).read_text(encoding='utf-8') for rel in required}

def replace_one(rel, old, new, exact=1):
    content = staged[rel]
    number = content.count(old)
    if number != exact:
        raise SystemExit(f'ERROR: Cannot safely patch {rel}; expected {exact} instance(s) of {old[:88]!r}, found {number}. Nothing changed.')
    staged[rel] = content.replace(old, new, 1)

def append(rel, text):
    staged[rel] = staged[rel].rstrip() + '\n\n' + text.strip() + '\n'

# ---------------------------------------------------------------------------
# FIVE normal spells (starting Soul Needle + four unlockables), four slots.
# Hollow Surge / Void Lightning are ultimates and do not use these slots.
# ---------------------------------------------------------------------------
rel = 'scripts/systems/spell_manager.gd'
replace_one(rel,
    'const PROJECTILE_SCENE := preload("res://scenes/spells/projectile.tscn")',
    '''const PROJECTILE_SCENE := preload("res://scenes/spells/projectile.tscn")
# HOLLOW_M6_SPELLS
const SPEAR_SCENE := preload("res://scenes/spells/abyssal_spear.tscn")
const BLOOM_FX_SCENE := preload("res://scenes/spells/death_bloom_fx.tscn")
const MAX_EQUIPPED_SPELLS: int = 4''')
replace_one(rel,
    'var shade_level: int = 0',
    '''var shade_level: int = 0
var spear_level: int = 0
var bloom_level: int = 0
var spear_timer: float = 0.8''')
replace_one(rel,
    '''    if shade_level > 0:
        shade_angle += delta * 3.2''',
    '''    if spear_level > 0:
        spear_timer -= delta
        if spear_timer <= 0.0:
            var spear_targets: Array[Node2D] = _find_needle_targets(1)
            if not spear_targets.is_empty():
                _fire_abyssal_spear(spear_targets[0])
                spear_timer = (2.6 if spear_level >= 4 else 3.6) * _m5_cooldown_multiplier()

    if shade_level > 0:
        shade_angle += delta * 3.2''')
replace_one(rel,
    '''func upgrade_spell(spell_id: String) -> void:
    match spell_id:''',
    '''func equipped_spell_count() -> int:
    var result: int = 1 if needle_level > 0 else 0
    for level_value in [pulse_level, shade_level, spear_level, bloom_level]:
        if level_value > 0:
            result += 1
    return result

func can_upgrade_spell(spell_id: String) -> bool:
    var current_level: int = -1
    match spell_id:
        "needle": current_level = needle_level
        "pulse": current_level = pulse_level
        "shade": current_level = shade_level
        "spear": current_level = spear_level
        "bloom": current_level = bloom_level
        _: return false
    if current_level >= 4:
        return false
    return current_level > 0 or equipped_spell_count() < MAX_EQUIPPED_SPELLS

func upgrade_spell(spell_id: String) -> void:
    if not can_upgrade_spell(spell_id):
        return
    match spell_id:''')
replace_one(rel,
    '''        "shade":
            shade_level = mini(4, shade_level + 1)
    queue_redraw()''',
    '''        "shade":
            shade_level = mini(4, shade_level + 1)
        "spear":
            if spear_level == 0:
                spear_timer = 0.12
            spear_level = mini(4, spear_level + 1)
        "bloom":
            bloom_level = mini(4, bloom_level + 1)
    queue_redraw()''')
append(rel, '''
# Abyssal Spear uses its own piercing Area2D so it never modifies Soul Needle.
func _fire_abyssal_spear(target: Node2D) -> void:
    if not is_instance_valid(target) or target.is_queued_for_deletion():
        return
    var direction: Vector2 = (target.global_position - global_position).normalized()
    if direction.length_squared() < 0.01:
        direction = Vector2.RIGHT
    var spear = SPEAR_SCENE.instantiate()
    spear.set("damage", roundi((62.0 if spear_level >= 3 else 40.0) * _m5_damage_multiplier()))
    spear.set("max_hits", 5 if spear_level >= 2 else 3)
    spear.set("direction", direction)
    projectiles.add_child(spear)
    spear.global_position = global_position + direction * 18.0
    spear.rotation = direction.angle()

# Enemies killed by a Bloom explosion cannot proc another Bloom.
# Rewards, XP and gold still work normally for those kills.
func on_enemy_killed(at_position: Vector2) -> void:
    if bloom_level <= 0 or get_tree().paused or bool(m5_run_manager.get("game_over")):
        return
    var chance: float = 0.22
    if bloom_level >= 2:
        chance = 0.33
    if bloom_level >= 4:
        chance = 0.44
    if randf() < chance:
        call_deferred("_explode_death_bloom", at_position)

func _explode_death_bloom(at_position: Vector2) -> void:
    if bool(m5_run_manager.get("game_over")) or bool(m5_run_manager.get("boss_active")):
        return
    var radius: float = 100.0
    if bloom_level >= 3:
        radius = 125.0
    if bloom_level >= 4:
        radius = 150.0
    var damage: int = roundi((44.0 if bloom_level >= 3 else 30.0) * _m5_damage_multiplier())
    var fx = BLOOM_FX_SCENE.instantiate()
    projectiles.add_child(fx)
    fx.global_position = at_position
    fx.call("configure", radius)
    for obj in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(obj) or not (obj is Node2D):
            continue
        var enemy: Node2D = obj as Node2D
        if enemy.is_queued_for_deletion() or enemy.global_position.distance_squared_to(at_position) > radius * radius:
            continue
        if enemy.has_method("take_bloom_damage"):
            enemy.call("take_bloom_damage", damage)
        elif enemy.has_method("take_damage"):
            enemy.call("take_damage", damage)

# Development-only shortcuts: 7 = unlock/upgrade Spear; 8 = Bloom.
# Testing disables high-score saving for that run.
func _unhandled_key_input(event: InputEvent) -> void:
    if not OS.is_debug_build() or not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo or get_tree().paused:
        return
    var chosen: String = ""
    if key_event.keycode == KEY_7:
        chosen = "spear"
    elif key_event.keycode == KEY_8:
        chosen = "bloom"
    if chosen != "":
        m5_run_manager.set("debug_modified", true)
        upgrade_spell(chosen)
        get_viewport().set_input_as_handled()
''')

# ---------------------------------------------------------------------------
# Enforce equipped spell slots at both candidate generation and purchase time.
# ---------------------------------------------------------------------------
rel = 'scripts/managers/upgrade_manager.gd'
replace_one(rel, 'if needle < 4:', 'if needle < 4 and bool(spells.call("can_upgrade_spell", "needle")):')
replace_one(rel, 'if pulse < 4:', 'if pulse < 4 and bool(spells.call("can_upgrade_spell", "pulse")):')
replace_one(rel, 'if shade < 4:', 'if shade < 4 and bool(spells.call("can_upgrade_spell", "shade")):')
replace_one(rel,
    '''    if int(passive_levels["focus"]) < 3:''',
    '''    var spear: int = int(spells.get("spear_level"))
    if bool(spells.call("can_upgrade_spell", "spear")):
        var spear_info: String = "Unlock a 40-damage piercing spear (3 targets)."
        if spear == 1:
            spear_info = "Abyssal Spear now pierces up to 5 enemies."
        elif spear == 2:
            spear_info = "Spear damage increases from 40 to 62."
        elif spear == 3:
            spear_info = "Reduce Spear cooldown from 3.6s to 2.6s."
        pool.append(_card("spear", "ABYSSAL SPEAR Lv.%d" % (spear + 1), spear_info))

    var bloom: int = int(spells.get("bloom_level"))
    if bool(spells.call("can_upgrade_spell", "bloom")):
        var bloom_info: String = "22% kill chance: explode for 30 damage in 100px."
        if bloom == 1:
            bloom_info = "Death Bloom activation chance increases to 33%."
        elif bloom == 2:
            bloom_info = "Bloom expands to 125px and deals 44 damage."
        elif bloom == 3:
            bloom_info = "44% chance and 150px explosion radius."
        pool.append(_card("bloom", "DEATH BLOOM Lv.%d" % (bloom + 1), bloom_info))

    if int(passive_levels["focus"]) < 3:''')
replace_one(rel, '"needle", "pulse", "shade":', '"needle", "pulse", "shade", "spear", "bloom":')
replace_one(rel,
    '''            spells.call("upgrade_spell", upgrade_id)''',
    '''            if bool(spells.call("can_upgrade_spell", upgrade_id)):
                spells.call("upgrade_spell", upgrade_id)''')

# ---------------------------------------------------------------------------
# Kill signal + bloom hook; separate player hit signal for shop relics.
# ---------------------------------------------------------------------------
rel = 'scripts/managers/run_manager.gd'
replace_one(rel, 'extends Node\n', 'extends Node\n\nsignal enemy_killed(position: Vector2, is_elite: bool)\n')
replace_one(rel,
    '''    _m5_gain_charge(elite)
    _spawn_rewards.call_deferred(origin, xp_amount, elite)''',
    '''    _m5_gain_charge(elite)
    enemy_killed.emit(origin, elite)
    # Trigger Bloom after rewards logic has observed the kill. Prevent Bloom->Bloom loops.
    var spell_manager: Node = player.get_node_or_null("SpellManager")
    if spell_manager != null and not bool(defeated_enemy.get("killed_by_bloom")):
        spell_manager.call("on_enemy_killed", origin)
    _spawn_rewards.call_deferred(origin, xp_amount, elite)''')

rel = 'scripts/actors/enemy.gd'
replace_one(rel, 'var score_reward: int = 10', 'var score_reward: int = 10\nvar killed_by_bloom: bool = false')
replace_one(rel, 'func take_damage(amount: int) -> void:',
    '''func take_bloom_damage(amount: int) -> void:
    if health <= 0:
        return
    if health <= amount:
        killed_by_bloom = true
    take_damage(amount)

func take_damage(amount: int) -> void:''')

rel = 'scripts/actors/player.gd'
replace_one(rel, 'signal died', 'signal died\nsignal damaged(amount: int)')
replace_one(rel, '''    if health == 0:
        died.emit()''', '''    # Shop relics can react and a one-use revival relic can prevent this death.
    damaged.emit(adjusted_damage)
    if health == 0:
        died.emit()''')

# ---------------------------------------------------------------------------
# Shop now sells trigger relics ONLY; no duplicated level-up stat upgrades.
# The game's existing shop visits, one-purchase rule, and economy stay intact.
# ---------------------------------------------------------------------------
shop_rel = 'scripts/managers/shop_manager.gd'
old_shop = staged[shop_rel]
if not all(x in old_shop for x in ['const ITEMS = [', '"vessel"', '"eye"', '"boots"', '"charm"', '"clock"', '"shell"', 'func purchase_item', 'func get_offers']):
    raise SystemExit('ERROR: Existing shop was customized; refusing to replace it. Nothing changed.')
staged[shop_rel] = '''extends Node

# HOLLOW_M6_RELIC_SHOP: Shop effects trigger during gameplay instead of
# repeating level-up upgrades to damage, cooldown, HP cap or movement speed.
const ITEMS = [
    {"id": "thorn_idol", "title": "THORN IDOL", "description": "When hit, strike nearby enemies with a thorn nova (2s cooldown).", "price": 17, "max_copies": 2},
    {"id": "blood_chalice", "title": "BLOOD CHALICE", "description": "Heal 10 HP per copy after every 12 enemy kills.", "price": 14, "max_copies": 2},
    {"id": "gilded_fang", "title": "GILDED FANG", "description": "Every 10 kills, gain 2 bonus gold per copy.", "price": 12, "max_copies": 2},
    {"id": "soul_battery", "title": "SOUL BATTERY", "description": "Every 10 kills, add 4 extra Void Lightning charge per copy.", "price": 18, "max_copies": 2},
    {"id": "magnet_bell", "title": "MAGNET BELL", "description": "Every 15 kills, pull loose pickups from a huge area to you.", "price": 15, "max_copies": 2},
    {"id": "second_breath", "title": "SECOND BREATH", "description": "Once per run, prevent lethal damage and restore 40 HP.", "price": 24, "max_copies": 1},
]

var purchases: Dictionary = {}
@onready var relics: Node = get_node("../World/ShopRelics")

func get_offers(count: int = 3) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []
    for item in ITEMS:
        var item_id: String = String(item["id"])
        if int(purchases.get(item_id, 0)) < int(item["max_copies"]):
            pool.append(item.duplicate(true))
    pool.shuffle()
    var selected: Array[Dictionary] = []
    for i in range(mini(count, pool.size())):
        selected.append(pool[i])
    return selected

func purchase_item(item_id: String, gold_available: int) -> int:
    var item: Dictionary = {}
    for entry in ITEMS:
        if String(entry["id"]) == item_id:
            item = entry
            break
    if item.is_empty():
        return -1
    if int(purchases.get(item_id, 0)) >= int(item["max_copies"]):
        return -1
    var price: int = int(item["price"])
    if gold_available < price:
        return -1
    if not bool(relics.call("add_relic", item_id)):
        return -1
    purchases[item_id] = int(purchases.get(item_id, 0)) + 1
    return price
'''
replace_one('scripts/ui/shop_panel.gd', '"THE HOLLOW MERCHANT  |  VISIT %d / 3"', '"THE HOLLOW MERCHANT - RELICS  |  VISIT %d / 3"')
replace_one('scripts/ui/level_up_panel.gd',
    'Choose one upgrade to carry deeper into the Hollow',
    'Choose an upgrade  |  Equip up to 4 spells (shop offers unique relics)')

# Compact HUD spells to fit the status row on a 1280x720 game.
replace_one('scripts/ui/hud.gd',
    '''    spells_label.text = "Soul Needle %d   |   Void Pulse %d   |   Orbiting Shade %d" % [
        int(spells.get("needle_level")), int(spells.get("pulse_level")),
        int(spells.get("shade_level"))
    ]''',
    '''    spells_label.text = "SPELLS %d/4   Needle %d | Pulse %d | Shade %d | Spear %d | Bloom %d" % [
        int(spells.call("equipped_spell_count")),
        int(spells.get("needle_level")), int(spells.get("pulse_level")),
        int(spells.get("shade_level")), int(spells.get("spear_level")),
        int(spells.get("bloom_level"))
    ]''')

# Godot may resave the header with a UID and a different load_steps value.
main = staged['scenes/main.tscn']
header = re.search(r'(?m)^\[gd_scene\b[^\n]*\]$', main)
if header is None or not re.search(r'\bformat\s*=\s*3\b', header.group(0)):
    raise SystemExit('ERROR: Unsupported scenes/main.tscn format. Nothing changed.')
if 'id="m6_relics"' in main or 'name="ShopRelics"' in main:
    raise SystemExit('ERROR: ShopRelics resource/node already exists. Nothing changed.')
if not re.search(r'(?m)^\[node\s+name="World"(?=[\s\]])[^\n]*parent="\."[^\n]*\]$', main):
    raise SystemExit('ERROR: Cannot locate the World node. Nothing changed.')
main = main[:header.end()] + '\n[ext_resource type="Script" path="res://scripts/systems/shop_relics.gd" id="m6_relics"]\n' + main[header.end():]
main = main.rstrip() + '''

[node name="ShopRelics" type="Node2D" parent="World"]
script = ExtResource("m6_relics")
'''
h = re.search(r'(?m)^\[gd_scene\b[^\n]*\]$', main)
original = h.group(0)
loads = 1 + len(re.findall(r'(?m)^\[(?:ext_resource|sub_resource)\b', main))
if re.search(r'\bload_steps\s*=\s*\d+', original):
    revised = re.sub(r'\bload_steps\s*=\s*\d+', f'load_steps={loads}', original)
else:
    revised = original[:-1] + f' load_steps={loads}]'
main = main[:h.start()] + revised + main[h.end():]
staged['scenes/main.tscn'] = main

# ---------------------------------------------------------------------------
# Entirely new source files/scenes. Asset pack is optional; VFX draw themselves.
# ---------------------------------------------------------------------------
staged['scripts/systems/abyssal_spear.gd'] = '''extends Area2D

# Fast piercing spear: damages each unique enemy once, up to max_hits.
@export var speed: float = 690.0
@export var damage: int = 40
@export var max_hits: int = 3
@export var direction: Vector2 = Vector2.RIGHT
var remaining_life: float = 1.45
var hit_ids: Dictionary = {}

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    rotation = direction.angle()
    queue_redraw()

func _physics_process(delta: float) -> void:
    remaining_life -= delta
    if remaining_life <= 0.0:
        queue_free()
        return
    global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
    if not is_instance_valid(body) or not body.is_in_group("enemies"):
        return
    if body.is_queued_for_deletion() or not body.has_method("take_damage"):
        return
    var id: int = body.get_instance_id()
    if hit_ids.has(id):
        return
    hit_ids[id] = true
    body.call("take_damage", damage)
    if hit_ids.size() >= max_hits:
        queue_free()

func _draw() -> void:
    draw_line(Vector2(-40, 0), Vector2(35, 0), Color(0.43, 0.14, 0.84, 0.26), 22.0, true)
    draw_colored_polygon(PackedVector2Array([
        Vector2(-34, -7), Vector2(17, -8), Vector2(43, 0),
        Vector2(17, 8), Vector2(-34, 7), Vector2(-25, 0)
    ]), Color(0.49, 0.25, 0.82, 0.94))
    draw_line(Vector2(-30, 0), Vector2(32, 0), Color(0.90, 0.82, 1.0, 0.96), 3.0, true)
    draw_circle(Vector2(25, 0), 4.0, Color(0.92, 0.73, 1.0))
'''
staged['scenes/spells/abyssal_spear.tscn'] = '''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/systems/abyssal_spear.gd" id="1_spear"]
[sub_resource type="RectangleShape2D" id="RectangleShape2D_spear"]
size = Vector2(70, 20)

[node name="AbyssalSpear" type="Area2D"]
collision_layer = 0
collision_mask = 2
monitoring = true
monitorable = false
script = ExtResource("1_spear")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_spear")
'''
staged['scripts/systems/death_bloom_fx.gd'] = '''extends Node2D

# Cosmetic death explosion; damage is applied once by SpellManager.
var radius: float = 100.0
var age: float = 0.0
const LIFE: float = 0.42

func configure(new_radius: float) -> void:
    radius = new_radius
    queue_redraw()

func _process(delta: float) -> void:
    age += delta
    if age >= LIFE:
        queue_free()
        return
    queue_redraw()

func _draw() -> void:
    var f: float = clampf(age / LIFE, 0.0, 1.0)
    var r: float = lerpf(18.0, radius, pow(f, 0.60))
    var fade: float = 1.0 - f
    draw_circle(Vector2.ZERO, r, Color(0.55, 0.10, 0.78, 0.25 * fade))
    draw_arc(Vector2.ZERO, r, 0.0, TAU, 60, Color(0.95, 0.47, 1.0, 0.95 * fade), 5.0)
    draw_arc(Vector2.ZERO, r * 0.76, 0.0, TAU, 44, Color(0.30, 0.06, 0.40, 0.75 * fade), 3.0)
    for i in range(9):
        var theta: float = TAU * float(i) / 9.0 + 0.19
        var direction: Vector2 = Vector2.RIGHT.rotated(theta)
        draw_line(direction * r * 0.48, direction * (r + 12.0 * fade),
            Color(0.88, 0.51, 1.0, fade), 3.2, true)
'''
staged['scenes/spells/death_bloom_fx.tscn'] = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/systems/death_bloom_fx.gd" id="1_bloom"]

[node name="DeathBloomFX" type="Node2D"]
script = ExtResource("1_bloom")
'''

staged['scripts/systems/shop_relics.gd'] = '''extends Node2D

# HOLLOW M6: Shop relics are event-based, NOT permanent stat upgrades.
# Purchases last for the current run. Only Second Breath has one-use charges.
var stacks: Dictionary = {}
var kills_seen: int = 0
var thorn_cooldown: float = 0.0
var thorn_visual_time: float = 0.0
var rescue_available: bool = false

@onready var player: Node2D = get_node("../Actors/Player") as Node2D
@onready var run_manager: Node = get_node("../../RunManager")
@onready var pickups: Node2D = get_node("../Pickups") as Node2D
@onready var lightning: Node = get_node_or_null("../VoidLightning")

func _ready() -> void:
    z_index = 20
    run_manager.connect("enemy_killed", Callable(self, "_on_enemy_killed"))
    player.connect("damaged", Callable(self, "_on_player_damaged"))

func add_relic(item_id: String) -> bool:
    if not ["thorn_idol", "blood_chalice", "gilded_fang", "soul_battery", "magnet_bell", "second_breath"].has(item_id):
        return false
    var cap: int = 1 if item_id == "second_breath" else 2
    if int(stacks.get(item_id, 0)) >= cap:
        return false
    stacks[item_id] = int(stacks.get(item_id, 0)) + 1
    if item_id == "second_breath":
        rescue_available = true
    return true

func _process(delta: float) -> void:
    if get_tree().paused or bool(run_manager.get("game_over")):
        return
    thorn_cooldown = maxf(0.0, thorn_cooldown - delta)
    thorn_visual_time = maxf(0.0, thorn_visual_time - delta)
    if thorn_visual_time > 0.0:
        global_position = player.global_position
        queue_redraw()

func _on_enemy_killed(_at_position: Vector2, _is_elite: bool) -> void:
    if bool(run_manager.get("game_over")):
        return
    kills_seen += 1
    var chalice: int = int(stacks.get("blood_chalice", 0))
    if chalice > 0 and kills_seen % 12 == 0:
        player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + 10 * chalice))
    var fang: int = int(stacks.get("gilded_fang", 0))
    if fang > 0 and kills_seen % 10 == 0:
        run_manager.set("gold", int(run_manager.get("gold")) + 2 * fang)
    var battery: int = int(stacks.get("soul_battery", 0))
    if battery > 0 and kills_seen % 10 == 0 and is_instance_valid(lightning):
        var max_charge: int = 25
        lightning.set("charge", mini(max_charge, int(lightning.get("charge")) + 4 * battery))
    var magnet: int = int(stacks.get("magnet_bell", 0))
    if magnet > 0 and kills_seen % 15 == 0:
        var radius: float = 500.0 + 150.0 * float(magnet - 1)
        for drop in pickups.get_children():
            if drop is Node2D and not drop.is_queued_for_deletion():
                if (drop as Node2D).global_position.distance_squared_to(player.global_position) <= radius * radius:
                    (drop as Node2D).global_position = player.global_position

func _on_player_damaged(_amount: int) -> void:
    if int(player.get("health")) <= 0 and rescue_available:
        rescue_available = false
        player.set("health", mini(int(player.get("max_health")), 40))
        player.set("invulnerable_for", 2.0)
        thorn_visual_time = 0.33
        global_position = player.global_position
        queue_redraw()

    var thorn: int = int(stacks.get("thorn_idol", 0))
    if thorn <= 0 or thorn_cooldown > 0.0:
        return
    thorn_cooldown = 2.0
    thorn_visual_time = 0.32
    global_position = player.global_position
    queue_redraw()
    var radius: float = 130.0
    for obj in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(obj) or not (obj is Node2D):
            continue
        var enemy: Node2D = obj as Node2D
        if not enemy.is_queued_for_deletion() and enemy.has_method("take_damage"):
            if enemy.global_position.distance_squared_to(player.global_position) <= radius * radius:
                enemy.call("take_damage", 28 * thorn)

func _draw() -> void:
    if thorn_visual_time <= 0.0:
        return
    var strength: float = thorn_visual_time / 0.32
    draw_circle(Vector2.ZERO, 130.0, Color(0.58, 0.16, 0.75, 0.13 * strength))
    draw_arc(Vector2.ZERO, 130.0, 0.0, TAU, 64, Color(0.97, 0.56, 1.0, strength), 5.0)
'''

staged['MILESTONE_6_NOTES.md'] = '''# HOLLOW - Milestone 6: Five Spells, Four Slots, Relic Shop

## Five normal spells, maximum four equipped
- Soul Needle: starting projectile, always counts as one slot.
- Void Pulse: area attack, unlocked from level-up.
- Orbiting Shade: rotating orb, unlocked from level-up.
- Abyssal Spear: 40 base damage, pierces 3 enemies, 3.6 sec cooldown.
  Levels: pierce 5, damage 62, cooldown 2.6 sec.
- Death Bloom: 22% kill chance for a 100px blast, 30 damage.
  Levels: 33% chance, 125px/44 damage, 44% chance/150px.
- Four of these five can be equipped in a run. The fifth does not appear
  as a new unlock after all four slots are occupied.
- Already-equipped spells can still be upgraded to level 4.
- Hollow Surge and manual Void Lightning are ULTIMATES and use no slots.

## Merchant now sells six different relics
- THORN IDOL (17): damaging nova when hit (2 sec cooldown).
- BLOOD CHALICE (14): every 12 kills restores 10 HP per copy.
- GILDED FANG (12): every 10 kills earns 2 extra gold per copy.
- SOUL BATTERY (18): every 10 kills charges Void Lightning by 4 per copy.
- MAGNET BELL (15): every 15 kills pulls dropped loot within 500/650px.
- SECOND BREATH (24): one-use rescue from death, 40 HP + 2s protection.
Shop is at 2:00/4:00/6:00 as before, one purchase per visit.
All relics last only for the current run. They are NOT stat upgrades duplicated
from level-up cards. Level-up passives remain unchanged.

## Test shortcuts (editor/debug builds only)
- G: enough XP for next level-up, then choose a card.
- 7: unlock or improve Abyssal Spear, if a spell slot is available.
- 8: unlock or improve Death Bloom, if a spell slot is available.
- H: +30 gold; B: show shop.
- L: charge Void Lightning; Q: activate.
- V: force Hollow Surge, K: summon boss.
Any debug shortcut disables high-score recording for that run.

## Smoke tests
1. Start fresh: HUD says SPELLS 1/4.
2. Press 7 and 8: HUD becomes 3/4, both spells activate automatically.
3. Unlock Pulse or Shade: HUD becomes 4/4.
4. At 4/4, unavailable new spell no longer appears; others upgrade normally.
5. Kill enemies: some deaths cause purple Bloom explosions, not infinite chains.
6. H then B: shop cards feature TRIGGER RELICS, not ordinary stat buffs.
7. Buy a relic, verify its triggered behavior, then restart; no relic persists.
8. Summon boss: spear can hit the boss; regular combat and lightning remain.

## Notes
- The installer modifies scripts in place with backups but does not touch
  existing artwork, existing player collision shapes, or Void Lightning scripts.
- New spell visuals are procedurally drawn; no additional PNG required.
- Shop purchases are intentionally run-specific. Second Breath is capped at 1.
'''

# Check that we only modified the intended files, BEFORE writing anything.
for path, content in staged.items():
    if not isinstance(content, str) or not content.strip():
        raise SystemExit(f'ERROR: Invalid staged file {path}. Nothing changed.')

backup = ROOT / ('.hollow_backup_m6_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
backup.mkdir(parents=True)
for rel in required:
    out = backup / rel
    out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / rel, out)

for rel, content in staged.items():
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name('.' + path.name + '.m6tmp')
    tmp.write_text(content, encoding='utf-8')
    os.replace(tmp, path)

print('SUCCESS: HOLLOW Milestone 6 installed.')
print(f'Original modified files backed up at: {backup}')
print('New: Abyssal Spear, Death Bloom, 4-spell cap, 6 unique trigger relics.')
print('F5 to play. Debug: 7=upgrade Spear, 8=upgrade Bloom, H=gold, B=shop.')
print('See MILESTONE_6_NOTES.md for testing instructions.')
PY
