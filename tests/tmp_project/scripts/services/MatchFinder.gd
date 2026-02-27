extends Node

# Minimal instance-based MatchFinder for isolated tests

func _is_matchable_helper(tile_type, exclude_values: Array, blocked_value: int) -> bool:
	if typeof(tile_type) != TYPE_INT:
		return false
	if tile_type <= 0:
		return false
	if tile_type == blocked_value:
		return false
	for ev in exclude_values:
		if tile_type == ev:
			return false
	return true

func find_matches(grid: Array, width: int, height: int, min_match_size: int = 3, exclude_values: Array = [], blocked_value: int = -1) -> Array:
	var matches: Array = []
	if grid == null or width <= 0 or height <= 0:
		return matches

	# Horizontal scan
	for y in range(height):
		var current_type = null
		var match_start = 0
		for x in range(width + 1):
			var tile_type = null
			if x < width:
				if grid.size() > x and grid[x].size() > y:
					tile_type = grid[x][y]
				else:
					tile_type = blocked_value
			else:
				tile_type = blocked_value

			var tile_matchable = _is_matchable_helper(tile_type, exclude_values, blocked_value)
			var curr_matchable = _is_matchable_helper(current_type, exclude_values, blocked_value) if current_type != null else false

			if not tile_matchable and curr_matchable:
				if x - match_start >= min_match_size:
					for i in range(match_start, x):
						matches.append(Vector2(i, y))
				current_type = null
				match_start = x + 1
				continue

			if current_type == null:
				if tile_matchable:
					current_type = tile_type
					match_start = x
			else:
				if tile_matchable and tile_type == current_type:
					pass
				else:
					if x - match_start >= min_match_size:
						for i in range(match_start, x):
							matches.append(Vector2(i, y))
					if tile_matchable:
						current_type = tile_type
						match_start = x
					else:
						current_type = null
						match_start = x + 1

	# Vertical scan
	for x in range(width):
		var current_type = null
		var match_start = 0
		for y in range(height + 1):
			var tile_type = null
			if y < height:
				if grid.size() > x and grid[x].size() > y:
					tile_type = grid[x][y]
				else:
					tile_type = blocked_value
			else:
				tile_type = blocked_value

			var tile_matchable = _is_matchable_helper(tile_type, exclude_values, blocked_value)
			var curr_matchable = _is_matchable_helper(current_type, exclude_values, blocked_value) if current_type != null else false

			if not tile_matchable and curr_matchable:
				if y - match_start >= min_match_size:
					for i in range(match_start, y):
						matches.append(Vector2(x, i))
				current_type = null
				match_start = y + 1
				continue

			if current_type == null:
				if tile_matchable:
					current_type = tile_type
					match_start = y
			else:
				if tile_matchable and tile_type == current_type:
					pass
				else:
					if y - match_start >= min_match_size:
						for i in range(match_start, y):
							matches.append(Vector2(x, i))
					if tile_matchable:
						current_type = tile_type
						match_start = y
					else:
						current_type = null
						match_start = y + 1

	# Remove duplicates while preserving order
	var unique: Array = []
	for p in matches:
		var found = false
		for q in unique:
			if int(p.x) == int(q.x) and int(p.y) == int(q.y):
				found = true
				break
		if not found:
			unique.append(p)

	return unique
