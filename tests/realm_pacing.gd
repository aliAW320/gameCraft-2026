extends SceneTree

func _initialize() -> void:
	call_deferred("_measure")

func _measure() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var run: Node = game.get_node("RunManager")
	var player: CharacterBody2D = game.get_node("World/Actors/Player")
	player.set_physics_process(false)
	player.set("invulnerable_for", 1000.0)
	run.set("debug_modified", true)
	game.get_node("SFXManager").set("sounds", {})
	var priorities := ["needle", "focus", "quickening", "pulse", "shade", "spear", "bloom", "magnet", "swift", "heart"]
	for realm_index in range(4):
		while float(run.get("realm_elapsed")) < 180.0 and not bool(run.get("boss_active")):
			if bool(run.get("level_up_active")):
				var choices: Array = game.get_node("UI/LevelUpPanel").get("available_cards")
				var chosen: String = choices[0]["id"]
				var priority: int = 99
				for choice in choices:
					var rank: int = priorities.find(choice["id"])
					if rank >= 0 and rank < priority:
						chosen = choice["id"]
						priority = rank
				run.call("_on_upgrade_selected", chosen)
			var goal: Vector2 = Vector2(1600, 1600) + Vector2.RIGHT.rotated(float(run.get("realm_elapsed")) * 0.12) * 300.0
			var nearest: float = 500.0 * 500.0
			for pickup in game.get_node("World/Pickups").get_children():
				var distance: float = player.position.distance_squared_to(pickup.position)
				if distance < nearest:
					nearest = distance
					goal = pickup.position
			player.velocity = player.position.direction_to(goal) * float(player.get("speed"))
			player.position = player.position.move_toward(goal, float(player.get("speed")) / 60.0)
			await physics_frame
		print("REALM %d GUARDIAN: %.1f seconds, %d points, %d total kills, level %d" % [realm_index + 1, run.get("realm_elapsed"), run.get("realm_points"), run.get("kills"), run.get("level")])
		if not bool(run.get("boss_active")):
			push_error("Realm %d failed to reach its guardian in 180 seconds" % realm_index)
			quit(1)
			return
		var guardian: Node = run.get("boss")
		guardian.call("take_damage", guardian.get("health"))
		run.call("_process", 0.0)
		run.call("_process", 0.0)
		if bool(run.get("shop_active")): run.call("_on_shop_skipped")
		paused = false
		await process_frame
	var reached: bool = run.get("victory")
	game.queue_free()
	await process_frame
	preload("res://scripts/realms/realm_catalog.gd").texture_cache.clear()
	quit(0 if reached else 1)
