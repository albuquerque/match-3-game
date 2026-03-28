extends Node
## GameFlowController — owns all level-completion, level-failure, and bonus-cascade logic.
## GameManager holds an instance of this and forwards public calls to it.
## All signals that external nodes listen to are re-emitted on GameManager for back-compat.

signal level_complete_ready(stars: int, coins: int, gems: int)
signal level_failed_ready
signal bonus_cascade_started(remaining_moves: int)
signal bonus_cascade_complete

# Injected by GameManager on instantiation
var gm: Node = null  # GameManager reference

func setup(game_manager: Node) -> void:
	gm = game_manager

# ─── Level completion ───────────────────────────────────────────────────────

func attempt_level_complete() -> void:
	# Do not trigger level-complete checks while the bonus cascade is already running
	if GameRunState.in_bonus_conversion:
		return
	if GameRunState.pending_level_complete:
		return
	GameRunState.pending_level_complete = true
	gm.call_deferred("_perform_level_completion_check")

func perform_level_completion_check() -> void:
	if not GameRunState.pending_level_complete:
		return
	# Do not re-trigger if we are already in the bonus conversion or transitioning
	if GameRunState.in_bonus_conversion or GameRunState.level_transitioning:
		GameRunState.pending_level_complete = false
		return

	var has_collectible_goal = GameRunState.collectible_target > 0
	var has_unmovable_goal   = GameRunState.unmovable_target > 0
	var has_spreader_goal    = GameRunState.use_spreader_objective

	var collectible_met = not has_collectible_goal or (GameRunState.collectibles_collected >= GameRunState.collectible_target)
	var unmovable_met   = not has_unmovable_goal  or (GameRunState.unmovables_cleared >= GameRunState.unmovable_target)
	var spreader_met    = not has_spreader_goal   or (GameRunState.spreader_count <= 0)
	var has_any_primary = has_collectible_goal or has_unmovable_goal or has_spreader_goal

	GameRunState.pending_level_complete = false

	if has_any_primary:
		if collectible_met and unmovable_met and spreader_met:
			print("[GFC] Level complete — all primary objectives met")
			gm.call_deferred("on_level_complete")
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
			gm.call_deferred("on_level_complete")

func on_level_complete() -> void:
	print("[GFC] on_level_complete()")
	if GameRunState.level_transitioning or GameRunState.in_bonus_conversion:
		return
	GameRunState.level_transitioning = true

	# Wait for any ongoing board activity
	var wait_time = 0.0
	while GameRunState.processing_moves and wait_time < 10.0:
		if gm.get_tree() == null: break
		await gm.get_tree().create_timer(0.1).timeout
		wait_time += 0.1
	if GameRunState.processing_moves:
		GameRunState.processing_moves = false
	if gm.get_tree() != null:
		await gm.get_tree().create_timer(0.2).timeout

	var original_moves_left = GameRunState.moves_left

	if GameRunState.moves_left > 0:
		await convert_remaining_moves_to_bonus(GameRunState.moves_left)
		if GameRunState.moves_left != 0:
			GameRunState.moves_left = 0
			gm.emit_signal("moves_changed", GameRunState.moves_left)
	else:
		print("[GFC] No bonus moves remaining")

	# Store final snapshot
	GameRunState.last_level_won = true
	GameRunState.last_level_score = GameRunState.score
	GameRunState.last_level_target = GameRunState.target_score
	GameRunState.last_level_number = GameRunState.level
	GameRunState.last_level_moves_left = original_moves_left

	# Calculate stars
	var stars = _calculate_stars(original_moves_left)
	print("[GFC] Level completed with %d stars" % stars)

	var star_manager = gm.get_node_or_null("/root/StarRatingManager")
	if star_manager:
		star_manager.save_level_stars(GameRunState.level, stars)

	var rm = gm.get_node_or_null("/root/RewardManager")
	if rm and rm.has_method("grant_level_completion_reward"):
		rm.grant_level_completion_reward(GameRunState.level, stars)

	gm.emit_signal("level_complete")

	var coins_earned = 100 + (50 * GameRunState.level)
	var gems_earned  = 5 if stars == 3 else 0
	_emit_eventbus_level_complete(stars, coins_earned, gems_earned)

func _calculate_stars(original_moves_left: int) -> int:
	var star_manager = gm.get_node_or_null("/root/StarRatingManager")
	if star_manager and gm.level_manager:
		var level_data = gm.level_manager.get_level(gm.level_manager.current_level_index)
		var total_moves = level_data.moves if level_data else 20
		var moves_used  = total_moves - original_moves_left
		return star_manager.calculate_stars(GameRunState.score, GameRunState.target_score, moves_used, total_moves)
	if GameRunState.score >= int(GameRunState.target_score * 1.5): return 3
	if GameRunState.score >= int(GameRunState.target_score * 1.2): return 2
	return 1

func _emit_eventbus_level_complete(stars: int, coins: int, gems: int) -> void:
	var level_id = "level_%d" % GameRunState.level
	if EventBus:
		EventBus.emit_level_complete(level_id, {
			"level": GameRunState.level, "score": GameRunState.score,
			"stars": stars, "coins_earned": coins, "gems_earned": gems
		})

# ─── Level failure ───────────────────────────────────────────────────────────

func perform_level_failed_check() -> void:
	if not GameRunState.pending_level_failed:
		return
	if GameRunState.pending_level_complete:
		return
	if GameRunState.score >= GameRunState.target_score:
		return
	if GameRunState.collectible_target > 0 and GameRunState.collectibles_collected >= GameRunState.collectible_target:
		return
	print("[GFC] Level failed: out of moves")
	GameRunState.pending_level_failed = false
	gm.emit_signal("game_over")
	_emit_eventbus_level_failed()

func _emit_eventbus_level_failed() -> void:
	var level_id = "level_%d" % GameRunState.level
	if EventBus:
		EventBus.emit_level_failed(level_id, {
			"level": GameRunState.level, "score": GameRunState.score,
			"target": GameRunState.target_score, "moves_used": GameRunState.moves_left
		})

# ─── Bonus cascade ───────────────────────────────────────────────────────────

func convert_remaining_moves_to_bonus(remaining_moves: int) -> void:
	print("[GFC] convert_remaining_moves_to_bonus: %d moves" % remaining_moves)
	GameRunState.processing_moves = true
	GameRunState.bonus_skipped = false
	GameRunState.in_bonus_conversion = true

	var board = gm.get_board()
	if not board:
		print("[GFC] GameBoard not found — skipping bonus")
		GameRunState.processing_moves = false
		GameRunState.in_bonus_conversion = false
		return

	if board.has_method("show_skip_bonus_hint"):
		board.show_skip_bonus_hint()

	for i in range(remaining_moves):
		if GameRunState.bonus_skipped:
			for j in range(i, remaining_moves):
				gm.add_score(100 * (j + 1))
			GameRunState.moves_left = 0
			gm.emit_signal("moves_changed", GameRunState.moves_left)
			break

		var random_pos = _get_random_active_tile_position()
		if random_pos == Vector2(-1, -1):
			break

		GameRunState.grid[int(random_pos.x)][int(random_pos.y)] = GameRunState.FOUR_WAY_ARROW
		if board.has_method("update_tile_visual"):
			board.update_tile_visual(random_pos, GameRunState.FOUR_WAY_ARROW)
		await gm.get_tree().create_timer(0.1).timeout
		if board.has_method("activate_special_tile"):
			await board.activate_special_tile(random_pos)

		GameRunState.moves_left -= 1
		gm.emit_signal("moves_changed", GameRunState.moves_left)
		gm.add_score(100 * (i + 1))

	if board.has_method("hide_skip_bonus_hint"):
		board.hide_skip_bonus_hint()
	if GameRunState.bonus_skipped:
		await gm.get_tree().create_timer(0.5).timeout
		if board:
			board.visible = false

	GameRunState.in_bonus_conversion = false
	GameRunState.processing_moves = false
	print("[GFC] convert_remaining_moves_to_bonus finished")

func _get_random_active_tile_position() -> Vector2:
	var positions: Array = []
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			var t = GameRunState.grid[x][y]
			if not gm.is_cell_blocked(x, y) and t >= 1 and t <= GameRunState.TILE_TYPES:
				positions.append(Vector2(x, y))
	if positions.size() == 0:
		return Vector2(-1, -1)
	return positions[randi() % positions.size()]

func skip_bonus_animation() -> void:
	if not GameRunState.bonus_skipped:
		GameRunState.bonus_skipped = true
