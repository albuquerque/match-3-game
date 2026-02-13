extends PipelineStep
class_name LoadLevelStep

## LoadLevelStep
## Loads a level and waits for level_complete or level_failed event

var level_id: String = ""
var level_number: int = 0

func _init(lvl_id: String = ""):
	super("load_level")
	level_id = lvl_id
	level_number = _extract_level_number(lvl_id)

func execute(context: PipelineContext) -> bool:
	if level_number <= 0:
		push_error("[LoadLevelStep] Invalid level number: %d" % level_number)
		return false

	print("[LoadLevelStep] Loading level %d (%s)" % [level_number, level_id])

	# Set waiting flag
	context.waiting_for_completion = true
	context.completion_type = "level"

	# Connect to level completion events
	print("[LoadLevelStep] Connecting to EventBus for level_complete/level_failed (EventBus available: %s)" % (EventBus != null))
	if EventBus:
		if not EventBus.level_complete.is_connected(_on_level_complete):
			EventBus.level_complete.connect(_on_level_complete)
		if not EventBus.level_failed.is_connected(_on_level_failed):
			EventBus.level_failed.connect(_on_level_failed)

	# Load level via GameUI
	print("[LoadLevelStep] Attempting to load level via GameUI (has game_ui: %s)" % (context.game_ui != null))
	if context.game_ui and context.game_ui.has_method("_load_level_by_number"):
		print("[LoadLevelStep] Calling GameUI._load_level_by_number(%d)" % level_number)
		var res = context.game_ui._load_level_by_number(level_number)
		# If the loader returns a GDScriptFunctionState, detect by class name and await it to ensure the level load completes
		if typeof(res) == TYPE_OBJECT and res and res.get_class() == "GDScriptFunctionState":
			print("[LoadLevelStep] Awaiting GameUI loader result for level %d" % level_number)
			await res
			print("[LoadLevelStep] GameUI loader completed for level %d" % level_number)
		return true
	elif GameManager:
		print("[LoadLevelStep] Setting GameManager.level = %d" % level_number)
		GameManager.level = level_number
		return true
	else:
		push_error("[LoadLevelStep] Cannot load level - no GameUI or GameManager")
		return false

func _on_level_complete(lvl_id: String, context: Dictionary = {}):
	print("[LoadLevelStep] Level completed: %s" % lvl_id)
	step_completed.emit(true)

func _on_level_failed(lvl_id: String, context: Dictionary = {}):
	print("[LoadLevelStep] Level failed: %s" % lvl_id)
	step_completed.emit(false)

func cleanup():
	if EventBus:
		if EventBus.level_complete.is_connected(_on_level_complete):
			EventBus.level_complete.disconnect(_on_level_complete)
		if EventBus.level_failed.is_connected(_on_level_failed):
			EventBus.level_failed.disconnect(_on_level_failed)

func _extract_level_number(lvl_id: String) -> int:
	var num_str = lvl_id.replace("level_", "").replace("level", "")
	return int(num_str)
