extends Node
class_name BoardVisuals

# BoardVisuals: tile creation / clearing / visual grid helpers
# API:
#   create_visual_grid(gameboard: Node, tiles_ref: Array)
#   clear_tiles(gameboard: Node, tiles_ref: Array)
#   instantiate_tile_visual(gameboard: Node, tile_scene: PackedScene, tile_type: int, grid_pos: Vector2, scale_factor: float, unmovable_meta = null) -> Node
#   spawn_collectible_visual(gameboard: Node, tiles_ref: Array, x:int, y:int, coll_type:String)

# Avoid module-level non-constant vars that static functions cannot access
# VisualFactory will be loaded locally inside static functions to keep them self-contained

static func clear_tiles(gameboard: Node, tiles_ref: Array) -> void:
	var tiles_to_remove = []
	# check board_container
	if gameboard.board_container and is_instance_valid(gameboard.board_container):
		for child in gameboard.board_container.get_children():
			if child and is_instance_valid(child) and child.name != "BorderContainer" and child.has_method("setup"):
				tiles_to_remove.append(child)
	# legacy direct children
	for child in gameboard.get_children():
		if child and is_instance_valid(child) and not (child.name in ["Background","BorderContainer","BoardContainer","TileAreaOverlay"]) and child.has_method("setup"):
			tiles_to_remove.append(child)

	for t in tiles_to_remove:
		if t and is_instance_valid(t):
			var p = t.get_parent()
			if p:
				p.remove_child(t)
			t.queue_free()

	# clear tiles_ref array
	for i in range(tiles_ref.size()):
		tiles_ref[i] = []
	# ensure length
	while tiles_ref.size() < GameManager.GRID_WIDTH:
		tiles_ref.append([])

static func instantiate_tile_visual(gameboard: Node, tile_scene: PackedScene, tile_type: int, grid_pos: Vector2, scale_factor: float, unmovable_meta = null) -> Node:
	var tile: Node = null
	# prefer VisualFactory via safe call (load locally to keep static function safe)
	var vf_local = load("res://scripts/game/VisualFactory.gd")
	if vf_local != null and vf_local.has_method("create_tile_instance") and (unmovable_meta == null):
		tile = vf_local.call("create_tile_instance", tile_scene, tile_type, grid_pos, scale_factor)
	else:
		tile = tile_scene.instantiate()
		if tile and tile.has_method("setup"):
			if unmovable_meta != null:
				tile.setup(0, grid_pos, scale_factor, true)
			else:
				tile.setup(tile_type, grid_pos, scale_factor)

	if unmovable_meta != null and tile != null:
		if tile.has_method("configure_unmovable_hard"):
			var textures_arr = []
			var reveals = {}
			if unmovable_meta.has("textures"):
				textures_arr = unmovable_meta["textures"]
			if unmovable_meta.has("reveals"):
				reveals = unmovable_meta["reveals"]
			if typeof(textures_arr) != TYPE_ARRAY:
				textures_arr = []
			if typeof(reveals) != TYPE_DICTIONARY:
				reveals = {}
			tile.configure_unmovable_hard(unmovable_meta.get("hits",1), unmovable_meta.get("type", GameManager.unmovable_type), textures_arr, reveals)

	# connect and parent under board_container
	if tile != null:
		if tile.has_method("connect"):
			tile.connect("tile_clicked", Callable(gameboard, "_on_tile_clicked"))
			tile.connect("tile_swiped", Callable(gameboard, "_on_tile_swiped"))
		if gameboard.board_container:
			gameboard.board_container.add_child(tile)
		else:
			gameboard.add_child(tile)
	return tile

static func create_visual_grid(gameboard: Node, tiles_ref: Array) -> void:
	# guard
	if gameboard.creating_visual_grid:
		return
	gameboard.creating_visual_grid = true
	clear_tiles(gameboard, tiles_ref)
	await gameboard.get_tree().process_frame
	tiles_ref.clear()
	if GameManager.grid.size() == 0:
		gameboard.creating_visual_grid = false
		return
	var scale_factor = gameboard.tile_size / 64.0
	var tiles_created = 0
	for x in range(GameManager.GRID_WIDTH):
		tiles_ref.append([])
		for y in range(GameManager.GRID_HEIGHT):
			var tile_type = GameManager.get_tile_at(Vector2(x,y))
			if tile_type == -1:
				tiles_ref[x].append(null)
				continue
			var tile = null
			var key = str(x) + "," + str(y)
			if GameManager.unmovable_map.has(key) and typeof(GameManager.unmovable_map[key]) == TYPE_DICTIONARY:
				# hard unmovable
				tile = gameboard.tile_scene.instantiate()
				if tile and tile.has_method("setup"):
					tile.setup(0, Vector2(x,y), scale_factor, true)
			else:
				var vf_local = load("res://scripts/game/VisualFactory.gd")
				if vf_local != null and vf_local.has_method("create_tile_instance"):
					tile = vf_local.call("create_tile_instance", gameboard.tile_scene, tile_type, Vector2(x,y), scale_factor)
				else:
					tile = gameboard.tile_scene.instantiate()
					if tile and tile.has_method("setup"):
						tile.setup(tile_type, Vector2(x,y), scale_factor)
			if not tile:
				tiles_ref[x].append(null)
				continue
			# configure unmovable or normal wiring
			if GameManager.unmovable_map.has(key) and typeof(GameManager.unmovable_map[key]) == TYPE_DICTIONARY:
				var meta = GameManager.unmovable_map[key]
				if tile.has_method("configure_unmovable_hard"):
					var textures_arr = []
					var reveals = {}
					if typeof(meta) == TYPE_DICTIONARY:
						if meta.has("textures"):
							textures_arr = meta["textures"]
						if meta.has("reveals"):
							reveals = meta["reveals"]
						if typeof(textures_arr) != TYPE_ARRAY:
							textures_arr = []
						if typeof(reveals) != TYPE_DICTIONARY:
							reveals = {}
					tile.configure_unmovable_hard(meta.get("hits",1), meta.get("type", GameManager.unmovable_type), textures_arr, reveals)
			else:
				if tile.has_method("connect"):
					tile.connect("tile_clicked", Callable(gameboard, "_on_tile_clicked"))
					tile.connect("tile_swiped", Callable(gameboard, "_on_tile_swiped"))
				if tile_type == GameManager.COLLECTIBLE and tile.has_method("configure_collectible"):
					tile.configure_collectible(GameManager.collectible_type)
				if tile_type == GameManager.SPREADER and tile.has_method("configure_spreader"):
					var textures = []
					if GameManager.spreader_textures_map.has(GameManager.spreader_type):
						textures = GameManager.spreader_textures_map[GameManager.spreader_type]
					tile.configure_spreader(GameManager.spreader_grace_default, GameManager.spreader_type, textures)
			# parent
			if gameboard.board_container:
				gameboard.board_container.add_child(tile)
			else:
				gameboard.add_child(tile)

			# Ensure tile node positioned correctly using GameBoard helper if available
			if tile and tile.has_method("set_position") or tile:
				if gameboard and gameboard.has_method("grid_to_world_position"):
					var world_pos = gameboard.grid_to_world_position(Vector2(x,y))
					# Some tile scenes expect center-based position; GameBoard uses center offset
					tile.position = world_pos
					# Also ensure tile.grid_position is set for consistency
					if tile.has_method("setup"):
						# setup was already called earlier but ensure property is saved
						tile.grid_position = Vector2(x,y)

			tiles_ref[x].append(tile)
			tiles_created += 1
	gameboard.creating_visual_grid = false
	# show group
	if gameboard.has_method("show_board_group"):
		gameboard.show_board_group()
	# show UI if available
	var gui = gameboard.get_node_or_null("../GameUI")
	if gui and gui.has_method("show_gameplay_ui"):
		gui.show_gameplay_ui()

	# DIAGNOSTIC LOGS: help debug layout issues
	print("[BoardVisuals] Created ", tiles_created, " tiles; board_container child_count=", gameboard.board_container.get_child_count() if gameboard.board_container else -1)
	# Count visible tiles
	var visible_count = 0
	for x_i in range(tiles_ref.size()):
		for y_i in range(tiles_ref[x_i].size()):
			var t = tiles_ref[x_i][y_i]
			if t and is_instance_valid(t) and t.visible:
				visible_count += 1
	print("[BoardVisuals] visible tiles in tiles_ref=", visible_count)
	# Print positions of first row and first column sample tiles
	if tiles_ref.size() > 0:
		var samples_row = []
		for i in range(min(4, tiles_ref[0].size())):
			if tiles_ref[0][i] != null:
				samples_row.append(tiles_ref[0][i].position)
			else:
				samples_row.append(null)
		print("[BoardVisuals] sample positions row0: ", samples_row)
	if tiles_ref.size() > 1:
		var samples_col = []
		for j in range(min(4, tiles_ref.size())):
			if tiles_ref[j].size() > 0 and tiles_ref[j][0] != null:
				samples_col.append(tiles_ref[j][0].position)
			else:
				samples_col.append(null)
		print("[BoardVisuals] sample positions col0: ", samples_col)

static func spawn_collectible_visual(gameboard: Node, tiles_ref: Array, x: int, y: int, coll_type: String = "coin") -> void:
	if x < 0 or x >= GameManager.GRID_WIDTH or y < 0 or y >= GameManager.GRID_HEIGHT:
		return
	var existing_tile = null
	if x < tiles_ref.size() and y < tiles_ref[x].size():
		existing_tile = tiles_ref[x][y]
	if existing_tile:
		if existing_tile.has_method("configure_collectible"):
			existing_tile.configure_collectible(coll_type)
			return
	var scale_factor = gameboard.tile_size / 64.0
	var tile = null
	var vf_local = load("res://scripts/game/VisualFactory.gd")
	if vf_local != null and vf_local.has_method("create_collectible_tile"):
		tile = vf_local.call("create_collectible_tile", gameboard.tile_scene, coll_type, Vector2(x,y), scale_factor)
	else:
		tile = gameboard.tile_scene.instantiate()
		if tile and tile.has_method("setup"):
			tile.setup(0, Vector2(x,y), scale_factor)
			if tile and tile.has_method("configure_collectible"):
				tile.configure_collectible(coll_type)
	if tile:
		if tile.has_method("connect"):
			tile.connect("tile_clicked", Callable(gameboard, "_on_tile_clicked"))
			tile.connect("tile_swiped", Callable(gameboard, "_on_tile_swiped"))
		if gameboard.board_container:
			gameboard.board_container.add_child(tile)
		else:
			gameboard.add_child(tile)
		# ensure tiles_ref size
		while tiles_ref.size() <= x:
			tiles_ref.append([])
		while tiles_ref[x].size() <= y:
			tiles_ref[x].append(null)
		tiles_ref[x][y] = tile
		return
