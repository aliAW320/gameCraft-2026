extends Node2D

# VOID LIGHTNING: a SECOND, manual ultimate. Hollow Surge remains unchanged.
# Press Q when charged. During the dash sequence the SceneTree is paused,
# which freezes the spawn director, all enemies, timers, and ordinary spells.
# This Node, Camera2D, and CombatFX run while paused for cinematic playback.

const ENERGY_NEEDED: int = 25
const NORMAL_DAMAGE: int = 80
const FRACTURED_DAMAGE: int = 110
const BOSS_DAMAGE: int = 180
const HIT_HOLD: float = 0.055
const INTRO_DURATION: float = 0.20
const MAX_TRAILS: int = 46

enum Phase { IDLE, INTRO, DASH, HIT, RETURN }

@onready var player: CharacterBody2D = get_node("../Actors/Player") as CharacterBody2D
@onready var run_manager: Node = get_node("../../RunManager")
@onready var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
@onready var combat_fx: Node = get_node_or_null("../CombatFX")

var charge: int = 0
var seen_kills: int = 0
var active: bool = false
var phase: int = Phase.IDLE
var targets: Array[int] = []
var target_index: int = 0
var current_target_id: int = 0
var saved_position: Vector2 = Vector2.ZERO
var saved_modulate: Color = Color.WHITE
var old_camera_mode: int = Node.PROCESS_MODE_PAUSABLE
var old_camera_smoothing: bool = false
var old_camera_callback: int = 0
var old_fx_mode: int = Node.PROCESS_MODE_PAUSABLE
var from_position: Vector2 = Vector2.ZERO
var to_position: Vector2 = Vector2.ZERO
var phase_elapsed: float = 0.0
var phase_duration: float = 0.0
var trails: Array[Dictionary] = []
var meter_panel: PanelContainer
var meter_bar: ProgressBar
var meter_title: Label
var meter_hint: Label
var charge_audio: AudioStreamPlayer
var impact_audio: AudioStreamPlayer
var flash_time: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    z_index = 115
    seen_kills = int(run_manager.get("kills"))
    _create_meter()
    _create_audio()
    _update_meter()


func _create_meter() -> void:
    var layer := CanvasLayer.new()
    layer.name = "VoidLightningHUD"
    layer.layer = 0  # Below the existing level-up, shop and end-screen canvas.
    layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer)

    meter_panel = PanelContainer.new()
    meter_panel.name = "VoidLightningPanel"
    layer.add_child(meter_panel)
    meter_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    meter_panel.offset_left = -312.0
    meter_panel.offset_right = -22.0
    meter_panel.offset_top = -130.0
    meter_panel.offset_bottom = -43.0
    meter_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var skin := StyleBoxFlat.new()
    skin.bg_color = Color(0.060, 0.071, 0.13, 0.87)
    skin.border_color = Color(0.23, 0.70, 0.93, 0.8)
    skin.set_border_width_all(2)
    skin.set_corner_radius_all(8)
    skin.content_margin_left = 11.0
    skin.content_margin_right = 11.0
    skin.content_margin_top = 7.0
    skin.content_margin_bottom = 7.0
    meter_panel.add_theme_stylebox_override("panel", skin)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 3)
    meter_panel.add_child(layout)

    meter_title = Label.new()
    meter_title.add_theme_font_size_override("font_size", 17)
    meter_title.add_theme_color_override("font_color", Color(0.56, 0.90, 1.0))
    layout.add_child(meter_title)

    meter_bar = ProgressBar.new()
    meter_bar.custom_minimum_size = Vector2(263.0, 14.0)
    meter_bar.max_value = float(ENERGY_NEEDED)
    meter_bar.show_percentage = false
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color(0.20, 0.78, 1.0)
    fill.set_corner_radius_all(4)
    meter_bar.add_theme_stylebox_override("fill", fill)
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.07, 0.11, 0.20, 1.0)
    bg.set_corner_radius_all(4)
    meter_bar.add_theme_stylebox_override("background", bg)
    layout.add_child(meter_bar)

    meter_hint = Label.new()
    meter_hint.add_theme_font_size_override("font_size", 12)
    meter_hint.add_theme_color_override("font_color", Color(0.76, 0.84, 0.96))
    layout.add_child(meter_hint)


func _create_audio() -> void:
    charge_audio = AudioStreamPlayer.new()
    charge_audio.name = "VoidLightningChargeSFX"
    charge_audio.process_mode = Node.PROCESS_MODE_ALWAYS
    charge_audio.volume_db = -10.0
    charge_audio.stream = load("res://assets/sounds/generated/void_lightning_charge.wav") as AudioStream
    add_child(charge_audio)

    impact_audio = AudioStreamPlayer.new()
    impact_audio.name = "VoidLightningImpactSFX"
    impact_audio.process_mode = Node.PROCESS_MODE_ALWAYS
    impact_audio.volume_db = -18.0
    impact_audio.stream = load("res://assets/sounds/generated/void_lightning_impact.wav") as AudioStream
    add_child(impact_audio)


func _process(delta: float) -> void:
    _tick_trails(delta)
    flash_time = maxf(0.0, flash_time - delta)

    if active:
        if bool(run_manager.get("game_over")):
            _finish_cinematic()
        else:
            _tick_cinematic(delta)
    else:
        if not bool(run_manager.get("game_over")) and not get_tree().paused:
            _update_kill_charge()

    _update_meter()
    if active or not trails.is_empty():
        queue_redraw()


func _update_kill_charge() -> void:
    var total: int = int(run_manager.get("kills"))
    if total > seen_kills:
        charge = mini(ENERGY_NEEDED, charge + total - seen_kills)
    seen_kills = total


func _update_meter() -> void:
    if meter_panel == null:
        return
    meter_panel.visible = not bool(run_manager.get("game_over"))
    meter_title.text = "VOID LIGHTNING  [Q]"
    if active:
        meter_bar.value = float(ENERGY_NEEDED)
        meter_hint.text = "TIME FROZEN  |  CHAINING ENEMIES"
    else:
        meter_bar.value = float(charge)
        if charge >= ENERGY_NEEDED:
            meter_hint.text = "READY - press Q to become lightning!"
        else:
            meter_hint.text = "SOUL CHARGE  %d / %d  |  Kills fill meter" % [charge, ENERGY_NEEDED]


func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event: InputEventKey = event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if bool(run_manager.get("game_over")) or active or get_tree().paused:
        return

    if key_event.keycode == KEY_L and OS.is_debug_build():
        # Test-only shortcut. Like other debug keys, disables high score recording.
        run_manager.set("debug_modified", true)
        charge = ENERGY_NEEDED
        _update_meter()
        get_viewport().set_input_as_handled()
    elif key_event.keycode == KEY_Q and charge >= ENERGY_NEEDED:
        _activate()
        get_viewport().set_input_as_handled()


func _activate() -> void:
    if active or get_tree().paused or bool(run_manager.get("game_over")):
        return
    if int(player.get("health")) <= 0:
        return

    var snapshots: Array[Dictionary] = []
    for obj in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(obj) or obj.is_queued_for_deletion():
            continue
        if not (obj is Node2D):
            continue
        var enemy: Node2D = obj as Node2D
        if enemy.has_method("take_damage") and int(enemy.get("health")) > 0:
            snapshots.append({"id": enemy.get_instance_id(), "pos": enemy.global_position})
    if snapshots.is_empty():
        meter_hint.text = "CHARGED - wait for an enemy, then press Q"
        return

    # Nearest-neighbor routing gives visible bounces rather than random teleports.
    targets.clear()
    var cursor: Vector2 = player.global_position
    while not snapshots.is_empty():
        var best: int = 0
        var best_dist: float = INF
        for i in range(snapshots.size()):
            var d: float = cursor.distance_squared_to(Vector2(snapshots[i]["pos"]))
            if d < best_dist:
                best_dist = d
                best = i
        var next_enemy: Dictionary = snapshots[best]
        targets.append(int(next_enemy["id"]))
        cursor = Vector2(next_enemy["pos"])
        snapshots.remove_at(best)

    active = true
    charge = 0
    target_index = 0
    phase = Phase.INTRO
    phase_elapsed = 0.0
    phase_duration = INTRO_DURATION
    saved_position = player.global_position
    from_position = saved_position
    to_position = saved_position
    saved_modulate = player.modulate
    player.modulate = Color(saved_modulate.r, saved_modulate.g, saved_modulate.b, 0.0)
    global_position = saved_position
    flash_time = 0.18
    trails.clear()

    if camera != null:
        old_camera_mode = int(camera.process_mode)
        old_camera_smoothing = camera.position_smoothing_enabled
        old_camera_callback = int(camera.process_callback)
        camera.process_mode = Node.PROCESS_MODE_ALWAYS
        camera.position_smoothing_enabled = false
        camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
        if camera.has_method("reset_smoothing"):
            camera.reset_smoothing()
    if combat_fx != null:
        old_fx_mode = int(combat_fx.process_mode)
        combat_fx.process_mode = Node.PROCESS_MODE_ALWAYS

    get_tree().paused = true
    if charge_audio != null and charge_audio.stream != null:
        charge_audio.play()
    queue_redraw()


func _tick_cinematic(delta: float) -> void:
    phase_elapsed += delta
    match phase:
        Phase.INTRO:
            if phase_elapsed >= phase_duration:
                _start_next_jump()
        Phase.DASH:
            var t: float = clampf(phase_elapsed / phase_duration, 0.0, 1.0)
            # Slight ease-in/out, with visible streaks on every travel frame.
            var smooth: float = t * t * (3.0 - 2.0 * t)
            _move_orb(from_position.lerp(to_position, smooth))
            if t >= 1.0:
                _impact()
        Phase.HIT:
            if phase_elapsed >= phase_duration:
                _start_next_jump()
        Phase.RETURN:
            var t: float = clampf(phase_elapsed / phase_duration, 0.0, 1.0)
            _move_orb(from_position.lerp(saved_position, t * t * (3.0 - 2.0 * t)))
            if t >= 1.0:
                _finish_cinematic()


func _start_next_jump() -> void:
    while target_index < targets.size():
        current_target_id = targets[target_index]
        target_index += 1
        var obj: Object = instance_from_id(current_target_id)
        if not is_instance_valid(obj):
            continue
        if not (obj is Node2D):
            continue
        var enemy: Node2D = obj as Node2D
        if enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"):
            continue
        from_position = player.global_position
        to_position = enemy.global_position
        phase_elapsed = 0.0
        phase_duration = clampf(0.075 + from_position.distance_to(to_position) / 4500.0, 0.09, 0.22)
        phase = Phase.DASH
        return
    _start_return()


func _impact() -> void:
    _move_orb(to_position)
    var obj: Object = instance_from_id(current_target_id)
    if is_instance_valid(obj) and obj is Node2D:
        var enemy: Node2D = obj as Node2D
        if not enemy.is_queued_for_deletion() and enemy.has_method("take_damage"):
            var boss_hit: bool = enemy.is_in_group("boss")
            var elite_hit: bool = false
            if not boss_hit:
                elite_hit = bool(enemy.get("fractured"))
            var damage: int = BOSS_DAMAGE if boss_hit else (FRACTURED_DAMAGE if elite_hit else NORMAL_DAMAGE)
            if bool(run_manager.get("surge_active")):
                damage = roundi(float(damage) * 1.55)
            enemy.call("take_damage", damage)
            if camera != null and camera.has_method("kick"):
                camera.call("kick", 8.0 if boss_hit else (6.0 if elite_hit else 4.2))
            if impact_audio != null and impact_audio.stream != null:
                impact_audio.pitch_scale = randf_range(0.89, 1.24)
                impact_audio.play()
            flash_time = 0.10
            _add_arc(to_position + Vector2(-21, -13), to_position + Vector2(21, 13), 0.20)
            _add_arc(to_position + Vector2(-15, 16), to_position + Vector2(18, -17), 0.18)
    phase = Phase.HIT
    phase_elapsed = 0.0
    phase_duration = HIT_HOLD


func _start_return() -> void:
    phase = Phase.RETURN
    phase_elapsed = 0.0
    from_position = player.global_position
    phase_duration = clampf(0.13 + from_position.distance_to(saved_position) / 2800.0, 0.18, 0.48)


func _move_orb(world_pos: Vector2) -> void:
    var old_pos: Vector2 = global_position
    player.global_position = world_pos
    global_position = world_pos
    if old_pos.distance_squared_to(world_pos) > 6.0:
        _add_arc(old_pos, world_pos, 0.20)


func _add_arc(a: Vector2, b: Vector2, lifespan: float) -> void:
    trails.append({"a": a, "b": b, "life": lifespan, "total": lifespan, "seed": randf_range(0.0, 20.0)})
    if trails.size() > MAX_TRAILS:
        trails.remove_at(0)


func _tick_trails(delta: float) -> void:
    for i in range(trails.size() - 1, -1, -1):
        var trail: Dictionary = trails[i]
        trail["life"] = float(trail["life"]) - delta
        if float(trail["life"]) <= 0.0:
            trails.remove_at(i)
        else:
            trails[i] = trail


func _finish_cinematic() -> void:
    if not active:
        return
    active = false
    phase = Phase.IDLE
    player.global_position = saved_position
    player.modulate = saved_modulate
    global_position = saved_position
    # Avoid an unfair contact hit the instant the frozen battlefield resumes.
    player.set("invulnerable_for", maxf(0.65, float(player.get("invulnerable_for"))))
    if camera != null:
        camera.set("process_mode", old_camera_mode)
        camera.position_smoothing_enabled = old_camera_smoothing
        camera.set("process_callback", old_camera_callback)
        if camera.has_method("reset_smoothing"):
            camera.reset_smoothing()
    if combat_fx != null:
        combat_fx.set("process_mode", old_fx_mode)
    targets.clear()
    trails.clear()
    seen_kills = int(run_manager.get("kills"))
    flash_time = 0.0
    if not bool(run_manager.get("game_over")):
        get_tree().paused = false
    queue_redraw()


func _draw() -> void:
    if not active:
        return
    # Short-lived jagged electricity between the orb and recent positions.
    for line in trails:
        var start_point: Vector2 = to_local(Vector2(line["a"]))
        var end_point: Vector2 = to_local(Vector2(line["b"]))
        var life_ratio: float = clampf(float(line["life"]) / float(line["total"]), 0.0, 1.0)
        var tangent: Vector2 = (end_point - start_point).orthogonal().normalized()
        var path := PackedVector2Array()
        path.append(start_point)
        for j in range(1, 5):
            var f: float = float(j) / 5.0
            var jitter: float = sin(float(Time.get_ticks_msec()) * 0.075 + float(j) * 1.92 + float(line["seed"])) * 5.0 * life_ratio
            path.append(start_point.lerp(end_point, f) + tangent * jitter)
        path.append(end_point)
        draw_polyline(path, Color(0.13, 0.61, 1.0, life_ratio * 0.55), 8.0, true)
        draw_polyline(path, Color(0.84, 0.98, 1.0, life_ratio * 0.95), 2.3, true)

    var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.023)
    draw_circle(Vector2.ZERO, 42.0, Color(0.20, 0.54, 1.0, 0.10))
    draw_circle(Vector2.ZERO, 27.0 + pulse * 3.0, Color(0.20, 0.75, 1.0, 0.27))
    draw_circle(Vector2.ZERO, 18.0, Color(0.18, 0.72, 1.0, 0.92))
    draw_circle(Vector2.ZERO, 10.0, Color(0.90, 0.99, 1.0, 1.0))
    for j in range(5):
        var theta: float = float(Time.get_ticks_msec()) * 0.008 + TAU * float(j) / 5.0
        var a: Vector2 = Vector2.RIGHT.rotated(theta)
        var b: Vector2 = Vector2.RIGHT.rotated(theta + 0.38)
        draw_line(a * 17.0, b * (29.0 + pulse * 6.0), Color(0.48, 0.94, 1.0, 0.88), 2.8)
    if flash_time > 0.0:
        draw_circle(Vector2.ZERO, 48.0, Color(0.86, 1.0, 1.0, flash_time * 0.85))
