extends Node
const _GQS = preload("res://games/match3/board/services/GridQueryService.gd")
const _MatchFinder = preload("res://scripts/services/MatchFinder.gd")

static var GameStateBridge = null

## Full cascade orchestrator. Replaces the inline process_cascade in GameBoard.
## All state read from GameRunState.
## Call: await MatchOrchestrator.process_cascade(board, initial_swap_pos)

static func _grid_snapshot(grid: Array) -> String:
	# Create a compact representation of the grid to detect no-op cascades
	var parts: Array = []
	for x in range(grid.size()):
		var col = grid[x]
		if typeof(col) != TYPE_ARRAY:
			parts.append("")
			continue
		parts.append(",".join(col.map(func(v): return str(int(v)))))
	return "|".join(parts)

static func process_cascade(board: Node, gm: Node = null, initial_swap_pos: Vector2 = Vector2(-1, -1)) -> void:
	# gm param accepted but ignored — all state read from GameRunState.
	if board == null:
		print("[MatchOrchestrator] ERROR: board is null")
		return
	# Mark processing moves to avoid re-entrant scheduling
	GameRunState.processing_moves = true

	var is_first_match = initial_swap_pos.x >= 0 and initial_swap_pos.y >= 0
	var cascade_depth = 0
	print("=== Starting cascade process (MatchOrchestrator) ===")

	while true:
		cascade_depth += 1
		if cascade_depth > 20:
			print("[MatchOrchestrator][ERROR] Cascade depth exceeded limit! Breaking loop.")
			break

		# Snapshot before finding matches
		var before_snap = _grid_snapshot(GameRunState.grid)

		var exclude = [GameRunState.HORIZONTAL_ARROW, GameRunState.VERTICAL_ARROW, GameRunState.FOUR_WAY_ARROW, GameRunState.COLLECTIBLE, GameRunState.SPREADER, GameRunState.UNMOVABLE]
		var matches = _MatchFinder.find_matches(GameRunState.grid, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.MIN_MATCH_SIZE, exclude, -1)
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
			_clear_matches(matches, special_tile_pos, board)
			# Determine the special tile type and write it into the grid
			var sf = load("res://games/match3/board/services/SpecialFactory.gd")
			var new_special_type: int = -1
			if sf != null:
				new_special_type = sf.determine_special_type(
					matches, special_tile_pos,
					GameRunState.grid, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT,
					GameRunState.MIN_MATCH_SIZE
				)
			if new_special_type >= 7:
				GameRunState.grid[int(special_tile_pos.x)][int(special_tile_pos.y)] = new_special_type
				board.update_tile_visual(special_tile_pos, new_special_type)
				print("[MatchOrchestrator] Created special tile type=%d at %s" % [new_special_type, special_tile_pos])
			else:
				# SpecialFactory returned nothing useful — fill with a random normal tile
				var rng = RandomNumberGenerator.new()
				rng.randomize()
				GameRunState.grid[int(special_tile_pos.x)][int(special_tile_pos.y)] = rng.randi_range(1, GameRunState.TILE_TYPES)
				print("[MatchOrchestrator] Special tile detection returned %d — filling with normal tile" % new_special_type)
		else:
			print("[MatchOrchestrator] Destroying ", matches.size(), " matched tiles")
			await board.animate_destroy_matches(matches)
			_clear_matches(matches, Vector2(-1, -1), board)

		# --- Score for this match ---
		# Tiles cleared = matches minus the special-spawn position (which stays occupied)
		var tiles_cleared_for_score := matches.size()
		if will_create_special:
			tiles_cleared_for_score = max(0, tiles_cleared_for_score - 1)
		if GameStateBridge == null:
			GameStateBridge = load("res://games/match3/services/GameStateBridge.gd")
		if GameStateBridge != null:
			GameRunState.combo_count = cascade_depth  # depth drives combo multiplier
			var pts = GameStateBridge.calculate_points(tiles_cleared_for_score)
			if pts > 0:
				GameStateBridge.add_score(pts)
				print("[MatchOrchestrator] Score +%d (tiles=%d combo=%d) → total=%d" % [pts, tiles_cleared_for_score, cascade_depth, GameRunState.score])

		# --- Emit match_cleared event (owner: board) ---
		# Build context for match_cleared signal
		var tiles_removed := matches.size()
		var ctx: Dictionary = {
			"level": GameRunState.level,
			"score": GameRunState.score,
			"target": GameRunState.target_score
		}
		# Emit on the board (true owner of the event)
		if board and board.has_signal and board.has_signal("match_cleared"):
			board.emit_signal("match_cleared", tiles_removed, ctx)

		# --- Adjacent tile damage ---
		board._damage_adjacent_unmovables(matches)
		board._damage_adjacent_spreaders(matches)

		# --- Gravity and refill ---
		print("[MatchOrchestrator] Applying gravity...")
		await board.animate_gravity()
		# Emit pre_refill on board (owner)
		if board and board.has_signal and board.has_signal("pre_refill"):
			board.emit_signal("pre_refill")
		print("[MatchOrchestrator] Refilling empty spaces...")
		await board.animate_refill()
		# Emit post_refill on board (owner)
		if board and board.has_signal and board.has_signal("post_refill"):
			board.emit_signal("post_refill")
		# --- Collect any collectibles that have settled at the bottom row ---
		if board.has_method("_check_collectibles_at_bottom"):
			await board._check_collectibles_at_bottom()

		# --- end of cascade iteration: check for no-op
		var after_snap = _grid_snapshot(GameRunState.grid)
		if before_snap == after_snap:
			print("[MatchOrchestrator][ERROR] Grid unchanged after cascade iteration - potential infinite loop. Breaking out.")
			break

	# --- Post-cascade: check for remaining empty cells ---
	var has_empties := false
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			if not _GQS.is_cell_blocked(null, x, y) and GameRunState.grid[x][y] == 0:
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
	var new_spreader_positions = []
	if GameStateBridge == null:
		GameStateBridge = load("res://games/match3/services/GameStateBridge.gd")
	if GameStateBridge != null and GameStateBridge.has_method("check_and_spread_tiles"):
		new_spreader_positions = GameStateBridge.check_and_spread_tiles()
	if new_spreader_positions.size() > 0:
		board._apply_spreader_visuals(new_spreader_positions)

	GameRunState.processing_moves = false
	GameStateBridge.reset_combo()
	print("=== Cascade process complete (MatchOrchestrator, depth=", cascade_depth, ") ===")

	# If any shard collections were deferred during the cascade because processing_moves
	# was true, resolve them now: emit signals, add to GalleryManager, and schedule a
	# deferred gravity+refill so any empty cells created by collection are filled.
	if GameRunState.pending_collectible_refill:
		print("[MatchOrchestrator] Processing deferred collectible/shard collections post-cascade")
		GameRunState.pending_collectible_refill = false
		var pending_map: Dictionary = GameRunState.pending_shard_cells if GameRunState.pending_shard_cells else {}
		for key in pending_map.keys():
			var iid = str(pending_map[key])
			if iid == "":
				continue
			print("[MatchOrchestrator] Post-cascade awarding shard for %s (pending key=%s)" % [iid, key])
			if board and board.has_signal and board.has_signal("shard_tile_collected"):
				board.emit_signal("shard_tile_collected", iid)
			if typeof(GalleryManager) != TYPE_NIL and GalleryManager != null:
				GalleryManager.add_shard(iid)
		# Clear pending map after awarding
		GameRunState.pending_shard_cells = {}
		# Schedule a refill to fill any empties left by deferred collections
		if board != null and board.has_method("deferred_gravity_then_refill"):
			print("[MatchOrchestrator] Scheduling deferred_gravity_then_refill() to fill empties after deferred shard award")
			board.call_deferred("deferred_gravity_then_refill")

	board.emit_signal("board_idle")

	# Attempt level completion (score goal or primary objectives)
	if not GameRunState.in_bonus_conversion:
		if GameStateBridge == null:
			GameStateBridge = load("res://games/match3/services/GameStateBridge.gd")
		if GameStateBridge != null:
			GameStateBridge.attempt_level_complete()
			# Also trigger failed check now that processing_moves is false
			if GameRunState.pending_level_failed:
				var gfc = GameStateBridge._get_gfc()
				if gfc:
					gfc.call_deferred("perform_level_failed_check")

	if board.get_tree() != null:
		await board.get_tree().create_timer(0.2).timeout

	if not GameRunState.in_bonus_conversion and not GameStateBridge.has_possible_moves():
		print("[MatchOrchestrator] No valid moves detected! Auto-shuffling...")
		await board.get_tree().create_timer(1.0).timeout
		await board.perform_auto_shuffle()

static func _clear_matches(matches: Array, swapped_pos: Vector2, board: Node) -> void:
	# Capture before snapshot unconditionally to avoid scope issues with verbose-only declaration
	var before = _grid_snapshot(GameRunState.grid)
	if GameRunState.VERBOSE_GRAVITY:
		print("[MatchOrchestrator] _clear_matches START matches=", matches)
		print("[MatchOrchestrator] Grid BEFORE snapshot: ", before)

	# Prefer central bridge to perform removal, otherwise use MatchProcessor fallback
	if GameStateBridge == null:
		GameStateBridge = load("res://games/match3/services/GameStateBridge.gd")
	if GameStateBridge != null and GameStateBridge.has_method("remove_matches"):
		var removed_count = GameStateBridge.remove_matches(matches, swapped_pos)
		if GameRunState.VERBOSE_GRAVITY:
			var after_gm = _grid_snapshot(GameRunState.grid)
			print("[MatchOrchestrator] Grid AFTER GameStateBridge.remove_matches: ", after_gm)
			if before == after_gm:
				print("[MatchOrchestrator][WARNING] Grid unchanged after GameStateBridge.remove_matches")
				# Attempt fallback processing to ensure model cleared
				var mp_fallback = load("res://games/match3/board/services/MatchProcessor.gd")
				if mp_fallback != null:
					print("[MatchOrchestrator] Falling back to MatchProcessor.process_matches because bridge did not update GameRunState.grid")
					mp_fallback.process_matches(GameRunState.grid, matches, swapped_pos, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, null)
					var after_fb = _grid_snapshot(GameRunState.grid)
					print("[MatchOrchestrator] Grid AFTER fallback MatchProcessor: ", after_fb)
				else:
					print("[MatchOrchestrator] WARNING: fallback MatchProcessor not available")
		return
	# Fallback: use MatchProcessor directly
	var mp = load("res://games/match3/board/services/MatchProcessor.gd")
	if mp == null:
		push_error("[MatchOrchestrator] MatchProcessor unavailable for fallback clear_matches")
		return
	var res = mp.process_matches(GameRunState.grid, matches, swapped_pos, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, null)
	# Snapshot after processor
	if GameRunState.VERBOSE_GRAVITY:
		var after = _grid_snapshot(GameRunState.grid)
		print("[MatchOrchestrator] Grid AFTER MatchProcessor.process_matches: ", after)
		if before == after:
			print("[MatchOrchestrator][ERROR] Grid unchanged after MatchProcessor.process_matches - potential issue")
			# produce a diff for first few columns
			for cx in range(min(GameRunState.GRID_WIDTH, 8)):
				var col_vals = []
				for cy in range(min(GameRunState.GRID_HEIGHT, 8)):
					col_vals.append(str(GameRunState.grid[cx][cy]) if GameRunState.grid.size() > cx and GameRunState.grid[cx].size() > cy else "?")
				print("[MatchOrchestrator] Column %d after: %s" % [cx, ",".join(col_vals)])

	if typeof(res) == TYPE_DICTIONARY and res.has("tiles_removed"):
		# Update GameRunState handled by MatchProcessor; ensure board visuals are updated
		if board != null and board.has_method("_on_external_remove_matches"):
			board.call_deferred("_on_external_remove_matches", matches)
	else:
		print("[MatchOrchestrator] Fallback process_matches did not return expected result")
