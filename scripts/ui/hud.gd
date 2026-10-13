extends Control

const Catalog := preload("res://scripts/realms/realm_catalog.gd")
var realm_label: Label
var descent_bar: ProgressBar
var objective: Label

@onready var player: Node = get_node("../../World/Actors/Player")
@onready var run_manager: Node = get_node("../../RunManager")
@onready var spawn_director: Node = get_node("../../SpawnDirector")
@onready var spells: Node = get_node("../../World/Actors/Player/SpellManager")
@onready var stats_label: Label = $Stats
@onready var xp_label: Label = $XPInfo
@onready var xp_bar: ProgressBar = $XPBar
@onready var spells_label: Label = $Spells
@onready var wave_label: Label = $WaveInfo
@onready var end_label: Label = $EndMessage
@onready var surge_bar: ProgressBar = $SurgeBar
@onready var surge_info: Label = $SurgeInfo
@onready var surge_announce: Label = $SurgeAnnounce
var m5_was_surge_active: bool = false
var m5_announce_remaining: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    end_label.visible = false
    surge_announce.visible = false
    var surge_fill := StyleBoxFlat.new()
    surge_fill.bg_color = Color(0.60, 0.34, 0.94, 1.0)
    surge_bar.add_theme_stylebox_override("fill", surge_fill)
    realm_label = Label.new()
    realm_label.position = Vector2(22, 211)
    realm_label.add_theme_font_size_override("font_size", 17)
    realm_label.add_theme_constant_override("outline_size", 4)
    add_child(realm_label)
    $Help.text = "WASD / arrows: move   |   Q: Void Lightning" + ("   |   R: next realm (DEV)" if OS.is_debug_build() else "")
    descent_bar = ProgressBar.new()
    descent_bar.position = Vector2(22, 245)
    descent_bar.size = Vector2(278, 14)
    descent_bar.show_percentage = false
    add_child(descent_bar)
    objective = Label.new()
    objective.position = Vector2(315, 239)
    objective.add_theme_font_size_override("font_size", 17)
    objective.add_theme_constant_override("outline_size", 4)
    add_child(objective)

func _process(_delta: float) -> void:
    var total_seconds: int = int(run_manager.get("elapsed_seconds"))
    var realm_index: int = int(get_node("../../RealmManager").get("current_realm"))
    var realm: Dictionary = Catalog.REALMS[realm_index]
    realm_label.text = "REALM %d/4  %s  |  %s  |  %s" % [realm_index + 1, realm["name"], realm["map"], realm["form"]]
    realm_label.modulate = realm["color"]
    descent_bar.max_value = run_manager.call("realm_point_target")
    descent_bar.value = run_manager.get("realm_points")
    objective.text = "EARNED POINTS %d / %d  ·  Awaken the guardian" % [run_manager.get("realm_points"), run_manager.call("realm_point_target")]
    if bool(run_manager.get("boss_active")):
        objective.text = "DEFEAT THE GUARDIAN  ·  " + ("Release your soul" if realm_index == 3 else "The next layer must be shed")
    objective.modulate = realm["color"]
    if realm_index == 3:
        var cohesion: float = float(get_node("../../World/RealmDread").get("cohesion"))
        objective.text += "  ·  SOUL %d%%" % roundi(cohesion)
        if cohesion < 25.0:
            objective.modulate = Color(1.0, 0.42, 0.45, 0.8 + sin(float(Time.get_ticks_msec()) * 0.008) * 0.2)
    stats_label.text = "HP %d/%d    GOLD %d    KILLS %d    SCORE %d    %02d:%02d" % [
        int(player.get("health")), int(player.get("max_health")),
        int(run_manager.get("gold")), int(run_manager.get("kills")),
        int(run_manager.get("score")), int(total_seconds / 60.0), total_seconds % 60
    ]
    var needed: int = int(run_manager.call("experience_needed"))
    xp_label.text = "LEVEL %d    XP %d / %d" % [
        int(run_manager.get("level")), int(run_manager.get("experience")), needed
    ]
    xp_bar.max_value = needed
    xp_bar.value = int(run_manager.get("experience"))
    spells_label.text = "SPELLS %d/4   Needle %d | Pulse %d | Shade %d | Spear %d | Bloom %d" % [
        int(spells.call("equipped_spell_count")),
        int(spells.get("needle_level")), int(spells.get("pulse_level")),
        int(spells.get("shade_level")), int(spells.get("spear_level")),
        int(spells.get("bloom_level"))
    ]
    var shop_text: String = "Merchant beyond the guardian" if realm_index < 3 else "Nothing left to trade"
    wave_label.text = "WAVE: %s     |     %s" % [String(spawn_director.get("phase_name")), shop_text]
    end_label.visible = false  # Milestone 4 uses EndScreen.
    # M5 HUD state updates even while shop/upgrade windows pause the scene.
    var active: bool = bool(run_manager.get("surge_active"))
    if active:
        surge_bar.max_value = 6.0
        surge_bar.value = float(run_manager.get("surge_remaining"))
        surge_info.text = "VOID SURGE!  %.1fs   |   +55%% damage   |   30%% faster casts" % [float(run_manager.get("surge_remaining"))]
    else:
        surge_bar.max_value = 40.0
        surge_bar.value = float(run_manager.get("surge_charge"))
        surge_info.text = "HOLLOW CORE   %d/%d   |   Elites give +5" % [
            int(run_manager.get("surge_charge")), 40]
    if active and not m5_was_surge_active:
        m5_announce_remaining = 1.45
    m5_was_surge_active = active
    if not get_tree().paused:
        m5_announce_remaining = maxf(0.0, m5_announce_remaining - _delta)
    surge_announce.visible = m5_announce_remaining > 0.0 and not bool(run_manager.get("game_over"))
    surge_announce.modulate = Color(1.0, 1.0, 1.0, minf(1.0, m5_announce_remaining / 0.35))
