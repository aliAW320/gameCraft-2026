extends Node2D

const Catalog := preload("res://scripts/realms/realm_catalog.gd")
const WHISPERS := [
	["Remember the warmth of your hands.", "The garden knows your name.", "Something waits beneath the roots."],
	["There is nothing between you and the pain.", "You cannot put the skin back on.", "The earth has learned your heartbeat."],
	["No breath. No warmth. Still you move.", "These bones belonged to someone.", "Can a skull remember a face?"],
	["Do not stop. Do not disappear.", "Who were you?", "Even your shadow has forgotten you."]
]
var realm_index: int = 0
var cohesion: float = 100.0
var hazard_clock: float = 0.0
var hazard_age: float = -1.0
var hazard_position := Vector2.ZERO
var whisper_clock: float = 0.0
var damage_clock: float = 0.0
var sanctuary_clock: float = 0.0
var veil_material: ShaderMaterial
var whisper: Label
var screen_layer: CanvasLayer
var footsteps: Array[Dictionary] = []
var last_step := Vector2.ZERO

@onready var player: CharacterBody2D = get_node("../Actors/Player")
@onready var run: Node = get_node("../../RunManager")

func _ready() -> void:
	z_index = -1
	screen_layer = CanvasLayer.new()
	screen_layer.layer = 0
	add_child(screen_layer)
	var darkness := ColorRect.new()
	darkness.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float dread = 0.2;
uniform vec4 tint : source_color = vec4(0.02, 0.02, 0.04, 1.0);
void fragment() {
    vec2 p = UV - vec2(0.5);
    float edge = smoothstep(0.20, 0.68, length(p));
    float breath = 0.96 + sin(TIME * 0.8) * 0.04;
    COLOR = vec4(tint.rgb, edge * dread * breath);
}
"""
	veil_material = ShaderMaterial.new()
	veil_material.shader = shader
	darkness.material = veil_material
	screen_layer.add_child(darkness)
	whisper = Label.new()
	whisper.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	whisper.offset_left = -430.0
	whisper.offset_right = 430.0
	whisper.offset_top = -174.0
	whisper.offset_bottom = -140.0
	whisper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	whisper.add_theme_font_size_override("font_size", 19)
	whisper.add_theme_constant_override("outline_size", 5)
	whisper.add_theme_color_override("font_outline_color", Color.BLACK)
	screen_layer.add_child(whisper)
	run.connect("enemy_killed", Callable(self, "_on_kill"))

func set_realm(index: int) -> void:
	realm_index = index
	cohesion = 100.0
	hazard_clock = 0.0
	hazard_age = -1.0
	whisper_clock = 0.0
	damage_clock = 0.0
	sanctuary_clock = 0.0
	footsteps.clear()
	if veil_material != null:
		veil_material.set_shader_parameter("dread", [0.20, 0.36, 0.48, 0.68][index])
		veil_material.set_shader_parameter("tint", [Color(0.015, 0.03, 0.025), Color(0.09, 0.01, 0.02), Color(0.025, 0.035, 0.03), Color(0.005, 0.005, 0.03)][index])
	queue_redraw()

func _on_kill(_where: Vector2, _elite: bool) -> void:
	cohesion = minf(100.0, cohesion + 9.0)

func _process(delta: float) -> void:
	if bool(run.get("game_over")):
		whisper.hide()
		return
	if bool(run.get("descent_pending")):
		return
	whisper_clock += delta
	var phrase_index: int = int(whisper_clock / 14.0) % 3
	whisper.text = WHISPERS[realm_index][phrase_index]
	var cycle: float = fmod(whisper_clock, 14.0)
	whisper.modulate = Color(Catalog.REALMS[realm_index]["color"], clampf((cycle - 8.0) / 2.0, 0, 0.65))
	for i in range(footsteps.size() - 1, -1, -1):
		footsteps[i]["age"] += delta
		if footsteps[i]["age"] > 4.0: footsteps.remove_at(i)
	if realm_index < 3 and player.global_position.distance_to(last_step) > 28.0:
		last_step = player.global_position
		footsteps.append({"pos": last_step, "age": 0.0})
		if footsteps.size() > 30: footsteps.remove_at(0)
	if realm_index == 3:
		cohesion = maxf(0.0, cohesion - delta * (0.8 if player.velocity.length_squared() > 1.0 else 3.0))
		if cohesion < 25.0:
			whisper.text = "YOUR SOUL IS UNRAVELLING. MOVE. FIGHT. REMEMBER."
			whisper.modulate = Color(0.96, 0.47, 0.53, 0.85)
		damage_clock += delta
		if cohesion <= 0.0 and damage_clock > 1.25:
			damage_clock = 0.0
			player.call("take_damage", 6)
	elif realm_index == 0 and not bool(run.get("boss_active")):
		if player.global_position.distance_to(Vector2(1600, 1600)) < 150.0 and player.velocity.length_squared() < 1.0:
			sanctuary_clock += delta
			if sanctuary_clock >= 2.0:
				sanctuary_clock = 0.0
				player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + 2))
		else:
			sanctuary_clock = 0.0
	if realm_index in [1, 2] and not bool(run.get("boss_active")) and not bool(run.get("descent_pending")):
		hazard_clock += delta
		if hazard_age < 0.0 and hazard_clock > (7.0 if realm_index == 1 else 9.0):
			hazard_clock = 0.0
			hazard_position = player.global_position
			hazard_age = 0.0
		if hazard_age >= 0.0:
			hazard_age += delta
			# A full second of warning, followed by a short eruption.
			if hazard_age >= 1.1 and hazard_age < 1.6 and player.global_position.distance_to(hazard_position) < 72.0:
				player.call("take_damage", 7 if realm_index == 1 else 9)
			if hazard_age >= 1.6: hazard_age = -1.0
	queue_redraw()

func _draw() -> void:
	for step in footsteps:
		var tint: Color = Catalog.REALMS[realm_index]["color"]
		tint.a = (1.0 - float(step["age"]) / 4.0) * 0.18
		draw_circle(step["pos"], 4.0, tint)
	if hazard_age >= 0.0:
		var tint: Color = Catalog.REALMS[realm_index]["color"]
		draw_arc(hazard_position, 72.0, 0, TAU, 48, Color(tint, 0.75), 3.0)
		draw_circle(hazard_position, 72.0, Color(tint, 0.12 if hazard_age < 1.1 else 0.45))
		if hazard_age > 1.1:
			for i in range(8):
				var d := Vector2.RIGHT.rotated(float(i) * TAU / 8.0)
				draw_line(hazard_position + d * 20.0, hazard_position + d * 85.0, tint, 4.0)
