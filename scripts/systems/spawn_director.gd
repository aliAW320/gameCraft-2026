extends Node

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const ARENA_MIN: float = 32.0
const ARENA_MAX: float = 3168.0
const GUARANTEED_ELITES := [100.0, 280.0]

const STAGES := [
    {"interval": 1.10, "cap": 18, "weights": [100, 0, 0], "name": "THE GARDEN STILL BREATHES"},
    {"interval": 0.95, "cap": 30, "weights": [65, 35, 0], "name": "EVERYTHING HURTS"},
    {"interval": 0.80, "cap": 45, "weights": [40, 35, 25], "name": "THE DEAD REMEMBER"},
    {"interval": 0.68, "cap": 65, "weights": [25, 40, 35], "name": "DO NOT DISAPPEAR"},
]

var countdown: float = 0.5
var next_elite_index: int = 0
var phase_name: String = "THE AWAKENING"
var realm_index: int = 0

func reset_realm(index: int) -> void:
    realm_index = index
    countdown = 1.5
    next_elite_index = 0
    phase_name = STAGES[index]["name"]

@onready var player: Node2D = get_node("../World/Actors/Player") as Node2D
@onready var container: Node2D = get_node("../World/Actors/Enemies") as Node2D
@onready var run_manager: Node = get_node("../RunManager")

func _physics_process(delta: float) -> void:
    if bool(run_manager.get("game_over")) or bool(run_manager.get("boss_active")) or bool(run_manager.get("descent_pending")):
        return

    var elapsed: float = float(run_manager.get("realm_elapsed"))
    var stage: Dictionary = STAGES[realm_index]
    phase_name = stage["name"]
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

    var is_fractured: bool = realm_index > 0 and elapsed >= 40.0 and randf() < 0.06
    _spawn_enemy(_pick_kind(stage), is_fractured, elapsed)

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
    enemy.call("configure", kind, elite, elapsed + realm_index * 90.0)
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
