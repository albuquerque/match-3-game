extends Node
# SpreaderService — loaded as a script resource (via SS var in GameBoard), not instanced directly

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

# Step 8: Adjacent unmovable/spreader damage and spreader visual application added here.

static func damage_adjacent_unmovables(board: Node, tiles_ref: Array, matched_positions: Array) -> void:
	## Deal 1 hit to every hard unmovable orthogonally adjacent to any matched position.
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	var already_hit: Dictionary = {}

	for pos in matched_positions:
		for dir in directions:
			var nx = int(pos.x) + int(dir.x)
			var ny = int(pos.y) + int(dir.y)
			if nx < 0 or nx >= GameRunState.GRID_WIDTH or ny < 0 or ny >= GameRunState.GRID_HEIGHT:
				continue
			var key = str(nx) + "," + str(ny)
			if already_hit.has(key):
				continue
			if not GameManager._is_unmovable_cell(nx, ny):
				continue
			already_hit[key] = true
			if nx >= tiles_ref.size() or ny >= tiles_ref[nx].size():
				continue
			var tile = tiles_ref[nx][ny]
			if not tile or not is_instance_valid(tile) or tile.is_queued_for_deletion():
				continue
			if not ("is_unmovable_hard" in tile) or not tile.is_unmovable_hard:
				continue

			var destroyed = tile.take_hit(1)
			if destroyed:
				var revealed_type = tile.tile_type if "tile_type" in tile else 0
				var is_coll = tile.is_collectible if "is_collectible" in tile else false
				if is_coll:
					GameRunState.grid[nx][ny] = GameRunState.COLLECTIBLE
				elif revealed_type > 0:
					GameRunState.grid[nx][ny] = revealed_type
				else:
					GameRunState.grid[nx][ny] = 0
					tiles_ref[nx][ny] = null
					if not tile.is_queued_for_deletion():
						tile.queue_free()
				if GameManager.has_method("report_unmovable_destroyed"):
					GameManager.report_unmovable_destroyed(key, revealed_type > 0 or is_coll)
				# Notify EventBus so ShardDropSystem can react to obstacle clears
				var _eb = EventBus if Engine.has_singleton("EventBus") else null
				if not _eb:
					var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
					if root:
						_eb = root.get_node_or_null("EventBus")
				if _eb:
					var parts = key.split(",")
					var gp := Vector2(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2(-1, -1)
					_eb.emit_tile_destroyed(key, {"is_obstacle": true, "grid_position": gp})

static func damage_adjacent_spreaders(board: Node, tiles_ref: Array, matched_positions: Array) -> void:
	## Destroy any spreader tile orthogonally adjacent to a matched position.
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	var already_hit: Dictionary = {}

	for pos in matched_positions:
		for dir in directions:
			var nx = int(pos.x) + int(dir.x)
			var ny = int(pos.y) + int(dir.y)
			if nx < 0 or nx >= GameRunState.GRID_WIDTH or ny < 0 or ny >= GameRunState.GRID_HEIGHT:
				continue
			var key = str(nx) + "," + str(ny)
			if already_hit.has(key):
				continue
			if GameManager.get_tile_at(Vector2(nx, ny)) != GameRunState.SPREADER:
				continue
			already_hit[key] = true

			GameRunState.grid[nx][ny] = 0
			GameManager.report_spreader_destroyed(Vector2(nx, ny))
			if nx < tiles_ref.size() and ny < tiles_ref[nx].size():
				var tile = tiles_ref[nx][ny]
				if tile and is_instance_valid(tile) and not tile.is_queued_for_deletion():
					if tile.has_method("animate_destroy"):
						var dtw = tile.animate_destroy()
						tile.set_process_input(false)
						if dtw != null:
							dtw.connect("finished", tile.queue_free.bind(), CONNECT_ONE_SHOT)
						else:
							tile.queue_free()
					else:
						tile.queue_free()
				tiles_ref[nx][ny] = null

static func apply_spreader_visuals(board: Node, tiles_ref: Array, new_positions: Array) -> void:
	## Reconfigure visual tiles at newly-infected spreader positions.
	var scale_factor = board.tile_size / 64.0
	var textures: Array = []
	if GameRunState.spreader_textures_map.has(GameRunState.spreader_type):
		textures = GameRunState.spreader_textures_map[GameRunState.spreader_type]

	for pos in new_positions:
		var x = int(pos.x)
		var y = int(pos.y)
		if x >= tiles_ref.size() or y >= tiles_ref[x].size():
			continue

		var tile = tiles_ref[x][y]
		if tile == null or not is_instance_valid(tile) or tile.is_queued_for_deletion():
			var new_tile = board.tile_scene.instantiate()
			new_tile.setup(GameRunState.SPREADER, pos, scale_factor)
			if new_tile.has_method("configure_spreader"):
				new_tile.configure_spreader(GameRunState.spreader_grace_default, GameRunState.spreader_type, textures)
			new_tile.position = board.grid_to_world_position(pos)
			new_tile.connect("tile_clicked",  Callable(board, "_on_tile_clicked"))
			new_tile.connect("tile_swiped",   Callable(board, "_on_tile_swiped"))
			if board.board_container:
				board.board_container.add_child(new_tile)
			else:
				board.add_child(new_tile)
			tiles_ref[x][y] = new_tile
		else:
			if tile.has_method("configure_spreader"):
				tile.configure_spreader(GameRunState.spreader_grace_default, GameRunState.spreader_type, textures)
			else:
				tile.update_type(GameRunState.SPREADER)
