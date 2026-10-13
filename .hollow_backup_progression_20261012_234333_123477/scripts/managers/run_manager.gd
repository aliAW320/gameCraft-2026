extends Node

var elapsed_seconds: float = 0.0
var score: int = 0
var kills: int = 0
var game_over: bool = false
var scored_seconds: int = 0

@onready var player = get_node("../World/Actors/Player")

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    player.died.connect(_on_player_died)

func _process(delta: float) -> void:
    if game_over:
        return
    elapsed_seconds += delta
    var whole_seconds := int(elapsed_seconds)
    if whole_seconds > scored_seconds:
        score += (whole_seconds - scored_seconds) * 2
        scored_seconds = whole_seconds

func on_enemy_defeated(points: int) -> void:
    if game_over:
        return
    kills += 1
    score += points

func _on_player_died() -> void:
    game_over = true
    get_tree().paused = true

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and game_over and event.pressed and not event.echo and event.keycode == KEY_R:
        get_tree().paused = false
        get_tree().reload_current_scene()
