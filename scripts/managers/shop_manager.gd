extends Node

# HOLLOW_M6_RELIC_SHOP: Shop effects trigger during gameplay instead of
# repeating level-up upgrades to damage, cooldown, HP cap or movement speed.
const ITEMS = [
    {"id": "thorn_idol", "title": "THORN IDOL", "description": "When hit, strike nearby enemies with a thorn nova (2s cooldown).", "price": 17, "max_copies": 2},
    {"id": "blood_chalice", "title": "BLOOD CHALICE", "description": "Heal 10 HP per copy after every 12 enemy kills.", "price": 14, "max_copies": 2},
    {"id": "gilded_fang", "title": "GILDED FANG", "description": "Every 10 kills, gain 2 bonus gold per copy.", "price": 12, "max_copies": 2},
    {"id": "soul_battery", "title": "SOUL BATTERY", "description": "Every 10 kills, add 4 extra Void Lightning charge per copy.", "price": 18, "max_copies": 2},
    {"id": "magnet_bell", "title": "MAGNET BELL", "description": "Every 15 kills, pull loose pickups from a huge area to you.", "price": 15, "max_copies": 2},
    {"id": "second_breath", "title": "SECOND BREATH", "description": "Once per run, prevent lethal damage and restore 40 HP.", "price": 24, "max_copies": 1},
]

var purchases: Dictionary = {}
@onready var relics: Node = get_node("../World/ShopRelics")

func get_offers(count: int = 3) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []
    for item in ITEMS:
        var item_id: String = String(item["id"])
        if int(purchases.get(item_id, 0)) < int(item["max_copies"]):
            pool.append(item.duplicate(true))
    pool.shuffle()
    var selected: Array[Dictionary] = []
    for i in range(mini(count, pool.size())):
        selected.append(pool[i])
    return selected

func purchase_item(item_id: String, gold_available: int) -> int:
    var item: Dictionary = {}
    for entry in ITEMS:
        if String(entry["id"]) == item_id:
            item = entry
            break
    if item.is_empty():
        return -1
    if int(purchases.get(item_id, 0)) >= int(item["max_copies"]):
        return -1
    var price: int = int(item["price"])
    if gold_available < price:
        return -1
    if not bool(relics.call("add_relic", item_id)):
        return -1
    purchases[item_id] = int(purchases.get(item_id, 0)) + 1
    return price
