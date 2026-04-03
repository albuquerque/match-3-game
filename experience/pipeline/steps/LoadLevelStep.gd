extends "res://experience/pipeline/PipelineStep.gd"

## LoadLevelStep
## Loads a level and waits for level_complete or level_failed event

var level_id: String = ""
var level_number: int = 0
var pipeline_context = null  # PipelineContext  # Store reference to pass completion data

func _init(lvl_id: String = ""):
	super("load_level")
	level_id = lvl_id
	level_number = _extract_level_number(lvl_id)

func execute(context) -> bool:
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

	# Connect to level completion signals on board_ref (preferred) or GameStateBridge (migration shim)
	var br = null
	if context and context.game_board:
		br = context.game_board
	else:
		# Fallback to resolving via NodeResolvers or GameRunState.board_ref
		var nr = load("res://scripts/helpers/node_resolvers.gd")
		if nr != null and nr.has_method("_get_board"):
			br = nr._get_board()
		if br == null and GameRunState.board_ref != null:
			br = GameRunState.board_ref
	# Connect if board provides signals
	if br != null:
		if br.has_signal and br.has_signal("level_complete") and not br.level_complete.is_connected(_on_level_complete_direct):
			br.level_complete.connect(_on_level_complete_direct)
		if br.has_signal and br.has_signal("level_failed") and not br.level_failed.is_connected(_on_level_failed):
			br.level_failed.connect(_on_level_failed)
		print("[LoadLevelStep] Connected to board_ref signals for level_complete/level_failed")

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
		# Race-guard: ensure visual grid is created on the board we have in context
		if context.game_board != null and is_instance_valid(context.game_board):
			print("[LoadLevelStep] Scheduling create_visual_grid on context.game_board")
			if context.game_board.has_method("create_visual_grid"):
				context.game_board.call_deferred("create_visual_grid")
			if context.game_board.has_method("_on_level_loaded"):
				context.game_board.call_deferred("_on_level_loaded")
		# Wait for GameRunState.initialized to avoid creating visuals against empty grid
		var wait_attempts = 0
		while not GameRunState.initialized and wait_attempts < 20:
			print("[LoadLevelStep] waiting for GameRunState.initialized (attempt=", wait_attempts, ")")
			await get_tree().create_timer(0.05).timeout
			wait_attempts += 1
		if not GameRunState.initialized:
			print("[LoadLevelStep] WARNING: GameRunState not initialized after wait; visuals may not create")
		return true
	elif context.game_ui and context.game_ui.has_method("_load_level_by_number"):
		# Already handled above; keep branch to be explicit
		return true
	else:
		push_error("[LoadLevelStep] Cannot load level - no GameUI or board loader")
		return false

func _clear_narrative_stage() -> void:
	# Engine.get_main_loop().root works from RefCounted; get_node_or_null("/root/...") does not
	var root = (Engine.get_main_loop() as SceneTree).root
	var nsm = root.get_node_or_null("NarrativeStageManager") if root else null
	if nsm and nsm.has_method("clear_stage"):
		nsm.clear_stage(true)
		print("[LoadLevelStep] NarrativeStageManager cleared")

func _on_level_complete_direct():
	print("[LoadLevelStep] _on_level_complete_direct fired for level %d (pipeline_context=%s)" % [level_number, str(pipeline_context)])
	var root := (Engine.get_main_loop() as SceneTree).root
	# Stars were already saved to StarRatingManager by GameFlowController
	var stars := 0
	var srm := root.get_node_or_null("StarRatingManager") if root else null
	if srm and srm.has_method("get_level_stars"):
		stars = srm.get_level_stars(level_number)
	# Coins formula matches RewardManager.grant_level_completion_reward
	var coins := 100 + (50 * level_number)
	var gems := 5 if stars == 3 else 0
	print("[LoadLevelStep] Resolved rewards — stars=%d coins=%d gems=%d" % [stars, coins, gems])

	# ── Save progress ─────────────────────────────────────────────────────────
	# RewardManager.grant_level_completion_reward is the single place that
	# increments levels_completed and persists player_progress.json.
	# Without this call, start_flow() always resumes at the same level.
	var rm := root.get_node_or_null("RewardManager") if root else null
	if rm and rm.has_method("grant_level_completion_reward"):
		rm.grant_level_completion_reward(level_number, stars)
		print("[LoadLevelStep] grant_level_completion_reward called — levels_completed now %d" % rm.levels_completed)
	else:
		push_warning("[LoadLevelStep] RewardManager not found — progress not saved")

	# Also update ProgressManager (used by WorldMap unlock logic)
	var pm := root.get_node_or_null("ProgressManager") if root else null
	if pm and pm.has_method("complete_level"):
		pm.complete_level("level_%d" % level_number, stars, GameRunState.score, 0)

	_on_level_complete("level_%d" % level_number, {
		"score": GameRunState.score,
		"stars": stars,
		"coins_earned": coins,
		"gems_earned": gems,
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

func _on_level_failed():
	var lvl_id = "level_%d" % level_number
	print("[LoadLevelStep] Level failed: %s" % lvl_id)
	_clear_narrative_stage()
	if pipeline_context:
		pipeline_context.set_result("current_level", level_number)
		pipeline_context.set_result("level_completed", false)
		pipeline_context.set_result("level_failed", true)
		pipeline_context.set_result("score", GameRunState.score)
		pipeline_context.set_result("target_score", GameRunState.target_score)
		pipeline_context.set_result("moves_used", 0)
		pipeline_context.set_result("stars", 0)
		pipeline_context.set_result("coins_earned", 0)
		pipeline_context.set_result("gems_earned", 0)
		print("[LoadLevelStep] Stored failure data in pipeline context")
	step_completed.emit(true)

func cleanup():
	# Disconnect any board_ref signals we connected earlier
	var br = null
	if pipeline_context and pipeline_context.game_board:
		br = pipeline_context.game_board
	if br != null and br.has_signal:
		if br.has_signal("level_complete") and br.level_complete.is_connected(_on_level_complete_direct):
			br.level_complete.disconnect(_on_level_complete_direct)
		if br.has_signal("level_failed") and br.level_failed.is_connected(_on_level_failed):
			br.level_failed.disconnect(_on_level_failed)

func _extract_level_number(lvl_id: String) -> int:
	var num_str = lvl_id.replace("level_", "").replace("level", "")
	return int(num_str)
