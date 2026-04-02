extends Node
const _GQS = preload("res://games/match3/board/services/GridQueryService.gd")

# Pure helper functions to compute positions affected by boosters.
# These work on grid coordinates and do not touch nodes or visuals.

static func bomb_3x3_positions(cx: int, cy: int, grid_w: int, grid_h: int) -> Array:
	var out = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var nx = cx + dx
			var ny = cy + dy
			if nx >= 0 and nx < grid_w and ny >= 0 and ny < grid_h:
				out.append(Vector2(nx, ny))
	return out

static func line_blast_positions(direction: String, center_x: int, center_y: int, grid_w: int, grid_h: int) -> Array:
	var out = []
	if direction == "horizontal":
		for row_offset in range(-1, 2):
			var y = center_y + row_offset
			if y >= 0 and y < grid_h:
				for x in range(grid_w):
					out.append(Vector2(x, y))
	elif direction == "vertical":
		for col_offset in range(-1, 2):
			var x = center_x + col_offset
			if x >= 0 and x < grid_w:
				for y in range(grid_h):
					out.append(Vector2(x, y))
	return out

static func chain_reaction_waves(cx: int, cy: int, grid_w: int, grid_h: int) -> Array:
	# Returns an array [wave1, wave2, wave3] where each wave is an Array of Vector2
	var wave1 = [Vector2(cx, cy)]
	var wave2 = []
	var wave3 = []
	var dirs = [Vector2(-1,0), Vector2(1,0), Vector2(0,-1), Vector2(0,1)]
	for d in dirs:
		var nx = cx + int(d.x)
		var ny = cy + int(d.y)
		if nx >= 0 and nx < grid_w and ny >= 0 and ny < grid_h:
			wave2.append(Vector2(nx, ny))
	# wave3: adjacent to wave2
	for pos in wave2:
		for d in dirs:
			var nx = int(pos.x) + int(d.x)
			var ny = int(pos.y) + int(d.y)
			if nx >= 0 and nx < grid_w and ny >= 0 and ny < grid_h:
				var p = Vector2(nx, ny)
				if not wave1.has(p) and not wave2.has(p) and not wave3.has(p):
					wave3.append(p)
	return [wave1, wave2, wave3]

static func tile_squasher_positions(target_type: int, grid: Array, grid_w: int, grid_h: int) -> Array:
	var out = []
	for x in range(grid_w):
		for y in range(grid_h):
			if grid[x][y] == target_type:
				out.append(Vector2(x, y))
	return out

static func row_clear_positions(row: int, grid_w: int, grid_h: int) -> Array:
	var out = []
	if row < 0 or row >= grid_h:
		return out
	for x in range(grid_w):
		out.append(Vector2(x, row))
	return out

static func column_clear_positions(col: int, grid_w: int, grid_h: int) -> Array:
	var out = []
	if col < 0 or col >= grid_w:
		return out
	for y in range(grid_h):
		out.append(Vector2(col, y))
	return out

static func _get_board() -> Node:
	# NodeResolvers is registered as an autoload — use it directly
	if NodeResolvers.has_method("_get_board"):
		var b = NodeResolvers._get_board()
		if b != null:
			return b
	# Next prefer explicit GameRunState board_ref (owner set by GameBoard._ready)
	if GameRunState.board_ref != null:
		return GameRunState.board_ref
	# fallback: try scene tree search
	var ml = Engine.get_main_loop()
	if ml != null and ml is SceneTree:
		var rt = ml.root
		if rt:
			return rt.get_node_or_null("GameBoard")
	return null

static var _Bridge = null
static func _get_bridge():
	if _Bridge == null:
		_Bridge = load("res://games/match3/services/GameStateBridge.gd")
	return _Bridge

static func activate_row_clear(row: int) -> void:
	print("[BoosterService] activate_row_clear:", row)
	var board = _get_board()
	if board and board.has_method("_create_row_clear_effect"):
		board._create_row_clear_effect(row)
	# Logic: clear all tiles in row
	var to_clear = []
	for x in range(GameRunState.GRID_WIDTH):
		if not _GQS.is_cell_blocked(null, x, row):
			to_clear.append(Vector2(x, row))
	var br = _get_bridge()
	if br != null:
		br.remove_matches(to_clear)

static func activate_column_clear(col: int) -> void:
	print("[BoosterService] activate_column_clear:", col)
	var board = _get_board()
	if board and board.has_method("_create_column_clear_effect"):
		board._create_column_clear_effect(col)
	var to_clear = []
	for y in range(GameRunState.GRID_HEIGHT):
		if not _GQS.is_cell_blocked(null, col, y):
			to_clear.append(Vector2(col, y))
	var br = _get_bridge()
	if br != null:
		br.remove_matches(to_clear)

static func activate_hammer(x: int, y: int) -> void:
	print("[BoosterService] activate_hammer at", x, y)
	var board = _get_board()
	if board and board.has_method("_create_impact_particles"):
		board._create_impact_particles(board.grid_to_world_position(Vector2(x,y)), Color(1,0.8,0.6))
	var br = _get_bridge()
	if br != null:
		br.remove_matches([Vector2(x,y)])

static func activate_bomb_3x3(x: int, y: int) -> void:
	print("[BoosterService] activate_bomb_3x3 at", x, y)
	var positions = []
	for dx in range(-1,2):
		for dy in range(-1,2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < GameRunState.GRID_WIDTH and ny >=0 and ny < GameRunState.GRID_HEIGHT and not _GQS.is_cell_blocked(null, nx, ny):
				positions.append(Vector2(nx, ny))
	var board = _get_board()
	if board and board.has_method("_create_impact_particles"):
		for p in positions:
			board._create_impact_particles(board.grid_to_world_position(p), Color(1,0.6,0.2))
	var br = _get_bridge()
	if br != null:
		br.remove_matches(positions)

static func activate_line_blast(direction: String, x: int, y: int) -> void:
	print("[BoosterService] activate_line_blast:", direction, x, y)
	var positions = []
	if direction == "horizontal":
		for cx in range(GameRunState.GRID_WIDTH):
			if not _GQS.is_cell_blocked(null, cx, y):
				positions.append(Vector2(cx, y))
	else:
		for cy in range(GameRunState.GRID_HEIGHT):
			if not _GQS.is_cell_blocked(null, x, cy):
				positions.append(Vector2(x, cy))
	var board = _get_board()
	if board:
		if direction == "horizontal":
			board._create_row_clear_effect(y)
		else:
			board._create_column_clear_effect(x)
	var br = _get_bridge()
	if br != null:
		br.remove_matches(positions)

static func activate_swap(x1: int, y1: int, x2: int, y2: int) -> void:
	print("[BoosterService] activate_swap:", x1, y1, x2, y2)
	_GQS.swap_tiles(Vector2(x1,y1), Vector2(x2,y2))

static func activate_shuffle() -> void:
	print("[BoosterService] activate_shuffle")
	var board = _get_board()
	# Prefer bridge shuffle logic for migration safety
	var br = _get_bridge()
	if br != null and br.shuffle_until_moves_available():
		if board != null and board.has_method("perform_auto_shuffle"):
			# ask board to animate the shuffle
			board.call_deferred("perform_auto_shuffle")
		return
	# Fallback: use GameStateBridge shuffle or board_ref perform_auto_shuffle
	var br2 = _get_bridge()
	if br2 != null and br2.shuffle_until_moves_available():
		if board != null and board.has_method("perform_auto_shuffle"):
			board.call_deferred("perform_auto_shuffle")
		return
	print("[BoosterService] No shuffle implementation available via bridge or board")
