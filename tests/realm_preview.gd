extends SceneTree

const Catalog := preload("res://scripts/realms/realm_catalog.gd")

func _initialize() -> void:
    call_deferred("_render_previews")

func _render_previews() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1280, 720)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var game: Node = load("res://scenes/main.tscn").instantiate()
    viewport.add_child(game)
    await process_frame
    var run: Node = game.get_node("RunManager")
    var player: Node2D = game.get_node("World/Actors/Player")
    var realms: Node = game.get_node("RealmManager")
    run.set("debug_modified", true)
    run.set_process(false)
    game.get_node("SpawnDirector").set_physics_process(false)
    player.set_physics_process(false)
    player.get_node("SpellManager").set_physics_process(false)
    game.get_node("World/RealmDread").set_process(false)
    var camera: Camera2D = player.get_node("Camera2D")
    camera.position_smoothing_enabled = false
    camera.position = Vector2.ZERO
    player.position = Vector2(1600, 1600)
    DirAccess.make_dir_recursive_absolute("res://assets/realms/previews")
    for index in range(4):
        viewport.size = Vector2i(1280, 720)
        run.set("elapsed_seconds", Catalog.REALMS[index]["difficulty_time"])
        realms.call("apply_realm", index, false)
        for enemy in game.get_node("World/Actors/Enemies").get_children():
            enemy.queue_free()
        for kind in ["husk", "skitter", "brute"]:
            var enemy: Node2D = load("res://scenes/enemies/enemy.tscn").instantiate()
            enemy.call("configure", kind, false, Catalog.REALMS[index]["difficulty_time"])
            game.get_node("World/Actors/Enemies").add_child(enemy)
            enemy.set_physics_process(false)
            enemy.position = Vector2(1410 + ["husk", "skitter", "brute"].find(kind) * 190, 1740)
        camera.zoom = Vector2.ONE * 1.65
        camera.position = Vector2(0, -85)
        await process_frame
        await RenderingServer.frame_post_draw
        viewport.get_texture().get_image().save_png("res://assets/realms/previews/%s_gameplay.png" % Catalog.REALMS[index]["id"])
        game.get_node("UI").hide()
        game.get_node("World/VoidLightning/VoidLightningHUD").hide()
        game.get_node("World/RealmDread").get("screen_layer").hide()
        viewport.size = Vector2i(1024, 1024)
        camera.zoom = Vector2.ONE * 0.30
        camera.position = Vector2.ZERO
        await process_frame
        await RenderingServer.frame_post_draw
        viewport.get_texture().get_image().save_png("res://assets/realms/previews/%s_map.png" % Catalog.REALMS[index]["id"])
        game.get_node("UI").show()
        game.get_node("World/VoidLightning/VoidLightningHUD").show()
        game.get_node("World/RealmDread").get("screen_layer").show()
    viewport.queue_free()
    await process_frame
    Catalog.texture_cache.clear()
    print("REALM PREVIEWS: saved eight PNGs")
    quit()
