extends Area2D

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
