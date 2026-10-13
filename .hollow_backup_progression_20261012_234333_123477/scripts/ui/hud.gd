extends Control

@onready var player = get_node("../../World/Actors/Player")
@onready var run_manager = get_node("../../RunManager")
@onready var stats_label: Label = $Stats
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
    end_label.visible = run_manager.game_over
