extends Node
const _GQS = preload("res://games/match3/board/services/GridQueryService.gd")
const _MatchFinder = preload("res://games/match3/board/services/MatchFinder.gd")
const GameStateBridge = preload("res://games/match3/services/GameStateBridge.gd")

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
	var br = GameStateBridge
	var pts = 0
	if br != null:
		pts = br.calculate_points(positions.size())
	for pos in positions:
		GameRunState.grid[int(pos.x)][int(pos.y)] = 0
	if pts > 0:
		if br != null:
			br.add_score(pts)
	await board.animate_gravity()
	await board.animate_refill()
	if board.has_method("_check_collectibles_at_bottom"):
		await board._check_collectibles_at_bottom()
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
				GameRunState.grid[gx][gy] = 0
				if not tile_instance.is_queued_for_deletion():
					tile_instance.queue_free()
				tiles_ref[gx][gy] = null
				scoring_count += 1
		else:
			GameRunState.grid[gx][gy] = 0
			scoring_count += 1
	var pts = GameStateBridge.calculate_points(scoring_count)
	if pts > 0:
		GameStateBridge.add_score(pts)
	await board.animate_gravity()
	await board.animate_refill()
	if board.has_method("_check_collectibles_at_bottom"):
		await board._check_collectibles_at_bottom()
	await board.process_cascade()

# ── Booster executors ─────────────────────────────────────────────────────────

static func activate_shuffle_booster(board: Node) -> void:
	if not RewardManager.use_booster("shuffle"):
		return
	GameRunState.processing_moves = true
	AudioManager.play_sfx("booster_shuffle")
	if GameStateBridge.shuffle_until_moves_available():
		await board.animate_shuffle()
	GameRunState.processing_moves = false

static func activate_swap_booster(board: Node, tiles_ref: Array, x1: int, y1: int, x2: int, y2: int) -> void:
	if not RewardManager.use_booster("swap"):
		return
	GameRunState.processing_moves = true
	AudioManager.play_sfx("booster_swap")
	if _GQS.is_cell_blocked(null, x1, y1) or _GQS.is_cell_blocked(null, x2, y2):
		GameRunState.processing_moves = false
		return
	var tile1 = tiles_ref[x1][y1]
	var tile2 = tiles_ref[x2][y2]
	if not tile1 or not tile2:
		GameRunState.processing_moves = false
		return
	var temp = GameRunState.grid[x1][y1]
	GameRunState.grid[x1][y1] = GameRunState.grid[x2][y2]
	GameRunState.grid[x2][y2] = temp
	var t1 = tile1.animate_swap_to(board.grid_to_world_position(Vector2(x2, y2)))
	var t2 = tile2.animate_swap_to(board.grid_to_world_position(Vector2(x1, y1)))
	tiles_ref[x1][y1] = tile2
	tiles_ref[x2][y2] = tile1
	tile1.grid_position = Vector2(x2, y2)
	tile2.grid_position = Vector2(x1, y1)
	if t1: await t1.finished
	if t2: await t2.finished
	# Clear processing_moves BEFORE collectible check so CollectibleService can schedule
	# gravity+refill and attempt_level_complete immediately when a coin lands at the bottom row.
	GameRunState.processing_moves = false
	await board._check_collectibles_at_bottom()
	# Run gravity+refill to fill any cell left empty by a collected collectible.
	# (CollectibleService skips its own deferred_gravity_then_refill when processing_moves was true,
	# so we own the refill here for the booster path.)
	if board.has_method("animate_gravity"):
		await board.animate_gravity()
	if board.has_method("animate_refill"):
		await board.animate_refill()
	var exclude = [GameRunState.HORIZONTAL_ARROW, GameRunState.VERTICAL_ARROW, GameRunState.FOUR_WAY_ARROW, GameRunState.COLLECTIBLE, GameRunState.SPREADER, GameRunState.UNMOVABLE]
	if _MatchFinder.find_matches(GameRunState.grid, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.MIN_MATCH_SIZE, exclude, -1).size() > 0:
		await board.process_cascade()
	else:
		# No cascade — still check for level completion (objectives may have been met by the swap)
		GameStateBridge.attempt_level_complete()

static func activate_chain_reaction_booster(board: Node, BS, x: int, y: int) -> void:
	if not RewardManager.use_booster("chain_reaction"):
		return
	GameRunState.processing_moves = true
	AudioManager.play_sfx("booster_chain")
	if _GQS.is_cell_blocked(null, x, y) or _GQS.get_tile_at(null, Vector2(x, y)) == GameRunState.COLLECTIBLE:
		GameRunState.processing_moves = false
		return
	# Compute 3-wave expanding ring inline
	var waves: Array = [[], [], []]
	waves[0] = [Vector2(x, y)]
	var dirs = [Vector2(-1,0), Vector2(1,0), Vector2(0,-1), Vector2(0,1)]
	var ring2 = []
	for d in dirs:
		var nx = x + int(d.x)
		var ny = y + int(d.y)
		if nx >= 0 and nx < GameRunState.GRID_WIDTH and ny >= 0 and ny < GameRunState.GRID_HEIGHT:
			ring2.append(Vector2(nx, ny))
	waves[1] = ring2
	var ring3 = []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if abs(dx) + abs(dy) == 2:
				var nx2 = x + dx
				var ny2 = y + dy
				if nx2 >= 0 and nx2 < GameRunState.GRID_WIDTH and ny2 >= 0 and ny2 < GameRunState.GRID_HEIGHT:
					ring3.append(Vector2(nx2, ny2))
	waves[2] = ring3

	var total_scoring = 0
	for wave in waves:
		if wave.size() == 0:
			continue
		var valid = wave.filter(func(p): return not _GQS.is_cell_blocked(null, int(p.x), int(p.y)) and _GQS.get_tile_at(null, p) > 0 and _GQS.get_tile_at(null, p) != GameRunState.COLLECTIBLE)
		if valid.size() == 0:
			continue
		await board.highlight_special_activation(valid)
		await board.animate_destroy_tiles(valid)
		for pos in valid:
			GameRunState.grid[int(pos.x)][int(pos.y)] = 0
			total_scoring += 1
		await board.get_tree().create_timer(0.3).timeout
	var pts = GameStateBridge.calculate_points(total_scoring)
	if pts > 0: GameStateBridge.add_score(pts)
	await board.animate_gravity()
	await board.animate_refill()
	if board.has_method("_check_collectibles_at_bottom"):
		await board._check_collectibles_at_bottom()
	await board.process_cascade()
	GameRunState.processing_moves = false

static func activate_bomb_3x3_booster(board: Node, BS, x: int, y: int) -> void:
	if not RewardManager.use_booster("bomb_3x3"):
		return
	GameRunState.processing_moves = true
	AudioManager.play_sfx("booster_bomb_3x3")
	if _GQS.is_cell_blocked(null, x, y):
		GameRunState.processing_moves = false
		return
	var positions = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < GameRunState.GRID_WIDTH and ny >= 0 and ny < GameRunState.GRID_HEIGHT:
				if not _GQS.is_cell_blocked(null, nx, ny) and _GQS.get_tile_at(null, Vector2(nx, ny)) != GameRunState.COLLECTIBLE:
					positions.append(Vector2(nx, ny))
	if positions.size() > 0:
		await execute_board_action(board, positions)
	GameRunState.processing_moves = false

static func activate_line_blast_booster(board: Node, BS, direction: String, center_x: int, center_y: int) -> void:
	if not RewardManager.use_booster("line_blast"):
		return
	GameRunState.processing_moves = true
	AudioManager.play_sfx("booster_line")
	var positions = []
	for offset in range(-1, 2):
		if direction == "horizontal":
			var ty = center_y + offset
			if ty >= 0 and ty < GameRunState.GRID_HEIGHT:
				for cx in range(GameRunState.GRID_WIDTH):
					if not _GQS.is_cell_blocked(null, cx, ty) and _GQS.get_tile_at(null, Vector2(cx, ty)) != GameRunState.COLLECTIBLE:
						positions.append(Vector2(cx, ty))
				board._create_lightning_beam_horizontal(ty, Color(1.0, 0.9, 0.2))
				await board.get_tree().create_timer(0.05).timeout
		else:
			var tx = center_x + offset
			if tx >= 0 and tx < GameRunState.GRID_WIDTH:
				for cy in range(GameRunState.GRID_HEIGHT):
					if not _GQS.is_cell_blocked(null, tx, cy) and _GQS.get_tile_at(null, Vector2(tx, cy)) != GameRunState.COLLECTIBLE:
						positions.append(Vector2(tx, cy))
				board._create_lightning_beam_vertical(tx, Color(0.4, 0.9, 1.0))
				await board.get_tree().create_timer(0.05).timeout
	if positions.size() > 0:
		await execute_board_action(board, positions)
	GameRunState.processing_moves = false

static func activate_hammer_booster(board: Node, x: int, y: int) -> void:
	if not RewardManager.use_booster("hammer"):
		return
	GameRunState.processing_moves = true
	AudioManager.play_sfx("booster_hammer")
	if _GQS.is_cell_blocked(null, x, y) or _GQS.get_tile_at(null, Vector2(x, y)) == GameRunState.COLLECTIBLE:
		GameRunState.processing_moves = false
		return
	await execute_board_action(board, [Vector2(x, y)])
	GameRunState.processing_moves = false

static func activate_tile_squasher_booster(board: Node, BS, x: int, y: int) -> void:
	if not RewardManager.use_booster("tile_squasher"):
		return
	GameRunState.processing_moves = true
	AudioManager.play_sfx("booster_tile_squasher")
	var target_type = _GQS.get_tile_at(null, Vector2(x, y))
	if _GQS.is_cell_blocked(null, x, y) or target_type == GameRunState.COLLECTIBLE or target_type >= 7:
		GameRunState.processing_moves = false
		return
	var positions = []
	for gx in range(GameRunState.GRID_WIDTH):
		for gy in range(GameRunState.GRID_HEIGHT):
			if _GQS.get_tile_at(null, Vector2(gx, gy)) == target_type and not _GQS.is_cell_blocked(null, gx, gy):
				positions.append(Vector2(gx, gy))
	if positions.size() > 0:
		await execute_board_action(board, positions)
	GameRunState.processing_moves = false

static func activate_row_clear_booster(board: Node, BS, tiles_ref: Array, row: int) -> void:
	if not RewardManager.use_booster("row_clear"):
		return
	GameRunState.processing_moves = true
	AudioManager.play_sfx("booster_row_clear")
	var positions = []
	for cx in range(GameRunState.GRID_WIDTH):
		if not _GQS.is_cell_blocked(null, cx, row) and _GQS.get_tile_at(null, Vector2(cx, row)) != GameRunState.COLLECTIBLE:
			positions.append(Vector2(cx, row))
	if positions.size() > 0:
		board._create_lightning_beam_horizontal(row, Color(1.0, 1.0, 0.3))
		await board.get_tree().create_timer(0.02).timeout
		board._create_lightning_beam_horizontal(row, Color(1.0, 0.8, 0.0))
		for cx in range(GameRunState.GRID_WIDTH):
			if not _GQS.is_cell_blocked(null, cx, row):
				board._create_impact_particles(board.grid_to_world_position(Vector2(cx, row)), Color.YELLOW)
		await execute_line_clear(board, positions, tiles_ref)
	GameRunState.processing_moves = false

static func activate_column_clear_booster(board: Node, BS, tiles_ref: Array, column: int) -> void:
	if not RewardManager.use_booster("column_clear"):
		return
	GameRunState.processing_moves = true
	AudioManager.play_sfx("booster_column_clear")
	var positions = []
	for cy in range(GameRunState.GRID_HEIGHT):
		if not _GQS.is_cell_blocked(null, column, cy) and _GQS.get_tile_at(null, Vector2(column, cy)) != GameRunState.COLLECTIBLE:
			positions.append(Vector2(column, cy))
	if positions.size() > 0:
		board._create_lightning_beam_vertical(column, Color(0.3, 0.8, 1.0))
		await board.get_tree().create_timer(0.02).timeout
		board._create_lightning_beam_vertical(column, Color(0.5, 1.0, 1.0))
		for cy in range(GameRunState.GRID_HEIGHT):
			if not _GQS.is_cell_blocked(null, column, cy):
				board._create_impact_particles(board.grid_to_world_position(Vector2(column, cy)), Color.CYAN)
		await execute_line_clear(board, positions, tiles_ref)
	GameRunState.processing_moves = false

# ── Special tile activation ───────────────────────────────────────────────────

static func activate_special_tile(board: Node, pos: Vector2) -> void:
	print("[BoardActionExecutor] activate_special_tile at ", pos)
	# Prefer the visual Tile instance's tile_type if available (authoritative)
	var tile_type = _GQS.get_tile_at(null, pos)
	var tiles_ref = board.tiles if board and board.has_method("get_tiles") == false else board.tiles
	var tile_instance = null
	if tiles_ref and int(pos.x) >= 0 and int(pos.x) < tiles_ref.size() and tiles_ref[int(pos.x)] and int(pos.y) >= 0 and int(pos.y) < tiles_ref[int(pos.x)].size():
		tile_instance = tiles_ref[int(pos.x)][int(pos.y)]
		if tile_instance and "tile_type" in tile_instance:
			var inst_type = tile_instance.tile_type
			if inst_type != tile_type:
				print("[BoardActionExecutor] grid/stale mismatch at ", pos, ": grid=", tile_type, " visual=", inst_type, " — syncing grid to visual")
				GameRunState.grid[int(pos.x)][int(pos.y)] = inst_type
				tile_type = inst_type

	# Emit via GameStateBridge
	var _ctx = {"position": pos, "tile_type": tile_type, "level": GameRunState.level}
	if GameStateBridge != null:
		GameStateBridge.emit_special_tile_activated("tile_%d_%d" % [int(pos.x), int(pos.y)], _ctx)

	var sas = load("res://games/match3/board/services/SpecialActivationService.gd")
	var activation_result = {}
	if sas != null:
		activation_result = sas.call("compute_activation", pos, tile_type, GameRunState.grid,
			GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.COLLECTIBLE)

	var positions_to_clear: Array = activation_result.get("positions", [])
	var special_tiles_to_activate: Array = activation_result.get("specials", [])
	# Fallback: if activation service returned empty positions (due to stale grid or migration timing),
	# compute positions here to ensure special activation always affects intended cells.
	if positions_to_clear.size() == 0:
		print("[BoardActionExecutor] activation_result returned no positions — using fallback computation for tile_type=", tile_type, " pos=", pos)
		positions_to_clear = []
		if tile_type == GameRunState.HORIZONTAL_ARROW:
			for x in range(GameRunState.GRID_WIDTH):
				var y = int(pos.y)
				var val = _GQS.get_tile_at(null, Vector2(x, y))
				if val == -1 or val <= 0 or val == GameRunState.COLLECTIBLE:
					continue
				positions_to_clear.append(Vector2(x, y))
		elif tile_type == GameRunState.VERTICAL_ARROW:
			for y in range(GameRunState.GRID_HEIGHT):
				var x = int(pos.x)
				var val = _GQS.get_tile_at(null, Vector2(x, y))
				if val == -1 or val <= 0 or val == GameRunState.COLLECTIBLE:
					continue
				positions_to_clear.append(Vector2(x, y))
		elif tile_type == GameRunState.FOUR_WAY_ARROW:
			for x in range(GameRunState.GRID_WIDTH):
				var y = int(pos.y)
				var valx = _GQS.get_tile_at(null, Vector2(x, y))
				if not (valx == -1 or valx <= 0 or valx == GameRunState.COLLECTIBLE):
					positions_to_clear.append(Vector2(x, y))
			for y in range(GameRunState.GRID_HEIGHT):
				var x = int(pos.x)
				var valy = _GQS.get_tile_at(null, Vector2(x, y))
				if not (valy == -1 or valy <= 0 or valy == GameRunState.COLLECTIBLE):
					var p = Vector2(x, y)
					if not positions_to_clear.has(p):
						positions_to_clear.append(p)

	if tile_type == GameRunState.HORIZONTAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		board._create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.9, 0.3))
		print("[BoardActionExecutor] HORIZONTAL activate: pos=", pos, " grid_val=", _GQS.get_tile_at(null,pos))
		print("[BoardActionExecutor] HORIZONTAL positions_to_clear count=", positions_to_clear.size(), " positions=", positions_to_clear)
		await destroy_tiles_immediately(board, positions_to_clear)
	elif tile_type == GameRunState.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		board._create_lightning_beam_vertical(int(pos.x), Color(0.4, 0.9, 1.0))
		print("[BoardActionExecutor] VERTICAL activate: pos=", pos, " grid_val=", _GQS.get_tile_at(null,pos))
		print("[BoardActionExecutor] VERTICAL positions_to_clear count=", positions_to_clear.size(), " positions=", positions_to_clear)
		await destroy_tiles_immediately(board, positions_to_clear)
	elif tile_type == GameRunState.FOUR_WAY_ARROW:
		AudioManager.play_sfx("special_fourway")
		var horiz = positions_to_clear.filter(func(p): return p.y == pos.y)
		var vert  = positions_to_clear.filter(func(p): return p.x == pos.x and p.y != pos.y)
		board._create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.5, 1.0))
		await destroy_tiles_immediately(board, horiz)
		await board.get_tree().create_timer(0.05).timeout
		board._create_lightning_beam_vertical(int(pos.x), Color(1.0, 0.5, 1.0))
		await destroy_tiles_immediately(board, vert)

	if not GameRunState.in_bonus_conversion:
		GameStateBridge.use_move()

	for st in special_tiles_to_activate:
		AudioManager.play_sfx("booster_chain")
		await activate_special_tile_chain(board, st["pos"], st["type"])

	await board.animate_gravity()
	await board.animate_refill()
	if board.has_method("_check_collectibles_at_bottom"):
		await board._check_collectibles_at_bottom()
	await board.process_cascade()
	GameRunState.processing_moves = false
	print("[BoardActionExecutor] activate_special_tile: complete")

static func activate_special_tile_chain(board: Node, pos: Vector2, tile_type: int) -> void:
	print("[BoardActionExecutor] chain at ", pos, " type ", tile_type)
	var sas = load("res://games/match3/board/services/SpecialActivationService.gd")
	var chain_result = {}
	if sas != null:
		chain_result = sas.call("compute_chain_activation", pos, tile_type, GameRunState.grid,
			GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.COLLECTIBLE)

	var positions_to_clear: Array = chain_result.get("positions", [])
	var chained_specials: Array   = chain_result.get("specials", [])

	if tile_type == GameRunState.HORIZONTAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		board._create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.9, 0.3))
		await board.get_tree().create_timer(0.1).timeout
	elif tile_type == GameRunState.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		board._create_lightning_beam_vertical(int(pos.x), Color(0.4, 0.9, 1.0))
		await board.get_tree().create_timer(0.1).timeout
	elif tile_type == GameRunState.FOUR_WAY_ARROW:
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
		var t  = _GQS.get_tile_at(null, clear_pos)
		var gx = int(clear_pos.x)
		var gy = int(clear_pos.y)
		if not tiles_ref or gx >= tiles_ref.size() or not tiles_ref[gx] or gy >= tiles_ref[gx].size():
			continue
		var tile_instance = tiles_ref[gx][gy]
		if tile_instance and tile_instance.is_unmovable_hard:
			var destroyed = tile_instance.take_hit(1)
			if destroyed:
				# Notify via bridge
				GameStateBridge.report_unmovable_destroyed(clear_pos, true)
				var is_coll       = tile_instance.is_collectible if "is_collectible" in tile_instance else false
				var tile_type_chk = tile_instance.tile_type if "tile_type" in tile_instance else 0
				if is_coll:
					GameRunState.grid[gx][gy] = GameRunState.COLLECTIBLE
				elif tile_type_chk > 0:
					GameRunState.grid[gx][gy] = tile_type_chk
				else:
					GameRunState.grid[gx][gy] = 0
					if not tile_instance.is_queued_for_deletion(): tile_instance.queue_free()
					tiles_ref[gx][gy] = null
		else:
			if t == GameRunState.SPREADER:
				GameRunState.spreader_count -= 1
				GameRunState.spreader_positions.erase(clear_pos)
			GameRunState.grid[gx][gy] = 0
			scoring_count += 1

	if scoring_count > 0:
		GameStateBridge.add_score(GameStateBridge.calculate_points(scoring_count))

	for st in chained_specials:
		await activate_special_tile_chain(board, st["pos"], st["type"])

static func destroy_tiles_immediately(board: Node, positions: Array) -> void:
	## Destroy tiles after lightning beam — handles unmovables correctly.
	if positions.size() == 0:
		return
	print("[BoardActionExecutor] destroy_tiles_immediately called; positions_count=", positions.size())

	# Local tiles reference used for visual instance checks
	var tiles_ref = board.tiles if board and board.has_method("get_tiles") == false else board.tiles

	# Count scoring-worthy tiles before animations
	var scoring_count = 0
	for clear_pos in positions:
		var t = _GQS.get_tile_at(null, clear_pos)
		if t > 0 and t != GameRunState.COLLECTIBLE:
			scoring_count += 1

	await board.highlight_special_activation(positions)

	for clear_pos in positions:
		var t = _GQS.get_tile_at(null, clear_pos)
		print("[BoardActionExecutor] destroying pos=", clear_pos, " grid_val=", t)
		var gx = int(clear_pos.x)
		var gy = int(clear_pos.y)

		var tile_instance = null
		if tiles_ref and gx < tiles_ref.size() and tiles_ref[gx] and gy < tiles_ref[gx].size():
			tile_instance = tiles_ref[gx][gy]

		if not tile_instance or not is_instance_valid(tile_instance):
			if t == GameRunState.SPREADER:
				# Use bridge to report spreader destroyed
				GameStateBridge.report_spreader_destroyed(clear_pos)
			GameRunState.grid[gx][gy] = 0
			print("[BoardActionExecutor] cleared grid at ", gx, ",", gy, " (no tile instance or invalid). New val=", GameRunState.grid[gx][gy])
			continue

		if "is_unmovable_hard" in tile_instance and tile_instance.is_unmovable_hard:
			var destroyed = tile_instance.take_hit(1)
			if destroyed:
				# Notify via bridge
				GameStateBridge.report_unmovable_destroyed(clear_pos, true)
				var is_coll       = tile_instance.is_collectible if "is_collectible" in tile_instance else false
				var tile_type_chk = tile_instance.tile_type if "tile_type" in tile_instance else 0
				if is_coll:
					GameRunState.grid[gx][gy] = GameRunState.COLLECTIBLE
					print("[BoardActionExecutor] unmovable destroyed -> became collectible at ", gx, ",", gy)
				elif tile_type_chk > 0:
					GameRunState.grid[gx][gy] = tile_type_chk
					print("[BoardActionExecutor] unmovable destroyed -> became tile_type ", tile_type_chk, " at ", gx, ",", gy)
				else:
					GameRunState.grid[gx][gy] = 0
					print("[BoardActionExecutor] unmovable destroyed -> cleared grid at ", gx, ",", gy)
					if not tile_instance.is_queued_for_deletion(): tile_instance.queue_free()
					tiles_ref[gx][gy] = null
			else:
				print("[BoardActionExecutor] unmovable_hit NOT destroyed at ", gx, ",", gy, " remaining hard_hits=", tile_instance.hard_hits if "hard_hits" in tile_instance else "?" )
				# unmovable not destroyed - leave grid value as-is (hard tile still blocks)
				continue
		else:
			if t == GameRunState.SPREADER:
				GameStateBridge.report_spreader_destroyed(clear_pos)
			GameRunState.grid[gx][gy] = 0
			print("[BoardActionExecutor] cleared grid at ", gx, ",", gy, " (normal clear). New val=", GameRunState.grid[gx][gy])
			if tile_instance and not tile_instance.is_queued_for_deletion():
				tile_instance.queue_free()
			tiles_ref[gx][gy] = null

	if GameRunState.use_spreader_objective:
		# Prefer bridge emits; GameStateBridge will forward to any legacy owners if present
		GameStateBridge.emit_spreaders_changed(GameRunState.spreader_count)
		# Guard: only trigger completion when the board is initialized AND both the counter
		# AND the positions array confirm zero spreaders remain.  This prevents a premature
		# cascade when spreader_count is transiently 0 (e.g. before the layout places
		# spreaders, or mid-cascade between a destroy and the next spread step).
		if GameRunState.spreader_count == 0 and GameRunState.spreader_positions.size() == 0 \
				and GameRunState.initialized:
			if not GameRunState.pending_level_complete and not GameRunState.level_transitioning:
				GameStateBridge.attempt_level_complete()

	if scoring_count > 0:
		GameStateBridge.add_score(GameStateBridge.calculate_points(scoring_count))
