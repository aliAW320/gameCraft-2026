extends Area2D

signal collected(amount: int)

@export var xp_amount: int = 1
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

    var distance := global_position.distance_to(player.global_position)
    if distance <= 23.0:
        _collect()
        return

    var magnet_radius: float = float(run_manager.get("pickup_radius"))
    if distance <= magnet_radius:
        global_position = global_position.move_toward(
            player.global_position, magnet_speed * delta
        )

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        _collect()

func _collect() -> void:
    if already_collected:
        return
    already_collected = true
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("show_pickup", global_position, "xp")
    collected.emit(xp_amount)
    queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 13.0, Color(0.21, 0.75, 1.0, 0.16))
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -10.0), Vector2(6.0, -2.0),
            Vector2(0.0, 9.0), Vector2(-6.0, -2.0)
        ]),
        Color(0.27, 0.77, 1.0)
    )
    draw_line(Vector2(0.0, -8.0), Vector2(0.0, 7.0), Color(0.77, 0.97, 1.0), 1.5)
