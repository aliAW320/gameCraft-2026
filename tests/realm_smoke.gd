extends SceneTree
const Catalog := preload("res://scripts/realms/realm_catalog.gd")
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error("FAIL: " + message)

func _run() -> void:
    if not OS.get_cmdline_user_args().has("--allow-pending-art"):
        var sheet_exists: bool = ResourceLoader.exists("res://assets/realms/players/descent_atlas.png")
        for realm in Catalog.REALMS:
            check(sheet_exists or ResourceLoader.exists("res://assets/realms/players/%s.png" % realm["id"]), "generated player: " + realm["id"])
    var game: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    var run: Node = game.get_node("RunManager")
    var realms: Node = game.get_node("RealmManager")
    var player: Node2D = game.get_node("World/Actors/Player")
    var dread: Node = game.get_node("World/RealmDread")
    run.set("debug_modified", true)
    run.set_process(false)
    dread.set_process(false)
    game.get_node("SFXManager").set("sounds", {})
    game.get_node("SpawnDirector").set_physics_process(false)
    player.set_physics_process(false)
    player.get_node("SpellManager").set_physics_process(false)
    player.set("max_health", 115)
    player.set("health", 73)
    player.position = Vector2(900, 1100)
    run.set("gold", 40)
    player.get_node("SpellManager").call("upgrade_spell", "spear")
    game.get_node("World/ShopRelics").call("add_relic", "second_breath")
    game.get_node("World/VoidLightning").set("charge", 20)
    run.call("_spawn_xp_crystal", Vector2(2800, 2800), 4)
    var drop: Node = game.get_node("World/Pickups").get_child(0)
    run.call("_process", 600.0)
    check(realms.get("current_realm") == 0 and not run.get("boss_active"), "waiting does not summon a guardian or cause descent")
    check(run.get("realm_points") == 0, "passive score cannot fill realm objective")
    for index in range(4):
        check(realms.get("current_realm") == index, "guardian victory is the realm gate")
        check(player.get("max_health") == 115 - index * 15, "vessel shrinks while health upgrades survive")
        check(player.get("health") == mini(73, 115 - index * 15), "descent clamps health without inflicting damage")
        check(player.position == Vector2(900, 1100), "position survives descent")
        check(run.get("gold") == 40, "gold survives descent")
        check(player.get_node("SpellManager").get("spear_level") == 1, "spells survive descent")
        check(game.get_node("World/ShopRelics").get("rescue_available"), "relic survives descent")
        check(is_instance_valid(drop), "uncollected XP survives descent")
        check(player.get_node("HollowArt").get("realm_index") == index, "player form follows realm")
        run.set("realm_points", int(run.call("realm_point_target")) - 10)
        run.call("_process", 0.0)
        check(not run.get("boss_active"), "below threshold leaves ordinary combat active")
        var enemy: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate()
        enemy.call("configure", "husk", false, index * 90.0)
        game.get_node("World/Actors/Enemies").add_child(enemy)
        enemy.position = Vector2(2800, 300)
        enemy.set_physics_process(false)
        check(enemy.get_node("HollowArt").get("realm_index") == index, "enemies match their realm")
        run.call("on_enemy_defeated", 10, enemy)
        run.call("_process", 0.0)
        check(run.get("boss_active"), "earned kill points summon guardian at threshold")
        check(realms.get("current_realm") == index, "summoning does not cause descent")
        var guardian: Node = run.get("boss")
        check(guardian.get("realm_index") == index, "guardian belongs to current realm")
        check(guardian.get("max_health") == [360, 540, 760, 1100][index], "guardian difficulty scales")
        paused = true
        guardian.call("take_damage", guardian.get("health"))
        run.call("_process", 1.0)
        check(realms.get("current_realm") == index and not run.get("game_over"), "paused lightning return defers descent and victory")
        paused = false
        run.call("_process", 0.0)
        if index < 3:
            check(realms.get("current_realm") == index + 1, "defeat unlocks next realm")
            check(run.get("realm_points") == 0, "new realm requires fresh earned points")
            run.call("_process", 0.0)
            check(paused and run.get("shop_active"), "merchant waits beyond each guardian")
            var old_time: float = run.get("elapsed_seconds")
            run.call("_process", 30.0)
            check(run.get("elapsed_seconds") == old_time, "shop freezes the run")
            run.call("_on_shop_skipped")
            check(not paused, "merchant exit resumes play")
        else:
            check(run.get("victory") and run.get("game_over") and paused, "fourth guardian releases the soul")
        await process_frame
    paused = false
    game.queue_free()
    await process_frame
    # Check the development shortcut on a fresh live run.
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    run = game.get_node("RunManager")
    run.set_process(false)
    game.get_node("SFXManager").set("sounds", {})
    game.get_node("SpawnDirector").set_physics_process(false)
    realms = game.get_node("RealmManager")
    for expected in [1, 2, 3, 0]:
        var key := InputEventKey.new()
        key.keycode = KEY_R
        key.pressed = true
        run.call("_unhandled_key_input", key)
        check(realms.get("current_realm") == expected, "R cycles live realms")
        check(run.get("debug_modified"), "R prevents debug high-score saves")
    dread = game.get_node("World/RealmDread")
    player = game.get_node("World/Actors/Player")
    realms.call("apply_realm", 3, false)
    dread.set("cohesion", 50.0)
    player.set("velocity", Vector2.ZERO)
    dread.call("_process", 1.0)
    check(is_equal_approx(float(dread.get("cohesion")), 47.0), "stillness erodes soul cohesion")
    player.set("velocity", Vector2(180, 0))
    dread.call("_process", 1.0)
    check(is_equal_approx(float(dread.get("cohesion")), 46.2), "movement slows erasure")
    dread.call("_on_kill", Vector2.ZERO, false)
    check(is_equal_approx(float(dread.get("cohesion")), 55.2), "kills restore cohesion")
    realms.call("apply_realm", 1, false)
    player.set("invulnerable_for", 0.0)
    dread.set("hazard_clock", 8.0)
    var old_health: int = player.get("health")
    dread.call("_process", 0.5)
    check(player.get("health") == old_health, "terrain warns before it hurts")
    dread.call("_process", 0.65)
    check(player.get("health") == old_health - 7, "remaining in an eruption causes damage")
    game.queue_free()
    await process_frame
    Catalog.texture_cache.clear()
    print("REALM SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
    quit(0 if failures == 0 else 1)
