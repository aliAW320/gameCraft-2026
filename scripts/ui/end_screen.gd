extends Control

signal restart_requested
signal quit_requested

var heading: Label
var subheading: Label
var stats: Label
var record: Label
var debug_label: Label
var restart_button: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_interface()
    hide()

func show_result(did_win: bool, total_score: int, best_score: int, total_kills: int,
        player_level: int, total_seconds: int, final_gold: int,
        debug_run: bool, new_record: bool) -> void:
    heading.text = "THE HOLLOW FALLS" if did_win else "CONSUMED BY THE HOLLOW"
    heading.add_theme_color_override("font_color",
        Color(0.70, 0.94, 1.0) if did_win else Color(1.0, 0.60, 0.70))
    var defeated_count: int = int(get_node("../../RunManager").get("bosses_defeated"))
    subheading.text = "All six Guardians have fallen. The Hollow is silent." if did_win else \
        "Your vessel shattered after defeating %d/6 Guardians." % defeated_count
    stats.text = "SCORE   %d\nSURVIVED   %02d:%02d\nENEMIES DEFEATED   %d\nLEVEL REACHED   %d\nGOLD LEFT   %d" % [
        total_score, int(total_seconds / 60.0), total_seconds % 60,
        total_kills, player_level, final_gold
    ]
    record.text = "BEST SCORE  %d%s" % [
        best_score, "  -  NEW RECORD!" if new_record else ""
    ]
    debug_label.visible = debug_run
    show()
    restart_button.grab_focus()

func _build_interface() -> void:
    var shade := ColorRect.new()
    shade.color = Color(0.009, 0.012, 0.027, 0.93)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)

    var centering := CenterContainer.new()
    centering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centering)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(625.0, 520.0)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.10, 0.09, 0.16)
    panel_style.border_color = Color(0.54, 0.41, 0.72)
    panel_style.set_border_width_all(3)
    panel_style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel", panel_style)
    centering.add_child(panel)

    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 25)
    panel.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 15)
    margin.add_child(column)

    heading = Label.new()
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 30)
    column.add_child(heading)

    subheading = Label.new()
    subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subheading.add_theme_font_size_override("font_size", 17)
    subheading.add_theme_color_override("font_color", Color(0.78, 0.76, 0.86))
    column.add_child(subheading)

    column.add_child(HSeparator.new())

    stats = Label.new()
    stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stats.add_theme_font_size_override("font_size", 20)
    stats.add_theme_color_override("font_color", Color(0.89, 0.90, 1.0))
    column.add_child(stats)

    record = Label.new()
    record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    record.add_theme_font_size_override("font_size", 21)
    record.add_theme_color_override("font_color", Color(0.98, 0.80, 0.53))
    column.add_child(record)

    debug_label = Label.new()
    debug_label.text = "DEBUG RUN - score is not saved"
    debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    debug_label.add_theme_font_size_override("font_size", 15)
    debug_label.add_theme_color_override("font_color", Color(1.0, 0.60, 0.60))
    column.add_child(debug_label)

    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 14)
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(buttons)

    restart_button = Button.new()
    restart_button.text = "RESTART RUN  (R)"
    restart_button.custom_minimum_size = Vector2(215.0, 48.0)
    restart_button.pressed.connect(func(): restart_requested.emit())
    buttons.add_child(restart_button)

    var quit_button := Button.new()
    quit_button.text = "QUIT GAME"
    quit_button.custom_minimum_size = Vector2(180.0, 48.0)
    quit_button.pressed.connect(func(): quit_requested.emit())
    buttons.add_child(quit_button)
