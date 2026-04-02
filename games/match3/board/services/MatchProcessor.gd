extends Node
# MatchProcessor — pure data-model helper: clear matched tiles from grid, handle
# special tile detection, collectibles and unmovables.
# PR 6.5a: gm parameter replaced with GameRunState/GameManager autoloads.
# gm kept as param for backward compat — ignored.

const GAME_STATE_BRIDGE_PATH := "res://games/match3/services/GameStateBridge.gd"

static func process_matches(grid: Array, matches: Array, swapped_pos: Vector2, grid_w: int, grid_h: int, gm: Node = null) -> Dictionary:
	var out: Dictionary = {"tiles_removed": 0, "special_placed": null}
	if matches == null or matches.size() == 0:
		return out

	# Debug: snapshot small view
	if GameRunState.VERBOSE_GRAVITY:
		print("[MatchProcessor] process_matches START matches_count=", matches.size())
		var preview = []
		for cx in range(min(grid_w, 6)):
			var col = []
			for cy in range(min(grid_h, 6)):
				col.append(str(grid[cx][cy]) if grid.size() > cx and grid[cx].size() > cy else "?")
			preview.append("(" + ",".join(col) + ")")
		print("[MatchProcessor] Grid preview (first 6x6): ", preview)

	var unique: Array = []
	for m in matches:
		var p = m
		if typeof(m) == TYPE_DICTIONARY and m.has("x") and m.has("y"):
			p = Vector2(float(m["x"]), float(m["y"]))
		elif typeof(m) == TYPE_STRING:
			var parts: Array = m.split(",")
			if parts.size() == 2:
				p = Vector2(int(parts[0]), int(parts[1]))
		if typeof(p) != TYPE_VECTOR2:
			continue
		var ix: int = int(p.x)
		var iy: int = int(p.y)
		if ix < 0 or ix >= grid_w or iy < 0 or iy >= grid_h:
			continue
		var already: bool = false
		for q in unique:
			if int(q.x) == ix and int(q.y) == iy:
				already = true
				break
		if not already:
			unique.append(Vector2(ix, iy))

	var tiles_removed: int = 0
	for p in unique:
		var gx: int = int(p.x)
		var gy: int = int(p.y)
		var val: int = int(grid[gx][gy])

		# Debug: log what we're about to handle
		if GameRunState.VERBOSE_GRAVITY:
			print("[MatchProcessor] Handling pos=", gx, gy, " val=", val)

		# Collectible tile (coin / shard)
		if val == GameRunState.COLLECTIBLE:
			GameRunState.collectibles_collected += 1
			if GameRunState.collectible_positions.has(p):
				GameRunState.collectible_positions.erase(p)
			if GameRunState.VERBOSE_GRAVITY:
				print("[MatchProcessor] Clearing COLLECTIBLE at", gx, gy)
			grid[gx][gy] = 0
			continue

		# Spreader tile
		if val == GameRunState.SPREADER:
			# Prefer bridge to report spreader destruction
			var br = load(GAME_STATE_BRIDGE_PATH)
			if typeof(br) != TYPE_NIL and br != null and br.has_method("report_spreader_destroyed"):
				br.report_spreader_destroyed(p)
			else:
				# Fallback: update GameRunState directly — keep count AND positions in sync
				GameRunState.spreader_count = max(0, GameRunState.spreader_count - 1)
				GameRunState.spreader_positions.erase(p)
				if not GameRunState.spreaders_destroyed_this_turn.has(p):
					GameRunState.spreaders_destroyed_this_turn.append(p)
			if GameRunState.VERBOSE_GRAVITY:
				print("[MatchProcessor] Clearing SPREADER at", gx, gy)
			grid[gx][gy] = 0
			tiles_removed += 1
			continue

		# Hard unmovable — report but let BoardActionExecutor manage the visual
		var key: String = str(gx) + "," + str(gy)
		if GameRunState.unmovable_map.has(key):
			# Use bridge shim (load locally)
			var br2 = load(GAME_STATE_BRIDGE_PATH)
			if typeof(br2) != TYPE_NIL and br2 != null and br2.has_method("report_unmovable_destroyed"):
				br2.report_unmovable_destroyed(Vector2(gx, gy), true)
			else:
				# Fallback: emit on board_ref if present
				if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("unmovable_destroyed"):
					GameRunState.board_ref.emit_signal("unmovable_destroyed", Vector2(gx, gy))
			if GameRunState.VERBOSE_GRAVITY:
				print("[MatchProcessor] Unmovable reported at", gx, gy, "grid val before=", grid[gx][gy])
			# If grid is zero already, skip clearing; otherwise continue to allow other handling
			if int(grid[gx][gy]) == 0:
				continue

		# Preserve swapped / special-spawn cell so caller can write the special type
		if swapped_pos.x >= 0 and swapped_pos.y >= 0 and int(swapped_pos.x) == gx and int(swapped_pos.y) == gy:
			if val > 0 and val != GameRunState.COLLECTIBLE:
				tiles_removed += 1
			continue

		# Regular tile — clear and count
		if val > 0 and val != GameRunState.COLLECTIBLE:
			tiles_removed += 1
		if val > 0:
			if GameRunState.VERBOSE_GRAVITY:
				print("[MatchProcessor] Clearing regular tile at", gx, gy, "oldval=", val)
			grid[gx][gy] = 0

	out["tiles_removed"] = tiles_removed

	# Debug: final tiles_removed
	if GameRunState.VERBOSE_GRAVITY:
		print("[MatchProcessor] process_matches END tiles_removed=", tiles_removed)

	# NOTE: Special tile detection and creation is handled entirely by MatchOrchestrator
	# BEFORE process_matches is called. Do NOT run independent detection here — it
	# creates conflicting grid writes and phantom tile visuals.

	return out

# ---------------------------------------------------------------------------

static func resolve_special_tile(req: Dictionary, unique: Array, grid: Array, gm: Node = null) -> int:
	if not (req is Dictionary) or not req.has("pos"):
		return -1
	var rpos = req["pos"]
	if rpos == null or rpos.x < 0 or rpos.y < 0:
		return -1

	var sf = load("res://games/match3/board/services/SpecialFactory.gd")
	if sf == null:
		return -1

	var special_type: int = sf.determine_special_type(
		unique, Vector2(int(rpos.x), int(rpos.y)),
		grid, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.MIN_MATCH_SIZE
	)
	if special_type != -1:
		if rpos.x >= 0 and rpos.x < GameRunState.GRID_WIDTH and rpos.y >= 0 and rpos.y < GameRunState.GRID_HEIGHT:
			grid[int(rpos.x)][int(rpos.y)] = special_type
			return special_type
	return -1

# ---------------------------------------------------------------------------

static func _run(positions: Array, cell: Vector2, horiz: bool, limit: int) -> int:
	var lookup: Dictionary = {}
	for p in positions:
		lookup[str(int(p.x)) + "," + str(int(p.y))] = true
	var cx: int = int(cell.x)
	var cy: int = int(cell.y)
	var lo: int = cx if horiz else cy
	var hi: int = cx if horiz else cy
	while lo - 1 >= 0:
		var k: String = (str(lo - 1) + "," + str(cy)) if horiz else (str(cx) + "," + str(lo - 1))
		if not lookup.has(k):
			break
		lo -= 1
	while hi + 1 < limit:
		var k: String = (str(hi + 1) + "," + str(cy)) if horiz else (str(cx) + "," + str(hi + 1))
		if not lookup.has(k):
			break
		hi += 1
	return hi - lo + 1

static func _is_L_or_T(positions: Array, grid_w: int, grid_h: int) -> bool:
	for p in positions:
		if _run(positions, p, true, grid_w) >= 3 and _run(positions, p, false, grid_h) >= 3:
			return true
	return false
