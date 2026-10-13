extends Node

signal realm_changed(index: int)
const Catalog := preload("res://scripts/realms/realm_catalog.gd")
var current_realm: int = 0
var announcement_remaining: float = 0.0
var title: Label
var subtitle: Label
var veil: ColorRect

@onready var run: Node = get_node("../RunManager")
@onready var player: Node2D = get_node("../World/Actors/Player")

func _ready() -> void:
	add_to_group("realm_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_announcement()
	apply_realm(0, false)

func apply_realm(index: int, announce: bool = true) -> void:
	if index < 0 or index >= Catalog.REALMS.size() or bool(run.get("game_over")):
		return
	if announce and bool(run.get("boss_active")):
		return
	current_realm = index
	var world: Node = get_node("../World")
	if announce:
		# Keep every drop and the complete build; clear the previous realm's combat.
		for container_name in ["Actors/Enemies", "Projectiles"]:
			for actor in world.get_node(container_name).get_children():
				actor.queue_free()
		player.set("invulnerable_for", maxf(1.8, float(player.get("invulnerable_for"))))
		get_node("../SpawnDirector").set("countdown", 1.5)
	world.get_node("ArenaVisual").call("set_realm", index)
	world.get_node("GroundDecorations/HollowEnvironmentArt").call("set_realm", index)
	player.call("set_form", index)
	player.get_node("HollowArt").call("set_realm", index)
	get_node("../SpawnDirector").call("reset_realm", index)
	world.get_node("RealmDread").call("set_realm", index)
	realm_changed.emit(index)
	if announce:
		announcement_remaining = 3.5
		title.text = "%02d / 04   %s" % [index + 1, Catalog.REALMS[index]["name"]]
		subtitle.text = "%s   |   %s" % [Catalog.REALMS[index]["line"], Catalog.REALMS[index]["loss"]]
		title.modulate = Catalog.REALMS[index]["color"]

func _process(delta: float) -> void:
	if not get_tree().paused:
		announcement_remaining = maxf(0.0, announcement_remaining - delta)
	var opacity: float = minf(1.0, announcement_remaining / 0.7)
	title.visible = announcement_remaining > 0.0 and not bool(run.get("game_over"))
	subtitle.visible = title.visible
	title.self_modulate.a = opacity
	subtitle.self_modulate.a = opacity
	veil.color = Color(0.01, 0.01, 0.03, maxf(0.0, announcement_remaining - 2.7) * 0.55)
	veil.visible = title.visible

func _build_announcement() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	column.offset_left = -440.0
	column.offset_right = 440.0
	column.offset_top = 260.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(column)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.03))
	column.add_child(title)
	subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_constant_override("outline_size", 5)
	subtitle.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.03))
	column.add_child(subtitle)
