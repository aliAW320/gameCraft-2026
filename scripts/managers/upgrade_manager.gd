extends Node

var passive_levels: Dictionary = {
    "focus": 0,
    "quickening": 0,
    "heart": 0,
    "swift": 0,
    "magnet": 0
}

@onready var player: CharacterBody2D = get_node("../World/Actors/Player") as CharacterBody2D
@onready var spells: Node = get_node("../World/Actors/Player/SpellManager")
@onready var run_manager: Node = get_node("../RunManager")

func get_choices(amount: int = 3) -> Array[Dictionary]:
    var pool: Array[Dictionary] = []

    var needle := int(spells.get("needle_level"))
    if needle < 4 and bool(spells.call("can_upgrade_spell", "needle")):
        var needle_text := "Fire two needles at once."
        if needle == 2:
            needle_text = "Increase Soul Needle damage from 14 to 21."
        elif needle == 3:
            needle_text = "Reduce Soul Needle cooldown from 0.70s to 0.55s."
        pool.append(_card("needle", "SOUL NEEDLE Lv.%d" % (needle + 1), needle_text))

    var pulse := int(spells.get("pulse_level"))
    if pulse < 4 and bool(spells.call("can_upgrade_spell", "pulse")):
        var pulse_text := "Unlock an area blast every 3 seconds."
        if pulse == 1:
            pulse_text = "Increase Void Pulse radius to 140px."
        elif pulse == 2:
            pulse_text = "Increase Void Pulse damage to 34."
        elif pulse == 3:
            pulse_text = "Reduce Void Pulse cooldown to 2.2s."
        pool.append(_card("pulse", "VOID PULSE Lv.%d" % (pulse + 1), pulse_text))

    var shade := int(spells.get("shade_level"))
    if shade < 4 and bool(spells.call("can_upgrade_spell", "shade")):
        var shade_text := "Unlock a damaging orb that circles you."
        if shade == 1:
            shade_text = "Create a second orbiting shade."
        elif shade == 2:
            shade_text = "Increase shade damage from 7 to 11."
        elif shade == 3:
            shade_text = "Increase the orbit radius to 100px."
        pool.append(_card("shade", "ORBITING SHADE Lv.%d" % (shade + 1), shade_text))

    var spear: int = int(spells.get("spear_level"))
    if bool(spells.call("can_upgrade_spell", "spear")):
        var spear_info: String = "Unlock a 40-damage piercing spear (3 targets)."
        if spear == 1:
            spear_info = "Abyssal Spear now pierces up to 5 enemies."
        elif spear == 2:
            spear_info = "Spear damage increases from 40 to 62."
        elif spear == 3:
            spear_info = "Reduce Spear cooldown from 3.6s to 2.6s."
        pool.append(_card("spear", "ABYSSAL SPEAR Lv.%d" % (spear + 1), spear_info))

    var bloom: int = int(spells.get("bloom_level"))
    if bool(spells.call("can_upgrade_spell", "bloom")):
        var bloom_info: String = "22% kill chance: explode for 30 damage in 100px."
        if bloom == 1:
            bloom_info = "Death Bloom activation chance increases to 33%."
        elif bloom == 2:
            bloom_info = "Bloom expands to 125px and deals 44 damage."
        elif bloom == 3:
            bloom_info = "44% chance and 150px explosion radius."
        pool.append(_card("bloom", "DEATH BLOOM Lv.%d" % (bloom + 1), bloom_info))

    if int(passive_levels["focus"]) < 3:
        pool.append(_card("focus", "VOID FOCUS", "+10% damage for every spell."))
    if int(passive_levels["quickening"]) < 3:
        pool.append(_card("quickening", "QUICKENING", "Spells cast 8% more frequently."))
    if int(passive_levels["heart"]) < 2:
        pool.append(_card("heart", "IRON HEART", "+15 maximum HP and heal 15 HP."))
    if int(passive_levels["swift"]) < 2:
        pool.append(_card("swift", "SWIFT STEP", "+10% movement speed."))
    if int(passive_levels["magnet"]) < 3:
        pool.append(_card("magnet", "SOUL MAGNET", "+25px XP crystal attraction radius."))

    # Infinite fallbacks only enter the pool when ordinary upgrades are exhausted.
    if pool.size() < amount:
        pool.append(_card("mending", "SOUL MENDING", "Restore up to 25 HP."))
        pool.append(_card("resilience", "RESILIENCE", "+5 maximum HP and heal 5 HP."))
        pool.append(_card("hunger", "SOUL HUNGER", "+5% damage for every spell."))

    pool.shuffle()
    var result: Array[Dictionary] = []
    for i in range(mini(amount, pool.size())):
        result.append(pool[i])
    return result

func apply_upgrade(upgrade_id: String) -> void:
    match upgrade_id:
        "needle", "pulse", "shade", "spear", "bloom":
            if bool(spells.call("can_upgrade_spell", upgrade_id)):
                spells.call("upgrade_spell", upgrade_id)
        "focus":
            spells.call("multiply_damage", 1.10)
        "quickening":
            spells.call("multiply_cooldown", 0.92)
        "heart":
            _increase_health(15)
        "swift":
            player.set("speed", float(player.get("speed")) * 1.10)
        "magnet":
            run_manager.set("pickup_radius", float(run_manager.get("pickup_radius")) + 25.0)
        "mending":
            player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + 25))
        "resilience":
            _increase_health(5)
        "hunger":
            spells.call("multiply_damage", 1.05)
        _:
            push_warning("Unknown upgrade: " + upgrade_id)
            return

    if passive_levels.has(upgrade_id):
        passive_levels[upgrade_id] = int(passive_levels[upgrade_id]) + 1

func _increase_health(amount: int) -> void:
    player.set("max_health", int(player.get("max_health")) + amount)
    player.set("health", mini(int(player.get("max_health")), int(player.get("health")) + amount))

func _card(id: String, title: String, description: String) -> Dictionary:
    return {"id": id, "title": title, "description": description}
