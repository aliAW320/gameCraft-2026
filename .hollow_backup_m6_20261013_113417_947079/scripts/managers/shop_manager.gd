extends Node

const ITEMS = [
    {"id": "vessel",  "title": "CRACKED VESSEL",  "description": "+20 maximum HP and heal 20 HP",        "price": 12},
    {"id": "eye",     "title": "GRASPING EYE",    "description": "+50px pickup and magnet radius",     "price": 12},
    {"id": "boots",   "title": "FLEET BOOTS",     "description": "+12% movement speed",                 "price": 15},
    {"id": "charm",   "title": "SHATTERED CHARM", "description": "+20% damage for all spells",         "price": 18},
    {"id": "clock",   "title": "CLOCKBONE",       "description": "Spells cast 15% more frequently",   "price": 20},
    {"id": "shell",   "title": "VOID SHELL",      "description": "Take 15% less incoming damage",     "price": 22},
]

const MAX_COPIES_PER_ITEM: int = 2

var purchases: Dictionary = {}

@onready var player: Node = get_node("../World/Actors/Player")
@onready var spells: Node = get_node("../World/Actors/Player/SpellManager")
@onready var run_manager: Node = get_node("../RunManager")

func get_offers(count: int = 3) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []
    for item in ITEMS:
        var item_id: String = String(item["id"])
        if int(purchases.get(item_id, 0)) < MAX_COPIES_PER_ITEM:
            pool.append(item.duplicate(true))
    pool.shuffle()
    var selected: Array[Dictionary] = []
    for i in range(mini(count, pool.size())):
        selected.append(pool[i])
    return selected

func purchase_item(item_id: String, gold_available: int) -> int:
    # Return amount spent, or -1 if rejected. Caller checks selected offers.
    if int(purchases.get(item_id, 0)) >= MAX_COPIES_PER_ITEM:
        return -1
    var item: Dictionary = {}
    for option in ITEMS:
        if String(option["id"]) == item_id:
            item = option
            break
    if item.is_empty():
        return -1
    var price: int = int(item["price"])
    if gold_available < price:
        return -1

    match item_id:
        "vessel":
            player.set("max_health", int(player.get("max_health")) + 20)
            player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + 20))
        "eye":
            run_manager.set("pickup_radius", float(run_manager.get("pickup_radius")) + 50.0)
        "boots":
            player.set("speed", float(player.get("speed")) * 1.12)
        "charm":
            spells.call("multiply_damage", 1.20)
        "clock":
            spells.call("multiply_cooldown", 0.85)
        "shell":
            player.set("damage_taken_multiplier", float(player.get("damage_taken_multiplier")) * 0.85)
        _:
            return -1

    purchases[item_id] = int(purchases.get(item_id, 0)) + 1
    return price
