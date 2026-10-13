extends Node2D

## A non-collidable environment art pass. Existing arena collision is untouched.
const FLOOR = [
    preload("res://assets/hollow_art/environment/floor_a.png"),
    preload("res://assets/hollow_art/environment/floor_b.png"),
    preload("res://assets/hollow_art/environment/floor_c.png"),
    preload("res://assets/hollow_art/environment/floor_rune.png"),
    preload("res://assets/hollow_art/environment/floor_crack.png")
]
const PROPS = [
    preload("res://assets/hollow_art/environment/pillar.png"),
    preload("res://assets/hollow_art/environment/statue.png"),
    preload("res://assets/hollow_art/environment/altar.png"),
    preload("res://assets/hollow_art/environment/tree.png"),
    preload("res://assets/hollow_art/environment/runestone.png"),
    preload("res://assets/hollow_art/environment/bones.png"),
    preload("res://assets/hollow_art/environment/brambles.png")
]
const SIGIL := preload("res://assets/hollow_art/environment/arena_sigil.png")
const FLOOR_GRID: int = 25
const TILE_LENGTH: float = 128.0


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    queue_redraw()


func _draw() -> void:
    # Sparse decorated tiles on top of the original solid arena.
    for row in range(FLOOR_GRID):
        for col in range(FLOOR_GRID):
            var pattern: int = (col * 19 + row * 41 + row * col * 7) % 17
            if pattern >= 8:
                continue
            var texture: Texture2D = FLOOR[pattern % FLOOR.size()]
            var world_top_left := Vector2(float(col), float(row)) * TILE_LENGTH
            draw_texture_rect(texture, Rect2(world_top_left + Vector2(5.0, 5.0), Vector2(118.0, 118.0)), false, Color(1.0, 1.0, 1.0, 0.78))

    var sigil_size := Vector2(465.0, 196.0)
    draw_texture_rect(SIGIL, Rect2(Vector2(1600.0, 1600.0) - sigil_size * 0.5, sigil_size), false)

    # Static background-only debris. No collision or enemy pathfinding is added.
    for i in range(66):
        var p := Vector2(float(175 + (i * 671) % 2850), float(195 + (i * 983) % 2830))
        if p.distance_squared_to(Vector2(1600.0, 1600.0)) < 370.0 * 370.0:
            continue
        var tex: Texture2D = PROPS[i % PROPS.size()]
        var target_span: float = 96.0 + float((i % 4) * 15)
        var factor: float = target_span / maxf(float(tex.get_width()), float(tex.get_height()))
        var dim: Vector2 = tex.get_size() * factor
        draw_texture_rect(tex, Rect2(p - dim * 0.5, dim), false, Color(1.0, 1.0, 1.0, 0.90))
