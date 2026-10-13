extends Control

@onready var player = get_node("../../World/Actors/Player")
@onready var run_manager = get_node("../../RunManager")
@onready var spells = get_node("../../World/Actors/Player/SpellManager")
@onready var stats_label: Label = $Stats
@onready var xp_label: Label = $XPInfo
@onready var xp_bar: ProgressBar = $XPBar
@onready var spells_label: Label = $Spells
@onready var end_label: Label = $EndMessage

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    end_label.visible = false

func _process(_delta: float) -> void:
    var total_seconds := int(run_manager.elapsed_seconds)
    stats_label.text = "HP %d/%d    Kills %d    Score %d    %02d:%02d" % [
        player.health, player.max_health, run_manager.kills, run_manager.score,
        int(total_seconds / 60.0), total_seconds % 60
    ]
    var needed: int = run_manager.experience_needed()
    xp_label.text = "LEVEL %d    XP %d / %d" % [
        run_manager.level, run_manager.experience, needed
    ]
    xp_bar.max_value = needed
    xp_bar.value = run_manager.experience
    spells_label.text = "Soul Needle %d   |   Void Pulse %d   |   Orbiting Shade %d" % [
        spells.needle_level, spells.pulse_level, spells.shade_level
    ]
    end_label.visible = run_manager.game_over
