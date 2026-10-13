extends Node2D

# M5: bounded, batched combat feedback. No one-node-per-number overhead.
const MAX_EFFECTS: int = 110
var effects: Array[Dictionary] = []
@onready var sounds: Node = get_node_or_null("../../SFXManager")

func _ready() -> void:
    add_to_group("combat_fx")
    z_index = 50

func _add(data: Dictionary) -> void:
    if effects.size() >= MAX_EFFECTS:
        effects.remove_at(0)
    effects.append(data)
    queue_redraw()

func _play_sound(event_name: String) -> void:
    if sounds != null:
        sounds.call("play_event", event_name)

func show_hit(world_pos: Vector2, amount: int, killed: bool, elite: bool) -> void:
    var hit_color := Color(0.94, 0.65, 1.0) if elite else Color(0.70, 0.92, 1.0)
    _add({"kind": "damage", "pos": world_pos + Vector2(randf_range(-12, 12), -15),
        "life": 0.58, "max": 0.58, "text": str(amount), "size": 20 if elite else 17,
        "color": hit_color, "vx": randf_range(-11.0, 11.0)})
    if killed:
        _add({"kind": "burst", "pos": world_pos, "life": 0.40, "max": 0.40,
            "color": Color(0.84, 0.48, 1.0) if elite else Color(0.42, 0.83, 1.0), "vx": 0.0})
        _play_sound("kill")
    else:
        _play_sound("hit")

func show_pickup(world_pos: Vector2, pickup_kind: String) -> void:
    var tint := Color(0.42, 0.90, 1.0)
    if pickup_kind == "gold":
        tint = Color(1.0, 0.80, 0.35)
    elif pickup_kind == "heart":
        tint = Color(1.0, 0.40, 0.52)
    elif pickup_kind == "cache":
        tint = Color(0.79, 0.54, 1.0)
    _add({"kind": "pickup", "pos": world_pos, "life": 0.33, "max": 0.33,
        "color": tint, "vx": 0.0})
    _play_sound("pickup")

func show_player_hit(world_pos: Vector2, amount: int) -> void:
    _add({"kind": "damage", "pos": world_pos + Vector2(0, -40),
        "life": 0.65, "max": 0.65, "text": "-%d" % amount, "size": 23,
        "color": Color(1.0, 0.38, 0.46), "vx": 0.0})
    _add({"kind": "burst", "pos": world_pos, "life": 0.42, "max": 0.42,
        "color": Color(1.0, 0.25, 0.36), "vx": 0.0})
    _play_sound("hurt")

func surge_burst(world_pos: Vector2) -> void:
    _add({"kind": "surge", "pos": world_pos, "life": 1.15, "max": 1.15,
        "color": Color(0.78, 0.46, 1.0), "vx": 0.0})
    _add({"kind": "banner", "pos": world_pos + Vector2(0, -70),
        "life": 1.45, "max": 1.45, "text": "HOLLOW SURGE!", "size": 25,
        "color": Color(0.93, 0.78, 1.0), "vx": 0.0})

func boss_entrance(world_pos: Vector2) -> void:
    _add({"kind": "surge", "pos": world_pos, "life": 1.15, "max": 1.15,
        "color": Color(1.0, 0.37, 0.58), "vx": 0.0})
    _add({"kind": "banner", "pos": world_pos + Vector2(0, -90),
        "life": 1.70, "max": 1.70, "text": "THE GUARDIAN AWAKENS", "size": 21,
        "color": Color(1.0, 0.70, 0.80), "vx": 0.0})

func _process(delta: float) -> void:
    if effects.is_empty():
        return
    for i in range(effects.size() - 1, -1, -1):
        var item: Dictionary = effects[i]
        var remaining: float = float(item["life"]) - delta
        if remaining <= 0.0:
            effects.remove_at(i)
            continue
        item["life"] = remaining
        if item["kind"] == "damage" or item["kind"] == "banner":
            item["pos"] = Vector2(item["pos"]) + Vector2(float(item["vx"]), -34.0) * delta
        effects[i] = item
    queue_redraw()

func _draw() -> void:
    for item in effects:
        var point: Vector2 = to_local(item["pos"])
        var ratio: float = clampf(float(item["life"]) / float(item["max"]), 0.0, 1.0)
        var tint: Color = item["color"]
        tint.a *= minf(1.0, ratio * 1.8)
        match String(item["kind"]):
            "damage":
                draw_string(ThemeDB.fallback_font, point - Vector2(11, 0),
                    String(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(item["size"]), tint)
            "banner":
                draw_string(ThemeDB.fallback_font, point - Vector2(92, 0),
                    String(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(item["size"]), tint)
            "pickup":
                draw_arc(point, 8.0 + (1.0 - ratio) * 17.0, 0.0, TAU, 18, tint, 2.0)
                draw_circle(point, 3.0 * ratio, tint)
            "burst":
                var radius: float = 8.0 + (1.0 - ratio) * 26.0
                draw_arc(point, radius, 0.0, TAU, 22, tint, 2.6)
                for j in range(6):
                    var vector: Vector2 = Vector2.RIGHT.rotated(float(j) * TAU / 6.0)
                    draw_line(point + vector * radius, point + vector * (radius + 8.0 * ratio), tint, 2.0)
            "surge":
                var growth: float = 1.0 - ratio
                draw_circle(point, 35.0 + growth * 90.0, Color(tint.r, tint.g, tint.b, 0.07 * ratio))
                draw_arc(point, 26.0 + growth * 130.0, 0.0, TAU, 52, tint, 6.0 * ratio + 1.0)
                draw_arc(point, 13.0 + growth * 86.0, 0.0, TAU, 45,
                    Color(1.0, 0.86, 1.0, 0.50 * ratio), 2.0)
