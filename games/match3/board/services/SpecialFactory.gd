extends Node
# SpecialFactory — determines which special tile type a match qualifies for.
# Loaded as a script resource via load() in MatchOrchestrator.
# NOTE: No class_name declared to avoid conflicts with variable names.
# API:
#   SpecialFactory.determine_special_type(matches, swapped_pos, grid, grid_w, grid_h, min_match_size=3) -> int
# Returns: HORIZ (7), VERT (8), FOUR (9) or -1 for none

const HORIZ = 7
const VERT = 8
const FOUR = 9

static func _to_vec2_list(matches: Array) -> Array:
	var out: Array = []
	if matches == null:
		return out
	for m in matches:
		var p = m
		if typeof(m) == TYPE_DICTIONARY and m.has("x") and m.has("y"):
			p = Vector2(float(m["x"]), float(m["y"]))
		elif typeof(m) == TYPE_STRING:
			var parts = m.split(",")
			if parts.size() == 2:
				p = Vector2(int(parts[0]), int(parts[1]))
		if typeof(p) == TYPE_VECTOR2:
			out.append(Vector2(int(p.x), int(p.y)))
	return out

static func _get_counts_from_maps(horiz: Dictionary, vert: Dictionary, kx: int, ky: int) -> Dictionary:
	var key = str(kx) + "," + str(ky)
	var h = 0
	var v = 0
	if horiz.has(key):
		h = int(horiz[key])
	if vert.has(key):
		v = int(vert[key])
	return {"h": h, "v": v}

static func determine_special_type(matches: Array, swapped_pos: Vector2, grid: Array, grid_w: int, grid_h: int, min_match_size: int = 3) -> int:
	var list = _to_vec2_list(matches)
	if list.size() == 0:
		return -1

	# build lookup set
	var set = {}
	for p in list:
		set[str(int(p.x)) + "," + str(int(p.y))] = true

	# compute runs for each matched cell
	var horiz = {}
	var vert = {}
	for p in list:
		var x = int(p.x)
		var y = int(p.y)
		# horizontal run
		var lx = x
		while lx - 1 >= 0 and set.has(str(lx - 1) + "," + str(y)):
			lx -= 1
		var rx = x
		while rx + 1 < grid_w and set.has(str(rx + 1) + "," + str(y)):
			rx += 1
		horiz[str(x) + "," + str(y)] = rx - lx + 1
		# vertical run
		var ty = y
		while ty - 1 >= 0 and set.has(str(x) + "," + str(ty - 1)):
			ty -= 1
		var by = y
		while by + 1 < grid_h and set.has(str(x) + "," + str(by + 1)):
			by += 1
		vert[str(x) + "," + str(y)] = by - ty + 1

	# prefer swapped_pos if part of matches
	if swapped_pos != null and swapped_pos.x >= 0 and swapped_pos.y >= 0:
		var sk = str(int(swapped_pos.x)) + "," + str(int(swapped_pos.y))
		if set.has(sk):
			var sc = _get_counts_from_maps(horiz, vert, int(swapped_pos.x), int(swapped_pos.y))
			if sc["h"] >= min_match_size and sc["v"] >= min_match_size:
				return FOUR
			if sc["h"] >= 4:
				return HORIZ
			if sc["v"] >= 4:
				return VERT

	# search for T/L
	for p in list:
		var c = _get_counts_from_maps(horiz, vert, int(p.x), int(p.y))
		if c["h"] >= min_match_size and c["v"] >= min_match_size:
			return FOUR

	# search for 4+ lines
	for p in list:
		var c = _get_counts_from_maps(horiz, vert, int(p.x), int(p.y))
		if c["h"] >= 4:
			return HORIZ
		if c["v"] >= 4:
			return VERT

	# fallback: large matches -> FOUR
	if list.size() >= 5:
		return FOUR

	return -1
