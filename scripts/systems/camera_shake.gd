extends Camera2D

# M5: shake only camera offset, never alter camera target or map limits.
var shake_strength: float = 0.0

func kick(amount: float) -> void:
    shake_strength = minf(13.0, shake_strength + amount)

func _process(delta: float) -> void:
    if shake_strength <= 0.05:
        shake_strength = 0.0
        offset = Vector2.ZERO
        return
    offset = Vector2(
        randf_range(-shake_strength, shake_strength),
        randf_range(-shake_strength, shake_strength)
    )
    shake_strength = maxf(0.0, shake_strength - 26.0 * delta)
