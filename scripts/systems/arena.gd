extends Node2D

const ARENA_SIZE := Vector2(3200.0, 3200.0)
const TILE_SIZE := 128

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.08, 0.09, 0.13))
    for x in range(0, int(ARENA_SIZE.x), TILE_SIZE):
        for y in range(0, int(ARENA_SIZE.y), TILE_SIZE):
            var even_tile := (int(float(x) / float(TILE_SIZE)) + int(float(y) / float(TILE_SIZE))) % 2 == 0
            var shade := Color(0.115, 0.12, 0.18) if even_tile else Color(0.10, 0.105, 0.16)
            var tile := Rect2(float(x), float(y), float(TILE_SIZE), float(TILE_SIZE))
            draw_rect(tile, shade)
            draw_rect(tile, Color(0.22, 0.20, 0.30, 0.18), false, 1.0)

    draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color(0.48, 0.32, 0.64), false, 20.0)
    var center := ARENA_SIZE / 2.0
    draw_arc(center, 156.0, 0.0, TAU, 80, Color(0.48, 0.28, 0.72, 0.5), 3.0)
    draw_arc(center, 90.0, 0.0, TAU, 64, Color(0.27, 0.59, 0.67, 0.4), 2.0)
    for i in range(32):
        var p := Vector2(float(160 + (i * 719) % 2860), float(160 + (i * 1009) % 2860))
        draw_line(p + Vector2(-11.0, -5.0), p + Vector2(12.0, 7.0), Color(0.38, 0.25, 0.51, 0.42), 2.0)
        draw_line(p + Vector2(12.0, 7.0), p + Vector2(5.0, 14.0), Color(0.38, 0.25, 0.51, 0.42), 2.0)

    # M5: scattered runestones and pale, ruined glyphs. Purely visual; no collisions.
    for i in range(48):
        var px: float = float(125 + (i * 757) % 2900)
        var py: float = float(155 + (i * 1093) % 2860)
        var center_stone := Vector2(px, py)
        draw_circle(center_stone + Vector2(5, 5), 11.0, Color(0.0, 0.0, 0.0, 0.19))
        draw_colored_polygon(PackedVector2Array([
            center_stone + Vector2(0, -10), center_stone + Vector2(7, -2),
            center_stone + Vector2(4, 9), center_stone + Vector2(-7, 8),
            center_stone + Vector2(-8, -3)
        ]), Color(0.23, 0.22, 0.33, 0.67))
        if i % 3 == 0:
            draw_line(center_stone + Vector2(-3, -3), center_stone + Vector2(3, 2),
                Color(0.57, 0.37, 0.88, 0.65), 2.0)
            draw_circle(center_stone + Vector2(3, 2), 2.0, Color(0.65, 0.48, 0.9, 0.65))
    for i in range(16):
        var a: float = TAU * float(i) / 16.0
        var rune_pos: Vector2 = ARENA_SIZE / 2.0 + Vector2.RIGHT.rotated(a) * 202.0
        draw_line(rune_pos, rune_pos + Vector2.RIGHT.rotated(a) * 19.0,
            Color(0.50, 0.31, 0.75, 0.40), 3.0)
