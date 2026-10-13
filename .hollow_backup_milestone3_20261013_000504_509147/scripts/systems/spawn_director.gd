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
    enemy.defeated.connect(Callable(run_manager, "on_enemy_defeated").bind(enemy))
