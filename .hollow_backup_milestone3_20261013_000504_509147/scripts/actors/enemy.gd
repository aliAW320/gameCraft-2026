extends CharacterBody2D

signal defeated(points: int)

@export var speed: float = 72.0
@export var max_health: int = 28
@export var contact_damage: int = 8

var health: int = 28
var hit_flash: float = 0.0
var player: Node2D

func _ready() -> void:
    add_to_group("enemies")
    health = max_health
    player = get_tree().get_first_node_in_group("player") as Node2D

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    if hit_flash > 0.0:
        hit_flash = maxf(0.0, hit_flash - delta)
        queue_redraw()

    var to_player := player.global_position - global_position
    velocity = to_player.normalized() * speed
    move_and_slide()
    if global_position.distance_squared_to(player.global_position) <= 29.0 * 29.0:
        player.call("take_damage", contact_damage)

func take_damage(amount: int) -> void:
    if health <= 0:
        return
    health -= amount
    if health <= 0:
        defeated.emit(10)
        queue_free()
    else:
        hit_flash = 0.12
        queue_redraw()

func _draw() -> void:
    var body_color := Color(1.0, 0.66, 0.75) if hit_flash > 0.0 else Color(0.46, 0.22, 0.34)
    draw_circle(Vector2(0.0, 6.0), 14.0, Color(0.0, 0.0, 0.0, 0.22))
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -16.0), Vector2(-13.0, -6.0), Vector2(-12.0, 11.0),
            Vector2(0.0, 15.0), Vector2(12.0, 11.0), Vector2(13.0, -6.0)
        ]),
        body_color
    )
    draw_circle(Vector2(-4.0, -3.0), 2.0, Color(1.0, 0.84, 0.91))
    draw_circle(Vector2(4.0, -3.0), 2.0, Color(1.0, 0.84, 0.91))
