extends CharacterBody2D

signal died
signal damaged(amount: int)

@export var speed: float = 185.0
@export var max_health: int = 100

var health: int = 100
var invulnerable_for: float = 0.0
var damage_taken_multiplier: float = 1.0
var realm_index: int = 0
var vessel_health_lost: int = 0

func set_form(index: int) -> void:
	realm_index = index
	var new_loss: int = index * 15
	max_health = maxi(25, max_health + vessel_health_lost - new_loss)
	vessel_health_lost = new_loss
	health = mini(health, max_health)
	queue_redraw()

func _ready() -> void:
	add_to_group("player")
	health = max_health

func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	var was_invulnerable: bool = invulnerable_for > 0.0
	invulnerable_for = maxf(0.0, invulnerable_for - delta)
	var horizontal := 0.0
	var vertical := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		horizontal -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		horizontal += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		vertical -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		vertical += 1.0

	velocity = Vector2(horizontal, vertical).normalized() * speed * _m5_movement_boost()
	move_and_slide()
	global_position = Vector2(
		clampf(global_position.x, 20.0, 3180.0),
		clampf(global_position.y, 20.0, 3180.0)
	)
	if was_invulnerable or _m5_surge_on():
		queue_redraw()

func take_damage(amount: int) -> void:
	if health <= 0 or invulnerable_for > 0.0:
		return
	var adjusted_damage := maxi(1, roundi(float(amount) * damage_taken_multiplier))
	health = maxi(0, health - adjusted_damage)
	invulnerable_for = 0.75
	var camera := get_node_or_null("Camera2D")
	if camera != null and camera.has_method("kick"):
		camera.call("kick", 8.0)
	var effects := get_tree().get_first_node_in_group("combat_fx")
	if effects != null:
		effects.call("show_player_hit", global_position, adjusted_damage)
	queue_redraw()
	# Shop relics can react and a one-use revival relic can prevent this death.
	damaged.emit(adjusted_damage)
	if health == 0:
		died.emit()

# M5: surge motion is calculated, not baked into the player's shop-upgraded speed.
func _m5_surge_on() -> bool:
	var manager := get_node_or_null("../../../RunManager")
	return manager != null and bool(manager.get("surge_active"))

func _m5_movement_boost() -> float:
	return 1.12 if _m5_surge_on() else 1.0

func _draw() -> void:
	if realm_index < 3:
		draw_circle(Vector2(0.0, 11.0), 17.0 - realm_index * 3.0, Color(0.0, 0.0, 0.0, 0.35))
	if invulnerable_for > 0.0:
		draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 36, Color(0.40, 0.82, 1.0, 0.65), 2.0)

	# M5: flickering violet halo while the Hollow Core is active.
	if _m5_surge_on():
		var orbit_time: float = float(Time.get_ticks_msec()) / 1000.0
		draw_circle(Vector2.ZERO, 34.0, Color(0.55, 0.23, 0.94, 0.13))
		for i in range(3):
			var theta: float = orbit_time * 2.6 + float(i) * TAU / 3.0
			draw_arc(Vector2.ZERO, 28.0 + float(i) * 5.0,
				theta, theta + 1.25, 18, Color(0.78, 0.48, 1.0, 0.8), 3.0)
			draw_circle(Vector2.RIGHT.rotated(theta) * 30.0, 3.0,
				Color(0.95, 0.78, 1.0, 0.92))
