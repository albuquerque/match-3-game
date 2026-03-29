extends Node
# GridQueryService — pure stateless grid queries extracted from GameManager (Round 4 refactor).
# All methods are static. Pass `gm` (GameManager node) to provide grid/dimension/map context.
# API:
#   is_cell_blocked(gm, x, y) -> bool
#   is_valid_position(gm, pos) -> bool
#   are_adjacent(pos1, pos2) -> bool
#   is_cell_movable(gm, x, y) -> bool
#   can_swap(gm, pos1, pos2) -> bool
#   get_tile_at(gm, pos) -> int
#   is_unmovable_cell(gm, x, y) -> bool

static func is_cell_blocked(gm: Node, x: int, y: int) -> bool:
	if x < 0 or x >= gm.GRID_WIDTH or y < 0 or y >= gm.GRID_HEIGHT:
		return true
	if gm.grid.size() <= x:
		return true
	if gm.grid[x].size() <= y:
		return true
	return gm.grid[x][y] == -1

static func is_valid_position(gm: Node, pos: Vector2) -> bool:
	if pos.x < 0 or pos.x >= gm.GRID_WIDTH or pos.y < 0 or pos.y >= gm.GRID_HEIGHT:
		return false
	return not is_cell_blocked(gm, int(pos.x), int(pos.y))

static func are_adjacent(pos1: Vector2, pos2: Vector2) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

static func is_cell_movable(gm: Node, x: int, y: int) -> bool:
	if x < 0 or x >= gm.GRID_WIDTH or y < 0 or y >= gm.GRID_HEIGHT:
		return false
	if gm.grid.size() <= x or gm.grid[x].size() <= y:
		return false
	var v = gm.grid[x][y]
	if v == -1 or v == 0 or v == gm.UNMOVABLE:
		return false
	if v == gm.SPREADER:
		return false
	# Check for hard unmovable tile instances on the board
	if gm.board_ref and gm.board_ref.tiles and x < gm.board_ref.tiles.size():
		if y < gm.board_ref.tiles[x].size():
			var tile = gm.board_ref.tiles[x][y]
			if tile and "is_unmovable_hard" in tile and tile.is_unmovable_hard:
				return false
	return true

static func can_swap(gm: Node, pos1: Vector2, pos2: Vector2) -> bool:
	if not is_valid_position(gm, pos1) or not is_valid_position(gm, pos2):
		return false
	if not is_cell_movable(gm, int(pos1.x), int(pos1.y)) or not is_cell_movable(gm, int(pos2.x), int(pos2.y)):
		return false
	return are_adjacent(pos1, pos2)

static func get_tile_at(gm: Node, pos: Vector2) -> int:
	var gx = int(pos.x)
	var gy = int(pos.y)
	if gx < 0 or gx >= gm.GRID_WIDTH or gy < 0 or gy >= gm.GRID_HEIGHT:
		return -1
	if gm.grid.size() <= gx or gm.grid[gx].size() <= gy:
		return -1
	return int(gm.grid[gx][gy])

static func is_unmovable_cell(gm: Node, x: int, y: int) -> bool:
	## Returns true if the cell holds a hard unmovable tile (tracked in unmovable_map).
	var key = str(x) + "," + str(y)
	return gm.unmovable_map.has(key)
