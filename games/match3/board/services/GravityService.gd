extends Node
# GravityService — pure grid gravity and refill.
# PR 6.5a: gm parameter replaced with GameRunState autoload references.

const _GQS = preload("res://games/match3/board/services/GridQueryService.gd")

## Barrier-aware gravity.
static func apply_gravity(grid: Array, gm: Node = null) -> bool:
	# gm kept as optional param for backward compat — ignored, uses GameRunState
	var moved = false
	var grid_w = GameRunState.GRID_WIDTH
	var grid_h = GameRunState.GRID_HEIGHT
	if GameRunState.VERBOSE_GRAVITY:
		print("[GravityService] apply_gravity START grid snapshot cols=%d rows=%d" % [grid_w, grid_h])
	for x in range(grid_w):
		# Optional per-column snapshot before
		if GameRunState.VERBOSE_GRAVITY:
			var col_before = []
			if grid.size() > x:
				for yy in range(grid_h):
					col_before.append(str(grid[x][yy]) if grid[x].size() > yy else "?")
			print("[GravityService] Column %d BEFORE: %s" % [x, ",".join(col_before)])
		var segment_start = -1
		var y = 0
		while y <= grid_h:
			var end_of_segment = (y == grid_h)
			var is_barrier = false
			if not end_of_segment:
				# Barriers for gravity: disabled cells (-1), hard unmovables, and SPREADER sentinels.
				# UNMOVABLE sentinel (11) and unmovable_map entries are gravity barriers while the
				# hard tile is still present. Once destroyed (grid==0, removed from unmovable_map),
				# the cell becomes a normal empty slot that gets refilled.
				var cell_val = GameRunState.grid[x][y] if (GameRunState.grid.size() > x and GameRunState.grid[x].size() > y) else 0
				if _GQS.is_cell_blocked(null, x, y) \
					or cell_val == GameRunState.UNMOVABLE \
					or cell_val == GameRunState.SPREADER \
					or GameRunState.unmovable_map.has(str(x) + "," + str(y)):
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
		# Optional per-column snapshot after
		if GameRunState.VERBOSE_GRAVITY:
			var col_after = []
			if grid.size() > x:
				for yy in range(grid_h):
					col_after.append(str(grid[x][yy]) if grid[x].size() > yy else "?")
			print("[GravityService] Column %d AFTER:  %s" % [x, ",".join(col_after)])
	if GameRunState.VERBOSE_GRAVITY:
		print("[GravityService] apply_gravity END moved=%s" % [str(moved)])
	return moved

## Barrier-aware fill.
static func fill_empty_spaces(grid: Array, gm: Node = null) -> Array:
	# gm kept as optional param for backward compat — ignored, uses GameRunState
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var created_positions: Array = []
	var grid_w = GameRunState.GRID_WIDTH
	var grid_h = GameRunState.GRID_HEIGHT
	if GameRunState.VERBOSE_GRAVITY:
		print("[GravityService] fill_empty_spaces START")
	for x in range(grid_w):
		var segment_accessible := true
		var in_barrier_run := true
		for y in range(grid_h):
			if grid.size() <= x or grid[x].size() <= y:
				continue
			var cell = grid[x][y]
			var is_unmov = _GQS.is_unmovable_cell(null, x, y)
			var is_barrier_cell = is_unmov or (cell == -1) or (cell == GameRunState.UNMOVABLE) or (cell == GameRunState.SPREADER)
			if is_barrier_cell:
				if not in_barrier_run:
					in_barrier_run = true
				segment_accessible = not (is_unmov or cell == GameRunState.SPREADER)
			else:
				in_barrier_run = false
				if cell == 0 and segment_accessible:
					# Pick a tile type that won't create a 3-in-a-row match
					var forbidden: Array = []
					# Check left two neighbours horizontally
					if x >= 2 and grid[x-1][y] == grid[x-2][y] and int(grid[x-1][y]) >= 1:
						forbidden.append(int(grid[x-1][y]))
					# Check above two neighbours vertically
					if y >= 2 and grid[x][y-1] == grid[x][y-2] and int(grid[x][y-1]) >= 1:
						forbidden.append(int(grid[x][y-1]))
					var tile_type = rng.randi_range(1, max(1, GameRunState.TILE_TYPES))
					var safety = 0
					while tile_type in forbidden and safety < GameRunState.TILE_TYPES:
						tile_type = rng.randi_range(1, max(1, GameRunState.TILE_TYPES))
						safety += 1
					grid[x][y] = tile_type
					created_positions.append(Vector2(x, y))
					if GameRunState.VERBOSE_GRAVITY:
						print("[GravityService] fill_empty_spaces: placed %d at (%d,%d) forbidden=%s" % [tile_type, x, y, str(forbidden)])
	if GameRunState.VERBOSE_GRAVITY:
		print("[GravityService] fill_empty_spaces END created=%d" % [created_positions.size()])
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
