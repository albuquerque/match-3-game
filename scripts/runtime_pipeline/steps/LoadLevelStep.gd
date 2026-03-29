extends PipelineStep
class_name LoadLevelStep

## LoadLevelStep
## Loads a level and waits for level_complete or level_failed event

var level_id: String = ""
var level_number: int = 0
var pipeline_context: PipelineContext = null  # Store reference to pass completion data

func _init(lvl_id: String = ""):
	super("load_level")
	level_id = lvl_id
	level_number = _extract_level_number(lvl_id)

func execute(context: PipelineContext) -> bool:
	if level_number <= 0:
		push_error("[LoadLevelStep] Invalid level number: %d" % level_number)
		return false

	print("[LoadLevelStep] Loading level %d (%s)" % [level_number, level_id])
	print("[LoadLevelStep] game_ui=%s game_board=%s" % [str(context.game_ui), str(context.game_board)])

	# Store pipeline context reference
	pipeline_context = context

	# Set waiting flag
	context.waiting_for_completion = true
	context.completion_type = "level"

	# Connect to level completion events
	# PR 5c: connect directly to GameManager autoload — EventBus no longer routes these
	# NOTE: LoadLevelStep is a RefCounted — cannot use get_node_or_null; use autoload directly
	if GameManager:
		if GameManager.has_signal("level_complete") and not GameManager.level_complete.is_connected(_on_level_complete_direct):
			GameManager.level_complete.connect(_on_level_complete_direct)
		if GameManager.has_signal("level_failed") and not GameManager.level_failed.is_connected(_on_level_failed):
			GameManager.level_failed.connect(_on_level_failed)
		print("[LoadLevelStep] Connected to GameManager signals (PR 5c)")
	elif EventBus:  # fallback until PR 5d
		if not EventBus.level_complete.is_connected(_on_level_complete):
			EventBus.level_complete.connect(_on_level_complete)
		if not EventBus.level_failed.is_connected(_on_level_failed):
			EventBus.level_failed.connect(_on_level_failed)

	# Ensure GameBoard node itself is visible — FlowCoordinator hides it (old_board.visible = false)
	# before the flow starts, and show_board_group() only shows BoardContainer children, not
	# the GameBoard Node2D itself. Must be set before initialize_game() so tiles render.
	if context.game_board and is_instance_valid(context.game_board):
		context.game_board.visible = true
		print("[LoadLevelStep] GameBoard node made visible before level load")

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

func _clear_narrative_stage() -> void:
	# Engine.get_main_loop().root works from RefCounted; get_node_or_null("/root/...") does not
	var root = (Engine.get_main_loop() as SceneTree).root
	var nsm = root.get_node_or_null("NarrativeStageManager") if root else null
	if nsm and nsm.has_method("clear_stage"):
		nsm.clear_stage(true)
		print("[LoadLevelStep] NarrativeStageManager cleared")

## PR 5c: shim for GameManager.level_complete (no-arg signal)
func _on_level_complete_direct():
	print("[LoadLevelStep] _on_level_complete_direct fired for level %d (pipeline_context=%s)" % [level_number, str(pipeline_context)])
	_on_level_complete("level_%d" % level_number, {
		"score": GameRunState.score,
		"stars": 0,  # stars computed by GameFlowController; pipeline reads from context
		"coins_earned": 0,
		"gems_earned": 0
	})

func _on_level_complete(lvl_id: String, context: Dictionary = {}):
	print("[LoadLevelStep] Level completed: %s" % lvl_id)
	_clear_narrative_stage()
	if pipeline_context:
		pipeline_context.set_result("current_level", level_number)
		pipeline_context.set_result("level_completed", true)
		pipeline_context.set_result("score", context.get("score", GameRunState.score))
		pipeline_context.set_result("stars", context.get("stars", 0))
		pipeline_context.set_result("coins_earned", context.get("coins_earned", 0))
		pipeline_context.set_result("gems_earned", context.get("gems_earned", 0))
		print("[LoadLevelStep] Stored completion data in pipeline context")
	step_completed.emit(true)

func _on_level_failed(lvl_id: String = "", context: Dictionary = {}):
	print("[LoadLevelStep] Level failed: %s" % lvl_id)
	_clear_narrative_stage()
	if pipeline_context:
		pipeline_context.set_result("current_level", level_number)
		pipeline_context.set_result("level_completed", false)
		pipeline_context.set_result("level_failed", true)
		pipeline_context.set_result("score", context.get("score", GameRunState.score))
		pipeline_context.set_result("target_score", context.get("target", GameRunState.target_score))
		pipeline_context.set_result("moves_used", context.get("moves_used", 0))
		pipeline_context.set_result("stars", 0)
		pipeline_context.set_result("coins_earned", 0)
		pipeline_context.set_result("gems_earned", 0)
		print("[LoadLevelStep] Stored failure data in pipeline context")
	step_completed.emit(true)

func cleanup():
	# NOTE: LoadLevelStep is a RefCounted — use autoload directly, not get_node_or_null
	if GameManager:
		if GameManager.has_signal("level_complete") and GameManager.level_complete.is_connected(_on_level_complete_direct):
			GameManager.level_complete.disconnect(_on_level_complete_direct)
		if GameManager.has_signal("level_failed") and GameManager.level_failed.is_connected(_on_level_failed):
			GameManager.level_failed.disconnect(_on_level_failed)
	if EventBus:  # passthrough cleanup until PR 5d
		if EventBus.level_complete.is_connected(_on_level_complete):
			EventBus.level_complete.disconnect(_on_level_complete)
		if EventBus.level_failed.is_connected(_on_level_failed):
			EventBus.level_failed.disconnect(_on_level_failed)

func _extract_level_number(lvl_id: String) -> int:
	var num_str = lvl_id.replace("level_", "").replace("level", "")
	return int(num_str)
