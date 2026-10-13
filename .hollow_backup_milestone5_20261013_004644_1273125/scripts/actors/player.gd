extends CharacterBody2D

signal died

@export var speed: float = 185.0
@export var max_health: int = 100

var health: int = 100
var invulnerable_for: float = 0.0
var damage_taken_multiplier: float = 1.0

func _ready() -> void:
    add_to_group("player")
    health = max_health

func _physics_process(delta: float) -> void:
    if health <= 0:
        return

    invulnerable_for = maxf(0.0, invulnerable_for - delta)
    var horizontal := 0.0
    var vertical := 0.0
    if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
        horizontal -= 1.0
    if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
        horizontal += 1.0
    if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
        vertical -= 1.0
    if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
        vertical += 1.0

    velocity = Vector2(horizontal, vertical).normalized() * speed
    move_and_slide()
    global_position = Vector2(
        clampf(global_position.x, 20.0, 3180.0),
        clampf(global_position.y, 20.0, 3180.0)
    )
    if invulnerable_for > 0.0:
        queue_redraw()

func take_damage(amount: int) -> void:
    if health <= 0 or invulnerable_for > 0.0:
        return
    var adjusted_damage := maxi(1, roundi(float(amount) * damage_taken_multiplier))
    health = maxi(0, health - adjusted_damage)
    invulnerable_for = 0.75
    queue_redraw()
    if health == 0:
        died.emit()

func _draw() -> void:
    draw_circle(Vector2(0.0, 11.0), 17.0, Color(0.0, 0.0, 0.0, 0.35))
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -18.0), Vector2(-15.0, 9.0),
            Vector2(-9.0, 18.0), Vector2(9.0, 18.0), Vector2(15.0, 9.0)
        ]),
        Color(0.20, 0.24, 0.36)
    )
    draw_circle(Vector2(0.0, -6.0), 11.0, Color(0.09, 0.11, 0.20))
    draw_circle(Vector2(-4.0, -7.0), 2.0, Color(0.45, 0.91, 1.0))
    draw_circle(Vector2(4.0, -7.0), 2.0, Color(0.45, 0.91, 1.0))
    if invulnerable_for > 0.0:
        draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 36, Color(0.40, 0.82, 1.0, 0.65), 2.0)
