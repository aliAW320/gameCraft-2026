extends Node2D

## Animated in-engine forms keep the descent visible if generated art is unavailable.
const Catalog := preload("res://scripts/realms/realm_catalog.gd")
var facing: float = 1.0
var phase: float = 0.0

func _ready() -> void:
    z_index = 1

func _process(delta: float) -> void:
    var body := get_parent() as CharacterBody2D
    if absf(body.velocity.x) > 1.0: facing = signf(body.velocity.x)
    phase += delta * (10.0 if body.velocity.length_squared() > 1.0 else 1.5)
    var index: int = body.get("realm_index")
    var id: String = Catalog.REALMS[index]["id"]
    var has_art: bool = ResourceLoader.exists("res://assets/realms/players/%s.png" % id) or ResourceLoader.exists("res://assets/realms/players/descent_atlas.png") or ResourceLoader.exists("res://assets/realms/%s_characters.png" % id)
    visible = not has_art
    body.get_node("HollowArt").visible = has_art
    modulate.a = 0.5 if float(body.get("invulnerable_for")) > 0.0 and int(Time.get_ticks_msec() / 90) % 2 == 0 else 1.0
    if visible: queue_redraw()

func _draw() -> void:
    var body := get_parent() as CharacterBody2D
    var index: int = body.get("realm_index")
    var moving: bool = body.velocity.length_squared() > 1.0
    var step: float = sin(phase) * (4.0 if moving else 0.5)
    draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
    var skin := Color(0.82, 0.60, 0.42)
    var muscle := Color(0.72, 0.18, 0.19)
    var bone := Color(0.86, 0.83, 0.63)
    var magic := Color(0.38, 0.91, 1.0)
    if index < 3:
        var limb_tint: Color = skin if index == 0 else (muscle if index == 1 else bone)
        _limb(Vector2(-6, -19), Vector2(-9, -6 + step), Vector2(-11, 3 + step), limb_tint, 5.0 if index < 2 else 3.0)
        _limb(Vector2(6, -19), Vector2(9, -6 - step), Vector2(11, 3 - step), limb_tint, 5.0 if index < 2 else 3.0)
        _limb(Vector2(-10, -45), Vector2(-16, -33), Vector2(-14, -25), limb_tint, 5.0 if index < 2 else 3.0)
        _limb(Vector2(10, -45), Vector2(17, -34), Vector2(24, -30), limb_tint, 5.0 if index < 2 else 3.0)
        if index == 0:
            draw_colored_polygon(PackedVector2Array([Vector2(-11, -48), Vector2(11, -48), Vector2(14, -12), Vector2(-14, -12)]), Color(0.17, 0.22, 0.38))
            draw_line(Vector2(-10, -24), Vector2(11, -24), Color(0.60, 0.48, 0.22), 3.0)
            draw_circle(Vector2(0, -57), 9.0, skin)
            draw_arc(Vector2(0, -58), 10.0, PI, TAU, 16, Color(0.23, 0.28, 0.43), 5.0)
            draw_line(Vector2(-4, -53), Vector2(1, -48), Color(0.76, 0.74, 0.65), 4.0)
            draw_line(Vector2(-9, 2 + step), Vector2(-14, 2 + step), Color(0.17, 0.12, 0.12), 6.0)
            draw_line(Vector2(9, 2 - step), Vector2(14, 2 - step), Color(0.17, 0.12, 0.12), 6.0)
        elif index == 1:
            draw_colored_polygon(PackedVector2Array([Vector2(-11, -48), Vector2(11, -48), Vector2(8, -22), Vector2(-8, -22)]), muscle)
            draw_circle(Vector2(0, -57), 9.0, muscle)
            for i in range(5):
                var y: float = -45 + i * 4.0
                draw_line(Vector2(-8, y), Vector2(-1, y + 3), Color(0.94, 0.42, 0.35), 1.3)
                draw_line(Vector2(8, y), Vector2(1, y + 3), Color(0.94, 0.42, 0.35), 1.3)
            draw_line(Vector2(0, -47), Vector2(0, -25), Color(0.96, 0.62, 0.48), 1.5)
            for x in [-5.0, 0.0, 5.0]:
                draw_line(Vector2(x, -64), Vector2(x * 0.7, -54), Color(0.94, 0.43, 0.36), 1.2)
            draw_rect(Rect2(-9, -25, 18, 8), Color(0.17, 0.18, 0.29))
        else:
            draw_line(Vector2(0, -49), Vector2(0, -20), bone, 3.0)
            for i in range(5):
                var y: float = -46 + i * 4.0
                draw_arc(Vector2(0, y), 10.0 - i * 0.8, 0.1, PI - 0.1, 12, bone, 2.0)
            draw_arc(Vector2(0, -21), 7.0, 0, PI, 12, bone, 4.0)
            draw_circle(Vector2(0, -57), 9.0, bone)
            draw_rect(Rect2(-5, -51, 10, 5), bone)
            draw_circle(Vector2(-4, -57), 3.0, Color(0.09, 0.12, 0.14))
            draw_circle(Vector2(4, -57), 3.0, Color(0.09, 0.12, 0.14))
            for x in range(-4, 5, 2): draw_line(Vector2(x, -49), Vector2(x, -46), Color(0.13, 0.15, 0.16), 1.0)
        draw_circle(Vector2(-3, -58), 1.5, magic)
        draw_circle(Vector2(3, -58), 1.5, magic)
        draw_line(Vector2(24, 4), Vector2(24, -61), Color(0.41, 0.29, 0.19), 3.0)
    else:
        var cohesion: float = float(body.get_node("../../RealmDread").get("cohesion"))
        var fade: float = lerpf(0.3, 1.0, cohesion / 100.0)
        var float_y: float = sin(phase) * 3.0
        draw_circle(Vector2(0, -35 + float_y), 27.0, Color(0.23, 0.64, 0.95, 0.08 * fade))
        draw_colored_polygon(PackedVector2Array([Vector2(0, -70 + float_y), Vector2(-13, -49 + float_y), Vector2(-11, -22), Vector2(-19, -1), Vector2(0, -12), Vector2(14, -4), Vector2(10, -29), Vector2(14, -49 + float_y)]), Color(0.28, 0.72, 0.95, 0.37 * fade))
        draw_arc(Vector2(0, -52 + float_y), 13.0, PI, TAU, 24, Color(magic, fade), 2.0)
        for side in [-1, 1]:
            draw_line(Vector2(side * 12, -44 + float_y), Vector2(side * 20, -27), Color(magic, 0.55 * fade), 2.0)
            for i in range(3):
                var x: float = side * (4.0 + i * 4.0)
                draw_line(Vector2(x, -22), Vector2(x + sin(phase + i) * 4, -5 + i * 3), Color(magic, 0.28 * fade), 1.5)
        draw_circle(Vector2(0, -35 + float_y), 4.0 + sin(phase) * 0.8, Color(magic, fade))
        draw_circle(Vector2(-4, -53 + float_y), 1.8, Color(magic, fade))
        draw_circle(Vector2(4, -53 + float_y), 1.8, Color(magic, fade))
        draw_line(Vector2(24, -8), Vector2(24, -61), Color(magic, 0.5 * fade), 2.0)
    draw_circle(Vector2(24, -65), 9.0, Color(magic, 0.12))
    draw_colored_polygon(PackedVector2Array([Vector2(24, -73), Vector2(29, -65), Vector2(24, -58), Vector2(19, -65)]), magic)
    draw_set_transform(Vector2.ZERO)

func _limb(a: Vector2, b: Vector2, c: Vector2, tint: Color, width: float) -> void:
    draw_line(a, b, Color(0.04, 0.05, 0.08), width + 2.0, true)
    draw_line(b, c, Color(0.04, 0.05, 0.08), width + 2.0, true)
    draw_line(a, b, tint, width, true)
    draw_line(b, c, tint, width, true)
    draw_circle(b, width * 0.6, tint)
