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
