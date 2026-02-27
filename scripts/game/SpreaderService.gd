extends Node
# SpreaderService — loaded as a script resource by GameManager, not instanced

# Handles spreader mechanics purely at data level
# spread(...) -> Dictionary {"new_spreaders": Array, "grid": Array}
static func spread(spreader_positions: Array, grid: Array, grid_w: int, grid_h: int, spread_limit: int = 0, spreader_type: String = "virus", immune_positions: Array = []) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var new_spreaders = []
	var attempted = 0
	for pos in spreader_positions:
		var x = int(pos.x)
		var y = int(pos.y)
		var dirs = [Vector2(-1,0), Vector2(1,0), Vector2(0,-1), Vector2(0,1)]
		dirs.shuffle()
		for d in dirs:
			if spread_limit > 0 and attempted >= spread_limit:
				break
			var nx = x + int(d.x)
			var ny = y + int(d.y)
			if nx < 0 or nx >= grid_w or ny < 0 or ny >= grid_h:
				continue
			# Skip blocked cells and existing spreaders/unmovables
			if grid[nx][ny] == -1 or grid[nx][ny] == 12:
				continue
			# Skip cells that were cleared as spreaders this turn (immune)
			if immune_positions.has(Vector2(nx, ny)):
				continue
			# Convert cell to spreader
			grid[nx][ny] = 12
			new_spreaders.append(Vector2(nx, ny))
			attempted += 1
			if spread_limit > 0 and attempted >= spread_limit:
				break

	return {"new_spreaders": new_spreaders, "grid": grid}
