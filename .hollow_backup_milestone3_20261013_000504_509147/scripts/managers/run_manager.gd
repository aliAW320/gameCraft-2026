extends Node

const XP_PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")

var elapsed_seconds: float = 0.0
var score: int = 0
var kills: int = 0
var game_over: bool = false
var scored_seconds: int = 0

var level: int = 1
var experience: int = 0
var pickup_radius: float = 75.0
var level_up_active: bool = false

@onready var player: Node = get_node("../World/Actors/Player")
@onready var pickups: Node2D = get_node("../World/Pickups") as Node2D
@onready var upgrade_manager: Node = get_node("../UpgradeManager")
@onready var level_up_panel: Control = get_node("../UI/LevelUpPanel") as Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("run_manager")
    player.connect("died", Callable(self, "_on_player_died"))
    level_up_panel.connect("upgrade_selected", Callable(self, "_on_upgrade_selected"))

func _process(delta: float) -> void:
    # The game timer and score must not increase while selecting an upgrade.
    if game_over or get_tree().paused:
        return
    elapsed_seconds += delta
    var whole_seconds := int(elapsed_seconds)
    if whole_seconds > scored_seconds:
        score += (whole_seconds - scored_seconds) * 2
        scored_seconds = whole_seconds

func experience_needed() -> int:
    return 10 + 5 * (level - 1)

func on_enemy_defeated(points: int, defeated_enemy: Node2D) -> void:
    if game_over:
        return
    kills += 1
    score += points
    if not is_instance_valid(defeated_enemy):
        return

    # Defer adding physics objects: a defeat can occur during a collision callback.
    _spawn_xp_crystal.call_deferred(defeated_enemy.global_position)

func _spawn_xp_crystal(world_position: Vector2) -> void:
    if game_over:
        return
    var crystal = XP_PICKUP_SCENE.instantiate()
    crystal.set("xp_amount", 1)
    pickups.add_child(crystal)
    crystal.global_position = world_position
    crystal.connect("collected", Callable(self, "gain_experience"))

func gain_experience(amount: int) -> void:
    if game_over:
        return
    experience += amount
    _try_level_up()

func _try_level_up() -> void:
    if game_over or level_up_active or experience < experience_needed():
        return

    var cost := experience_needed()
    experience -= cost
    level += 1
    level_up_active = true
    var choices: Array[Dictionary] = upgrade_manager.call("get_choices", 3)
    level_up_panel.call("show_choices", choices, level)
    get_tree().paused = true

func _on_upgrade_selected(upgrade_id: String) -> void:
    if not level_up_active or game_over:
        return
    upgrade_manager.call("apply_upgrade", upgrade_id)
    level_up_panel.hide()
    level_up_active = false
    get_tree().paused = false
    # If one large pickup earned several levels, offer them one at a time.
    call_deferred("_try_level_up")

func _on_player_died() -> void:
    game_over = true
    get_tree().paused = true

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if game_over and key_event.keycode == KEY_R:
        get_tree().paused = false
        get_tree().reload_current_scene()
    elif not game_over and not get_tree().paused and OS.is_debug_build() and key_event.keycode == KEY_G:
        # Quick manual test: G grants precisely enough XP to trigger a level-up.
        gain_experience(maxi(1, experience_needed() - experience))
