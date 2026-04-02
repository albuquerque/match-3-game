extends Node
# GameStateBridge — thin bridge to mutate GameRunState and emit signals to board_ref.
# All state reads/writes go through GameRunState.

const _MatchFinder = preload("res://scripts/services/MatchFinder.gd")
const _Spreader = preload("res://games/match3/board/services/SpreaderService.gd")
const _Scoring = preload("res://scripts/services/Scoring.gd")


static func use_move() -> void:
	# Clear the per-turn spreader immunity list at the start of each new move
	GameRunState.spreaders_destroyed_this_turn.clear()
	if GameRunState.moves_left > 0:
		GameRunState.moves_left -= 1
	emit_moves_changed(GameRunState.moves_left)
	if GameRunState.moves_left <= 0:
		GameRunState.pending_level_failed = true
		# Trigger level-failed check via GameFlowController after cascade completes
		# (MatchOrchestrator checks processing_moves before calling attempt_level_complete,
		#  so we hook in at the same point — after the cascade, via _get_gfc)
		var gfc = _get_gfc()
		if gfc != null:
			gfc.call_deferred("perform_level_failed_check")

static func reset_combo() -> void:
	GameRunState.combo_count = 0

static func calculate_points(tiles_removed: int) -> int:
	if tiles_removed <= 0:
		return 0
	# _Scoring is a preloaded script resource (RefCounted) that provides a static points_for method.
	# Calling has_method() on the Script resource causes a parse error, so just check for null and call.
	if _Scoring != null:
		return _Scoring.points_for(tiles_removed, GameRunState.combo_count)
	# fallback
	return int(tiles_removed * GameRunState.POINTS_PER_TILE * (1.0 + (0.1 * float(GameRunState.combo_count))))

static func add_score(points: int) -> void:
	if points == null or points <= 0:
		return
	GameRunState.score += int(points)
	# Preferred: emit score_changed on board_ref (true owner of board-level UI signals)
	emit_score_changed(GameRunState.score)

static func add_moves(n: int) -> void:
	# Increase moves by n and notify board_ref
	if n == null or n == 0:
		return
	GameRunState.moves_left += int(n)
	# Emit moves_changed so UI updates
	emit_moves_changed(GameRunState.moves_left)

static func has_possible_moves() -> bool:
	# Use MatchFinder to test swaps for possible moves
	var grid = GameRunState.grid
	if grid == null or GameRunState.GRID_WIDTH <= 0 or GameRunState.GRID_HEIGHT <= 0:
		return false
	var exclude = [GameRunState.COLLECTIBLE, GameRunState.SPREADER]
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			# Use GridQueryService availability
			var v:int = int(grid[x][y]) if grid.size() > x and grid[x].size() > y else -1
			if v < 1 or v > GameRunState.TILE_TYPES:
				continue
			# Try swap right
			if x + 1 < GameRunState.GRID_WIDTH:
				var v2 = int(grid[x+1][y])
				if v2 >= 1 and v2 <= GameRunState.TILE_TYPES and v != v2:
					var tg = _copy_grid(grid)
					var t = tg[x][y]; tg[x][y] = tg[x+1][y]; tg[x+1][y] = t
					if _MatchFinder.find_matches(tg, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.MIN_MATCH_SIZE, exclude, -1).size() > 0:
						return true
			# Try swap down
			if y + 1 < GameRunState.GRID_HEIGHT:
				var v3 = int(grid[x][y+1])
				if v3 >= 1 and v3 <= GameRunState.TILE_TYPES and v != v3:
					var tg2 = _copy_grid(grid)
					var t2 = tg2[x][y]; tg2[x][y] = tg2[x][y+1]; tg2[x][y+1] = t2
					if _MatchFinder.find_matches(tg2, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.MIN_MATCH_SIZE, exclude, -1).size() > 0:
						return true
	return false

static func _copy_grid(src_grid: Array) -> Array:
	var copy = []
	for cx in range(GameRunState.GRID_WIDTH):
		var col = []
		for cy in range(GameRunState.GRID_HEIGHT):
			var v = 0
			if src_grid.size() > cx and src_grid[cx].size() > cy:
				v = src_grid[cx][cy]
			col.append(v)
		copy.append(col)
	return copy

static func shuffle_until_moves_available(max_attempts: int = 100) -> bool:
	var cells: Array = []
	var values: Array = []
	var grid = GameRunState.grid
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			if grid.size() > x and grid[x].size() > y:
				var v = int(grid[x][y])
				if v >= 1 and v <= GameRunState.TILE_TYPES:
					cells.append(Vector2(x, y))
					values.append(v)
	if cells.size() == 0:
		return false
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for attempt in range(max_attempts):
		values.shuffle()
		for i in range(cells.size()):
			var p = cells[i]
			GameRunState.grid[int(p.x)][int(p.y)] = values[i]
		# Reject if existing matches present OR no valid swaps available
		var exclude = [GameRunState.COLLECTIBLE, GameRunState.SPREADER]
		if _MatchFinder.find_matches(GameRunState.grid, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.MIN_MATCH_SIZE, exclude, -1).size() == 0 and has_possible_moves():
			return true
	return false

static func check_and_spread_tiles() -> Array:
	# Delegate to SpreaderService (preloaded script resource). Avoid has_method() calls on script resources.
	if _Spreader == null:
		return []
	# If any spreader was destroyed this turn, block spreading entirely for this move.
	# Pass the destroyed positions as the immune list so SpreaderService skips those cells.
	var immune: Array = GameRunState.spreaders_destroyed_this_turn.duplicate()
	if immune.size() > 0:
		print("[GameStateBridge] Spreading blocked — %d spreader(s) destroyed this turn" % immune.size())
		# Clear the destroyed-this-turn list now that the move is complete
		GameRunState.spreaders_destroyed_this_turn.clear()
		return []
	var res = _Spreader.spread(GameRunState.spreader_positions, GameRunState.grid, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.spreader_spread_limit, GameRunState.spreader_type, immune)
	# Clear the destroyed-this-turn list after spreading
	GameRunState.spreaders_destroyed_this_turn.clear()
	if typeof(res) == TYPE_DICTIONARY and res.has("new_spreaders"):
		var new_list: Array = res["new_spreaders"]
		for np in new_list:
			if not GameRunState.spreader_positions.has(np):
				GameRunState.spreader_positions.append(np)
		GameRunState.spreader_count = GameRunState.spreader_positions.size()
		GameRunState.grid = res.get("grid", GameRunState.grid)
		# Notify via bridge (preferred) — consumers should listen to board_ref or GameStateBridge.emit_spreaders_changed
		emit_spreaders_changed(GameRunState.spreader_count)
		return new_list
	return []

static func skip_bonus_animation() -> void:
	# Migration: set the GameRunState flag and notify board_ref if available.
	GameRunState.bonus_skipped = true
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("bonus_skipped"):
		GameRunState.board_ref.emit_signal("bonus_skipped")

static func remove_matches(matches: Array, swapped_pos: Vector2 = Vector2(-1, -1)) -> int:
	# Migration: perform conservative grid clearing and attempt to free visuals via board_ref.
	# Callers should rely on MatchProcessor + GameRunState.
	var removed = 0
	for m in matches:
		var x = int(m.x); var y = int(m.y)
		if x >= 0 and x < GameRunState.GRID_WIDTH and y >= 0 and y < GameRunState.GRID_HEIGHT:
			if GameRunState.grid.size() > x and GameRunState.grid[x].size() > y and GameRunState.grid[x][y] != 0:
				GameRunState.grid[x][y] = 0
				removed += 1
	# NOTE: Visual destruction is handled by animate_destroy_matches() BEFORE _clear_matches()
	# is called. Do NOT call _on_external_remove_matches here — it would destroy the
	# freshly-spawned refill tiles that were placed after animate_refill().
	return removed

static func report_unmovable_destroyed(pos, skip_clear: bool = false) -> void:
	var vec_pos: Vector2 = Vector2(-1, -1)
	if typeof(pos) == TYPE_STRING:
		var parts = pos.split(",")
		if parts.size() == 2:
			vec_pos = Vector2(int(parts[0]), int(parts[1]))
	elif typeof(pos) == TYPE_VECTOR2:
		vec_pos = pos
	if vec_pos.x < 0:
		return

	# Remove from unmovable_map so gravity can refill the cell
	var key = str(int(vec_pos.x)) + "," + str(int(vec_pos.y))
	if GameRunState.unmovable_map.has(key):
		GameRunState.unmovable_map.erase(key)
		print("[GameStateBridge] Removed unmovable_map entry %s" % key)

	# Clear grid cell so gravity fills it
	if not skip_clear:
		var gx = int(vec_pos.x); var gy = int(vec_pos.y)
		if gx >= 0 and gx < GameRunState.GRID_WIDTH and gy >= 0 and gy < GameRunState.GRID_HEIGHT:
			if GameRunState.grid.size() > gx and GameRunState.grid[gx].size() > gy:
				GameRunState.grid[gx][gy] = 0

	# Increment cleared counter and notify HUD
	GameRunState.unmovables_cleared += 1
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("unmovables_changed"):
		GameRunState.board_ref.emit_signal("unmovables_changed", GameRunState.unmovables_cleared, GameRunState.unmovable_target)

	# Emit destroyed event for visual/effect consumers
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("unmovable_destroyed"):
		GameRunState.board_ref.emit_signal("unmovable_destroyed", vec_pos)

static func report_spreader_destroyed(pos: Vector2) -> void:
	# Update GameRunState and notify via centralized emitter
	GameRunState.spreader_count = max(0, GameRunState.spreader_count - 1)
	GameRunState.spreader_positions.erase(pos)
	# Track destroyed position so spread is blocked this turn (immune list)
	if not GameRunState.spreaders_destroyed_this_turn.has(pos):
		GameRunState.spreaders_destroyed_this_turn.append(pos)
	# Notify interested parties
	emit_spreaders_changed(GameRunState.spreader_count)

static func collectible_landed_at(pos: Vector2, coll_type: String) -> void:
	# Notify the board/collectible service that a collectible landed at pos.
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("collectible_landed"):
		GameRunState.board_ref.emit_signal("collectible_landed", pos, coll_type)
	# Legacy fallback removed — CollectibleService does not expose on_collectible_landed; consumers should listen to board_ref signals.

static func spawn_level_collectibles() -> void:
	# Spawn level collectibles via CollectibleService or board_ref.
	var svc = load("res://games/match3/board/services/CollectibleService.gd")
	if svc != null and svc.has_method("spawn_level_collectibles"):
		svc.spawn_level_collectibles()
	elif GameRunState.board_ref != null and GameRunState.board_ref.has_method("spawn_level_collectibles"):
		GameRunState.board_ref.call_deferred("spawn_level_collectibles")

# Shims to centralize legacy emits and lifecycle hooks.
static func emit_special_tile_activated(name: String, ctx: Dictionary) -> void:
	# Prefer emitting on the board (true owner) if available
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("special_tile_activated"):
		GameRunState.board_ref.emit_signal("special_tile_activated", name, ctx)
	# Emit directly on board_ref (true signal owner)

static func emit_spreaders_changed(count: int) -> void:
	# Emit to board (true signal owner).
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("spreaders_changed"):
		GameRunState.board_ref.emit_signal("spreaders_changed", count)
	# Additionally, write to GameRunState so consumers using the state can read it
	GameRunState.spreader_count = count

static func _get_gfc():
	# Get or create the GameFlowController instance on the board
	var board = GameRunState.board_ref
	if board == null:
		return null
	var gfc = board.get_node_or_null("GameFlowController")
	if gfc == null:
		var gfc_script = load("res://games/match3/board/services/GameFlowController.gd")
		if gfc_script == null:
			return null
		gfc = gfc_script.new()
		gfc.name = "GameFlowController"
		gfc.setup()
		board.add_child(gfc)
	return gfc

static func attempt_level_complete() -> void:
	var gfc = _get_gfc()
	if gfc != null:
		gfc.attempt_level_complete()
	else:
		GameRunState.pending_level_complete = true

# Lifecycle emit shims
static func emit_moves_changed(moves: int) -> void:
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("moves_changed"):
		GameRunState.board_ref.emit_signal("moves_changed", moves)
	# Keep GameRunState authoritative
	GameRunState.moves_left = moves

static func emit_score_changed(score: int) -> void:
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("score_changed"):
		GameRunState.board_ref.emit_signal("score_changed", score)
	GameRunState.score = score

static func emit_level_complete() -> void:
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("level_complete"):
		GameRunState.board_ref.emit_signal("level_complete")
	# Mark GameRunState so other systems can observe
	GameRunState.pending_level_complete = true

static func emit_game_over() -> void:
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("game_over"):
		GameRunState.board_ref.emit_signal("game_over")
	GameRunState.pending_level_failed = true

static func emit_level_failed(level_id: String, ctx: Dictionary) -> void:
	# Store context in GameRunState so handlers can read it
	GameRunState.last_level_score = ctx.get("score", GameRunState.score)
	if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("level_failed"):
		GameRunState.board_ref.emit_signal("level_failed")
	GameRunState.pending_level_failed = true

static func emit_level_loaded_ctx(level_id: String, ctx: Dictionary) -> void:
	GameRunState.initialized = true
	print("[GameStateBridge] emit_level_loaded_ctx: level=", level_id)
	if GameRunState.board_ref == null:
		print("[GameStateBridge] emit_level_loaded_ctx: WARNING - board_ref is NULL")
		return
	# Emit level_loaded_ctx for narrative/shard/booster listeners
	if GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("level_loaded_ctx"):
		GameRunState.board_ref.emit_signal("level_loaded_ctx", level_id, ctx)
	# Emit level_loaded (no-arg) so HUDComponent._on_level_loaded fires and refreshes HUD
	if GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("level_loaded"):
		GameRunState.board_ref.emit_signal("level_loaded")
	# Trigger board visual setup
	if GameRunState.board_ref.has_method("_on_level_loaded"):
		GameRunState.board_ref.call_deferred("_on_level_loaded")
	# Also ensure visual grid creation is scheduled (compatibility with previous flows)
	if GameRunState.board_ref != null and GameRunState.board_ref.has_method("create_visual_grid"):
		print("[GameStateBridge] Scheduling create_visual_grid on board_ref")
		GameRunState.board_ref.call_deferred("create_visual_grid")
	# If board_ref is not yet available (race with GameBoard._ready), poll NodeResolvers for the GameBoard node and then call setup.
	if GameRunState.board_ref == null:
		print("[GameStateBridge] board_ref missing; will poll for GameBoard via NodeResolvers")
		var nr = load("res://scripts/helpers/node_resolvers.gd")
		var attempts = 0
		while attempts < 40:
			var candidate = null
			if nr != null:
				candidate = nr._get_board()
				if candidate != null:
					print("[GameStateBridge] Found GameBoard via NodeResolvers: ", candidate)
					GameRunState.board_ref = candidate
					if candidate.has_method("create_visual_grid"):
						candidate.call_deferred("create_visual_grid")
					if candidate.has_method("_on_level_loaded"):
						candidate.call_deferred("_on_level_loaded")
					return
			# wait 50ms using global SceneTree
			var _st2 = Engine.get_main_loop() as SceneTree
			if _st2:
				await _st2.create_timer(0.05).timeout
			else:
				pass
			attempts += 1
		print("[GameStateBridge] Polling for GameBoard timed out after attempts=", attempts)

static func initialize_game():
	# Initializer: resets state and loads level via LevelLoader.
	# Resets transient flags, invokes LevelLoader to populate GameRunState, and emits level_loaded_ctx.
	print("[GameStateBridge] initialize_game: start")
	GameRunState.score = 0
	GameRunState.combo_count = 0
	GameRunState.processing_moves = false
	GameRunState.level_transitioning = false
	GameRunState.pending_level_complete = false
	GameRunState.pending_level_failed = false
	GameRunState.in_bonus_conversion = false
	GameRunState.bonus_skipped = false
	GameRunState.collectibles_collected = 0
	# Instantiate LevelLoader and call load_level()
	var loader_script = load("res://games/match3/board/services/LevelLoader.gd")
	if loader_script == null:
		push_error("[GameStateBridge] initialize_game: LevelLoader script not found")
		return null
	var loader = loader_script.new()
	# await load_level() — returns true on success
	var res = loader.load_level()
	if typeof(res) == TYPE_OBJECT and res and res.get_class() == "GDScriptFunctionState":
		await res
	print("[GameStateBridge] initialize_game: LevelLoader.load_level returned, GameRunState.initialized=", GameRunState.initialized)
	# After level data applied, emit level_loaded_ctx
	var lvlid = "level_%d" % GameRunState.level
	var ctx = {"level": GameRunState.level, "target": GameRunState.target_score}
	print("[GameStateBridge] initialize_game: about to emit_level_loaded_ctx for ", lvlid)
	emit_level_loaded_ctx(lvlid, ctx)
	print("[GameStateBridge] initialize_game: emit_level_loaded_ctx completed")
	# Return success state
	return null
