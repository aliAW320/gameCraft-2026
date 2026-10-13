extends Node

signal enemy_killed(position: Vector2, is_elite: bool)

const XP_PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")
const LOOT_SCENE := preload("res://scenes/pickups/loot.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/boss.tscn")
const REALM_POINT_TARGETS := [750, 1300, 1900, 2500]
const RECORD_PATH := "user://hollow_best_score.cfg"

var elapsed_seconds: float = 0.0
var score: int = 0
var kills: int = 0
var game_over: bool = false
var realm_points: int = 0
var realm_elapsed: float = 0.0
var descent_pending: bool = false
var merchant_pending: bool = false

var level: int = 1
var experience: int = 0
var pickup_radius: float = 75.0
var level_up_active: bool = false

var gold: int = 0
var shop_active: bool = false
var next_shop_index: int = 0
var current_shop_ids: Array[String] = []

var boss_active: bool = false
var boss: Node2D = null
var victory: bool = false
var best_score: int = 0
var debug_modified: bool = false

# M5_SURGE_STATE: additive buffs; base spell and shop upgrades are untouched.
const SURGE_THRESHOLD: int = 40
const SURGE_DURATION: float = 6.0
var surge_charge: int = 0
var surge_active: bool = false
var surge_remaining: float = 0.0

@onready var player: Node = get_node("../World/Actors/Player")
@onready var enemies: Node2D = get_node("../World/Actors/Enemies") as Node2D
@onready var pickups: Node2D = get_node("../World/Pickups") as Node2D
@onready var player_projectiles: Node2D = get_node("../World/Projectiles") as Node2D
@onready var spawn_director: Node = get_node("../SpawnDirector")
@onready var upgrade_manager: Node = get_node("../UpgradeManager")
@onready var shop_manager: Node = get_node("../ShopManager")
@onready var level_up_panel: Control = get_node("../UI/LevelUpPanel") as Control
@onready var shop_panel: Control = get_node("../UI/ShopPanel") as Control
@onready var end_screen: Control = get_node("../UI/EndScreen") as Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("run_manager")
    _load_best_score()
    player.connect("died", Callable(self, "_on_player_died"))
    level_up_panel.connect("upgrade_selected", Callable(self, "_on_upgrade_selected"))
    shop_panel.connect("item_requested", Callable(self, "_on_item_requested"))
    shop_panel.connect("shop_skipped", Callable(self, "_on_shop_skipped"))
    end_screen.connect("restart_requested", Callable(self, "_restart_run"))
    end_screen.connect("quit_requested", Callable(self, "_quit_game"))

func _process(delta: float) -> void:
    # Pause must freeze the run clock, boss threshold and merchant visits.
    if game_over or get_tree().paused:
        return
    _m5_tick_surge(delta)
    elapsed_seconds += delta
    if descent_pending:
        _complete_descent()
        return
    if merchant_pending and not level_up_active and not shop_active:
        merchant_pending = false
        _open_shop(false)
        return
    if not boss_active:
        realm_elapsed += delta
    if not boss_active and realm_points >= realm_point_target():
        _start_boss_encounter()
        return

func realm_point_target() -> int:
    var index: int = int(get_node("../RealmManager").get("current_realm"))
    return REALM_POINT_TARGETS[index]

func _complete_descent() -> void:
    descent_pending = false
    var realms: Node = get_node("../RealmManager")
    var index: int = int(realms.get("current_realm"))
    if index == 3:
        _finish_run(true)
        return
    realm_points = 0
    realm_elapsed = 0.0
    realms.call("apply_realm", index + 1)
    merchant_pending = true

func debug_next_realm() -> void:
    if game_over or get_tree().paused or not OS.is_debug_build():
        return
    debug_modified = true
    if is_instance_valid(boss):
        boss.queue_free()
    boss = null
    boss_active = false
    descent_pending = false
    merchant_pending = false
    realm_points = 0
    realm_elapsed = 0.0
    var realms: Node = get_node("../RealmManager")
    realms.call("apply_realm", (int(realms.get("current_realm")) + 1) % 4)

func experience_needed() -> int:
    return 10 + 5 * (level - 1)

func on_enemy_defeated(points: int, defeated_enemy: Node2D) -> void:
    if game_over or boss_active:
        return
    kills += 1
    score += points
    realm_points += points
    if not is_instance_valid(defeated_enemy):
        return
    var origin: Vector2 = defeated_enemy.global_position
    var xp_amount: int = int(defeated_enemy.get("xp_reward"))
    var elite: bool = bool(defeated_enemy.get("fractured"))
    _m5_gain_charge(elite)
    enemy_killed.emit(origin, elite)
    # Trigger Bloom after rewards logic has observed the kill. Prevent Bloom->Bloom loops.
    var spell_manager: Node = player.get_node_or_null("SpellManager")
    if spell_manager != null and not bool(defeated_enemy.get("killed_by_bloom")):
        spell_manager.call("on_enemy_killed", origin)
    _spawn_rewards.call_deferred(origin, xp_amount, elite)

func _spawn_rewards(origin: Vector2, xp_amount: int, elite: bool) -> void:
    if game_over:
        return
    _spawn_xp_crystal(origin, xp_amount)
    if elite:
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
    if game_over or boss_active or get_tree().paused or level_up_active or shop_active:
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

func _start_boss_encounter() -> void:
    if game_over or boss_active or level_up_active or shop_active:
        return
    boss_active = true
    var realm_index: int = int(get_node("../RealmManager").get("current_realm"))
    spawn_director.set("phase_name", preload("res://scripts/realms/realm_catalog.gd").guardian_name(realm_index))

    # Stop the swarm and its projectiles; the boss becomes the sole target.
    for enemy in enemies.get_children():
        enemy.queue_free()
    for projectile in player_projectiles.get_children():
        projectile.queue_free()

    var guardian = BOSS_SCENE.instantiate()
    guardian.set("realm_index", realm_index)
    guardian.call("configure_realm", realm_index)
    enemies.add_child(guardian)
    boss = guardian as Node2D
    boss.global_position = _boss_spawn_position()
    guardian.connect("defeated", Callable(self, "_on_boss_defeated"))
    _m5_boss_entrance()

func _boss_spawn_position() -> Vector2:
    var candidate_directions: Array[Vector2] = [
        Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP
    ]
    candidate_directions.shuffle()
    for direction in candidate_directions:
        var candidate: Vector2 = player.global_position + direction * 325.0
        if candidate.x >= 90.0 and candidate.x <= 3110.0 \
                and candidate.y >= 90.0 and candidate.y <= 3110.0:
            return candidate
    return Vector2(
        clampf(player.global_position.x + 260.0, 90.0, 3110.0),
        clampf(player.global_position.y, 90.0, 3110.0)
    )

func _on_boss_defeated() -> void:
    if game_over or not boss_active:
        return
    kills += 1
    score += 1500 if int(get_node("../RealmManager").get("current_realm")) == 3 else 500
    boss_active = false
    boss = null
    player.set("invulnerable_for", maxf(1.8, float(player.get("invulnerable_for"))))
    # Lightning may still be finishing its paused return cinematic.
    descent_pending = true

func _on_player_died() -> void:
    _finish_run(false)

func _finish_run(did_win: bool) -> void:
    if game_over:
        return
    game_over = true
    victory = did_win
    var new_record: bool = false
    if not debug_modified and score > best_score:
        best_score = score
        new_record = true
        _save_best_score()
    end_screen.call("show_result", did_win, score, best_score, kills,
        level, int(elapsed_seconds), gold, debug_modified, new_record)
    get_tree().paused = true

func _load_best_score() -> void:
    var config := ConfigFile.new()
    if config.load(RECORD_PATH) == OK:
        best_score = maxi(0, int(config.get_value("records", "high_score", 0)))

func _save_best_score() -> void:
    var config := ConfigFile.new()
    config.set_value("records", "high_score", best_score)
    var err: Error = config.save(RECORD_PATH)
    if err != OK:
        push_warning("Could not save HOLLOW record (error %d)" % err)

func _restart_run() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()

func _quit_game() -> void:
    get_tree().paused = false
    get_tree().quit()

# M5 gameplay and feedback hooks.
func _m5_gain_charge(is_elite: bool) -> void:
    if surge_active or game_over:
        return
    surge_charge = mini(SURGE_THRESHOLD, surge_charge + (5 if is_elite else 1))
    if surge_charge >= SURGE_THRESHOLD:
        _m5_start_surge()

func _m5_start_surge() -> void:
    if game_over or surge_active:
        return
    surge_charge = 0
    surge_active = true
    surge_remaining = SURGE_DURATION
    player.queue_redraw()
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("surge_burst", player.global_position)
    var camera := player.get_node_or_null("Camera2D")
    if camera != null and camera.has_method("kick"):
        camera.call("kick", 7.0)
    var sounds := get_node_or_null("../SFXManager")
    if sounds != null:
        sounds.call("play_event", "surge")

func _m5_tick_surge(delta: float) -> void:
    if not surge_active:
        return
    surge_remaining = maxf(0.0, surge_remaining - delta)
    if surge_remaining <= 0.0:
        surge_active = false
        player.queue_redraw()

func _m5_boss_entrance() -> void:
    var effects := get_tree().get_first_node_in_group("combat_fx")
    if effects != null:
        effects.call("boss_entrance", boss.global_position)
    var camera := player.get_node_or_null("Camera2D")
    if camera != null and camera.has_method("kick"):
        camera.call("kick", 9.0)
    var sounds := get_node_or_null("../SFXManager")
    if sounds != null:
        sounds.call("play_event", "boss")

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if game_over:
        if key_event.keycode == KEY_R:
            get_viewport().set_input_as_handled()
            _restart_run()
        return
    if get_tree().paused or not OS.is_debug_build():
        return
    match key_event.keycode:
        KEY_R:
            get_viewport().set_input_as_handled()
            debug_next_realm()
        KEY_G:
            debug_modified = true
            gain_experience(maxi(1, experience_needed() - experience))
        KEY_H:
            debug_modified = true
            gold += 30
        KEY_B:
            debug_modified = true
            _open_shop(true)
        KEY_N:
            debug_modified = true
            elapsed_seconds += 60.0
        KEY_K:
            debug_modified = true
            _start_boss_encounter()
        KEY_J:
            if boss_active and is_instance_valid(boss):
                debug_modified = true
                boss.call("take_damage", 400)
        KEY_V:
            debug_modified = true
            _m5_start_surge()
        KEY_M:
            debug_modified = true
            player.set("health", 0)
            _finish_run(false)
