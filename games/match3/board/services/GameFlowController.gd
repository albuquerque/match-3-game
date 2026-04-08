extends Node
## GameFlowController — owns all level-completion, level-failure, and bonus-cascade logic.

signal level_complete_ready(stars: int, coins: int, gems: int)
signal level_failed_ready
signal bonus_cascade_started(remaining_moves: int)
signal bonus_cascade_complete
signal request_show_skip_bonus_hint
signal request_hide_skip_bonus_hint
signal request_update_tile_visual(pos: Vector2, tile_type: int)

var GameStateBridge = null
const _GQS = preload("res://games/match3/board/services/GridQueryService.gd")

func setup(_ignored: Node = null) -> void:
	if GameStateBridge == null:
		GameStateBridge = load("res://games/match3/services/GameStateBridge.gd")

func _get_board() -> Node:
	return GameRunState.board_ref

func _get_tree_ref():
	var b = _get_board()
	if b and b.get_tree():
		return b.get_tree()
	return null

# ─── Level completion ───────────────────────────────────────────────────────

func attempt_level_complete() -> void:
	if GameRunState.in_bonus_conversion:
		return
	if GameRunState.pending_level_complete:
		return
	GameRunState.pending_level_complete = true
	call_deferred("perform_level_completion_check")

func perform_level_completion_check() -> void:
	if not GameRunState.pending_level_complete:
		return
	if GameRunState.in_bonus_conversion or GameRunState.level_transitioning:
		GameRunState.pending_level_complete = false
		return

	var has_collectible_goal = GameRunState.collectible_target > 0
	var has_unmovable_goal   = GameRunState.unmovable_target > 0
	var has_spreader_goal    = GameRunState.use_spreader_objective

	var collectible_met = not has_collectible_goal or (GameRunState.collectibles_collected >= GameRunState.collectible_target)
	var unmovable_met   = not has_unmovable_goal  or (GameRunState.unmovables_cleared >= GameRunState.unmovable_target)
	var spreader_met    = not has_spreader_goal   or (GameRunState.spreader_count <= 0 and GameRunState.spreader_positions.size() == 0)
	var has_any_primary = has_collectible_goal or has_unmovable_goal or has_spreader_goal

	GameRunState.pending_level_complete = false

	if has_any_primary:
		if collectible_met and unmovable_met and spreader_met:
			print("[GFC] Level complete — all primary objectives met")
			call_deferred("on_level_complete")
		else:
			if not collectible_met:
				print("[GFC] Waiting on collectibles: %d/%d" % [GameRunState.collectibles_collected, GameRunState.collectible_target])
			if not unmovable_met:
				print("[GFC] Waiting on unmovables: %d/%d" % [GameRunState.unmovables_cleared, GameRunState.unmovable_target])
			if not spreader_met:
				print("[GFC] Waiting on spreaders: %d remaining" % GameRunState.spreader_count)
	else:
		if GameRunState.score >= GameRunState.target_score:
			print("[GFC] Level complete by score")
			call_deferred("on_level_complete")

func on_level_complete() -> void:
	print("[GFC] on_level_complete()")
	if GameRunState.level_transitioning or GameRunState.in_bonus_conversion:
		return
	GameRunState.level_transitioning = true
	if GameStateBridge == null:
		GameStateBridge = load("res://games/match3/services/GameStateBridge.gd")

	var tree = _get_tree_ref()
	var wait_time = 0.0
	while GameRunState.processing_moves and wait_time < 10.0:
		if tree == null: break
		await tree.create_timer(0.1).timeout
		wait_time += 0.1
	if GameRunState.processing_moves:
		GameRunState.processing_moves = false
	if tree:
		await tree.create_timer(0.2).timeout

	var original_moves_left = GameRunState.moves_left

	if GameRunState.moves_left > 0:
		await convert_remaining_moves_to_bonus(GameRunState.moves_left)
		if GameRunState.moves_left != 0:
			GameRunState.moves_left = 0
			GameStateBridge.emit_moves_changed(GameRunState.moves_left)
	else:
		print("[GFC] No bonus moves remaining")

	GameRunState.last_level_won = true
	GameRunState.last_level_score = GameRunState.score
	GameRunState.last_level_target = GameRunState.target_score
	GameRunState.last_level_number = GameRunState.level
	GameRunState.last_level_moves_left = original_moves_left

	var stars = _calculate_stars(original_moves_left)
	print("[GFC] Level completed with %d stars" % stars)

	# Persist star rating — StarRatingManager is an autoload, use it directly
	if StarRatingManager:
		StarRatingManager.save_level_stars(GameRunState.level, stars)

	# NOTE: Reward granting (coins, gems, achievements) is the pipeline's responsibility.
	# GrantRewardsStep handles it after show_rewards. Do NOT call RewardManager here.

	# Fire the bridge event — LoadLevelStep listens to GameBoard.level_complete to advance the pipeline.
	print("[GFC] Emitting level_complete via bridge (level=%d score=%d)" % [GameRunState.level, GameRunState.score])
	GameStateBridge.emit_level_complete()

	# Local signal for any in-game overlay subscribers
	var coins_earned = 100 + (50 * GameRunState.level)
	var gems_earned  = 5 if stars == 3 else 0
	emit_signal("level_complete_ready", stars, coins_earned, gems_earned)

func _calculate_stars(original_moves_left: int) -> int:
	# StarRatingManager and LevelManager are autoloads — use them directly
	if StarRatingManager and LevelManager:
		var level_data = LevelManager.get_level(LevelManager.current_level_index) if LevelManager.has_method("get_level") else null
		# LevelData is a typed class (RefCounted) — access .moves directly, not via .has()
		var total_moves = level_data.moves if level_data != null else 20
		var moves_used  = total_moves - original_moves_left
		return StarRatingManager.calculate_stars(GameRunState.score, GameRunState.target_score, moves_used, total_moves)
	if GameRunState.score >= int(GameRunState.target_score * 1.5): return 3
	if GameRunState.score >= int(GameRunState.target_score * 1.2): return 2
	return 1

# ─── Level failure ───────────────────────────────────────────────────────────

func perform_level_failed_check() -> void:
	if not GameRunState.pending_level_failed:
		return
	if GameRunState.pending_level_complete or GameRunState.level_transitioning:
		return
	# Don't check while cascade is still running — board_idle will re-trigger
	if GameRunState.processing_moves:
		return
	# Don't fail if objectives are actually met
	var has_collectible_goal = GameRunState.collectible_target > 0
	var has_unmovable_goal   = GameRunState.unmovable_target > 0
	var has_spreader_goal    = GameRunState.use_spreader_objective
	var collectible_met = not has_collectible_goal or (GameRunState.collectibles_collected >= GameRunState.collectible_target)
	var unmovable_met   = not has_unmovable_goal  or (GameRunState.unmovables_cleared >= GameRunState.unmovable_target)
	var spreader_met    = not has_spreader_goal   or (GameRunState.spreader_count <= 0 and GameRunState.spreader_positions.size() == 0)
	var score_met       = GameRunState.score >= GameRunState.target_score
	var has_any_primary = has_collectible_goal or has_unmovable_goal or has_spreader_goal
	if (has_any_primary and collectible_met and unmovable_met and spreader_met) or (not has_any_primary and score_met):
		# Actually complete — don't fail
		GameRunState.pending_level_failed = false
		call_deferred("attempt_level_complete")
		return
	print("[GFC] Level failed: out of moves")
	GameRunState.pending_level_failed = false
	GameRunState.level_transitioning = true
	# Emit bridge events so LoadLevelStep fires level_failed and the pipeline routes to ShowLevelFailureStep
	GameStateBridge.emit_game_over()
	var level_id = "level_%d" % GameRunState.level
	var ctx := {"level": GameRunState.level, "score": GameRunState.score, "target": GameRunState.target_score, "moves_used": GameRunState.moves_left}
	GameStateBridge.emit_level_failed(level_id, ctx)
	emit_signal("level_failed_ready")

# ─── Bonus cascade ───────────────────────────────────────────────────────────

func convert_remaining_moves_to_bonus(remaining_moves: int) -> void:
	print("[GFC] convert_remaining_moves_to_bonus: %d moves" % remaining_moves)
	GameRunState.processing_moves = true
	GameRunState.bonus_skipped = false
	GameRunState.in_bonus_conversion = true

	var board = _get_board()
	if not board:
		print("[GFC] GameBoard not found — skipping bonus")
		GameRunState.processing_moves = false
		GameRunState.in_bonus_conversion = false
		return

	var tree = _get_tree_ref()

	if board.has_method("show_skip_bonus_hint"):
		board.show_skip_bonus_hint()
	# Also signal-based path for decoupled callers
	emit_signal("request_show_skip_bonus_hint")

	for i in range(remaining_moves):
		if GameRunState.bonus_skipped:
			for j in range(i, remaining_moves):
				GameStateBridge.add_score(100 * (j + 1))
			GameRunState.moves_left = 0
			GameStateBridge.emit_moves_changed(GameRunState.moves_left)
			break

		var random_pos = _get_random_active_tile_position()
		if random_pos == Vector2(-1, -1):
			break

		GameRunState.grid[int(random_pos.x)][int(random_pos.y)] = GameRunState.FOUR_WAY_ARROW
		# Signal-driven: board listens to request_update_tile_visual
		emit_signal("request_update_tile_visual", random_pos, GameRunState.FOUR_WAY_ARROW)
		if board.has_method("update_tile_visual"):
			board.update_tile_visual(random_pos, GameRunState.FOUR_WAY_ARROW)
		if tree:
			await tree.create_timer(0.1).timeout
		if board.has_method("activate_special_tile"):
			await board.activate_special_tile(random_pos)

		GameRunState.moves_left -= 1
		GameStateBridge.emit_moves_changed(GameRunState.moves_left)
		GameStateBridge.add_score(100 * (i + 1))

	if board.has_method("hide_skip_bonus_hint"):
		board.hide_skip_bonus_hint()
	# Also signal-based path for decoupled callers
	emit_signal("request_hide_skip_bonus_hint")
	if GameRunState.bonus_skipped:
		if tree:
			await tree.create_timer(0.5).timeout
		board.visible = false

	GameRunState.in_bonus_conversion = false
	GameRunState.processing_moves = false
	print("[GFC] convert_remaining_moves_to_bonus finished")

func _get_random_active_tile_position() -> Vector2:
	var positions: Array = []
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			var t = GameRunState.grid[x][y]
			if not _GQS.is_cell_blocked(null, x, y) and t >= 1 and t <= GameRunState.TILE_TYPES:
				positions.append(Vector2(x, y))
	if positions.size() == 0:
		return Vector2(-1, -1)
	return positions[randi() % positions.size()]

func skip_bonus_animation() -> void:
	if not GameRunState.bonus_skipped:
		GameRunState.bonus_skipped = true
