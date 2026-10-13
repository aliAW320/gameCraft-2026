extends Node

const XP_PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")
const LOOT_SCENE := preload("res://scenes/pickups/loot.tscn")
const SHOP_TIMES := [120.0, 240.0, 360.0]

var elapsed_seconds: float = 0.0
var score: int = 0
var kills: int = 0
var game_over: bool = false
var scored_seconds: int = 0

var level: int = 1
var experience: int = 0
var pickup_radius: float = 75.0
var level_up_active: bool = false

var gold: int = 0
var shop_active: bool = false
var next_shop_index: int = 0
var current_shop_ids: Array[String] = []

@onready var player: Node = get_node("../World/Actors/Player")
@onready var pickups: Node2D = get_node("../World/Pickups") as Node2D
@onready var upgrade_manager: Node = get_node("../UpgradeManager")
@onready var shop_manager: Node = get_node("../ShopManager")
@onready var level_up_panel: Control = get_node("../UI/LevelUpPanel") as Control
@onready var shop_panel: Control = get_node("../UI/ShopPanel") as Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("run_manager")
    player.connect("died", Callable(self, "_on_player_died"))
    level_up_panel.connect("upgrade_selected", Callable(self, "_on_upgrade_selected"))
    shop_panel.connect("item_requested", Callable(self, "_on_item_requested"))
    shop_panel.connect("shop_skipped", Callable(self, "_on_shop_skipped"))

func _process(delta: float) -> void:
    # Actual gameplay time: it does not progress while leveling or shopping.
    if game_over or get_tree().paused:
        return
    elapsed_seconds += delta
    var whole_seconds: int = int(elapsed_seconds)
    if whole_seconds > scored_seconds:
        score += (whole_seconds - scored_seconds) * 2
        scored_seconds = whole_seconds
    if next_shop_index < SHOP_TIMES.size() \
            and elapsed_seconds >= float(SHOP_TIMES[next_shop_index]) \
            and not level_up_active and not shop_active:
        _open_shop(false)

func experience_needed() -> int:
    return 10 + 5 * (level - 1)

func seconds_to_next_shop() -> int:
    if next_shop_index >= SHOP_TIMES.size():
        return -1
    return maxi(0, ceili(float(SHOP_TIMES[next_shop_index]) - elapsed_seconds))

func on_enemy_defeated(points: int, defeated_enemy: Node2D) -> void:
    if game_over:
        return
    kills += 1
    score += points
    if not is_instance_valid(defeated_enemy):
        return

    # Capture all data now because the enemy is queue_free()'d after its signal.
    var origin: Vector2 = defeated_enemy.global_position
    var xp_amount: int = int(defeated_enemy.get("xp_reward"))
    var elite: bool = bool(defeated_enemy.get("fractured"))
    _spawn_rewards.call_deferred(origin, xp_amount, elite)

func _spawn_rewards(origin: Vector2, xp_amount: int, elite: bool) -> void:
    if game_over:
        return
    _spawn_xp_crystal(origin, xp_amount)

    if elite:
        # One guaranteed cache for every Fractured enemy: +8 gold and +8 XP.
        _spawn_loot(origin + Vector2(14, -8), "cache", 1)
    elif randf() < 0.25:
        _spawn_loot(origin + Vector2(10, -6), "gold", 1)
    if randf() < 0.01:
        _spawn_loot(origin + Vector2(-10, -6), "heart", 20)

func _spawn_xp_crystal(world_position: Vector2, amount: int) -> void:
    if game_over:
        return
    var crystal = XP_PICKUP_SCENE.instantiate()
    crystal.set("xp_amount", amount)
    pickups.add_child(crystal)
    crystal.global_position = world_position
    crystal.connect("collected", Callable(self, "gain_experience"))

func _spawn_loot(world_position: Vector2, kind: String, amount: int) -> void:
    if game_over:
        return
    var loot = LOOT_SCENE.instantiate()
    loot.set("kind", kind)
    loot.set("amount", amount)
    pickups.add_child(loot)
    loot.global_position = world_position
    loot.connect("collected", Callable(self, "on_loot_collected"))

func on_loot_collected(kind: String, amount: int) -> void:
    if game_over:
        return
    match kind:
        "gold":
            gold += amount
        "heart":
            player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + amount))
        "cache":
            gold += 8
            gain_experience(8)

func gain_experience(amount: int) -> void:
    if game_over:
        return
    experience += amount
    _try_level_up()

func _try_level_up() -> void:
    if game_over or level_up_active or shop_active or experience < experience_needed():
        return
    var cost: int = experience_needed()
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
    call_deferred("_try_level_up")

func _open_shop(is_debug: bool) -> void:
    if game_over or get_tree().paused or level_up_active or shop_active:
        return
    var choices: Array[Dictionary] = shop_manager.call("get_offers", 3)
    if choices.is_empty():
        if not is_debug:
            next_shop_index += 1
        return

    current_shop_ids.clear()
    for choice in choices:
        current_shop_ids.append(String(choice["id"]))
    shop_active = true
    var visit_number: int = 0
    if not is_debug:
        next_shop_index += 1
        visit_number = next_shop_index
    shop_panel.call("show_offers", choices, gold, visit_number)
    get_tree().paused = true

func _on_item_requested(item_id: String) -> void:
    if not shop_active or not current_shop_ids.has(item_id) or game_over:
        return
    var price: int = int(shop_manager.call("purchase_item", item_id, gold))
    if price < 0:
        return
    gold -= price
    _close_shop()

func _on_shop_skipped() -> void:
    if shop_active:
        _close_shop()

func _close_shop() -> void:
    shop_panel.hide()
    shop_active = false
    current_shop_ids.clear()
    get_tree().paused = false
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
    elif not game_over and not get_tree().paused and OS.is_debug_build():
        match key_event.keycode:
            KEY_G:
                gain_experience(maxi(1, experience_needed() - experience))
            KEY_H:
                gold += 30
            KEY_B:
                _open_shop(true)
            KEY_N:
                elapsed_seconds += 60.0
                scored_seconds = int(elapsed_seconds)
