
extends Control

@onready var run_manager: Node = get_node("../../RunManager")
@onready var health_bar: ProgressBar = $Life
@onready var boss_name: Label = $BossName


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_name.text = "THE HOLLOW GUARDIAN"
	hide()


func _process(_delta: float) -> void:
	# Check the game state BEFORE accessing the boss.
	if bool(run_manager.get("game_over")):
		hide()
		return

	if not bool(run_manager.get("boss_active")):
		hide()
		return

	# Keep this untyped until we know the object is valid.
	var boss_ref = run_manager.get("boss")

	if not is_instance_valid(boss_ref):
		hide()
		return

	# Now it is safe to cast.
	var guardian: Node2D = boss_ref as Node2D

	if guardian == null or guardian.is_queued_for_deletion():
		hide()
		return

	# Update boss health bar.
	show()
	health_bar.max_value = float(guardian.get("max_health"))
	health_bar.value = float(guardian.get("health"))
