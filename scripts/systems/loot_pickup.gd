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
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("show_pickup", global_position, kind)
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
