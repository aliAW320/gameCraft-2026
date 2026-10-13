extends Control

signal upgrade_selected(upgrade_id: String)

var available_cards: Array[Dictionary] = []
var buttons: Array[Button] = []
var title_label: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_interface()
    hide()

func show_choices(choices: Array[Dictionary], player_level: int) -> void:
    available_cards = choices
    title_label.text = "HOLLOW AWAKENING  |  LEVEL %d" % player_level
    for i in range(buttons.size()):
        var button := buttons[i]
        button.visible = i < choices.size()
        if button.visible:
            var card: Dictionary = choices[i]
            button.text = "%d  ·  %s\n\n%s" % [
                i + 1, String(card["title"]), String(card["description"])
            ]
    show()
    if not buttons.is_empty():
        buttons[0].grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
    if not visible or not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    var choice := -1
    match key_event.keycode:
        KEY_1:
            choice = 0
        KEY_2:
            choice = 1
        KEY_3:
            choice = 2
    if choice >= 0 and choice < available_cards.size():
        get_viewport().set_input_as_handled()
        _select_card(choice)

func _select_card(index: int) -> void:
    if not visible or index < 0 or index >= available_cards.size():
        return
    upgrade_selected.emit(String(available_cards[index]["id"]))

func _build_interface() -> void:
    var overlay := ColorRect.new()
    overlay.color = Color(0.01, 0.015, 0.035, 0.85)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var centering := CenterContainer.new()
    centering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centering)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(870.0, 338.0)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.10, 0.10, 0.16)
    panel_style.border_color = Color(0.44, 0.33, 0.63)
    panel_style.set_border_width_all(3)
    panel_style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel", panel_style)
    centering.add_child(panel)

    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 22)
    margins.add_theme_constant_override("margin_right", 22)
    margins.add_theme_constant_override("margin_top", 22)
    margins.add_theme_constant_override("margin_bottom", 22)
    panel.add_child(margins)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 18)
    margins.add_child(content)

    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 28)
    title_label.add_theme_color_override("font_color", Color(0.86, 0.79, 1.0))
    content.add_child(title_label)

    var subtitle := Label.new()
    subtitle.text = "Choose an upgrade  |  Equip up to 4 spells (shop offers unique relics)"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 17)
    content.add_child(subtitle)

    var cards := HBoxContainer.new()
    cards.add_theme_constant_override("separation", 14)
    content.add_child(cards)

    for i in range(3):
        var button := Button.new()
        button.custom_minimum_size = Vector2(260.0, 176.0)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.add_theme_font_size_override("font_size", 17)
        button.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
        button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.72))
        button.pressed.connect(_select_card.bind(i))
        cards.add_child(button)
        buttons.append(button)

    var hint := Label.new()
    hint.text = "Click a card, or press 1 / 2 / 3"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.64, 0.68, 0.77))
    content.add_child(hint)
