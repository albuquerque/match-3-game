extends Node
# BoardActionExecutor — loaded as a script resource (via BAX var in GameBoard), not instanced directly

## BoardActionExecutor — all booster execution, special tile activation,
## and immediate tile destruction.
## Step 6 of GameBoard Round 3 refactor.
## All methods are static; call with the GameBoard node as first argument.

# ── Generic board-action executor ────────────────────────────────────────────

## Execute a simple "clear positions → score → gravity → refill → cascade" action.
## `effect_fn` is an optional Callable(board) for pre-clear visual effects.
static func execute_board_action(board: Node, positions: Array, effect_fn: Callable = Callable()) -> void:
	if positions.size() == 0:
		return
	if effect_fn.is_valid():
		await effect_fn.call(board)
	await board.highlight_special_activation(positions)
	await board.animate_destroy_tiles(positions)
	var pts = GameManager.calculate_points(positions.size())
	for pos in positions:
		GameManager.grid[int(pos.x)][int(pos.y)] = 0
	if pts > 0:
		GameManager.add_score(pts)
	await board.animate_gravity()
	await board.animate_refill()
	await board.process_cascade()

## Clear positions that may include hard unmovables (row/column clear).
static func execute_line_clear(board: Node, positions: Array, tiles_ref: Array) -> void:
	if positions.size() == 0:
		return
	await board.highlight_special_activation(positions)
	await board.animate_destroy_tiles(positions)
	var scoring_count = 0
	for pos in positions:
		var gx = int(pos.x)
		var gy = int(pos.y)
		var tile_instance = tiles_ref[gx][gy] if gx < tiles_ref.size() and gy < tiles_ref[gx].size() else null
		if tile_instance and tile_instance.is_unmovable_hard:
			var destroyed = tile_instance.take_hit(1)
			if destroyed:
				GameManager.grid[gx][gy] = 0
				if not tile_instance.is_queued_for_deletion():
					tile_instance.queue_free()
				tiles_ref[gx][gy] = null
				scoring_count += 1
		else:
			GameManager.grid[gx][gy] = 0
			scoring_count += 1
	var pts = GameManager.calculate_points(scoring_count)
	if pts > 0:
		GameManager.add_score(pts)
	await board.animate_gravity()
	await board.animate_refill()
	await board.process_cascade()

# ── Booster executors ─────────────────────────────────────────────────────────

static func activate_shuffle_booster(board: Node) -> void:
	if not RewardManager.use_booster("shuffle"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_shuffle")
	if GameManager.shuffle_until_moves_available():
		await board.animate_shuffle()
	GameManager.processing_moves = false

static func activate_swap_booster(board: Node, tiles_ref: Array, x1: int, y1: int, x2: int, y2: int) -> void:
	if not RewardManager.use_booster("swap"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_swap")
	if GameManager.is_cell_blocked(x1, y1) or GameManager.is_cell_blocked(x2, y2):
		GameManager.processing_moves = false
		return
	var tile1 = tiles_ref[x1][y1]
	var tile2 = tiles_ref[x2][y2]
	if not tile1 or not tile2:
		GameManager.processing_moves = false
		return
	var temp = GameManager.grid[x1][y1]
	GameManager.grid[x1][y1] = GameManager.grid[x2][y2]
	GameManager.grid[x2][y2] = temp
	var t1 = tile1.animate_swap_to(board.grid_to_world_position(Vector2(x2, y2)))
	var t2 = tile2.animate_swap_to(board.grid_to_world_position(Vector2(x1, y1)))
	tiles_ref[x1][y1] = tile2
	tiles_ref[x2][y2] = tile1
	tile1.grid_position = Vector2(x2, y2)
	tile2.grid_position = Vector2(x1, y1)
	if t1: await t1.finished
	if t2: await t2.finished
	board._check_collectibles_at_bottom()
	if GameManager.find_matches().size() > 0:
		await board.process_cascade()
	GameManager.processing_moves = false

static func activate_chain_reaction_booster(board: Node, BS, x: int, y: int) -> void:
	if not RewardManager.use_booster("chain_reaction"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_chain")
	if GameManager.is_cell_blocked(x, y) or GameManager.get_tile_at(Vector2(x, y)) == GameManager.COLLECTIBLE:
		GameManager.processing_moves = false
		return
	# Compute 3-wave expanding ring inline
	var waves: Array = [[], [], []]
	waves[0] = [Vector2(x, y)]
	var dirs = [Vector2(-1,0), Vector2(1,0), Vector2(0,-1), Vector2(0,1)]
	var ring2 = []
	for d in dirs:
		var nx = x + int(d.x)
		var ny = y + int(d.y)
		if nx >= 0 and nx < GameManager.GRID_WIDTH and ny >= 0 and ny < GameManager.GRID_HEIGHT:
			ring2.append(Vector2(nx, ny))
	waves[1] = ring2
	var ring3 = []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if abs(dx) + abs(dy) == 2:
				var nx2 = x + dx
				var ny2 = y + dy
				if nx2 >= 0 and nx2 < GameManager.GRID_WIDTH and ny2 >= 0 and ny2 < GameManager.GRID_HEIGHT:
					ring3.append(Vector2(nx2, ny2))
	waves[2] = ring3

	var total_scoring = 0
	for wave in waves:
		if wave.size() == 0:
			continue
		var valid = wave.filter(func(p): return not GameManager.is_cell_blocked(int(p.x), int(p.y)) and GameManager.get_tile_at(p) > 0 and GameManager.get_tile_at(p) != GameManager.COLLECTIBLE)
		if valid.size() == 0:
			continue
		await board.highlight_special_activation(valid)
		await board.animate_destroy_tiles(valid)
		for pos in valid:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0
			total_scoring += 1
		await board.get_tree().create_timer(0.3).timeout
	var pts = GameManager.calculate_points(total_scoring)
	if pts > 0: GameManager.add_score(pts)
	await board.animate_gravity()
	await board.animate_refill()
	await board.process_cascade()
	GameManager.processing_moves = false

static func activate_bomb_3x3_booster(board: Node, BS, x: int, y: int) -> void:
	if not RewardManager.use_booster("bomb_3x3"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_bomb_3x3")
	if GameManager.is_cell_blocked(x, y):
		GameManager.processing_moves = false
		return
	var positions = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < GameManager.GRID_WIDTH and ny >= 0 and ny < GameManager.GRID_HEIGHT:
				if not GameManager.is_cell_blocked(nx, ny) and GameManager.get_tile_at(Vector2(nx, ny)) != GameManager.COLLECTIBLE:
					positions.append(Vector2(nx, ny))
	if positions.size() > 0:
		await execute_board_action(board, positions)
	GameManager.processing_moves = false

static func activate_line_blast_booster(board: Node, BS, direction: String, center_x: int, center_y: int) -> void:
	if not RewardManager.use_booster("line_blast"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_line")
	var positions = []
	for offset in range(-1, 2):
		if direction == "horizontal":
			var ty = center_y + offset
			if ty >= 0 and ty < GameManager.GRID_HEIGHT:
				for cx in range(GameManager.GRID_WIDTH):
					if not GameManager.is_cell_blocked(cx, ty) and GameManager.get_tile_at(Vector2(cx, ty)) != GameManager.COLLECTIBLE:
						positions.append(Vector2(cx, ty))
				board._create_lightning_beam_horizontal(ty, Color(1.0, 0.9, 0.2))
				await board.get_tree().create_timer(0.05).timeout
		else:
			var tx = center_x + offset
			if tx >= 0 and tx < GameManager.GRID_WIDTH:
				for cy in range(GameManager.GRID_HEIGHT):
					if not GameManager.is_cell_blocked(tx, cy) and GameManager.get_tile_at(Vector2(tx, cy)) != GameManager.COLLECTIBLE:
						positions.append(Vector2(tx, cy))
				board._create_lightning_beam_vertical(tx, Color(0.4, 0.9, 1.0))
				await board.get_tree().create_timer(0.05).timeout
	if positions.size() > 0:
		await execute_board_action(board, positions)
	GameManager.processing_moves = false

static func activate_hammer_booster(board: Node, x: int, y: int) -> void:
	if not RewardManager.use_booster("hammer"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_hammer")
	if GameManager.is_cell_blocked(x, y) or GameManager.get_tile_at(Vector2(x, y)) == GameManager.COLLECTIBLE:
		GameManager.processing_moves = false
		return
	await execute_board_action(board, [Vector2(x, y)])
	GameManager.processing_moves = false

static func activate_tile_squasher_booster(board: Node, BS, x: int, y: int) -> void:
	if not RewardManager.use_booster("tile_squasher"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_tile_squasher")
	var target_type = GameManager.get_tile_at(Vector2(x, y))
	if GameManager.is_cell_blocked(x, y) or target_type == GameManager.COLLECTIBLE or target_type >= 7:
		GameManager.processing_moves = false
		return
	var positions = []
	for gx in range(GameManager.GRID_WIDTH):
		for gy in range(GameManager.GRID_HEIGHT):
			if GameManager.get_tile_at(Vector2(gx, gy)) == target_type and not GameManager.is_cell_blocked(gx, gy):
				positions.append(Vector2(gx, gy))
	if positions.size() > 0:
		await execute_board_action(board, positions)
	GameManager.processing_moves = false

static func activate_row_clear_booster(board: Node, BS, tiles_ref: Array, row: int) -> void:
	if not RewardManager.use_booster("row_clear"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_row_clear")
	var positions = []
	for cx in range(GameManager.GRID_WIDTH):
		if not GameManager.is_cell_blocked(cx, row) and GameManager.get_tile_at(Vector2(cx, row)) != GameManager.COLLECTIBLE:
			positions.append(Vector2(cx, row))
	if positions.size() > 0:
		board._create_lightning_beam_horizontal(row, Color(1.0, 1.0, 0.3))
		await board.get_tree().create_timer(0.02).timeout
		board._create_lightning_beam_horizontal(row, Color(1.0, 0.8, 0.0))
		for cx in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(cx, row):
				board._create_impact_particles(board.grid_to_world_position(Vector2(cx, row)), Color.YELLOW)
		await execute_line_clear(board, positions, tiles_ref)
	GameManager.processing_moves = false

static func activate_column_clear_booster(board: Node, BS, tiles_ref: Array, column: int) -> void:
	if not RewardManager.use_booster("column_clear"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_column_clear")
	var positions = []
	for cy in range(GameManager.GRID_HEIGHT):
		if not GameManager.is_cell_blocked(column, cy) and GameManager.get_tile_at(Vector2(column, cy)) != GameManager.COLLECTIBLE:
			positions.append(Vector2(column, cy))
	if positions.size() > 0:
		board._create_lightning_beam_vertical(column, Color(0.3, 0.8, 1.0))
		await board.get_tree().create_timer(0.02).timeout
		board._create_lightning_beam_vertical(column, Color(0.5, 1.0, 1.0))
		for cy in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(column, cy):
				board._create_impact_particles(board.grid_to_world_position(Vector2(column, cy)), Color.CYAN)
		await execute_line_clear(board, positions, tiles_ref)
	GameManager.processing_moves = false

# ── Special tile activation ───────────────────────────────────────────────────

static func activate_special_tile(board: Node, pos: Vector2) -> void:
	print("[BoardActionExecutor] activate_special_tile at ", pos)
	var tile_type = GameManager.get_tile_at(pos)
	GameManager.processing_moves = true
	AudioManager.play_sfx("special_activate")

	EventBus.emit_special_tile_activated("tile_%d_%d" % [int(pos.x), int(pos.y)], {
		"position": pos, "tile_type": tile_type, "level": GameManager.level
	})

	var sas = load("res://scripts/game/SpecialActivationService.gd")
	var activation_result = {}
	if sas != null:
		activation_result = sas.call("compute_activation", pos, tile_type, GameManager.grid,
			GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT, GameManager.COLLECTIBLE)

	var positions_to_clear: Array = activation_result.get("positions", [])
	var special_tiles_to_activate: Array = activation_result.get("specials", [])

	if tile_type == GameManager.HORIZTONAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		board._create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.9, 0.3))
		await destroy_tiles_immediately(board, positions_to_clear)
	elif tile_type == GameManager.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		board._create_lightning_beam_vertical(int(pos.x), Color(0.4, 0.9, 1.0))
		await destroy_tiles_immediately(board, positions_to_clear)
	elif tile_type == GameManager.FOUR_WAY_ARROW:
		AudioManager.play_sfx("special_fourway")
		var horiz = positions_to_clear.filter(func(p): return p.y == pos.y)
		var vert  = positions_to_clear.filter(func(p): return p.x == pos.x and p.y != pos.y)
		board._create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.5, 1.0))
		await destroy_tiles_immediately(board, horiz)
		await board.get_tree().create_timer(0.05).timeout
		board._create_lightning_beam_vertical(int(pos.x), Color(1.0, 0.5, 1.0))
		await destroy_tiles_immediately(board, vert)

	if not GameManager.in_bonus_conversion:
		GameManager.use_move()

	for st in special_tiles_to_activate:
		AudioManager.play_sfx("booster_chain")
		await activate_special_tile_chain(board, st["pos"], st["type"])

	await board.animate_gravity()
	await board.animate_refill()
	await board.process_cascade()
	print("[BoardActionExecutor] activate_special_tile: complete")

static func activate_special_tile_chain(board: Node, pos: Vector2, tile_type: int) -> void:
	print("[BoardActionExecutor] chain at ", pos, " type ", tile_type)
	var sas = load("res://scripts/game/SpecialActivationService.gd")
	var chain_result = {}
	if sas != null:
		chain_result = sas.call("compute_chain_activation", pos, tile_type, GameManager.grid,
			GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT, GameManager.COLLECTIBLE)

	var positions_to_clear: Array = chain_result.get("positions", [])
	var chained_specials: Array   = chain_result.get("specials", [])

	if tile_type == GameManager.HORIZTONAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		board._create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.9, 0.3))
		await board.get_tree().create_timer(0.1).timeout
	elif tile_type == GameManager.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		board._create_lightning_beam_vertical(int(pos.x), Color(0.4, 0.9, 1.0))
		await board.get_tree().create_timer(0.1).timeout
	elif tile_type == GameManager.FOUR_WAY_ARROW:
		AudioManager.play_sfx("special_fourway")
		board._create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.5, 1.0))
		await board.get_tree().create_timer(0.05).timeout
		board._create_lightning_beam_vertical(int(pos.x), Color(1.0, 0.5, 1.0))
		await board.get_tree().create_timer(0.1).timeout

	await board.highlight_special_activation(positions_to_clear)
	await board.animate_destroy_tiles(positions_to_clear)

	var scoring_count = 0
	var tiles_ref = board.tiles
	for clear_pos in positions_to_clear:
		var t  = GameManager.get_tile_at(clear_pos)
		var gx = int(clear_pos.x)
		var gy = int(clear_pos.y)
		if not tiles_ref or gx >= tiles_ref.size() or not tiles_ref[gx] or gy >= tiles_ref[gx].size():
			continue
		var tile_instance = tiles_ref[gx][gy]
		if tile_instance and tile_instance.is_unmovable_hard:
			var destroyed = tile_instance.take_hit(1)
			if destroyed:
				if GameManager.has_method("report_unmovable_destroyed"):
					GameManager.report_unmovable_destroyed(clear_pos, true)
				var is_coll       = tile_instance.is_collectible if "is_collectible" in tile_instance else false
				var tile_type_chk = tile_instance.tile_type if "tile_type" in tile_instance else 0
				if is_coll:
					GameManager.grid[gx][gy] = GameManager.COLLECTIBLE
				elif tile_type_chk > 0:
					GameManager.grid[gx][gy] = tile_type_chk
				else:
					GameManager.grid[gx][gy] = 0
					if not tile_instance.is_queued_for_deletion(): tile_instance.queue_free()
					tiles_ref[gx][gy] = null
					scoring_count += 1
		else:
			if t == GameManager.SPREADER:
				GameManager.spreader_count -= 1
				GameManager.spreader_positions.erase(clear_pos)
			GameManager.grid[gx][gy] = 0
			scoring_count += 1

	if scoring_count > 0:
		GameManager.add_score(GameManager.calculate_points(scoring_count))

	for st in chained_specials:
		await activate_special_tile_chain(board, st["pos"], st["type"])

static func destroy_tiles_immediately(board: Node, positions: Array) -> void:
	## Destroy tiles after lightning beam — handles unmovables correctly.
	if positions.size() == 0:
		return

	await board.highlight_special_activation(positions)

	var scoring_count = 0
	for clear_pos in positions:
		var t = GameManager.get_tile_at(clear_pos)
		if t > 0 and t != GameManager.COLLECTIBLE:
			scoring_count += 1

	await board.animate_destroy_tiles(positions)

	var tiles_ref = board.tiles
	for clear_pos in positions:
		var t  = GameManager.get_tile_at(clear_pos)
		var gx = int(clear_pos.x)
		var gy = int(clear_pos.y)

		var tile_instance = null
		if tiles_ref and gx < tiles_ref.size() and tiles_ref[gx] and gy < tiles_ref[gx].size():
			tile_instance = tiles_ref[gx][gy]

		if not tile_instance or not is_instance_valid(tile_instance):
			if t == GameManager.SPREADER:
				if GameManager.has_method("report_spreader_destroyed"):
					GameManager.report_spreader_destroyed(clear_pos)
				else:
					GameManager.spreader_count -= 1
					GameManager.spreader_positions.erase(clear_pos)
			GameManager.grid[gx][gy] = 0
			continue

		if "is_unmovable_hard" in tile_instance and tile_instance.is_unmovable_hard:
			var destroyed = tile_instance.take_hit(1)
			if destroyed:
				if GameManager.has_method("report_unmovable_destroyed"):
					GameManager.report_unmovable_destroyed(clear_pos, true)
				var is_coll       = tile_instance.is_collectible if "is_collectible" in tile_instance else false
				var tile_type_chk = tile_instance.tile_type if "tile_type" in tile_instance else 0
				if is_coll:
					GameManager.grid[gx][gy] = GameManager.COLLECTIBLE
				elif tile_type_chk > 0:
					GameManager.grid[gx][gy] = tile_type_chk
				else:
					GameManager.grid[gx][gy] = 0
					if not tile_instance.is_queued_for_deletion(): tile_instance.queue_free()
					tiles_ref[gx][gy] = null
		else:
			if t == GameManager.SPREADER:
				if GameManager.has_method("report_spreader_destroyed"):
					GameManager.report_spreader_destroyed(clear_pos)
				else:
					GameManager.spreader_count -= 1
					GameManager.spreader_positions.erase(clear_pos)
			GameManager.grid[gx][gy] = 0
			if tile_instance and not tile_instance.is_queued_for_deletion():
				tile_instance.queue_free()
			tiles_ref[gx][gy] = null

	if GameManager.use_spreader_objective:
		GameManager.emit_signal("spreaders_changed", GameManager.spreader_count)
		if GameManager.spreader_count == 0:
			if not GameManager.pending_level_complete and not GameManager.level_transitioning:
				GameManager._attempt_level_complete()

	if scoring_count > 0:
		GameManager.add_score(GameManager.calculate_points(scoring_count))
