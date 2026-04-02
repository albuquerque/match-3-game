extends Node

# Pure logic for computing the positions affected by special tile activations.
# compute_activation(pos: Vector2, tile_type: int, grid: Array, grid_w: int, grid_h: int, collectible_type: int = 10) -> Dictionary
# Returns {"positions": Array, "specials": Array}
const _GQS = preload("res://games/match3/board/services/GridQueryService.gd")

static func compute_activation(pos: Vector2, tile_type: int, grid: Array, grid_w: int, grid_h: int, collectible_type: int = 10) -> Dictionary:
	var positions_to_clear = []
	var special_tiles_to_activate = []
	print("[SpecialActivationService] compute_activation called: pos=", pos, " tile_type=", tile_type, " grid_w=", grid_w, " grid_h=", grid_h, " collectible_type=", collectible_type)
	if tile_type == null:
		return {"positions": positions_to_clear, "specials": special_tiles_to_activate}

	if tile_type == 7: # HORIZONTAL
		for x in range(grid_w):
			var y = int(pos.y)
			var val = _GQS.get_tile_at(null, Vector2(x, y))
			# Skip only truly invalid/empty cells or collectibles; include unmovables so they can be damaged
			if val == -1 or val <= 0 or val == collectible_type:
				continue
			positions_to_clear.append(Vector2(x, y))
			if x != int(pos.x) and val >= 7 and val <= 9:
				special_tiles_to_activate.append({"pos": Vector2(x, y), "type": int(val)})

	elif tile_type == 8: # VERTICAL
		for y in range(grid_h):
			var x = int(pos.x)
			var val = _GQS.get_tile_at(null, Vector2(x, y))
			if val == -1 or val <= 0 or val == collectible_type:
				continue
			positions_to_clear.append(Vector2(x, y))
			if y != int(pos.y) and val >= 7 and val <= 9:
				special_tiles_to_activate.append({"pos": Vector2(x, y), "type": int(val)})

	elif tile_type == 9: # FOUR_WAY
		for x in range(grid_w):
			var y = int(pos.y)
			var val = _GQS.get_tile_at(null, Vector2(x, y))
			if val == -1 or val <= 0 or val == collectible_type:
				continue
			positions_to_clear.append(Vector2(x, y))
			if x != int(pos.x) and val >= 7 and val <= 9:
				special_tiles_to_activate.append({"pos": Vector2(x, y), "type": int(val)})
		for y in range(grid_h):
			var x = int(pos.x)
			var val = _GQS.get_tile_at(null, Vector2(x, y))
			if val == -1 or val <= 0 or val == collectible_type:
				continue
			var p = Vector2(x, y)
			if not positions_to_clear.has(p):
				positions_to_clear.append(p)
			if y != int(pos.y) and val >= 7 and val <= 9:
				special_tiles_to_activate.append({"pos": Vector2(x, y), "type": int(val)})

	print("[SpecialActivationService] computed positions_to_clear count=", positions_to_clear.size(), " specials count=", special_tiles_to_activate.size())
	return {"positions": positions_to_clear, "specials": special_tiles_to_activate}

static func compute_chain_activation(pos: Vector2, tile_type: int, grid: Array, grid_w: int, grid_h: int, collectible_type: int = 10) -> Dictionary:
	return compute_activation(pos, tile_type, grid, grid_w, grid_h, collectible_type)
