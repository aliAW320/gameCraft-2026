extends Control

signal item_requested(item_id: String)
signal shop_skipped

var available_offers: Array[Dictionary] = []
var buttons: Array[Button] = []
var title_label: Label
var gold_label: Label
var skip_button: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_interface()
    hide()

func show_offers(offers: Array[Dictionary], available_gold: int, visit_number: int) -> void:
    available_offers = offers
    title_label.text = "THE HOLLOW MERCHANT  |  VISIT %d / 3" % visit_number if visit_number > 0 else "THE HOLLOW MERCHANT  |  DEBUG VISIT"
    gold_label.text = "YOUR GOLD: %d  -  Buy ONE item or leave" % available_gold
    for i in range(buttons.size()):
        var button: Button = buttons[i]
        button.visible = i < available_offers.size()
        if not button.visible:
            continue
        var offer: Dictionary = available_offers[i]
        var price: int = int(offer["price"])
        var affordable: bool = available_gold >= price
        button.disabled = not affordable
        button.text = "%d  |  %s\n\n%s\n\n%d GOLD%s" % [
            i + 1, String(offer["title"]), String(offer["description"]),
            price, "" if affordable else "  (NOT ENOUGH)"
        ]
    show()
    var got_focus: bool = false
    for button in buttons:
        if button.visible and not button.disabled:
            button.grab_focus()
            got_focus = true
            break
    if not got_focus:
        skip_button.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
    if not visible or not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    var choice: int = -1
    match key_event.keycode:
        KEY_1:
            choice = 0
        KEY_2:
            choice = 1
        KEY_3:
            choice = 2
        KEY_0, KEY_ESCAPE:
            get_viewport().set_input_as_handled()
            _skip_shop()
            return
    if choice >= 0 and choice < available_offers.size():
        get_viewport().set_input_as_handled()
        _select_card(choice)

func _select_card(index: int) -> void:
    if not visible or index < 0 or index >= available_offers.size():
        return
    if buttons[index].disabled:
        return
    item_requested.emit(String(available_offers[index]["id"]))

func _skip_shop() -> void:
    if visible:
        shop_skipped.emit()

func _build_interface() -> void:
    var overlay := ColorRect.new()
    overlay.color = Color(0.01, 0.01, 0.035, 0.88)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var centering := CenterContainer.new()
    centering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centering)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(930.0, 365.0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.105, 0.09, 0.14)
    style.border_color = Color(0.72, 0.53, 0.22)
    style.set_border_width_all(3)
    style.set_corner_radius_all(12)
    panel.add_theme_stylebox_override("panel", style)
    centering.add_child(panel)

    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 22)
    margins.add_theme_constant_override("margin_right", 22)
    margins.add_theme_constant_override("margin_top", 20)
    margins.add_theme_constant_override("margin_bottom", 20)
    panel.add_child(margins)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 14)
    margins.add_child(content)

    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 27)
    title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.49))
    content.add_child(title_label)

    gold_label = Label.new()
    gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gold_label.add_theme_font_size_override("font_size", 17)
    gold_label.add_theme_color_override("font_color", Color(0.94, 0.89, 0.78))
    content.add_child(gold_label)

    var cards := HBoxContainer.new()
    cards.add_theme_constant_override("separation", 14)
    content.add_child(cards)

    for i in range(3):
        var button := Button.new()
        button.custom_minimum_size = Vector2(280.0, 185.0)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.add_theme_font_size_override("font_size", 16)
        button.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
        button.pressed.connect(_select_card.bind(i))
        cards.add_child(button)
        buttons.append(button)

    var hint := Label.new()
    hint.text = "Click a card or press 1 / 2 / 3  |  Escape / 0 skips the shop"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_color_override("font_color", Color(0.72, 0.70, 0.81))
    content.add_child(hint)

    skip_button = Button.new()
    skip_button.name = "SkipButton"
    skip_button.text = "LEAVE MERCHANT  (FREE)"
    skip_button.custom_minimum_size = Vector2(260.0, 39.0)
    skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    skip_button.pressed.connect(_skip_shop)
    content.add_child(skip_button)
