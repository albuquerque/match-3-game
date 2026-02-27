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
