extends CharacterBody2D

signal defeated(points: int)

@export var speed: float = 65.0
@export var max_health: int = 24
@export var contact_damage: int = 8

var health: int = 24
var hit_flash: float = 0.0
var player: Node2D

var enemy_kind: String = "husk"
var fractured: bool = false
var xp_reward: int = 1
var score_reward: int = 10
var killed_by_bloom: bool = false

func configure(kind: String, is_fractured: bool, elapsed_seconds: float) -> void:
    enemy_kind = kind
    fractured = is_fractured

    var base_hp: int = 24
    var base_speed: float = 65.0
    var base_damage: int = 8
    var base_xp: int = 1
    var base_score: int = 10
    match enemy_kind:
        "skitter":
            base_hp = 14
            base_speed = 115.0
            base_damage = 5
            base_xp = 1
            base_score = 15
        "brute":
            base_hp = 80
            base_speed = 43.0
            base_damage = 14
            base_xp = 3
            base_score = 35
        _:
            enemy_kind = "husk"

    var minutes: float = elapsed_seconds / 60.0
    var health_scale: float = 1.0 + 0.12 * minutes
    var damage_scale: float = 1.0 + 0.07 * minutes
    var elite_hp_scale: float = 1.7 if fractured else 1.0
    var elite_speed_scale: float = 1.15 if fractured else 1.0

    max_health = maxi(1, roundi(float(base_hp) * health_scale * elite_hp_scale))
    health = max_health
    speed = base_speed * elite_speed_scale
    contact_damage = maxi(1, roundi(float(base_damage) * damage_scale))
    xp_reward = base_xp * (2 if fractured else 1)
    score_reward = base_score + (100 if fractured else 0)

    var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collider != null:
        var hit_shape := CircleShape2D.new()
        hit_shape.radius = 21.0 if enemy_kind == "brute" else (10.0 if enemy_kind == "skitter" else 13.0)
        collider.shape = hit_shape

func _ready() -> void:
    add_to_group("enemies")
    health = max_health
    player = get_tree().get_first_node_in_group("player") as Node2D

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player) or health <= 0:
        return
    if hit_flash > 0.0:
        hit_flash = maxf(0.0, hit_flash - delta)
        queue_redraw()

    var towards_player: Vector2 = player.global_position - global_position
    velocity = towards_player.normalized() * speed
    move_and_slide()
    var contact_radius: float = 35.0 if enemy_kind == "brute" else (24.0 if enemy_kind == "skitter" else 29.0)
    if global_position.distance_squared_to(player.global_position) <= contact_radius * contact_radius:
        player.call("take_damage", contact_damage)

func take_bloom_damage(amount: int) -> void:
    if health <= 0:
        return
    if health <= amount:
        killed_by_bloom = true
    take_damage(amount)

func take_damage(amount: int) -> void:
    if health <= 0:
        return
    # M5: floating combat feedback runs before queue_free() on a fatal hit.
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("show_hit", global_position, amount, health <= amount, fractured)
    health -= amount
    if health <= 0:
        defeated.emit(score_reward)
        queue_free()
    else:
        hit_flash = 0.12
        queue_redraw()

func _draw() -> void:
    var damaged: bool = hit_flash > 0.0
    draw_circle(Vector2(0.0, 7.0), 16.0 if enemy_kind == "brute" else 11.0, Color(0.0, 0.0, 0.0, 0.30))
    match enemy_kind:
        "skitter":
            var skitter_color := Color(1.0, 0.72, 0.79) if damaged else Color(0.65, 0.27, 0.45)
            for side in [-1, 1]:
                for i in range(3):
                    var dy: float = float(i - 1) * 6.0
                    draw_line(Vector2(4.0 * side, dy), Vector2(15.0 * side, dy + 4.0), skitter_color, 2.0)
            draw_circle(Vector2.ZERO, 10.0, skitter_color)
            draw_circle(Vector2(-4.0, -2.0), 1.8, Color(0.99, 0.9, 1.0))
            draw_circle(Vector2(4.0, -2.0), 1.8, Color(0.99, 0.9, 1.0))
        "brute":
            var brute_color := Color(1.0, 0.75, 0.83) if damaged else Color(0.37, 0.34, 0.48)
            draw_colored_polygon(PackedVector2Array([
                Vector2(-21, -14), Vector2(0, -20), Vector2(20, -15),
                Vector2(23, 11), Vector2(0, 21), Vector2(-23, 12)
            ]), brute_color)
            draw_line(Vector2(-8, -10), Vector2(-1, 8), Color(0.6, 0.34, 0.85), 3.0)
            draw_line(Vector2(-1, 8), Vector2(9, 3), Color(0.6, 0.34, 0.85), 3.0)
            draw_circle(Vector2(-6, -4), 2.5, Color(0.95, 0.72, 1.0))
            draw_circle(Vector2(6, -4), 2.5, Color(0.95, 0.72, 1.0))
        _:
            var husk_color := Color(1.0, 0.66, 0.75) if damaged else Color(0.46, 0.22, 0.34)
            draw_colored_polygon(PackedVector2Array([
                Vector2(0, -16), Vector2(-13, -6), Vector2(-12, 11),
                Vector2(0, 15), Vector2(12, 11), Vector2(13, -6)
            ]), husk_color)
            draw_circle(Vector2(-4, -3), 2.0, Color(1.0, 0.84, 0.91))
            draw_circle(Vector2(4, -3), 2.0, Color(1.0, 0.84, 0.91))

    if fractured:
        draw_arc(Vector2.ZERO, 24.0 if enemy_kind == "brute" else 17.0,
            0.0, TAU, 40, Color(0.75, 0.38, 1.0, 0.87), 3.0)
        draw_circle(Vector2(0, -20), 4.0, Color(0.82, 0.57, 1.0, 0.75))
