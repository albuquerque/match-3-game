extends Node
class_name GravityService

# Pure grid gravity and refill helpers. These mutate the provided `grid` (Array of columns).
# API:
#   GravityService.apply_gravity(grid: Array, grid_w: int, grid_h: int) -> bool
#   GravityService.fill_empty_spaces(grid: Array, grid_w: int, grid_h: int, tile_types: int) -> Array

static func apply_gravity(grid: Array, grid_w: int, grid_h: int) -> bool:
	var moved = false
	for x in range(grid_w):
		# Build a list of active (non-blocked) row indices in this column, top to bottom
		var active_rows: Array = []
		for y in range(grid_h):
			if grid.size() > x and grid[x].size() > y and grid[x][y] != -1:
				active_rows.append(y)

		# Collect non-empty tile values from the active rows (bottom to top order)
		var column_vals: Array = []
		for i in range(active_rows.size() - 1, -1, -1):
			var y = active_rows[i]
			var v = int(grid[x][y])
			if v != 0:
				column_vals.append(v)

		# Write values back into active rows from the bottom up
		var write_idx = active_rows.size() - 1
		for val in column_vals:
			var wy = active_rows[write_idx]
			if grid[x][wy] != val:
				moved = true
			grid[x][wy] = val
			write_idx -= 1

		# Zero out remaining active rows at the top (tiles fell down)
		for i in range(write_idx, -1, -1):
			var wy = active_rows[i]
			if grid[x][wy] != 0:
				moved = true
				grid[x][wy] = 0
		# Note: inactive rows (-1) are never touched

	return moved

static func fill_empty_spaces(grid: Array, grid_w: int, grid_h: int, tile_types: int) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var created_positions: Array = []
	for x in range(grid_w):
		for y in range(grid_h):
			if grid.size() <= x or grid[x].size() <= y:
				# Ensure grid cell exists
				if grid.size() <= x:
					grid.append([])
				while grid[x].size() <= y:
					grid[x].append(0)
			# Only fill truly empty active cells — never fill inactive (-1) cells
			if grid[x][y] == 0:
				var tile_type = rng.randi_range(1, max(1, tile_types))
				grid[x][y] = tile_type
				created_positions.append(Vector2(x, y))
	return created_positions
