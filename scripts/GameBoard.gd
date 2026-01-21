extends Node2D
class_name GameBoard

signal move_completed
signal board_idle

# Map to track tween finished flags (avoids closure/lambda capture issues)
var _tween_finished_flags := {}

# Helper: await multiple tweens with timeout to avoid hanging if a tween never finishes
func _await_tweens_with_timeout(tweens: Array, timeout: float = 2.0) -> void:
	if tweens == null or tweens.size() == 0:
		return

	# Initialize flags and connect each tween's finished to a local handler
	for tween in tweens:
		if tween == null:
			continue
		_tween_finished_flags[tween] = false
		# Connect using Callable bound to the tween instance (avoids anonymous lambda captures)
		if tween.is_connected("finished", Callable(self, "_on_tween_finished").bind(tween)) == false:
			tween.finished.connect(Callable(self, "_on_tween_finished").bind(tween))

	var attempts = 0
	var max_attempts = int(timeout / 0.05)
	while true:
		var all_done = true
		for t in tweens:
			if t == null:
				continue
			if not _tween_finished_flags.has(t) or not _tween_finished_flags[t]:
				all_done = false
				break
		if all_done:
			break
		if attempts >= max_attempts:
			print("[WARNING] Tween wait timed out after ", timeout, "s")
			break
		if get_tree() == null:
			break
		attempts += 1
		await get_tree().create_timer(0.05).timeout

	# Cleanup flags and disconnect handlers
	for tween in tweens:
		if tween == null:
			continue
		if _tween_finished_flags.has(tween):
			_tween_finished_flags.erase(tween)

# Handler called by tweens when they finish (bound with the tween instance)
func _on_tween_finished(tween):
	if _tween_finished_flags.has(tween):
		_tween_finished_flags[tween] = true

var tiles = []
var selected_tile = null
var tile_scene = preload("res://scenes/Tile.tscn")

# Queues/state for collectible spawning
var collectible_spawn_queue: Array = []
var _just_collected_columns: Array = []

# Provide basic layout variables in case calculate_responsive_layout hasn't run yet
var tile_size: float = 64.0
var grid_offset: Vector2 = Vector2.ZERO

# Convert a grid coordinate (Vector2) to world/screen position for tile placement
func grid_to_world_position(grid_pos: Vector2) -> Vector2:
	# Center the position inside the tile
	return Vector2(
		grid_pos.x * tile_size + grid_offset.x + tile_size * 0.5,
		grid_pos.y * tile_size + grid_offset.y + tile_size * 0.5
	)

# Enqueue a column for collectible spawn (idempotent)
func queue_collectible_spawn(column: int) -> void:
	if column == null:
		return
	if not collectible_spawn_queue.has(column):
		collectible_spawn_queue.append(column)

# Process cascades until no more matches - safe minimal implementation
func process_cascade(start_pos = null) -> void:
	# Keep processing until no matches remain
	while true:
		var matches = []
		# Require GameManager.find_matches to exist; otherwise we can't continue
		if not (GameManager and GameManager.has_method("find_matches")):
			print("[GameBoard] process_cascade: no GameManager.find_matches available; aborting cascade")
			break
		matches = GameManager.find_matches()

		if matches == null or matches.size() == 0:
			break

		# Visual highlight and destroy
		await highlight_matches(matches)
		await animate_destroy_tiles(matches)

		# Clear logical grid for matches (GameManager should handle scoring and logic normally)
		for m in matches:
			if GameManager and GameManager.grid and m.x >= 0 and m.y >= 0:
				GameManager.grid[int(m.x)][int(m.y)] = 0

		# Award points if GameManager supports it
		if GameManager and GameManager.has_method("calculate_points") and GameManager.has_method("add_score"):
			var pts = GameManager.calculate_points(matches.size())
			GameManager.add_score(pts)

		# Gravity/refill
		await animate_gravity()
		await animate_refill()

		# small guard delay
		if get_tree() != null:
			await get_tree().create_timer(0.06).timeout

	# cascade finished
	return

# Perform visual + logical swap between two tile nodes (used by swipe/click)
func perform_swap(tile_a, tile_b) -> void:
	if tile_a == null or tile_b == null:
		return

	# Logical positions
	var pos_a = tile_a.grid_position
	var pos_b = tile_b.grid_position

	# Delegate to GameManager swap if available
	if GameManager and GameManager.has_method("swap_tiles"):
		GameManager.swap_tiles(pos_a, pos_b)
	else:
		# fallback: swap logical grid values
		var tmp = GameManager.grid[int(pos_a.x)][int(pos_a.y)]
		GameManager.grid[int(pos_a.x)][int(pos_a.y)] = GameManager.grid[int(pos_b.x)][int(pos_b.y)]
		GameManager.grid[int(pos_b.x)][int(pos_b.y)] = tmp

	# Animate visually
	var world_a = grid_to_world_position(pos_a)
	var world_b = grid_to_world_position(pos_b)
	var tlist = []
	if tile_a.has_method("animate_swap_to"):
		var ta = tile_a.animate_swap_to(world_b)
		if ta: tlist.append(ta)
	if tile_b.has_method("animate_swap_to"):
		var tb = tile_b.animate_swap_to(world_a)
		if tb: tlist.append(tb)
	if tlist.size() > 0:
		await _await_tweens_with_timeout(tlist, 1.6)

	# Update tiles array references
	if tiles.size() > int(pos_a.x) and tiles[int(pos_a.x)].size() > int(pos_a.y):
		tiles[int(pos_a.x)][int(pos_a.y)] = tile_b
	if tiles.size() > int(pos_b.x) and tiles[int(pos_b.x)].size() > int(pos_b.y):
		tiles[int(pos_b.x)][int(pos_b.y)] = tile_a

	# Update node grid positions
	tile_a.grid_position = pos_b
	tile_b.grid_position = pos_a

	# Emit move completed so higher-level systems can react
	emit_signal("move_completed")

# Default higher-level tile click handler if GameManager doesn't provide one
func _handle_tile_click(tile) -> void:
	# If GameManager provides logic, prefer it
	if GameManager and GameManager.has_method("handle_tile_click"):
		GameManager.call("handle_tile_click", tile)
		return

	# Basic selection logic (same as earlier inline behavior)
	if GameManager.processing_moves or (GameManager.has_method("level_transitioning") and GameManager.level_transitioning):
		return

	if selected_tile == null:
		selected_tile = tile
		tile.set_selected(true)
	else:
		if selected_tile == tile:
			selected_tile.set_selected(false)
			selected_tile = null
		else:
			# If adjacent, swap
			var can_swap = false
			if GameManager and GameManager.has_method("can_swap"):
				can_swap = GameManager.call("can_swap", selected_tile.grid_position, tile.grid_position)
			else:
				# fallback: adjacency test
				var d = selected_tile.grid_position - tile.grid_position
				can_swap = (abs(d.x) + abs(d.y)) == 1

			if can_swap:
				perform_swap(selected_tile, tile)
			else:
				selected_tile.set_selected(false)
				selected_tile = tile
				tile.set_selected(true)

# Default swipe handler if GameManager doesn't provide one
func _handle_tile_swipe(tile, dir: Vector2) -> void:
	if GameManager and GameManager.has_method("handle_tile_swipe"):
		GameManager.call("handle_tile_swipe", tile, dir)
		return

	# Default: attempt to swap with neighboring tile
	var target_pos = tile.grid_position + dir
	if not GameManager.is_valid_position(target_pos):
		return
	var target = tiles[int(target_pos.x)][int(target_pos.y)]
	if not target:
		return
	perform_swap(tile, target)

# Minimal highlight_matches: play a tiny flash for each matched tile; used during cascades
func highlight_matches(matches: Array) -> void:
	if matches == null or matches.size() == 0:
		return
	# Try to animate each tile if possible, otherwise just wait briefly
	var tweens = []
	for pos in matches:
		if pos.x < 0 or pos.y < 0:
			continue
		if pos.x >= tiles.size() or pos.y >= (tiles[int(pos.x)].size() if tiles.size() > int(pos.x) else 0):
			continue
		var tnode = tiles[int(pos.x)][int(pos.y)]
		if tnode and tnode.has_method("animate_match_highlight"):
			var tw = tnode.animate_match_highlight()
			if tw:
				tweens.append(tw)

	if tweens.size() > 0:
		await _await_tweens_with_timeout(tweens, 1.0)
	else:
		# fallback pause for visual consistency
		if get_tree() != null:
			await get_tree().create_timer(0.08).timeout

# Minimal animate_destroy_tiles implementation: fades out visual tiles and frees them
func animate_destroy_tiles(positions: Array) -> void:
	if positions == null or positions.size() == 0:
		return
	var tweens = []
	var nodes_to_free = []
	for pos in positions:
		if pos.x < 0 or pos.y < 0:
			continue
		var ix = int(pos.x)
		var iy = int(pos.y)
		if ix < 0 or iy < 0:
			continue
		if ix >= tiles.size():
			continue
		if iy >= tiles[ix].size():
			continue
		var node = tiles[ix][iy]
		if node:
			# prefer node-provided animation
			if node.has_method("animate_destroy"):
				var tw = node.animate_destroy()
				if tw:
					tweens.append(tw)
			else:
				var tw2 = create_tween()
				tw2.tween_property(node, "modulate", Color(1,1,1,0), 0.12)
				tweens.append(tw2)
			nodes_to_free.append({"node": node, "x": ix, "y": iy})

	if tweens.size() > 0:
		await _await_tweens_with_timeout(tweens, 1.5)
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.06).timeout

	# Clear tile references and free nodes
	for item in nodes_to_free:
		var n = item["node"]
		var x = item["x"]
		var y = item["y"]
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			n.queue_free()
		if x < tiles.size() and y < tiles[x].size():
			tiles[x][y] = null

# Minimal animate_gravity: call GameManager.apply_gravity() if available and wait for visuals
func animate_gravity() -> void:
	if GameManager and GameManager.has_method("apply_gravity"):
		var moved = GameManager.apply_gravity()
		print("[GameBoard] animate_gravity: GameManager.apply_gravity -> ", moved)
	else:
		print("[GameBoard] animate_gravity: GameManager.apply_gravity not available; skipping logical gravity")
	# small visual pause to allow repositioning
	if get_tree() != null:
		await get_tree().create_timer(0.06).timeout

# Minimal animate_refill: call GameManager.fill_empty_spaces() if available and spawn visual tiles conservatively
func animate_refill() -> void:
	var new_positions = []
	if GameManager and GameManager.has_method("fill_empty_spaces"):
		new_positions = GameManager.fill_empty_spaces()
		print("[GameBoard] animate_refill: GameManager.fill_empty_spaces returned ", new_positions)
	else:
		# Nothing to refill
		if get_tree() != null:
			await get_tree().create_timer(0.08).timeout
			return

	# Try to create basic visuals for positions if tile_scene is valid
	var tweens = []
	var scale_factor = tile_size / 64.0
	for p in new_positions:
		var x = int(p.x)
		var y = int(p.y)
		if x < 0 or y < 0 or x >= GameManager.GRID_WIDTH or y >= GameManager.GRID_HEIGHT:
			continue
		if tiles.size() <= x:
			# ensure inner array exists
			while tiles.size() <= x:
				tiles.append([])
		if tiles[x].size() <= y:
			while tiles[x].size() <= y:
				tiles[x].append(null)
		if tiles[x][y] == null:
			var tnode = tile_scene.instantiate()
			tnode.setup(GameManager.get_tile_at(Vector2(x,y)), Vector2(x,y), scale_factor)
			tnode.position = grid_to_world_position(Vector2(x, -1))
			tnode.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
			tnode.connect("tile_swiped", Callable(self, "_on_tile_swiped"))
			add_child(tnode)
			tnode.z_index = 0
			tiles[x][y] = tnode
			var tgt = grid_to_world_position(Vector2(x, y))
			if tnode.has_method("animate_to_position"):
				var tw = tnode.animate_to_position(tgt)
				if tw:
					tweens.append(tw)

	if tweens.size() > 0:
		await _await_tweens_with_timeout(tweens, 2.0)
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.06).timeout

# Calculate responsive layout for the board and set tile_size and grid_offset
func calculate_responsive_layout() -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	var screen_size = viewport.get_visible_rect().size
	# Reserve some UI space; these can be tuned later
	var ui_top_space = 140.0
	var ui_bottom_space = 100.0
	var available_width = max(100.0, screen_size.x - 40.0)
	var available_height = max(100.0, screen_size.y - ui_top_space - ui_bottom_space - 40.0)
	# Use GameManager grid dimensions if available
	var gw = 8
	var gh = 8
	if Engine.has_singleton("GameManager"):
		# Try to read constants from GameManager if present (use typeof guard to avoid errors)
		if typeof(GameManager.GRID_WIDTH) != TYPE_NIL:
			gw = GameManager.GRID_WIDTH
		if typeof(GameManager.GRID_HEIGHT) != TYPE_NIL:
			gh = GameManager.GRID_HEIGHT
	# Compute tile size to fit
	var max_tile_w = available_width / float(gw)
	var max_tile_h = available_height / float(gh)
	tile_size = clamp(min(max_tile_w, max_tile_h), 40.0, 200.0)
	# Center grid
	var total_w = gw * tile_size
	var total_h = gh * tile_size
	grid_offset = Vector2((screen_size.x - total_w) / 2.0, ui_top_space + (available_height - total_h) / 2.0)
	print("[GameBoard] calculate_responsive_layout -> tile_size:", tile_size, " grid_offset:", grid_offset)

# Setup a simple background ColorRect (if not already present) and hide it if we prefer image backgrounds
func setup_background() -> void:
	# If a background node named 'BoardBackground' exists, reuse it
	var bg = get_node_or_null("BoardBackground")
	if not bg:
		bg = ColorRect.new()
		bg.name = "BoardBackground"
		bg.color = Color(0, 0, 0, 0.35)
		add_child(bg)
		bg.z_index = -50
	# Set size & position to cover computed board area
	var board_w = GameManager.GRID_WIDTH * tile_size
	var board_h = GameManager.GRID_HEIGHT * tile_size
	bg.rect_position = Vector2(grid_offset.x - 10, grid_offset.y - 10)
	bg.rect_size = Vector2(board_w + 20, board_h + 20)
	bg.visible = true
	print("[GameBoard] setup_background created/updated BoardBackground")

# Create the visual tile grid based on GameManager.grid
func create_visual_grid() -> void:
	# Clear any existing tiles created by this board
	for child in get_children():
		if child and child != get_node_or_null("BoardBackground") and child.has_method("setup"):
			child.queue_free()
	# Reset tiles array
	tiles.clear()

	if not Engine.has_singleton("GameManager"):
		print("[GameBoard] create_visual_grid: No GameManager singleton available")
		return
	# Validate grid
	if GameManager == null or GameManager.grid == null:
		print("[GameBoard] create_visual_grid: GameManager.grid not available")
		return

	var gw = GameManager.GRID_WIDTH
	var gh = GameManager.GRID_HEIGHT
	var scale_factor = tile_size / 64.0
	var created = 0
	for x in range(gw):
		tiles.append([])
		for y in range(gh):
			var ttype = GameManager.get_tile_at(Vector2(x, y))
			if ttype == -1:
				tiles[x].append(null)
				continue
			var node = tile_scene.instantiate()
			node.setup(ttype, Vector2(x, y), scale_factor)
			node.position = grid_to_world_position(Vector2(x, y))
			node.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
			node.connect("tile_swiped", Callable(self, "_on_tile_swiped"))
			add_child(node)
			node.z_index = 0
			tiles[x].append(node)
			created += 1
	print("[GameBoard] create_visual_grid: created ", created, " tiles")
