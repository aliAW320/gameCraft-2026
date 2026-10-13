extends Sprite2D

## Visual-only artwork. Collision, damage, pickups, and enemy AI are unchanged.
@export_enum("player", "enemy", "guardian", "xp", "loot", "needle", "boss_bolt") var art_type: String = "enemy"

const HERO := preload("res://assets/hollow_art/characters/player.png")
const Catalog := preload("res://scripts/realms/realm_catalog.gd")
const HUSK := preload("res://assets/hollow_art/characters/husk.png")
const SKITTER := preload("res://assets/hollow_art/characters/skitter.png")
const BRUTE := preload("res://assets/hollow_art/characters/brute.png")
const GUARDIAN := preload("res://assets/hollow_art/characters/guardian.png")
const XP := preload("res://assets/hollow_art/pickups/xp.png")
const GOLD := preload("res://assets/hollow_art/pickups/gold.png")
const HEART := preload("res://assets/hollow_art/pickups/heart.png")
const CACHE := preload("res://assets/hollow_art/pickups/cache.png")
const NEEDLE := preload("res://assets/hollow_art/spells/needle.png")
const BOSS_ORB := preload("res://assets/hollow_art/spells/boss_orb.png")

var baseline_y: float = 0.0
var character_elite: bool = false
var realm_index: int = 0
var last_player_slot: int = 0


func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    z_index = 1
    var desired_span: float = 64.0
    var foot_y: float = 0.0

    match art_type:
        "player":
            texture = HERO
            desired_span = 86.0
            foot_y = 12.0
        "enemy":
            var enemy_kind: String = String(get_parent().get("enemy_kind"))
            character_elite = bool(get_parent().get("fractured"))
            match enemy_kind:
                "skitter":
                    texture = SKITTER
                    desired_span = 79.0
                    foot_y = 9.0
                "brute":
                    texture = BRUTE
                    desired_span = 122.0
                    foot_y = 17.0
                _:
                    texture = HUSK
                    desired_span = 83.0
                    foot_y = 10.0
        "guardian":
            texture = GUARDIAN
            desired_span = 210.0
            foot_y = 25.0
        "xp":
            texture = XP
            desired_span = 28.0
            foot_y = 10.0
        "loot":
            match String(get_parent().get("kind")):
                "heart":
                    texture = HEART
                    desired_span = 31.0
                    foot_y = 9.0
                "cache":
                    texture = CACHE
                    desired_span = 40.0
                    foot_y = 13.0
                _:
                    texture = GOLD
                    desired_span = 29.0
                    foot_y = 9.0
        "needle":
            texture = NEEDLE
            desired_span = 44.0
        "boss_bolt":
            texture = BOSS_ORB
            desired_span = 30.0

    if texture == null:
        set_process(false)
        return

    var src_span: float = maxf(float(texture.get_width()), float(texture.get_height()))
    var factor: float = desired_span / src_span
    scale = Vector2.ONE * factor
    # Keep each sprite's feet near the actor's origin/collision point.
    if art_type == "player" or art_type == "enemy" or art_type == "guardian" or art_type == "xp" or art_type == "loot":
        position.y = foot_y - float(texture.get_height()) * factor * 0.5
    baseline_y = position.y
    set_process(true)
    if art_type in ["player", "enemy", "guardian"]:
        var realm_manager: Node = get_tree().get_first_node_in_group("realm_manager")
        var index: int = int(realm_manager.get("current_realm")) if realm_manager != null else 0
        if art_type == "guardian":
            index = int(get_parent().get("realm_index"))
        set_realm(index)


func set_realm(index: int) -> void:
    realm_index = index
    var slot: int = 0
    var desired_span: float = [106.0, 100.0, 94.0, 103.0][index]
    var foot_y: float = 14.0
    if art_type == "enemy":
        slot = {"husk": 2, "skitter": 3, "brute": 4}.get(String(get_parent().get("enemy_kind")), 2)
        desired_span = 135.0 if slot == 4 else (87.0 if slot == 3 else 103.0)
    elif art_type == "guardian":
        slot = 5
        desired_span = 245.0
        foot_y = 30.0
    texture = Catalog.character(index, slot)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if index > 0 and art_type != "player" else CanvasItem.TEXTURE_FILTER_LINEAR
    material = null
    if art_type == "player" and texture is AtlasTexture:
        var source: Texture2D = (texture as AtlasTexture).atlas
        if source.resource_path.ends_with("descent_atlas.png"):
            var cutout := ShaderMaterial.new()
            cutout.shader = preload("res://scripts/visuals/player_cutout.gdshader")
            material = cutout
    var factor: float = desired_span / maxf(texture.get_width(), texture.get_height())
    scale = Vector2.ONE * factor
    position.y = foot_y - texture.get_height() * factor * 0.5
    baseline_y = position.y
    last_player_slot = 0


func _process(_delta: float) -> void:
    var owner_node: Node = get_parent()
    if realm_index == 3 and art_type == "enemy" and texture is AtlasTexture:
        var atlas := texture as AtlasTexture
        if atlas.atlas.resource_path.ends_with("Sheet.png"):
            atlas.region.position.x = float((int(Time.get_ticks_msec() / 140) + int(get_instance_id() % 6)) % 6) * atlas.region.size.x
    if art_type == "enemy":
        var flash: float = float(owner_node.get("hit_flash"))
        if flash > 0.0:
            modulate = Color(1.0, 0.82, 0.88)
        elif character_elite:
            modulate = Color(0.98, 0.72, 1.0)
        else:
            modulate = Color.WHITE
    elif art_type == "player":
        var body := owner_node as CharacterBody2D
        if body != null and body.velocity.length_squared() > 1.0:
            if absf(body.velocity.x) > 1.0:
                flip_h = body.velocity.x < 0.0
            var slot: int = 1 if body.velocity.y < -1.0 else 0
            if slot != last_player_slot:
                texture = Catalog.character(realm_index, slot)
                last_player_slot = slot
        var invuln: float = float(owner_node.get("invulnerable_for"))
        modulate.a = 0.55 if invuln > 0.0 and int(float(Time.get_ticks_msec()) / 90.0) % 2 == 0 else 1.0
        if realm_index == 3:
            var dread: Node = owner_node.get_node("../../RealmDread")
            modulate.a *= lerpf(0.38, 0.92, float(dread.get("cohesion")) / 100.0)
            position.y = baseline_y + sin(float(Time.get_ticks_msec()) * 0.004) * 3.0
        if owner_node is CharacterBody2D and (owner_node as CharacterBody2D).velocity.length_squared() > 1.0:
            position.y = baseline_y + sin(float(Time.get_ticks_msec()) * 0.014) * 1.5
        elif realm_index != 3:
            position.y = baseline_y
    elif art_type == "guardian":
        modulate = Color(1.0, 0.82, 0.88) if float(owner_node.get("hit_flash")) > 0.0 else Color.WHITE
    elif art_type == "needle" or art_type == "boss_bolt":
        var direction: Vector2 = owner_node.get("direction")
        if direction.length_squared() > 0.001:
            rotation = direction.angle()
    elif art_type == "xp" or art_type == "loot":
        position.y = baseline_y + sin(float(Time.get_ticks_msec()) * 0.005 + float(get_instance_id() % 13)) * 2.0
