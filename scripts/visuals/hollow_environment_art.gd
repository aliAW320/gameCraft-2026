extends Node2D

const Catalog := preload("res://scripts/realms/realm_catalog.gd")
const FLESH_ROOT := "res://hollow_art_pack/assets/meat and suffer area/PNG/Objects_separetely/"
const BONE_ROOT := "res://hollow_art_pack/assets/skull and bones area/PNG/"
const SOUL_ROOT := "res://hollow_art_pack/assets/soul and emptyness area/Structures & Details/"
const PROP_PATHS := [
    [],
    [FLESH_ROOT + "Ruins_shadow1_3.png", FLESH_ROOT + "Rock_eyes_shadow1_1.png", FLESH_ROOT + "Tentacle_plant_shadow1_1.png", FLESH_ROOT + "Spike_plant_shadow1_1.png", FLESH_ROOT + "Veins_shadow1_1.png"],
    [BONE_ROOT + "128/Demon_scull_light_shadow.png", BONE_ROOT + "128/Gates_light_shadow1.png", BONE_ROOT + "256/Dinosaur_skeleton_full_light_shadow.png", BONE_ROOT + "128/Dark_totem_dark_shadow2.png", BONE_ROOT + "128/white_crystal_light_shadow2.png"],
    [SOUL_ROOT + "Statue A1.png", SOUL_ROOT + "Amalgam Arc 1.png", SOUL_ROOT + "Book Altar.png", SOUL_ROOT + "Tall Vein Column 1.png", SOUL_ROOT + "Urn 1.png"],
]
var realm_index: int = 0
var props: Array[Texture2D] = []

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_realm(index: int) -> void:
    realm_index = index
    props.clear()
    if index == 0:
        var sheet: Texture2D = Catalog.texture_at("res://assets/realms/living_props.png")
        for slot in range(6):
            if sheet != null:
                props.append(Catalog.cell(sheet, slot))
            else:
                var fallback: String = ["tree", "pillar", "statue", "altar", "runestone", "brambles"][slot]
                props.append(Catalog.texture_at("res://assets/hollow_art/environment/%s.png" % fallback))
    else:
        for path in PROP_PATHS[index]:
            props.append(Catalog.texture_at(path))
    queue_redraw()

func _draw() -> void:
    if props.is_empty(): return
    # Matter thins out with every descent: 84 -> 64 -> 48 -> 20 landmarks.
    var count: int = [84, 64, 48, 20][realm_index]
    for i in range(count):
        var p := Vector2(160 + (i * 673) % 2880, 180 + (i * 997) % 2840)
        if p.distance_to(Vector2(1600, 1600)) < 280.0: continue
        if realm_index == 0 and (absf(p.x - 1600) < 140 or absf(p.y - 1600) < 140): continue
        _prop(props[i % props.size()], p, 105.0 + float(i % 4) * 22.0)
    if realm_index == 0:
        _prop(props[3], Vector2(1600, 1380), 160.0)
        for p in [Vector2(850, 850), Vector2(2350, 850), Vector2(850, 2350), Vector2(2350, 2350)]:
            _prop(props[0], p, 240.0)
    elif realm_index == 1:
        for i in range(6):
            _prop(props[2], Vector2(1600, 1600) + Vector2.RIGHT.rotated(float(i) * TAU / 6.0) * 350.0, 145.0)
    elif realm_index == 2:
        for p in [Vector2(720, 720), Vector2(2480, 720), Vector2(720, 2480), Vector2(2480, 2480)]:
            _prop(props[2], p, 320.0)
        _prop(props[1], Vector2(1600, 1260), 210.0)
    else:
        _prop(props[2], Vector2(1600, 1430), 115.0)
        for i in range(4):
            _prop(props[0], Vector2(1600, 1600) + Vector2.RIGHT.rotated(float(i) * TAU / 4.0) * 940.0, 155.0)

func _prop(texture: Texture2D, foot: Vector2, span: float) -> void:
    if texture == null: return
    var dim: Vector2 = texture.get_size() * span / maxf(texture.get_width(), texture.get_height())
    draw_texture_rect(texture, Rect2(foot - Vector2(dim.x * 0.5, dim.y * 0.85), dim), false)
