extends Node2D

# HOLLOW M6: Shop relics are event-based, NOT permanent stat upgrades.
# Purchases last for the current run. Only Second Breath has one-use charges.
var stacks: Dictionary = {}
var kills_seen: int = 0
var thorn_cooldown: float = 0.0
var thorn_visual_time: float = 0.0
var rescue_available: bool = false

@onready var player: Node2D = get_node("../Actors/Player") as Node2D
@onready var run_manager: Node = get_node("../../RunManager")
@onready var pickups: Node2D = get_node("../Pickups") as Node2D
@onready var lightning: Node = get_node_or_null("../VoidLightning")

func _ready() -> void:
    z_index = 20
    run_manager.connect("enemy_killed", Callable(self, "_on_enemy_killed"))
    player.connect("damaged", Callable(self, "_on_player_damaged"))

func add_relic(item_id: String) -> bool:
    if not ["thorn_idol", "blood_chalice", "gilded_fang", "soul_battery", "magnet_bell", "second_breath"].has(item_id):
        return false
    var cap: int = 1 if item_id == "second_breath" else 2
    if int(stacks.get(item_id, 0)) >= cap:
        return false
    stacks[item_id] = int(stacks.get(item_id, 0)) + 1
    if item_id == "second_breath":
        rescue_available = true
    return true

func _process(delta: float) -> void:
    if get_tree().paused or bool(run_manager.get("game_over")):
        return
    thorn_cooldown = maxf(0.0, thorn_cooldown - delta)
    thorn_visual_time = maxf(0.0, thorn_visual_time - delta)
    if thorn_visual_time > 0.0:
        global_position = player.global_position
        queue_redraw()

func _on_enemy_killed(_at_position: Vector2, _is_elite: bool) -> void:
    if bool(run_manager.get("game_over")):
        return
    kills_seen += 1
    var chalice: int = int(stacks.get("blood_chalice", 0))
    if chalice > 0 and kills_seen % 12 == 0:
        player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + 10 * chalice))
    var fang: int = int(stacks.get("gilded_fang", 0))
    if fang > 0 and kills_seen % 10 == 0:
        run_manager.set("gold", int(run_manager.get("gold")) + 2 * fang)
    var battery: int = int(stacks.get("soul_battery", 0))
    if battery > 0 and kills_seen % 10 == 0 and is_instance_valid(lightning):
        var max_charge: int = 25
        lightning.set("charge", mini(max_charge, int(lightning.get("charge")) + 4 * battery))
    var magnet: int = int(stacks.get("magnet_bell", 0))
    if magnet > 0 and kills_seen % 15 == 0:
        var radius: float = 500.0 + 150.0 * float(magnet - 1)
        for drop in pickups.get_children():
            if drop is Node2D and not drop.is_queued_for_deletion():
                if (drop as Node2D).global_position.distance_squared_to(player.global_position) <= radius * radius:
                    (drop as Node2D).global_position = player.global_position

func _on_player_damaged(_amount: int) -> void:
    if int(player.get("health")) <= 0 and rescue_available:
        rescue_available = false
        player.set("health", mini(int(player.get("max_health")), 40))
        player.set("invulnerable_for", 2.0)
        thorn_visual_time = 0.33
        global_position = player.global_position
        queue_redraw()

    var thorn: int = int(stacks.get("thorn_idol", 0))
    if thorn <= 0 or thorn_cooldown > 0.0:
        return
    thorn_cooldown = 2.0
    thorn_visual_time = 0.32
    global_position = player.global_position
    queue_redraw()
    var radius: float = 130.0
    for obj in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(obj) or not (obj is Node2D):
            continue
        var enemy: Node2D = obj as Node2D
        if not enemy.is_queued_for_deletion() and enemy.has_method("take_damage"):
            if enemy.global_position.distance_squared_to(player.global_position) <= radius * radius:
                enemy.call("take_damage", 28 * thorn)

func _draw() -> void:
    if thorn_visual_time <= 0.0:
        return
    var strength: float = thorn_visual_time / 0.32
    draw_circle(Vector2.ZERO, 130.0, Color(0.58, 0.16, 0.75, 0.13 * strength))
    draw_arc(Vector2.ZERO, 130.0, 0.0, TAU, 64, Color(0.97, 0.56, 1.0, strength), 5.0)
