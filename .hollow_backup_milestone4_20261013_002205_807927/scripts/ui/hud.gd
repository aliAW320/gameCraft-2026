extends Control

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

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    end_label.visible = false

func _process(_delta: float) -> void:
    var total_seconds: int = int(run_manager.get("elapsed_seconds"))
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
    spells_label.text = "Soul Needle %d   |   Void Pulse %d   |   Orbiting Shade %d" % [
        int(spells.get("needle_level")), int(spells.get("pulse_level")),
        int(spells.get("shade_level"))
    ]
    var remaining: int = int(run_manager.call("seconds_to_next_shop"))
    var shop_text: String = "No more merchant visits"
    if remaining >= 0:
        shop_text = "Merchant in %02d:%02d" % [int(remaining / 60.0), remaining % 60]
    wave_label.text = "WAVE: %s     |     %s" % [String(spawn_director.get("phase_name")), shop_text]
    end_label.visible = bool(run_manager.get("game_over"))
