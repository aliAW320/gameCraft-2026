extends Node2D

const Catalog := preload("res://scripts/realms/realm_catalog.gd")
const ARENA_SIZE := Vector2(3200.0, 3200.0)
const CENTER := ARENA_SIZE / 2.0
var realm_index: int = 0

func set_realm(index: int) -> void:
    realm_index = index
    queue_redraw()

func _draw() -> void:
    var realm: Dictionary = Catalog.REALMS[realm_index]
    var accent: Color = realm["color"]
    draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), realm["floor"])
    match realm_index:
        0: _garden()
        1: _mire()
        2: _ossuary()
        3: _absence()
    draw_rect(Rect2(Vector2(12, 12), ARENA_SIZE - Vector2(24, 24)), Color(accent, 0.35), false, 16.0)
    if realm_index == 0:
        draw_arc(CENTER, 155.0, 0.0, TAU, 96, Color(accent, 0.40), 3.0)
        for i in range(8):
            var direction := Vector2.RIGHT.rotated(float(i) * TAU / 8.0)
            draw_line(CENTER + direction * 160.0, CENTER + direction * 184.0, Color(0.70, 0.63, 0.38, 0.45), 4.0)
    elif realm_index == 1:
        # Arteries meet at an open heart, rather than another ceremonial circle.
        for i in range(7):
            var direction := Vector2.RIGHT.rotated(float(i) * TAU / 7.0)
            var artery := PackedVector2Array()
            var a: Vector2 = CENTER + direction * 80.0
            var b: Vector2 = CENTER + direction * 170.0 + direction.orthogonal() * 65.0
            var c: Vector2 = CENTER + direction * 280.0
            for j in range(24):
                var t: float = float(j) / 23.0
                artery.append(a * (1.0 - t) * (1.0 - t) + b * 2.0 * (1.0 - t) * t + c * t * t)
            draw_polyline(artery, Color(0.52, 0.16, 0.17, 0.55), 16.0, true)
            draw_polyline(artery, Color(0.79, 0.33, 0.29, 0.30), 2.0, true)
    elif realm_index == 2:
        # The central court resembles a ribcage picked clean.
        for i in range(6):
            var y: float = -155.0 + i * 52.0
            for side in [-1, 1]:
                var rib := PackedVector2Array([CENTER + Vector2(side * 60, y), CENTER + Vector2(side * 150, y - 20), CENTER + Vector2(side * 200, y + 20)])
                draw_polyline(rib, Color(0.65, 0.61, 0.45, 0.32), 8.0, true)
    else:
        # Only fragments of the first realm's magic survive.
        for i in range(3):
            draw_arc(CENTER, 115.0 + i * 23.0, float(i) * 2.0, float(i) * 2.0 + 0.48, 16, Color(accent, 0.20), 2.0)

func _garden() -> void:
    var ground: Texture2D = Catalog.texture_at("res://assets/realms/living_ground.png")
    for row in range(13):
        for col in range(13):
            draw_texture_rect(ground, Rect2(Vector2(col, row) * 256.0, Vector2(256, 256)), false)
    # Formal garden: four courtyards, cross paths and concentric stone walks.
    var path := Color(0.30, 0.33, 0.29, 0.70)
    draw_rect(Rect2(0, 1500, 3200, 200), path)
    draw_rect(Rect2(1500, 0, 200, 3200), path)
    for radius in [470.0, 1040.0]:
        draw_arc(CENTER, radius, 0, TAU, 160, path, 95.0)
        draw_arc(CENTER, radius - 48.0, 0, TAU, 160, Color(0.63, 0.56, 0.34, 0.25), 3.0)
    for p in [Vector2(850, 850), Vector2(2350, 850), Vector2(850, 2350), Vector2(2350, 2350)]:
        draw_rect(Rect2(p - Vector2(240, 240), Vector2(480, 480)), Color(0.10, 0.20, 0.13, 0.58))
        draw_rect(Rect2(p - Vector2(240, 240), Vector2(480, 480)), Color(0.57, 0.55, 0.35, 0.40), false, 7.0)

func _mire() -> void:
    var tiles: Texture2D = Catalog.texture_at("res://hollow_art_pack/assets/meat and suffer area/PNG/Ground.png")
    _surface(tiles, Rect2(208, 160, 16, 16), Color(0.65, 0.43, 0.43, 0.42))
    # Winding sinew lanes and irregular dark pools replace the garden's order.
    for branch in range(5):
        var vein := PackedVector2Array()
        for step in range(65):
            var y: float = float(step) * 50.0
            vein.append(Vector2(330.0 + float(branch) * 640.0 + sin(y / 260.0 + branch) * 170.0, y))
        draw_polyline(vein, Color(0.38, 0.14, 0.15), 140.0, true)
        draw_polyline(vein, Color(0.59, 0.25, 0.22, 0.55), 14.0, true)
    for i in range(18):
        var p := Vector2(200 + (i * 719) % 2800, 220 + (i * 977) % 2780)
        if p.distance_to(CENTER) < 260.0: continue
        _pool(p, 95.0 + float(i % 4) * 20.0, Color(0.10, 0.045, 0.075), i)

func _ossuary() -> void:
    var tiles: Texture2D = Catalog.texture_at("res://hollow_art_pack/assets/skull and bones area/PNG/Ground_rocks.png")
    _surface(tiles, Rect2(456, 264, 16, 16), Color(0.78, 0.80, 0.70, 0.48))
    # Rib spokes surround a circular necropolis with four tomb courts.
    for i in range(12):
        var direction := Vector2.RIGHT.rotated(TAU * float(i) / 12.0)
        draw_line(CENTER + direction * 210.0, CENTER + direction * 1550.0, Color(0.31, 0.33, 0.29), 72.0)
        draw_line(CENTER + direction * 210.0, CENTER + direction * 1550.0, Color(0.66, 0.63, 0.47, 0.25), 3.0)
    for radius in [500.0, 1000.0, 1380.0]:
        draw_arc(CENTER, radius, 0, TAU, 160, Color(0.47, 0.46, 0.37, 0.25), 38.0)
    for p in [Vector2(720, 720), Vector2(2480, 720), Vector2(720, 2480), Vector2(2480, 2480)]:
        draw_rect(Rect2(p - Vector2(200, 200), Vector2(400, 400)), Color(0.10, 0.13, 0.13, 0.75))
        draw_rect(Rect2(p - Vector2(200, 200), Vector2(400, 400)), Color(0.64, 0.60, 0.44, 0.4), false, 8.0)

func _absence() -> void:
    # All spirit-space is traversable; islands and bridges are remembered matter.
    var tiles: Texture2D = Catalog.texture_at("res://hollow_art_pack/assets/soul and emptyness area/Terrain/Tiles.png")
    for i in range(170):
        var p := Vector2(40 + (i * 773) % 3120, 40 + (i * 1091) % 3120)
        draw_circle(p, 1.0 + float(i % 3), Color(0.43, 0.62, 0.78, 0.22))
    for i in range(8):
        var angle: float = TAU * float(i) / 8.0
        var p: Vector2 = CENTER + Vector2.RIGHT.rotated(angle) * (940.0 if i % 2 == 0 else 650.0)
        draw_line(CENTER, p, Color(0.26, 0.29, 0.50, 0.25), 86.0)
        draw_line(CENTER, p, Color(0.45, 0.65, 0.80, 0.18), 2.0)
        _pool(p, 210.0 if i % 2 == 0 else 155.0, Color(0.12, 0.13, 0.23), i)
        for row in range(-2, 3):
            for col in range(-2, 3):
                draw_texture_rect_region(tiles, Rect2(p + Vector2(col, row) * 48.0 - Vector2(24, 24), Vector2(48, 48)), Rect2((i % 5) * 16, 16, 16, 16), Color(0.7, 0.8, 1.0, 0.32))
    _pool(CENTER, 180.0, Color(0.10, 0.11, 0.20), 0)

func _surface(texture: Texture2D, source: Rect2, tint: Color) -> void:
    for row in range(50):
        for col in range(50):
            draw_texture_rect_region(texture, Rect2(Vector2(col, row) * 64.0, Vector2(64, 64)), source, tint)

func _pool(center: Vector2, radius: float, color: Color, seed_value: int) -> void:
    var points := PackedVector2Array()
    for i in range(24):
        var a: float = TAU * float(i) / 24.0
        var r: float = radius * (1.0 + sin(a * 3.0 + seed_value) * 0.14)
        points.append(center + Vector2.RIGHT.rotated(a) * r)
    draw_colored_polygon(points, color)
    points.append(points[0])
    draw_polyline(points, Color(Catalog.REALMS[realm_index]["color"], 0.14), 5.0, true)
