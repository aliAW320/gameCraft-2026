extends Node2D

# Cosmetic death explosion; damage is applied once by SpellManager.
var radius: float = 100.0
var age: float = 0.0
const LIFE: float = 0.42

func configure(new_radius: float) -> void:
    radius = new_radius
    queue_redraw()

func _process(delta: float) -> void:
    age += delta
    if age >= LIFE:
        queue_free()
        return
    queue_redraw()

func _draw() -> void:
    var f: float = clampf(age / LIFE, 0.0, 1.0)
    var r: float = lerpf(18.0, radius, pow(f, 0.60))
    var fade: float = 1.0 - f
    draw_circle(Vector2.ZERO, r, Color(0.55, 0.10, 0.78, 0.25 * fade))
    draw_arc(Vector2.ZERO, r, 0.0, TAU, 60, Color(0.95, 0.47, 1.0, 0.95 * fade), 5.0)
    draw_arc(Vector2.ZERO, r * 0.76, 0.0, TAU, 44, Color(0.30, 0.06, 0.40, 0.75 * fade), 3.0)
    for i in range(9):
        var theta: float = TAU * float(i) / 9.0 + 0.19
        var direction: Vector2 = Vector2.RIGHT.rotated(theta)
        draw_line(direction * r * 0.48, direction * (r + 12.0 * fade),
            Color(0.88, 0.51, 1.0, fade), 3.2, true)
