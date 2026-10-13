extends Area2D

@export var speed: float = 580.0
@export var damage: int = 14
@export var lifetime: float = 1.15

var direction := Vector2.RIGHT

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func setup(shot_direction: Vector2) -> void:
    direction = shot_direction.normalized()

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node2D) -> void:
    if is_queued_for_deletion():
        return
    if body.is_in_group("enemies"):
        body.call("take_damage", damage)
        queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 9.0, Color(0.33, 0.77, 1.0, 0.25))
    draw_circle(Vector2.ZERO, 5.0, Color(0.64, 0.94, 1.0))
