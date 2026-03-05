extends Node
class_name SpecialActivationService

# Pure logic for computing the positions affected by special tile activations.
# compute_activation(pos: Vector2, tile_type: int, grid: Array, grid_w: int, grid_h: int, collectible_type: int = 10) -> Dictionary
# Returns {"positions": Array, "specials": Array}
static func compute_activation(pos: Vector2, tile_type: int, grid: Array, grid_w: int, grid_h: int, collectible_type: int = 10) -> Dictionary:
	var positions_to_clear = []
	var special_tiles_to_activate = []
	if tile_type == null:
		return {"positions": positions_to_clear, "specials": special_tiles_to_activate}

	if tile_type == 7: # HORIZONTAL
		for x in range(grid_w):
			if grid[x][int(pos.y)] != -1 and grid[x][int(pos.y)] != collectible_type:
				positions_to_clear.append(Vector2(x, pos.y))
				if x != int(pos.x) and grid[x][int(pos.y)] >= 7 and grid[x][int(pos.y)] <= 9:
					special_tiles_to_activate.append({"pos": Vector2(x, pos.y), "type": int(grid[x][int(pos.y)])})

	elif tile_type == 8: # VERTICAL
		for y in range(grid_h):
			if grid[int(pos.x)][y] != -1 and grid[int(pos.x)][y] != collectible_type:
				positions_to_clear.append(Vector2(pos.x, y))
				if y != int(pos.y) and grid[int(pos.x)][y] >= 7 and grid[int(pos.x)][y] <= 9:
					special_tiles_to_activate.append({"pos": Vector2(pos.x, y), "type": int(grid[int(pos.x)][y])})

	elif tile_type == 9: # FOUR_WAY
		for x in range(grid_w):
			if grid[x][int(pos.y)] != -1 and grid[x][int(pos.y)] != collectible_type:
				positions_to_clear.append(Vector2(x, pos.y))
				if x != int(pos.x) and grid[x][int(pos.y)] >= 7 and grid[x][int(pos.y)] <= 9:
					special_tiles_to_activate.append({"pos": Vector2(x, pos.y), "type": int(grid[x][int(pos.y)])})
		for y in range(grid_h):
			if grid[int(pos.x)][y] != -1 and grid[int(pos.x)][y] != collectible_type:
				var p = Vector2(pos.x, y)
				if not positions_to_clear.has(p):
					positions_to_clear.append(p)
				if y != int(pos.y) and grid[int(pos.x)][y] >= 7 and grid[int(pos.x)][y] <= 9:
					special_tiles_to_activate.append({"pos": Vector2(pos.x, y), "type": int(grid[int(pos.x)][y])})

	return {"positions": positions_to_clear, "specials": special_tiles_to_activate}

static func compute_chain_activation(pos: Vector2, tile_type: int, grid: Array, grid_w: int, grid_h: int, collectible_type: int = 10) -> Dictionary:
	return compute_activation(pos, tile_type, grid, grid_w, grid_h, collectible_type)
