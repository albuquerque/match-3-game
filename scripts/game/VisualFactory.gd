extends Node
class_name VisualFactory

# Existing helpers may exist above; add safe factory functions used by GameBoard

static func create_tile_instance(tile_scene: PackedScene, tile_type: int, grid_pos: Vector2, scale_factor: float) -> Node:
	# Instantiate a tile and call setup if available
	var tile = null
	if tile_scene:
		tile = tile_scene.instantiate()
		if tile and tile.has_method("setup"):
			tile.setup(tile_type, grid_pos, scale_factor)
		# position/other wiring is expected to be handled by caller
	return tile

static func create_collectible_tile(tile_scene: PackedScene, coll_type: String, grid_pos: Vector2, scale_factor: float) -> Node:
	var tile = null
	if tile_scene:
		tile = tile_scene.instantiate()
		if tile and tile.has_method("setup"):
			tile.setup(0, grid_pos, scale_factor)
		if tile and tile.has_method("configure_collectible"):
			tile.configure_collectible(coll_type)
	return tile

static func animate_spawn(tile: Node, board_node: Node) -> Tween:
	# Optionally animate spawn (scale/alpha) if tile provides methods
	if not tile:
		return null
	if tile.has_method("animate_spawn"):
		return tile.animate_spawn()
	# Fallback generic tween
	if board_node and board_node.has_method("create_tween"):
		var tw = board_node.create_tween()
		tw.tween_property(tile, "modulate:a", 1.0, 0.35)
		return tw
	return null
