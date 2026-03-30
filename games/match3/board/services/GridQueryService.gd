extends Node
# GridQueryService — pure stateless grid queries.
# PR 6.5a: gm parameter replaced with GameRunState autoload.
# gm kept as first param on all methods for backward compat with GameManager callers
# that pass `self` — the value is now ignored.

static func is_cell_blocked(gm, x: int, y: int) -> bool:
	if x < 0 or x >= GameRunState.GRID_WIDTH or y < 0 or y >= GameRunState.GRID_HEIGHT: return true
	if GameRunState.grid.size() <= x or GameRunState.grid[x].size() <= y: return true
	if GameRunState.grid[x][y] == -1: return true
	return GameRunState.unmovable_map.has(str(x) + "," + str(y))

static func is_valid_position(gm, pos: Vector2) -> bool:
	var x := int(pos.x); var y := int(pos.y)
	return not is_cell_blocked(gm, x, y)

static func are_adjacent(pos1: Vector2, pos2: Vector2) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

static func is_cell_movable(gm, x: int, y: int) -> bool:
	if x < 0 or x >= GameRunState.GRID_WIDTH or y < 0 or y >= GameRunState.GRID_HEIGHT:
		return false
	if GameRunState.grid.size() <= x or GameRunState.grid[x].size() <= y:
		return false
	var v = GameRunState.grid[x][y]
	if v == -1 or v == 0 or v == GameRunState.UNMOVABLE or v == GameRunState.SPREADER:
		return false
	# Check hard unmovable tile instances on the board
	var board = GameRunState.board_ref
	if board and board.tiles and x < board.tiles.size() and y < board.tiles[x].size():
		var tile = board.tiles[x][y]
		if tile and "is_unmovable_hard" in tile and tile.is_unmovable_hard:
			return false
	return true

static func can_swap(gm, pos1: Vector2, pos2: Vector2) -> bool:
	if not is_valid_position(gm, pos1) or not is_valid_position(gm, pos2):
		return false
	if not is_cell_movable(gm, int(pos1.x), int(pos1.y)) or not is_cell_movable(gm, int(pos2.x), int(pos2.y)):
		return false
	return are_adjacent(pos1, pos2)

static func get_tile_at(gm, pos: Vector2) -> int:
	var gx := int(pos.x); var gy := int(pos.y)
	if gx < 0 or gx >= GameRunState.GRID_WIDTH or gy < 0 or gy >= GameRunState.GRID_HEIGHT: return -1
	if GameRunState.grid.size() <= gx or GameRunState.grid[gx].size() <= gy: return -1
	return int(GameRunState.grid[gx][gy])

static func is_unmovable_cell(gm, x: int, y: int) -> bool:
	return GameRunState.unmovable_map.has(str(x) + "," + str(y))

static func swap_tiles(pos1: Vector2, pos2: Vector2) -> void:
	## Raw grid swap — no validation. Callers must check can_swap first.
	var temp = GameRunState.grid[int(pos1.x)][int(pos1.y)]
	GameRunState.grid[int(pos1.x)][int(pos1.y)] = GameRunState.grid[int(pos2.x)][int(pos2.y)]
	GameRunState.grid[int(pos2.x)][int(pos2.y)] = temp

