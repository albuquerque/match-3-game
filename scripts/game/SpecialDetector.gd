extends Node
class_name SpecialDetector

# Pure logic to detect special tile creation positions from a set of matched positions.
# API: SpecialDetector.find_special_position(matches: Array, grid_w: int, grid_h: int, min_match_size: int = 3) -> Vector2

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

static func find_special_position(matches: Array, grid_w: int, grid_h: int, min_match_size: int = 3) -> Vector2:
	var list = _to_vec2_list(matches)
	if list.size() < 4:
		return Vector2(-1, -1)

	# T/L shape detection: a tile that has 3+ in both row and column
	for test_pos in list:
		var matches_on_same_row = 0
		var matches_on_same_col = 0
		for m in list:
			if int(m.y) == int(test_pos.y):
				matches_on_same_row += 1
			if int(m.x) == int(test_pos.x):
				matches_on_same_col += 1
		if matches_on_same_row >= min_match_size and matches_on_same_col >= min_match_size:
			return Vector2(int(test_pos.x), int(test_pos.y))

	# 4+ horizontal
	var rows = {}
	for m in list:
		var ry = int(m.y)
		if not rows.has(ry):
			rows[ry] = []
		rows[ry].append(m)
	for ry in rows:
		if rows[ry].size() >= 4:
			var mid = int(rows[ry].size() / 2)
			var p = rows[ry][mid]
			return Vector2(int(p.x), int(p.y))

	# 4+ vertical
	var cols = {}
	for m in list:
		var cx = int(m.x)
		if not cols.has(cx):
			cols[cx] = []
		cols[cx].append(m)
	for cx in cols:
		if cols[cx].size() >= 4:
			var midc = int(cols[cx].size() / 2)
			var p2 = cols[cx][midc]
			return Vector2(int(p2.x), int(p2.y))

	# fallback: if 5+ unique tiles, return middle one
	if list.size() >= 5:
		var mididx = int(list.size() / 2)
		var pm = list[mididx]
		return Vector2(int(pm.x), int(pm.y))

	return Vector2(-1, -1)
