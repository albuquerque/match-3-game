extends Node
class_name GravityAnimator

# Minimal GravityAnimator stubs to keep project compiling.
# Full async implementations will be added in a controlled follow-up.

static func animate_gravity(game_manager: Node, gameboard: Node, tiles_ref: Array) -> void:
	# Apply gravity at data level first
	var moved = false
	if typeof(game_manager) != TYPE_NIL and game_manager != null and game_manager.has_method("apply_gravity"):
		moved = game_manager.apply_gravity()
	else:
		# fallback to GravityService (pure data)
		var gs_res = load("res://scripts/game/GravityService.gd")
		if gs_res != null and gs_res.has_method("apply_gravity"):
			moved = gs_res.call("apply_gravity", game_manager.grid, game_manager.GRID_WIDTH, game_manager.GRID_HEIGHT)

	if not moved:
		await gameboard.get_tree().process_frame
		return

	# For each column, gather existing visual nodes and reassign them bottom-up according to new data grid
	var all_tweens: Array = []
	for x in range(game_manager.GRID_WIDTH):
		var visual_nodes: Array = []
		if x < tiles_ref.size():
			# collect nodes from bottom to top so ordering matches gravity fill
			for y in range(tiles_ref[x].size() - 1, -1, -1):
				var n = tiles_ref[x][y]
				if n != null and is_instance_valid(n):
					visual_nodes.append(n)

		# build new column with nulls
		var new_col = []
		for i in range(game_manager.GRID_HEIGHT):
			new_col.append(null)

		var write_y = game_manager.GRID_HEIGHT - 1
		for node in visual_nodes:
			# skip blocked cells in data
			while write_y >= 0 and game_manager.get_tile_at(Vector2(x, write_y)) == -1:
				new_col[write_y] = null
				write_y -= 1
			if write_y < 0:
				break
			new_col[write_y] = node
			var target_world = gameboard.grid_to_world_position(Vector2(x, write_y))
			if node.has_method("animate_to_position"):
				var tw = node.animate_to_position(target_world, 0.18)
				if tw != null:
					all_tweens.append(tw)
			else:
				var t = gameboard.create_tween()
				t.tween_property(node, "position", target_world, 0.18)
				all_tweens.append(t)
			write_y -= 1

		# assign new column
		if x < tiles_ref.size():
			tiles_ref[x] = new_col
		else:
			# ensure size
			while tiles_ref.size() <= x:
				tiles_ref.append(new_col)

	# await animations
	if all_tweens.size() > 0:
		await all_tweens[0].finished
	await gameboard.get_tree().process_frame
	return

static func animate_refill(game_manager: Node, gameboard: Node, tiles_ref: Array) -> Array:
	# Ask GameManager for filled positions
	var filled: Array = []
	if typeof(game_manager) != TYPE_NIL and game_manager != null and game_manager.has_method("fill_empty_spaces"):
		filled = game_manager.fill_empty_spaces()
	else:
		var gs_res = load("res://scripts/game/GravityService.gd")
		if gs_res != null and gs_res.has_method("fill_empty_spaces"):
			filled = gs_res.call("fill_empty_spaces", game_manager.grid, game_manager.GRID_WIDTH, game_manager.GRID_HEIGHT, game_manager.tile_types if game_manager.has("tile_types") else 6)

	if filled == null or filled.size() == 0:
		await gameboard.get_tree().process_frame
		return []

	var tweens: Array = []
	var scale_factor = gameboard.tile_size / 64.0
	var created_positions: Array = []
	for pos in filled:
		var x = int(pos.x)
		var y = int(pos.y)
		# ensure tiles_ref size
		while tiles_ref.size() <= x:
			tiles_ref.append([])
		while tiles_ref[x].size() <= y:
			tiles_ref[x].append(null)

		var tile_type = game_manager.get_tile_at(Vector2(x, y))
		var tile_node = null
		# Use gameboard.instantiate_tile_visual helper (always present on GameBoard)
		if gameboard.has_method("instantiate_tile_visual"):
			tile_node = gameboard.instantiate_tile_visual(tile_type, Vector2(x, y), scale_factor)
		else:
			# last resort: instantiate tile scene directly
			var ts = gameboard.tile_scene
			if ts != null:
				tile_node = ts.instantiate()
				if tile_node != null and tile_node.has_method("setup"):
					tile_node.setup(tile_type, Vector2(x, y), scale_factor)

		if tile_node == null:
			continue

		# initial start position above board
		var start_world = gameboard.grid_to_world_position(Vector2(x, 0))
		start_world.y = gameboard.grid_offset.y - gameboard.tile_size - (randf() * gameboard.tile_size)
		tile_node.position = start_world
		var target = gameboard.grid_to_world_position(Vector2(x, y))
		if tile_node.has_method("animate_to_position"):
			var tw = tile_node.animate_to_position(target, 0.28)
			if tw != null:
				tweens.append(tw)
		else:
			var t = gameboard.create_tween()
			t.tween_property(tile_node, "position", target, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tweens.append(t)

		tiles_ref[x][y] = tile_node
		created_positions.append(Vector2(x, y))

	if tweens.size() > 0:
		await tweens[0].finished
	await gameboard.get_tree().process_frame
	return created_positions

static func deferred_gravity_then_refill(game_manager: Node, gameboard: Node, tiles_ref: Array) -> void:
	if typeof(game_manager) != TYPE_NIL and game_manager != null:
		if game_manager.has_method("apply_gravity"):
			game_manager.apply_gravity()
		if game_manager.has_method("fill_empty_spaces"):
			game_manager.fill_empty_spaces()
	return
