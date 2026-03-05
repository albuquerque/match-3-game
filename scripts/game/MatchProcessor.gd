extends Node
class_name MatchProcessor

# Pure logic helper to process matched tiles (data-model level). Does NOT touch visuals.
# API:
#   MatchProcessor.process_matches(grid, matches, swapped_pos, grid_w, grid_h, game_manager)
# Returns: Dictionary { tiles_removed: int, special_placed: Dictionary? }

static func process_matches(grid: Array, matches: Array, swapped_pos: Vector2, grid_w: int, grid_h: int, gm: Node) -> Dictionary:
	var out = {"tiles_removed": 0, "special_placed": null}
	if matches == null or matches.size() == 0:
		return out

	# Normalize matches into Vector2 list
	var norm = []
	for m in matches:
		var p = m
		if typeof(m) == TYPE_DICTIONARY and m.has("x") and m.has("y"):
			p = Vector2(float(m["x"]), float(m["y"]))
		elif typeof(m) == TYPE_STRING:
			var parts = m.split(",")
			if parts.size() == 2:
				p = Vector2(int(parts[0]), int(parts[1]))
		if typeof(p) == TYPE_VECTOR2 and p.x >= 0 and p.y >= 0:
			norm.append(Vector2(int(p.x), int(p.y)))

	# Remove duplicates and blocked
	var unique = []
	for p in norm:
		var found = false
		for q in unique:
			if int(p.x) == int(q.x) and int(p.y) == int(q.y):
				found = true
				break
		if not found:
			# check bounds
			if int(p.x) >= 0 and int(p.x) < grid_w and int(p.y) >= 0 and int(p.y) < grid_h:
				unique.append(p)

	# iterate and clear
	var tiles_removed = 0
	for p in unique:
		var gx = int(p.x)
		var gy = int(p.y)
		var val = grid[gx][gy]
		if val == gm.COLLECTIBLE:
			# Collectible handling
			gm.collectibles_collected += 1
			if gm.collectible_positions.has(p):
				gm.collectible_positions.erase(p)
			grid[gx][gy] = 0
			continue
		if val == gm.SPREADER:
			gm.report_spreader_destroyed(p)
			grid[gx][gy] = 0
			tiles_removed += 1
			continue
		var key = str(gx) + "," + str(gy)
		if gm.unmovable_map.has(key):
			gm.report_unmovable_destroyed(key, true)
			if grid[gx][gy] == 0:
				continue
		# preserve swapped_pos for potential special creation
		if swapped_pos.x >= 0 and swapped_pos.y >= 0 and int(swapped_pos.x) == gx and int(swapped_pos.y) == gy:
			if val > 0 and val != gm.COLLECTIBLE:
				tiles_removed += 1
			continue
		if val > 0 and val != gm.COLLECTIBLE:
			tiles_removed += 1
		grid[gx][gy] = 0

	# scoring handled by caller
	out["tiles_removed"] = tiles_removed

	# If swapped_pos participated, request special and let caller handle placement
	if swapped_pos.x >= 0 and swapped_pos.y >= 0:
		for p in unique:
			if int(p.x) == int(swapped_pos.x) and int(p.y) == int(swapped_pos.y):
				gm.request_special_tile_creation(swapped_pos, "auto")
				break

	return out

## Resolve a pending special-tile request using SpecialFactory and write it to the grid.
## Called by GameManager.remove_matches() after scoring/combo.
## Returns the special type placed (int), or -1 if none.
static func resolve_special_tile(req: Dictionary, unique: Array, grid: Array, gm: Node) -> int:
	if not (req is Dictionary) or not req.has("pos"):
		return -1
	var rpos = req["pos"]
	var rtype = req.get("type", "auto")
	if rpos == null or rpos.x < 0 or rpos.y < 0:
		return -1

	if rtype == "auto":
		var sf = gm.SpecialFactory
		if sf == null:
			sf = load("res://scripts/game/SpecialFactory.gd")
			if sf:
				gm.SpecialFactory = sf
		if sf == null:
			print("[MatchProcessor] SpecialFactory script failed to load")
			return -1
		var special_type = -1
		if sf.has_method("determine_special_type"):
			special_type = sf.determine_special_type(
				unique, Vector2(int(rpos.x), int(rpos.y)),
				grid, gm.GRID_WIDTH, gm.GRID_HEIGHT, gm.MIN_MATCH_SIZE
			)
		print("[MatchProcessor] SpecialFactory.determine_special_type -> ", special_type)
		if special_type != -1:
			if rpos.x >= 0 and rpos.x < gm.GRID_WIDTH and rpos.y >= 0 and rpos.y < gm.GRID_HEIGHT:
				grid[int(rpos.x)][int(rpos.y)] = int(special_type)
				print("[MatchProcessor] Special tile placed at ", rpos, " type=", special_type)
				return special_type
			else:
				print("[MatchProcessor] Warning: requested special pos out of bounds: ", rpos)
		else:
			print("[MatchProcessor] SpecialFactory found no special for pos ", rpos)
	else:
		print("[MatchProcessor] Explicit special type '", rtype, "' at ", rpos, " (future use)")
	return -1

