extends Node
# BoardAnimator — loaded as a script resource (via BA var in GameBoard), not instanced directly

## BoardAnimator — all tile destruction, highlight, shuffle and clear animations.
## Step 4 of GameBoard Round 3 refactor.
## All methods are static; call with (board, tiles_ref, ...) following the GravityAnimator pattern.

# ── Tile destruction ──────────────────────────────────────────────────────────

static func animate_destroy_tiles(board: Node, tiles_ref: Array, positions: Array) -> void:
	if positions == null or positions.size() == 0:
		return

	var destroy_tweens = []
	var tiles_to_free = []
	var destroyed_positions = []

	for pos in positions:
		if pos.x < 0 or pos.y < 0:
			continue
		if pos.x >= GameManager.GRID_WIDTH or pos.y >= GameManager.GRID_HEIGHT:
			continue

		var gx = int(pos.x)
		var gy = int(pos.y)

		if not tiles_ref or gx >= tiles_ref.size() or not tiles_ref[gx] or gy >= tiles_ref[gx].size():
			print("[BoardAnimator] WARNING: Invalid tiles array access at (", gx, ",", gy, ")")
			continue

		var tile = tiles_ref[gx][gy]
		if not tile or not is_instance_valid(tile):
			print("[BoardAnimator] No valid tile at (", gx, ",", gy, ")")
			continue

		var is_hard = tile.is_unmovable_hard if "is_unmovable_hard" in tile else false
		if is_hard:
			continue

		if tile.has_method("animate_destroy"):
			var tw = tile.animate_destroy()
			if tw:
				destroy_tweens.append(tw)
		else:
			var tw2 = board.create_tween()
			tw2.tween_property(tile, "modulate", Color(1, 1, 1, 0), 0.15)
			destroy_tweens.append(tw2)

		tile.set_process_input(false)
		tiles_to_free.append(tile)
		destroyed_positions.append(pos)

	if destroy_tweens.size() > 0:
		for tw in destroy_tweens:
			if tw != null:
				await tw.finished
	else:
		if board.get_tree() != null:
			await board.get_tree().create_timer(0.15).timeout

	for i in range(tiles_to_free.size()):
		var pos = destroyed_positions[i]
		if pos.x >= 0 and pos.y >= 0:
			if tiles_ref[int(pos.x)][int(pos.y)] == tiles_to_free[i]:
				tiles_ref[int(pos.x)][int(pos.y)] = null
			if not tiles_to_free[i].is_queued_for_deletion():
				tiles_to_free[i].queue_free()

	print("[BoardAnimator] animate_destroy_tiles: destroyed ", tiles_to_free.size(), " visual tiles")

static func animate_destroy_matches(board: Node, tiles_ref: Array, matches: Array) -> void:
	if matches == null or matches.size() == 0:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - board.last_match_time > board.COMBO_TIMEOUT:
		board.combo_chain_count = 0

	board.combo_chain_count    += 1
	board.last_match_time       = current_time

	print("[BoardAnimator] Match! Size: ", matches.size(), ", Combo chain: ", board.combo_chain_count)

	if not (matches.size() == 3 and board.combo_chain_count == 1):
		board._show_combo_text(matches.size(), matches, board.combo_chain_count)

	if matches.size() >= 5 or board.combo_chain_count >= 3:
		var shake_intensity = max(matches.size() * 2, board.combo_chain_count * 3)
		board._apply_screen_shake(0.15, shake_intensity)

	await animate_destroy_tiles(board, tiles_ref, matches)

static func animate_destroy_matches_except(board: Node, tiles_ref: Array, matches: Array, skip_pos: Vector2) -> void:
	if matches == null or matches.size() == 0:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - board.last_match_time > board.COMBO_TIMEOUT:
		board.combo_chain_count = 0

	board.combo_chain_count += 1
	board.last_match_time    = current_time

	print("[BoardAnimator] Match (creating special)! Size: ", matches.size(), ", Combo chain: ", board.combo_chain_count)

	board._show_combo_text(matches.size(), matches, board.combo_chain_count)

	if matches.size() >= 5 or board.combo_chain_count >= 3:
		var shake_intensity = max(matches.size() * 2, board.combo_chain_count * 3)
		board._apply_screen_shake(0.15, shake_intensity)

	var to_destroy = []
	for m in matches:
		var pos = m
		if typeof(m) == TYPE_DICTIONARY and m.has("x") and m.has("y"):
			pos = Vector2(float(m["x"]), float(m["y"]))
		if pos == skip_pos:
			continue
		to_destroy.append(pos)

	if to_destroy.size() > 0:
		await animate_destroy_tiles(board, tiles_ref, to_destroy)

# ── Shuffle animation ─────────────────────────────────────────────────────────

static func animate_shuffle(board: Node, tiles_ref: Array) -> void:
	var shuffle_tweens = []
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			var tile = tiles_ref[x][y] if x < tiles_ref.size() and y < tiles_ref[x].size() else null
			if tile and not GameManager.is_cell_blocked(x, y):
				var new_type = GameManager.get_tile_at(Vector2(x, y))
				tile.update_type(new_type)
				var original_pos = tile.position
				var tween = board.create_tween()
				tween.set_parallel(true)
				tween.tween_property(tile, "position", original_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.1)
				tween.tween_property(tile, "rotation", randf_range(-0.2, 0.2), 0.1)
				tween.set_parallel(false)
				tween.tween_property(tile, "position", original_pos, 0.2)
				tween.tween_property(tile, "rotation", 0.0, 0.1)
				shuffle_tweens.append(tween)

	if shuffle_tweens.size() > 0:
		await shuffle_tweens[0].finished
	else:
		await board.get_tree().create_timer(0.3).timeout

# ── Highlight animations ──────────────────────────────────────────────────────

static func highlight_matches(board: Node, tiles_ref: Array, matches: Array) -> void:
	var highlight_tweens = []
	for match_pos in matches:
		var tile = tiles_ref[int(match_pos.x)][int(match_pos.y)] if int(match_pos.x) < tiles_ref.size() else null
		if tile:
			var tween = tile.animate_match_highlight()
			if tween != null:
				highlight_tweens.append(tween)
	for tw in highlight_tweens:
		if tw != null:
			await tw.finished

static func highlight_special_activation(board: Node, tiles_ref: Array, positions: Array) -> void:
	if positions == null or positions.size() == 0:
		return

	if positions.size() > 3:
		AudioManager.play_sfx("special_tile")

	var tweens = []
	for pos in positions:
		if pos.x < 0 or pos.y < 0:
			continue
		if pos.x >= GameManager.GRID_WIDTH or pos.y >= GameManager.GRID_HEIGHT:
			continue
		var tile = tiles_ref[int(pos.x)][int(pos.y)] if int(pos.x) < tiles_ref.size() else null
		if tile:
			var t = board.create_tween()
			t.tween_property(tile, "modulate", Color(2, 2, 1, 1), 0.06)
			t.tween_property(tile, "modulate", Color.WHITE, 0.12)
			tweens.append(t)
			BoardEffects.create_special_activation_particles(board, board.grid_to_world_position(pos))

	if tweens.size() > 0:
		await tweens[0].finished

# ── Clear tiles ───────────────────────────────────────────────────────────────

static func clear_tiles(board: Node) -> void:
	print("[BoardAnimator] Starting tile cleanup")
	var tiles_to_remove = []

	if board.board_container and is_instance_valid(board.board_container):
		for child in board.board_container.get_children():
			if child and is_instance_valid(child) and child.name != "BorderContainer" and child.has_method("setup"):
				tiles_to_remove.append(child)

	for child in board.get_children():
		if child and is_instance_valid(child) and not (child.name in ["Background", "BorderContainer", "BoardContainer", "TileAreaOverlay"]) and child.has_method("setup"):
			tiles_to_remove.append(child)

	for tile in tiles_to_remove:
		if tile and is_instance_valid(tile):
			var p = tile.get_parent()
			if p and is_instance_valid(p):
				p.remove_child(tile)
			tile.queue_free()

	print("[BoardAnimator] Cleared ", tiles_to_remove.size(), " tiles from scene")

# ── Special tile position detection ──────────────────────────────────────────

static func find_special_tile_position_in_matches(matches: Array) -> Vector2:
	## Find T/L shape or 4+ line in matches; return position for special tile creation.
	if matches.size() < 4:
		return Vector2(-1, -1)

	for test_pos in matches:
		var on_row = 0
		var on_col = 0
		for mp in matches:
			if mp.y == test_pos.y: on_row += 1
			if mp.x == test_pos.x: on_col += 1
		if on_row >= 3 and on_col >= 3:
			return test_pos

	var rows: Dictionary = {}
	for mp in matches:
		if not rows.has(mp.y): rows[mp.y] = []
		rows[mp.y].append(mp)
	for row_y in rows:
		if rows[row_y].size() >= 4:
			var mid = int(rows[row_y].size() / 2)
			return rows[row_y][mid]

	var cols: Dictionary = {}
	for mp in matches:
		if not cols.has(mp.x): cols[mp.x] = []
		cols[mp.x].append(mp)
	for col_x in cols:
		if cols[col_x].size() >= 4:
			var midc = int(cols[col_x].size() / 2)
			return cols[col_x][midc]

	return Vector2(-1, -1)
