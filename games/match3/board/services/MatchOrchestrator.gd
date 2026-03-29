extends Node

## Full cascade orchestrator. Replaces the inline process_cascade in GameBoard.
## PR 6: gm parameter removed — GameManager and GameRunState autoloads referenced directly.
## Call: await MatchOrchestrator.process_cascade(board, initial_swap_pos)

static func process_cascade(board: Node, gm: Node = null, initial_swap_pos: Vector2 = Vector2(-1, -1)) -> void:
	# gm kept as optional param for backward compatibility during migration — ignored, uses autoload
	if board == null:
		print("[MatchOrchestrator] ERROR: board is null")
		return

	var is_first_match = initial_swap_pos.x >= 0 and initial_swap_pos.y >= 0
	var cascade_depth = 0
	print("=== Starting cascade process (MatchOrchestrator) ===")

	while true:
		cascade_depth += 1
		if cascade_depth > 20:
			print("[MatchOrchestrator][ERROR] Cascade depth exceeded limit! Breaking loop.")
			break

		var matches = GameManager.find_matches()
		print("[MatchOrchestrator] Found ", matches.size(), " matches at depth ", cascade_depth)
		if matches.size() == 0:
			break

		await board.highlight_matches(matches)

		# --- Determine special tile creation ---
		var special_tile_pos: Vector2 = Vector2(-1, -1)
		var will_create_special := false

		if is_first_match:
			var matches_on_same_row := 0
			var matches_on_same_col := 0
			for match_pos in matches:
				if match_pos.y == initial_swap_pos.y:
					matches_on_same_row += 1
				if match_pos.x == initial_swap_pos.x:
					matches_on_same_col += 1

			var has_horizontal := matches_on_same_row >= 3
			var has_vertical := matches_on_same_col >= 3
			var is_t_or_l_shape := has_horizontal and has_vertical
			var is_long_line := matches_on_same_row >= 4 or matches_on_same_col >= 4

			will_create_special = is_t_or_l_shape or is_long_line
			if will_create_special:
				special_tile_pos = initial_swap_pos
			else:
				var fallback: Vector2 = board.find_special_tile_position_in_matches(matches)
				if fallback.x >= 0 and fallback.y >= 0:
					will_create_special = true
					special_tile_pos = fallback
					print("[MatchOrchestrator] First-match fallback: creating special at ", special_tile_pos)
			is_first_match = false
		else:
			special_tile_pos = board.find_special_tile_position_in_matches(matches)
			will_create_special = (special_tile_pos.x >= 0 and special_tile_pos.y >= 0)
			if will_create_special:
				print("[MatchOrchestrator] Cascade match - Special tile will be created at: ", special_tile_pos)

		# --- Audio ---
		if cascade_depth > 1:
			AudioManager.play_sfx("combo")
		else:
			AudioManager.play_sfx("match")

		# --- Destroy and remove ---
		if will_create_special and special_tile_pos.x >= 0 and special_tile_pos.y >= 0:
			await board.animate_destroy_matches_except(matches, special_tile_pos)
			GameManager.remove_matches(matches, special_tile_pos)
			var new_special_type: int = GameManager.get_tile_at(special_tile_pos)
			if new_special_type >= 7:
				board.update_tile_visual(special_tile_pos, new_special_type)
		else:
			print("[MatchOrchestrator] Destroying ", matches.size(), " matched tiles")
			await board.animate_destroy_matches(matches)
			GameManager.remove_matches(matches)

		# --- Adjacent tile damage ---
		board._damage_adjacent_unmovables(matches)
		board._damage_adjacent_spreaders(matches)

		# --- Gravity and refill ---
		print("[MatchOrchestrator] Applying gravity...")
		await board.animate_gravity()
		GameManager.emit_signal("pre_refill")
		print("[MatchOrchestrator] Refilling empty spaces...")
		await board.animate_refill()
		GameManager.emit_signal("post_refill")

		# --- Collect any collectibles that have settled at the bottom row ---
		if board.has_method("_check_collectibles_at_bottom"):
			await board._check_collectibles_at_bottom()

	# --- Post-cascade: check for remaining empty cells ---
	var has_empties := false
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(x, y) and GameRunState.grid[x][y] == 0:
				has_empties = true
				break
		if has_empties:
			break

	if has_empties:
		print("[MatchOrchestrator] Empty cells found - running final gravity+refill")
		await board.animate_gravity()
		await board.animate_refill()
		if board.has_method("_check_collectibles_at_bottom"):
			await board._check_collectibles_at_bottom()

	# --- Spreader spreading after all cascades ---
	var new_spreader_positions = GameManager.check_and_spread_tiles()
	if new_spreader_positions.size() > 0:
		board._apply_spreader_visuals(new_spreader_positions)

	GameRunState.processing_moves = false
	GameManager.reset_combo()
	print("=== Cascade process complete (MatchOrchestrator, depth=", cascade_depth, ") ===")

	board.emit_signal("board_idle")

	if not GameRunState.in_bonus_conversion and GameManager.has_method("_attempt_level_complete"):
		GameManager._attempt_level_complete()

	if board.get_tree() != null:
		await board.get_tree().create_timer(0.2).timeout

	if not GameRunState.in_bonus_conversion and not GameManager.has_possible_moves():
		print("[MatchOrchestrator] No valid moves detected! Auto-shuffling...")
		await board.get_tree().create_timer(1.0).timeout
		await board.perform_auto_shuffle()
