extends Node
# MatchProcessor — pure data-model helper: clear matched tiles from grid, handle
# special tile detection, collectibles and unmovables.
# Loaded as a script resource (no class_name — avoids global name conflict with
# the GameManager instance variable of the same name).

static func process_matches(grid: Array, matches: Array, swapped_pos: Vector2, grid_w: int, grid_h: int, gm: Node) -> Dictionary:
	var out: Dictionary = {"tiles_removed": 0, "special_placed": null}
	if matches == null or matches.size() == 0:
		return out

	# Normalise input into Vector2 list and deduplicate
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

		# Collectible tile (coin / shard)
		if val == gm.COLLECTIBLE:
			gm.collectibles_collected += 1
			if gm.collectible_positions.has(p):
				gm.collectible_positions.erase(p)
			grid[gx][gy] = 0
			continue

		# Spreader tile
		if val == gm.SPREADER:
			gm.report_spreader_destroyed(p)
			grid[gx][gy] = 0
			tiles_removed += 1
			continue

		# Hard unmovable — report but let SpreaderService manage the visual
		var key: String = str(gx) + "," + str(gy)
		if gm.unmovable_map.has(key):
			gm.report_unmovable_destroyed(key, true)
			if int(grid[gx][gy]) == 0:
				continue

		# Preserve the swapped / special-spawn cell so caller can write the special type
		if swapped_pos.x >= 0 and swapped_pos.y >= 0 and int(swapped_pos.x) == gx and int(swapped_pos.y) == gy:
			if val > 0 and val != gm.COLLECTIBLE:
				tiles_removed += 1
			continue

		# Regular tile — clear and count
		if val > 0 and val != gm.COLLECTIBLE:
			tiles_removed += 1
		grid[gx][gy] = 0

	out["tiles_removed"] = tiles_removed

	# Detect if the match qualifies for a special tile and register the best position
	if unique.size() >= 4 or _is_L_or_T(unique, grid_w, grid_h):
		var best_pos: Vector2 = Vector2(-1, -1)
		var best_score: int = -1
		for p in unique:
			var h: int = _run(unique, p, true, grid_w)
			var v: int = _run(unique, p, false, grid_h)
			var score: int = h + v
			if swapped_pos.x >= 0 and int(p.x) == int(swapped_pos.x) and int(p.y) == int(swapped_pos.y):
				score += 10
			if score > best_score:
				best_score = score
				best_pos = p
		if best_pos.x >= 0:
			gm.request_special_tile_creation(best_pos, "auto")

	return out

# ---------------------------------------------------------------------------

static func resolve_special_tile(req: Dictionary, unique: Array, grid: Array, gm: Node) -> int:
	if not (req is Dictionary) or not req.has("pos"):
		return -1
	var rpos = req["pos"]
	if rpos == null or rpos.x < 0 or rpos.y < 0:
		return -1

	var sf = gm.SpecialFactory
	if sf == null:
		sf = load("res://games/match3/board/services/SpecialFactory.gd")
		if sf:
			gm.SpecialFactory = sf
	if sf == null:
		return -1

	# Call determine_special_type directly — no has_method guard (static method)
	var special_type: int = sf.determine_special_type(
		unique, Vector2(int(rpos.x), int(rpos.y)),
		grid, gm.GRID_WIDTH, gm.GRID_HEIGHT, gm.MIN_MATCH_SIZE
	)
	if special_type != -1:
		if rpos.x >= 0 and rpos.x < gm.GRID_WIDTH and rpos.y >= 0 and rpos.y < gm.GRID_HEIGHT:
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
