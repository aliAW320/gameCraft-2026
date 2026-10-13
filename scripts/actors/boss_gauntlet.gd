extends CharacterBody2D

# HOLLOW M7: six bosses use the same scene, collision and spell target group,
# but each has a separate attack script, timings, appearance tint and armor.
signal defeated

const BOLT_SCENE := preload("res://scenes/spells/boss_bolt.tscn")
const MIN_ARENA: float = 62.0
const MAX_ARENA: float = 3138.0

const SPECS := [
    {"name": "THE ASH WARDEN", "health": 365, "speed": 66.0, "color": Color(0.95, 0.68, 0.56), "reward": 220},
    {"name": "THE VEIL STALKER", "health": 530, "speed": 106.0, "color": Color(0.63, 0.92, 1.0), "reward": 350},
    {"name": "THE THORN ORACLE", "health": 755, "speed": 77.0, "color": Color(0.87, 0.67, 1.0), "reward": 550},
    {"name": "THE RIFT COLOSSUS", "health": 1050, "speed": 52.0, "color": Color(1.0, 0.68, 0.86), "reward": 750},
    {"name": "THE MIRROR SERAPH", "health": 1360, "speed": 99.0, "color": Color(0.64, 0.96, 0.93), "reward": 1100},
    {"name": "THE HOLLOW SOVEREIGN", "health": 1980, "speed": 93.0, "color": Color(0.90, 0.61, 1.0), "reward": 1800},
]

enum State { INTRO, WALK, WARNING, DASH, RECOVERY }

@export var max_health: int = 365
var health: int = 365
var variant_index: int = 0
var display_name: String = "THE ASH WARDEN"
var walking_speed: float = 66.0
var state: State = State.INTRO
var state_timer: float = 0.8
var attack_step: int = 0
var attack_kind: String = "fan"
var warning_total: float = 0.9
var hit_flash: float = 0.0
var impact_flash_remaining: float = 0.0
var impact_flash_kind: String = ""
var aimed_direction: Vector2 = Vector2.RIGHT
var ring_gap_angle: float = 0.0
var slam_spots: Array[Vector2] = []
var slam_radius: float = 90.0
var cross_center: Vector2 = Vector2.ZERO
var cross_directions: Array[Vector2] = []

@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player") as CharacterBody2D
@onready var projectile_container: Node2D = get_node("../../../Projectiles") as Node2D
@onready var art: Sprite2D = get_node_or_null("HollowArt") as Sprite2D

func configure_boss(index: int) -> void:
    variant_index = clampi(index, 0, SPECS.size() - 1)
    var spec: Dictionary = SPECS[variant_index]
    display_name = String(spec["name"])
    max_health = int(spec["health"])
    health = max_health
    walking_speed = float(spec["speed"])

func _ready() -> void:
    add_to_group("enemies")
    add_to_group("boss")
    health = max_health
    state = State.INTRO
    state_timer = 0.85
    if art != null:
        art.modulate = SPECS[variant_index]["color"]
        if variant_index == 3:
            art.scale *= 1.15
        elif variant_index == 1:
            art.scale *= 0.80
        elif variant_index == 5:
            art.scale *= 1.12
    queue_redraw()

func _physics_process(delta: float) -> void:
    if health <= 0 or not is_instance_valid(player):
        return
    state_timer -= delta
    hit_flash = maxf(0.0, hit_flash - delta)
    if impact_flash_remaining > 0.0:
        impact_flash_remaining = maxf(0.0, impact_flash_remaining - delta)
        queue_redraw()
    if art != null:
        art.modulate = Color.WHITE if hit_flash > 0.0 else SPECS[variant_index]["color"]

    match state:
        State.INTRO:
            velocity = Vector2.ZERO
            if state_timer <= 0.0:
                _start_walk()
        State.WALK:
            var to_player: Vector2 = player.global_position - global_position
            velocity = to_player.normalized() * walking_speed if to_player.length() > 115.0 else Vector2.ZERO
            move_and_slide()
            _contact_hit(7 + 2 * variant_index)
            if state_timer <= 0.0:
                _begin_attack()
        State.WARNING:
            velocity = Vector2.ZERO
            queue_redraw()
            if state_timer <= 0.0:
                _execute_attack()
        State.DASH:
            var faster: float = 495.0 + 35.0 * float(variant_index)
            velocity = aimed_direction * faster
            move_and_slide()
            global_position = _clamp_pos(global_position)
            _contact_hit(14 + 3 * variant_index)
            if state_timer <= 0.0:
                _start_recovery()
        State.RECOVERY:
            velocity = Vector2.ZERO
            if state_timer <= 0.0:
                _start_walk()

func _clamp_pos(point: Vector2) -> Vector2:
    return Vector2(clampf(point.x, MIN_ARENA, MAX_ARENA), clampf(point.y, MIN_ARENA, MAX_ARENA))

func _start_walk() -> void:
    state = State.WALK
    var pace: float = 1.60 - 0.08 * float(variant_index)
    if variant_index == 5 and float(health) < float(max_health) * 0.5:
        pace *= 0.78
    state_timer = maxf(0.70, pace)
    queue_redraw()

func _start_recovery() -> void:
    state = State.RECOVERY
    state_timer = 0.75 if variant_index < 3 else 1.10
    if variant_index == 5 and float(health) < float(max_health) * 0.5:
        state_timer = 0.80
    queue_redraw()

func _begin_attack() -> void:
    attack_step += 1
    match variant_index:
        0: attack_kind = "fan"
        1: attack_kind = "dash"
        2: attack_kind = "ring"
        3: attack_kind = "slam"
        4: attack_kind = "cross"
        5:
            var cycle := ["ring", "slam", "cross", "dash"]
            attack_kind = cycle[(attack_step - 1) % cycle.size()]

    state = State.WARNING
    warning_total = 0.90
    match attack_kind:
        "fan":
            warning_total = 1.0
            aimed_direction = (player.global_position - global_position).normalized()
            if aimed_direction.length_squared() < 0.01:
                aimed_direction = Vector2.RIGHT
        "dash":
            warning_total = 0.90 if variant_index == 1 else 0.70
            if variant_index == 1:
                # A sudden flank, followed by a highly visible straight warning.
                var side: float = -1.0 if attack_step % 2 == 0 else 1.0
                global_position = _clamp_pos(player.global_position + Vector2(225.0 * side, -110.0))
            aimed_direction = (player.global_position - global_position).normalized()
            if aimed_direction.length_squared() < 0.01:
                aimed_direction = Vector2.RIGHT
        "ring":
            warning_total = 0.95 if variant_index == 2 else 0.75
            ring_gap_angle = (player.global_position - global_position).angle()
        "slam":
            warning_total = 1.15 if variant_index == 3 else 0.90
            slam_spots.clear()
            slam_spots.append(player.global_position)
            var move_direction: Vector2 = player.velocity.normalized()
            if move_direction == Vector2.ZERO:
                move_direction = Vector2.RIGHT
            slam_spots.append(_clamp_pos(player.global_position + move_direction * 155.0))
            if variant_index == 5:
                slam_spots.append(_clamp_pos(player.global_position - move_direction * 150.0))
        "cross":
            warning_total = 1.10 if variant_index == 4 else 0.82
            cross_center = player.global_position
            cross_directions.clear()
            var rotation_angle: float = float(attack_step) * 0.48
            cross_directions.append(Vector2.RIGHT.rotated(rotation_angle))
            cross_directions.append(Vector2.UP.rotated(rotation_angle))
            if variant_index == 5:
                cross_directions.append(Vector2(1, 1).normalized().rotated(rotation_angle))

    if variant_index == 5 and float(health) < float(max_health) * 0.5:
        warning_total *= 0.84
    state_timer = warning_total
    queue_redraw()

func _execute_attack() -> void:
    match attack_kind:
        "fan":
            _fire_fan()
            _start_recovery()
        "dash":
            state = State.DASH
            state_timer = 0.46 if variant_index == 1 else 0.56
            queue_redraw()
        "ring":
            _fire_ring()
            _start_recovery()
        "slam":
            _hit_slam()
            impact_flash_kind = "slam"
            impact_flash_remaining = 0.20
            _shake_camera(5.0)
            _start_recovery()
        "cross":
            _hit_cross()
            impact_flash_kind = "cross"
            impact_flash_remaining = 0.19
            _shake_camera(6.5)
            _start_recovery()

func _fire_bolt(direction: Vector2, power: int, speed: float) -> void:
    if not is_instance_valid(projectile_container):
        return
    var bolt: Area2D = BOLT_SCENE.instantiate() as Area2D
    if bolt == null:
        return
    projectile_container.add_child(bolt)
    bolt.global_position = global_position + direction * 51.0
    bolt.call("setup", direction, power)
    bolt.set("speed", speed)
    bolt.modulate = SPECS[variant_index]["color"]

func _fire_fan() -> void:
    var base_angle: float = aimed_direction.angle()
    for i in range(5):
        var offset: float = (float(i) - 2.0) * 0.19
        _fire_bolt(Vector2.RIGHT.rotated(base_angle + offset), 10, 310.0)

func _fire_ring() -> void:
    var count: int = 14 if variant_index == 2 else 18
    var gap_width: float = TAU * (3.0 if variant_index == 2 else 2.0) / float(count)
    for i in range(count):
        var angle: float = ring_gap_angle + TAU * float(i) / float(count)
        if absf(wrapf(angle - ring_gap_angle, -PI, PI)) < gap_width * 0.5:
            continue
        _fire_bolt(Vector2.RIGHT.rotated(angle), 11 + variant_index * 2, 280.0 + float(variant_index) * 18.0)

func _hit_slam() -> void:
    var radius: float = 87.0 if variant_index == 3 else 94.0
    for spot in slam_spots:
        if player.global_position.distance_squared_to(spot) <= radius * radius:
            player.call("take_damage", 17 + 2 * variant_index)
            break

func _shake_camera(strength: float) -> void:
    var camera: Node = player.get_node_or_null("Camera2D")
    if camera != null and camera.has_method("kick"):
        camera.call("kick", strength)

func _hit_cross() -> void:
    for direction in cross_directions:
        var delta_to_player: Vector2 = player.global_position - cross_center
        if absf(delta_to_player.cross(direction)) <= 31.0 and absf(delta_to_player.dot(direction)) <= 900.0:
            player.call("take_damage", 18 + variant_index * 2)
            break

func _contact_hit(amount: int) -> void:
    if is_instance_valid(player) and global_position.distance_squared_to(player.global_position) <= 52.0 * 52.0:
        player.call("take_damage", amount)

func take_damage(amount: int) -> void:
    if health <= 0 or amount <= 0:
        return
    var multiplier: float = 1.0
    if variant_index >= 2:
        if state == State.RECOVERY:
            multiplier = [1.0, 1.0, 1.35, 1.6, 1.65, 1.9][variant_index]
        else:
            multiplier = [1.0, 1.0, 0.80, 0.62, 0.55, 0.50][variant_index]
    var dealt: int = maxi(1, roundi(float(amount) * multiplier))
    var fx: Node = get_tree().get_first_node_in_group("combat_fx")
    if fx != null:
        fx.call("show_hit", global_position, dealt, health <= dealt, true)
    health = maxi(0, health - dealt)
    hit_flash = 0.13
    if health == 0:
        defeated.emit()
        queue_free()

func _draw() -> void:
    var tint: Color = SPECS[variant_index]["color"]
    draw_circle(Vector2(0, 18), 48.0, Color(tint.r, tint.g, tint.b, 0.09))
    draw_arc(Vector2.ZERO, 45.0, 0.0, TAU, 50, Color(tint.r, tint.g, tint.b, 0.7), 2.0)
    if impact_flash_remaining > 0.0:
        var impact_alpha: float = clampf(impact_flash_remaining / 0.20, 0.0, 1.0)
        if impact_flash_kind == "slam":
            for spot in slam_spots:
                draw_circle(to_local(spot), 87.0 if variant_index == 3 else 94.0,
                    Color(0.94, 0.48, 0.94, 0.32 * impact_alpha))
        elif impact_flash_kind == "cross":
            var center: Vector2 = to_local(cross_center)
            for direction in cross_directions:
                draw_line(center - direction * 900.0, center + direction * 900.0,
                    Color(1.0, 0.88, 0.98, impact_alpha), 16.0)
    if state != State.WARNING:
        return
    var phase: float = 1.0 - clampf(state_timer / warning_total, 0.0, 1.0)
    var warning_color: Color = Color(1.0, 0.28, 0.45, 0.65 + phase * 0.30)
    match attack_kind:
        "fan":
            var base_angle: float = aimed_direction.angle()
            for i in range(5):
                var angle: float = base_angle + (float(i) - 2.0) * 0.19
                draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle) * 480.0, warning_color, 2.0)
        "dash":
            draw_line(Vector2.ZERO, aimed_direction * 850.0, warning_color, 12.0)
            draw_line(Vector2.ZERO, aimed_direction * 850.0, Color(1.0, 0.84, 0.87), 2.0)
        "ring":
            var count: float = 14.0 if variant_index == 2 else 18.0
            var gap: float = TAU * (3.0 if variant_index == 2 else 2.0) / count
            draw_arc(Vector2.ZERO, 105.0 + phase * 15.0, ring_gap_angle + gap * 0.5,
                ring_gap_angle + TAU - gap * 0.5, 70, Color(0.85, 0.42, 1.0, 0.85), 5.0)
        "slam":
            var radius: float = 87.0 if variant_index == 3 else 94.0
            for spot in slam_spots:
                var local: Vector2 = to_local(spot)
                draw_circle(local, radius, Color(1.0, 0.25, 0.43, 0.10 + phase * 0.13))
                draw_arc(local, radius, 0.0, TAU, 60, warning_color, 4.0)
        "cross":
            var local_center: Vector2 = to_local(cross_center)
            for direction in cross_directions:
                draw_line(local_center - direction * 900.0, local_center + direction * 900.0,
                    warning_color, 62.0)
                draw_line(local_center - direction * 900.0, local_center + direction * 900.0,
                    Color(1.0, 0.84, 0.89, 0.86), 2.5)
