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
	# M5: check lifecycle flags before casting a potentially freed object.
	if bool(run_manager.get("game_over")) or not bool(run_manager.get("boss_active")):
		hide()
		return
	var boss_ref: Variant = run_manager.get("boss")
	if not is_instance_valid(boss_ref):
		hide()
		return
	var guardian: Node2D = boss_ref as Node2D
	if guardian == null or guardian.is_queued_for_deletion():
		hide()
		return
	show()
	var m7_boss_num: int = int(run_manager.get("active_boss_index")) + 1
	var m7_boss_title: String = String(guardian.get("display_name"))
	var m7_exposed: bool = int(guardian.get("state")) == 4 and m7_boss_num >= 3
	boss_name.text = "%d/6  %s%s" % [m7_boss_num, m7_boss_title, "  [EXPOSED]" if m7_exposed else ""]
	health_bar.max_value = float(guardian.get("max_health"))
	health_bar.value = float(guardian.get("health"))
