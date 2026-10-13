extends RefCounted

## The descent is earned through combat, and sealed by each realm's guardian.
const REALMS := [
	{"id": "living", "name": "THE WHOLE", "map": "Arcane Garden", "form": "Living wizard", "difficulty_time": 0.0,
		"color": Color(0.56, 0.82, 0.64), "floor": Color(0.12, 0.18, 0.15),
		"line": "A body. A name. A world still whole.", "loss": "You still cast a shadow."},
	{"id": "flesh", "name": "THE WOUND", "map": "Suffering Mire", "form": "Flesh without skin", "difficulty_time": 90.0,
		"color": Color(0.96, 0.43, 0.38), "floor": Color(0.25, 0.10, 0.12),
		"line": "The skin falls away. Only suffering remains.", "loss": "SKIN LOST · Maximum health -15"},
	{"id": "bone", "name": "THE REMAINS", "map": "Silent Ossuary", "form": "Bone and skull", "difficulty_time": 180.0,
		"color": Color(0.85, 0.82, 0.66), "floor": Color(0.17, 0.19, 0.18),
		"line": "The flesh is forgotten. The bones remember.", "loss": "FLESH LOST · Maximum health -15"},
	{"id": "soul", "name": "THE HOLLOW", "map": "Sea of Absence", "form": "Unbound soul", "difficulty_time": 270.0,
		"color": Color(0.48, 0.83, 0.97), "floor": Color(0.035, 0.035, 0.075),
		"line": "No skin. No flesh. No bone. Only the echo of you.", "loss": "BODY LOST · Stay in motion. Keep your soul alive."},
]
static var texture_cache: Dictionary = {}
const ACTOR_PATHS := [
	[],
	["meat and suffer area/PNG/Objects_separetely/Rock_eyes_shadow1_1.png", "meat and suffer area/PNG/Objects_separetely/Tentacle_plant_shadow1_1.png", "meat and suffer area/PNG/Objects_separetely/Rock_eyes_shadow1_5.png", "meat and suffer area/PNG/Objects_separetely/Rock_eyes_shadow2_5.png"],
	["skull and bones area/PNG/128/Demon_scull_light_shadow.png", "skull and bones area/PNG/256/centipede_light_shadow1.png", "skull and bones area/PNG/256/Dinosaur_skeleton_full_light_shadow.png", "skull and bones area/PNG/128/Dark_totem_dark_shadow2.png"],
	["soul and emptyness area/Creatures/Amalgam 1 Sheet.png", "soul and emptyness area/Creatures/Tentacle 1 Sheet.png", "soul and emptyness area/Creatures/Amalgam 2 Sheet.png", "soul and emptyness area/Creatures/Eldritch Entity Awaken.png"]
]

static func texture_at(path: String) -> Texture2D:
	if not texture_cache.has(path):
		if not ResourceLoader.exists(path):
			return null
		texture_cache[path] = load(path) as Texture2D
	return texture_cache[path] as Texture2D

static func character(index: int, slot: int) -> AtlasTexture:
	if slot < 2:
		var player_form: Texture2D = texture_at("res://assets/realms/players/%s.png" % REALMS[index]["id"])
		if player_form != null:
			var player_atlas := AtlasTexture.new()
			player_atlas.atlas = player_form
			return player_atlas
		var descent: Texture2D = texture_at("res://assets/realms/players/descent_atlas.png")
		if descent != null:
			var player_atlas := AtlasTexture.new()
			player_atlas.atlas = descent
			var dim: Vector2 = descent.get_size() / 2.0
			player_atlas.region = Rect2(Vector2(index % 2, floori(float(index) / 2.0)) * dim, dim)
			player_atlas.filter_clip = true
			return player_atlas
	var sheet: Texture2D = texture_at("res://assets/realms/%s_characters.png" % REALMS[index]["id"])
	if sheet == null:
		if index > 0 and slot >= 2:
			var actor := AtlasTexture.new()
			actor.atlas = texture_at("res://hollow_art_pack/assets/" + ACTOR_PATHS[index][slot - 2])
			if index == 3 and slot < 5:
				actor.region = Rect2(0, 0, 48 if slot == 3 else 96, 64)
				actor.filter_clip = true
			return actor
		# Keep the project playable if an optional art file is missing from a checkout.
		var fallback: String = ["player", "player", "husk", "skitter", "brute", "guardian"][slot]
		var atlas := AtlasTexture.new()
		atlas.atlas = texture_at("res://assets/hollow_art/characters/%s.png" % fallback)
		return atlas
	return cell(sheet, slot)

static func cell(sheet: Texture2D, slot: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var dimensions: Vector2 = sheet.get_size() / Vector2(3.0, 2.0)
	atlas.region = Rect2(Vector2(slot % 3, floori(float(slot) / 3.0)) * dimensions, dimensions)
	atlas.filter_clip = true
	return atlas

static func guardian_name(index: int) -> String:
	return ["THE GARDEN WARDEN", "THE SUFFERING HEART", "THE OSSUARY KING", "THE HOLLOW GUARDIAN"][index]
