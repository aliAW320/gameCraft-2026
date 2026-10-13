extends Area2D

@export var speed: float = 260.0
@export var lifetime: float = 3.25

var direction: Vector2 = Vector2.RIGHT
var damage: int = 12

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func setup(travel_direction: Vector2, hit_damage: int = 12) -> void:
    direction = travel_direction.normalized()
    damage = hit_damage

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node2D) -> void:
    if is_queued_for_deletion():
        return
    if body.is_in_group("player"):
        body.call("take_damage", damage)
        queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.18, 0.56, 0.20))
    draw_circle(Vector2.ZERO, 6.0, Color(0.96, 0.49, 0.83))
    draw_circle(Vector2(-1.0, -1.0), 2.0, Color(1.0, 0.91, 0.97))
