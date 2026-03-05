extends Node
# GravityService — pure grid gravity and refill.
# Barrier-aware versions migrated from GameManager inline (Round 4 refactor).
# API (all static):
#   apply_gravity(grid, gm) -> bool            -- uses gm for SPREADER/unmovable_map
#   fill_empty_spaces(grid, gm) -> Array       -- uses gm for dimensions, SPREADER/unmovable
#   apply_gravity_simple(grid, w, h) -> bool   -- legacy simple version (no barriers)
#   fill_empty_spaces_simple(grid, w, h, tile_types) -> Array  -- legacy simple version

## Barrier-aware gravity (canonical — matches GameManager inline logic exactly).
## Segments are bounded by: blocked(-1), hard-unmovable, and SPREADER cells.
static func apply_gravity(grid: Array, gm: Node) -> bool:
	var moved = false
	var grid_w = gm.GRID_WIDTH
	var grid_h = gm.GRID_HEIGHT
	for x in range(grid_w):
		var segment_start = -1
		var y = 0
		while y <= grid_h:
			var end_of_segment = (y == grid_h)
			var is_barrier = false
			if not end_of_segment:
				if grid[x][y] == -1 or gm._is_unmovable_cell(x, y) or grid[x][y] == gm.SPREADER:
					is_barrier = true
			if is_barrier or end_of_segment:
				if segment_start >= 0:
					var vals: Array = []
					for sy in range(y - 1, segment_start - 1, -1):
						var v = int(grid[x][sy])
						if v != 0:
							vals.append(v)
					var write_y = y - 1
					for val in vals:
						if grid[x][write_y] != val:
							moved = true
						grid[x][write_y] = val
						write_y -= 1
					for sy in range(write_y, segment_start - 1, -1):
						if grid[x][sy] != 0:
							moved = true
							grid[x][sy] = 0
				segment_start = -1
			else:
				if segment_start == -1:
					segment_start = y
			y += 1
	return moved

## Barrier-aware fill (canonical — matches GameManager inline logic exactly).
static func fill_empty_spaces(grid: Array, gm: Node) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var created_positions: Array = []
	var grid_w = gm.GRID_WIDTH
	var grid_h = gm.GRID_HEIGHT
	for x in range(grid_w):
		var segment_accessible := true
		var in_barrier_run := true
		for y in range(grid_h):
			if grid.size() <= x or grid[x].size() <= y:
				continue
			var cell = grid[x][y]
			var is_unmov = gm._is_unmovable_cell(x, y)
			var is_barrier_cell = is_unmov or (cell == -1) or (cell == gm.SPREADER)
			if is_barrier_cell:
				if not in_barrier_run:
					in_barrier_run = true
				segment_accessible = not (is_unmov or cell == gm.SPREADER)
			else:
				in_barrier_run = false
				if cell == 0 and segment_accessible:
					var tile_type = rng.randi_range(1, max(1, gm.TILE_TYPES))
					grid[x][y] = tile_type
					created_positions.append(Vector2(x, y))
	return created_positions

## Legacy simple apply_gravity (no unmovable/spreader barriers). Kept for backward compat.
static func apply_gravity_simple(grid: Array, grid_w: int, grid_h: int) -> bool:
	var moved = false
	for x in range(grid_w):
		var active_rows: Array = []
		for y in range(grid_h):
			if grid.size() > x and grid[x].size() > y and grid[x][y] != -1:
				active_rows.append(y)
		var column_vals: Array = []
		for i in range(active_rows.size() - 1, -1, -1):
			var y = active_rows[i]
			var v = int(grid[x][y])
			if v != 0:
				column_vals.append(v)
		var write_idx = active_rows.size() - 1
		for val in column_vals:
			var wy = active_rows[write_idx]
			if grid[x][wy] != val:
				moved = true
			grid[x][wy] = val
			write_idx -= 1
		for i in range(write_idx, -1, -1):
			var wy = active_rows[i]
			if grid[x][wy] != 0:
				moved = true
				grid[x][wy] = 0
	return moved


## Legacy simple fill (no barrier awareness). Kept for backward compat.
static func fill_empty_spaces_simple(grid: Array, grid_w: int, grid_h: int, tile_types: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var created_positions: Array = []
	for x in range(grid_w):
		for y in range(grid_h):
			if grid.size() <= x or grid[x].size() <= y:
				if grid.size() <= x:
					grid.append([])
				while grid[x].size() <= y:
					grid[x].append(0)
			if grid[x][y] == 0:
				var tile_type = rng.randi_range(1, max(1, tile_types))
				grid[x][y] = tile_type
				created_positions.append(Vector2(x, y))
	return created_positions
