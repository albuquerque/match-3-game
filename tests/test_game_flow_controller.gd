extends Node
## Unit tests for scripts/game/GameFlowController.gd
## Uses a lightweight MockGM stub — no scene tree or autoloads required.

# ── MockGM stub ───────────────────────────────────────────────────────────────
class MockGM extends Node:
	# State fields read/written by GameFlowController
	var score: int                  = 0
	var target_score: int           = 5000
	var moves_left: int             = 10
	var level: int                  = 1
	var level_manager               = null
	var collectible_target: int     = 0
	var collectibles_collected: int = 0
	var unmovable_target: int       = 0
	var unmovables_cleared: int     = 0
	var spreader_count: int         = 0
	var use_spreader_objective: bool = false
	var pending_level_complete: bool = false
	var pending_level_failed: bool  = false
	var level_transitioning: bool   = false
	var processing_moves: bool      = false
	var in_bonus_conversion: bool   = false
	var bonus_skipped: bool         = false
	var last_level_won: bool        = false
	var last_level_score: int       = 0
	var last_level_target: int      = 0
	var last_level_number: int      = 0
	var last_level_moves_left: int  = 0
	var GRID_WIDTH: int             = 8
	var GRID_HEIGHT: int            = 8
	var TILE_TYPES: int             = 6
	var FOUR_WAY_ARROW: int         = 9
	var grid: Array                 = []

	# Recorded calls
	var _signals_emitted: Array     = []
	var _deferred_calls: Array      = []
	var _board_ref                  = null

	func emit_signal(sig: String, _a = null, _b = null) -> void:
		_signals_emitted.append(sig)

	func call_deferred(method: String, _a = null) -> void:
		_deferred_calls.append(method)

	func get_board() -> Node:
		return _board_ref

	func is_cell_blocked(_x: int, _y: int) -> bool:
		return false

	func add_score(amount: int) -> void:
		score += amount

	func get_node_or_null(_path) -> Node:
		return null

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_gfc(gm_node: MockGM) -> Node:
	var script = load("res://scripts/game/GameFlowController.gd")
	var gfc = script.new()
	gfc.setup(gm_node)
	return gfc

# ── Entry point ───────────────────────────────────────────────────────────────

func _ready():
	print("[TEST] test_game_flow_controller starting")

	_test_attempt_level_complete_sets_pending()
	_test_score_based_completion()
	_test_primary_objective_blocks_score_completion()
	_test_collectible_completion()
	_test_unmovable_completion()
	_test_spreader_completion()
	_test_level_failed_check_emits_game_over()
	_test_level_failed_skipped_when_score_met()
	_test_failed_skipped_when_collectible_met()
	_test_calculate_stars_score_thresholds()
	_test_skip_bonus_sets_flag()

	print("[TEST] All GameFlowController tests passed")
	get_tree().quit(0)

# ── Tests ─────────────────────────────────────────────────────────────────────

func _test_attempt_level_complete_sets_pending():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	gm.pending_level_complete = false
	gfc.attempt_level_complete()

	assert(gm.pending_level_complete == true,
		"attempt_level_complete must set pending_level_complete=true")
	assert("_perform_level_completion_check" in gm._deferred_calls,
		"must call_deferred _perform_level_completion_check")
	print("[TEST] _test_attempt_level_complete_sets_pending passed")
	gfc.queue_free(); gm.queue_free()

func _test_attempt_level_complete_no_op_when_already_pending():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	gm.pending_level_complete = true
	gfc.attempt_level_complete()
	# Should not add another deferred call
	assert(gm._deferred_calls.size() == 0,
		"should not schedule twice when already pending")
	print("[TEST] _test_attempt_level_complete_no_op_when_already_pending passed")
	gfc.queue_free(); gm.queue_free()

func _test_score_based_completion():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	# No primary goals, score met
	gm.score = 6000; gm.target_score = 5000
	gm.collectible_target = 0; gm.unmovable_target = 0; gm.use_spreader_objective = false
	gm.pending_level_complete = true

	gfc.perform_level_completion_check()

	assert("on_level_complete" in gm._deferred_calls,
		"score-based completion must call_deferred on_level_complete")
	assert(gm.pending_level_complete == false,
		"pending_level_complete must be cleared")
	print("[TEST] _test_score_based_completion passed")
	gfc.queue_free(); gm.queue_free()

func _test_primary_objective_blocks_score_completion():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	# Score met, but has collectible goal not met
	gm.score = 6000; gm.target_score = 5000
	gm.collectible_target = 3; gm.collectibles_collected = 1
	gm.pending_level_complete = true

	gfc.perform_level_completion_check()

	assert(not ("on_level_complete" in gm._deferred_calls),
		"must NOT complete when collectible goal unmet")
	print("[TEST] _test_primary_objective_blocks_score_completion passed")
	gfc.queue_free(); gm.queue_free()

func _test_collectible_completion():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	gm.collectible_target = 3; gm.collectibles_collected = 3
	gm.unmovable_target = 0; gm.use_spreader_objective = false
	gm.pending_level_complete = true

	gfc.perform_level_completion_check()

	assert("on_level_complete" in gm._deferred_calls,
		"collectible goal met must trigger on_level_complete")
	print("[TEST] _test_collectible_completion passed")
	gfc.queue_free(); gm.queue_free()

func _test_unmovable_completion():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	gm.unmovable_target = 5; gm.unmovables_cleared = 5
	gm.collectible_target = 0; gm.use_spreader_objective = false
	gm.pending_level_complete = true

	gfc.perform_level_completion_check()

	assert("on_level_complete" in gm._deferred_calls,
		"unmovable goal met must trigger on_level_complete")
	print("[TEST] _test_unmovable_completion passed")
	gfc.queue_free(); gm.queue_free()

func _test_spreader_completion():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	gm.use_spreader_objective = true; gm.spreader_count = 0
	gm.collectible_target = 0; gm.unmovable_target = 0
	gm.pending_level_complete = true

	gfc.perform_level_completion_check()

	assert("on_level_complete" in gm._deferred_calls,
		"spreader goal met (count=0) must trigger on_level_complete")
	print("[TEST] _test_spreader_completion passed")
	gfc.queue_free(); gm.queue_free()

func _test_level_failed_check_emits_game_over():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	gm.pending_level_failed = true
	gm.pending_level_complete = false
	gm.score = 0; gm.target_score = 5000
	gm.collectible_target = 0

	gfc.perform_level_failed_check()

	assert("game_over" in gm._signals_emitted,
		"level failed must emit game_over signal")
	assert(gm.pending_level_failed == false,
		"pending_level_failed must be cleared")
	print("[TEST] _test_level_failed_check_emits_game_over passed")
	gfc.queue_free(); gm.queue_free()

func _test_level_failed_skipped_when_score_met():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	gm.pending_level_failed = true
	gm.score = 6000; gm.target_score = 5000
	gm.collectible_target = 0

	gfc.perform_level_failed_check()

	assert(not ("game_over" in gm._signals_emitted),
		"must NOT emit game_over when score already meets target")
	print("[TEST] _test_level_failed_skipped_when_score_met passed")
	gfc.queue_free(); gm.queue_free()

func _test_failed_skipped_when_collectible_met():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	gm.pending_level_failed = true
	gm.score = 0; gm.target_score = 5000
	gm.collectible_target = 2; gm.collectibles_collected = 2

	gfc.perform_level_failed_check()

	assert(not ("game_over" in gm._signals_emitted),
		"must NOT emit game_over when collectible goal already met")
	print("[TEST] _test_failed_skipped_when_collectible_met passed")
	gfc.queue_free(); gm.queue_free()

func _test_calculate_stars_score_thresholds():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	# 1 star: score < 1.2x target
	gm.score = 5000; gm.target_score = 5000
	assert(gfc._calculate_stars(0) == 1, "below 1.2x must be 1 star")

	# 2 stars: score >= 1.2x target
	gm.score = 6000
	assert(gfc._calculate_stars(0) == 2, "1.2x must be 2 stars")

	# 3 stars: score >= 1.5x target
	gm.score = 8000
	assert(gfc._calculate_stars(0) == 3, "1.5x+ must be 3 stars")

	print("[TEST] _test_calculate_stars_score_thresholds passed")
	gfc.queue_free(); gm.queue_free()

func _test_skip_bonus_sets_flag():
	var gm = MockGM.new(); add_child(gm)
	var gfc = _make_gfc(gm); add_child(gfc)

	gm.bonus_skipped = false
	gfc.skip_bonus_animation()
	assert(gm.bonus_skipped == true, "skip_bonus_animation must set bonus_skipped=true")
	print("[TEST] _test_skip_bonus_sets_flag passed")
	gfc.queue_free(); gm.queue_free()
