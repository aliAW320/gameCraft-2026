extends CharacterBody2D

signal defeated

const BOLT_SCENE := preload("res://scenes/spells/boss_bolt.tscn")
const ARENA_MIN := 44.0
const ARENA_MAX := 3156.0

enum State { INTRO, CHASE, BARRAGE_WARNING, CHARGE_WARNING, DASH, RECOVERY }

@export var max_health: int = 1500
@export var walking_speed: float = 73.0
@export var dash_speed: float = 500.0

var health: int = 1500
var realm_index: int = 3
var state: State = State.INTRO
var state_timer: float = 0.85
var attacks_performed: int = 0
var hit_flash: float = 0.0
var charge_direction: Vector2 = Vector2.RIGHT
var charge_target: Vector2 = Vector2.ZERO
var volleys: int = 1

func configure_realm(index: int) -> void:
    realm_index = index
    max_health = [360, 540, 760, 1100][index]
    health = max_health
    walking_speed = [56.0, 65.0, 78.0, 86.0][index]
    dash_speed = [340.0, 420.0, 540.0, 580.0][index]

@onready var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
@onready var projectile_container: Node2D = get_node("../../../Projectiles") as Node2D

func _ready() -> void:
    add_to_group("enemies")
    add_to_group("boss")
    health = max_health
    queue_redraw()

func _physics_process(delta: float) -> void:
    if health <= 0 or not is_instance_valid(player):
        return

    state_timer -= delta
    if hit_flash > 0.0:
        hit_flash = maxf(0.0, hit_flash - delta)
        queue_redraw()

    match state:
        State.INTRO:
            velocity = Vector2.ZERO
            if state_timer <= 0.0:
                _enter_state(State.CHASE, 1.7)
        State.CHASE:
            var towards: Vector2 = player.global_position - global_position
            if towards.length_squared() > 145.0 * 145.0:
                velocity = towards.normalized() * walking_speed
            else:
                velocity = Vector2.ZERO
            move_and_slide()
            _deal_contact_damage(12)
            if state_timer <= 0.0:
                if attacks_performed % 2 == 0:
                    _enter_state(State.BARRAGE_WARNING, 0.65)
                else:
                    charge_target = player.global_position
                    charge_direction = (charge_target - global_position).normalized()
                    if charge_direction == Vector2.ZERO:
                        charge_direction = Vector2.RIGHT
                    _enter_state(State.CHARGE_WARNING, 0.80)
                attacks_performed += 1
        State.BARRAGE_WARNING:
            velocity = Vector2.ZERO
            queue_redraw()
            if state_timer <= 0.0:
                _fire_barrage()
                if realm_index == 3:
                    global_position = Vector2(clampf(player.global_position.x - charge_direction.x * 270.0, 90, 3110), clampf(player.global_position.y - charge_direction.y * 270.0, 90, 3110))
                _enter_state(State.RECOVERY, 0.45)
        State.CHARGE_WARNING:
            velocity = Vector2.ZERO
            queue_redraw()
            if state_timer <= 0.0:
                _enter_state(State.DASH, 0.42)
        State.DASH:
            velocity = charge_direction * dash_speed
            move_and_slide()
            global_position = Vector2(
                clampf(global_position.x, ARENA_MIN, ARENA_MAX),
                clampf(global_position.y, ARENA_MIN, ARENA_MAX)
            )
            _deal_contact_damage(20)
            if state_timer <= 0.0:
                if realm_index == 2:
                    _fire_barrage()
                _enter_state(State.RECOVERY, 0.55)
        State.RECOVERY:
            velocity = Vector2.ZERO
            if state_timer <= 0.0:
                _enter_state(State.CHASE, 1.9)

func _enter_state(new_state: State, seconds: float) -> void:
    state = new_state
    state_timer = seconds
    queue_redraw()

func _deal_contact_damage(amount: int) -> void:
    if global_position.distance_squared_to(player.global_position) <= 56.0 * 56.0:
        player.call("take_damage", amount)

func _fire_barrage() -> void:
    if not is_instance_valid(projectile_container):
        return
    var aim_angle: float = (player.global_position - global_position).angle()
    var count: int = [6, 8, 12, 16][realm_index]
    for i in range(count):
        var direction: Vector2 = Vector2.RIGHT.rotated(aim_angle + TAU * float(i) / count)
        var bolt = BOLT_SCENE.instantiate()
        projectile_container.add_child(bolt)
        bolt.global_position = global_position + direction * 45.0
        bolt.call("setup", direction, 12)
        bolt.set("speed", [210.0, 230.0, 255.0, 280.0][realm_index])

func take_damage(amount: int) -> void:
    if health <= 0 or amount <= 0:
        return
    # M5: communicate each hit before the boss can be freed.
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("show_hit", global_position, amount, health <= amount, true)
    health = maxi(0, health - amount)
    hit_flash = 0.14
    queue_redraw()
    if health == 0:
        defeated.emit()
        queue_free()

func _draw() -> void:
    # The generated sprite supplies the body; combat warnings remain separate.
    draw_circle(Vector2(0.0, 23.0), 41.0, Color(0.0, 0.0, 0.0, 0.32))

    if state == State.BARRAGE_WARNING:
        var progress: float = 1.0 - clampf(state_timer / 0.65, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 62.0 + progress * 27.0, 0.0, TAU, 52,
            Color(0.93, 0.37, 0.74, 0.85), 4.0)
        for i in range(10):
            var angle: float = TAU * float(i) / 10.0
            draw_line(Vector2.RIGHT.rotated(angle) * 48.0,
                Vector2.RIGHT.rotated(angle) * 75.0,
                Color(0.95, 0.44, 0.76, 0.65), 2.0)

    if state == State.CHARGE_WARNING:
        var end_point: Vector2 = to_local(charge_target)
        var direction: Vector2 = charge_direction
        draw_line(direction * 27.0, end_point + direction * 120.0,
            Color(1.0, 0.30, 0.43, 0.75), 9.0)
        draw_line(direction * 30.0, end_point + direction * 120.0,
            Color(1.0, 0.75, 0.82, 0.93), 2.0)
    elif state == State.DASH:
        draw_arc(Vector2.ZERO, 50.0, 0.0, TAU, 48,
            Color(1.0, 0.32, 0.49, 0.8), 4.0)
