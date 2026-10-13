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
@onready var m5_run_manager: Node = get_node("../../../../RunManager")

func _m5_damage_multiplier() -> float:
    return damage_multiplier * (1.55 if bool(m5_run_manager.get("surge_active")) else 1.0)

func _m5_cooldown_multiplier() -> float:
    return cooldown_multiplier * (0.70 if bool(m5_run_manager.get("surge_active")) else 1.0)

func _physics_process(delta: float) -> void:
    active_seconds += delta

    needle_timer -= delta
    if needle_timer <= 0.0:
        var targets := _find_needle_targets(2 if needle_level >= 2 else 1)
        if not targets.is_empty():
            for target in targets:
                _fire_needle(target)
            needle_timer = (0.55 if needle_level >= 4 else 0.70) * _m5_cooldown_multiplier()

    if pulse_level > 0:
        pulse_timer -= delta
        if pulse_timer <= 0.0:
            _cast_void_pulse()
            pulse_timer = (2.2 if pulse_level >= 4 else 3.0) * _m5_cooldown_multiplier()

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
    projectile.set("damage", roundi((21.0 if needle_level >= 3 else 14.0) * _m5_damage_multiplier()))
    projectiles.add_child(projectile)
    projectile.global_position = global_position
    projectile.call("setup", (target.global_position - global_position).normalized())

func _pulse_radius() -> float:
    return 140.0 if pulse_level >= 2 else 105.0

func _cast_void_pulse() -> void:
    var radius_squared := _pulse_radius() * _pulse_radius()
    var damage := roundi((34.0 if pulse_level >= 3 else 22.0) * _m5_damage_multiplier())
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
    var damage := roundi((11.0 if shade_level >= 3 else 7.0) * _m5_damage_multiplier())
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
