extends Node2D

## Decorative only. SpellManager still owns targeting, hit detection, and cooldowns.
const PULSE := preload("res://assets/hollow_art/spells/pulse.png")
const SHADE := preload("res://assets/hollow_art/spells/shade.png")

var pulse_sprite: Sprite2D
var shade_sprites: Array[Sprite2D] = []


func _ready() -> void:
    pulse_sprite = Sprite2D.new()
    pulse_sprite.texture = PULSE
    pulse_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    pulse_sprite.z_index = -1
    pulse_sprite.visible = false
    add_child(pulse_sprite)

    for i in range(2):
        var art := Sprite2D.new()
        art.texture = SHADE
        art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        art.z_index = 2
        art.scale = Vector2.ONE * (51.0 / float(maxi(SHADE.get_width(), SHADE.get_height())))
        art.visible = false
        add_child(art)
        shade_sprites.append(art)


func _process(_delta: float) -> void:
    var spells: Node2D = get_parent() as Node2D
    if spells == null:
        return

    var pulse_time: float = float(spells.get("pulse_visual_time"))
    pulse_sprite.visible = pulse_time > 0.0
    if pulse_sprite.visible:
        var radius: float = float(spells.call("_pulse_radius"))
        pulse_sprite.scale = Vector2(radius * 2.0 / float(PULSE.get_width()), radius * 1.7 / float(PULSE.get_height()))
        pulse_sprite.modulate.a = clampf(pulse_time / 0.24, 0.0, 0.8)

    var shade_level: int = int(spells.get("shade_level"))
    var positions: Array = []
    if shade_level > 0:
        positions = spells.call("_shade_positions")
    for i in range(shade_sprites.size()):
        var art: Sprite2D = shade_sprites[i]
        art.visible = i < positions.size()
        if art.visible:
            art.position = to_local(positions[i])
