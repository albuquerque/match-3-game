extends Node
class_name GravityAnimator

# GravityAnimator — barrier/segment-aware gravity and refill animations.
# A2: Full logic ported from GameBoard.animate_gravity / GameBoard.animate_refill (2026-03-05).
# All methods are static and receive the gameboard (GameBoard) and game_manager (GameManager
# autoload) as parameters so they remain decoupled from both god objects.

static func animate_gravity(game_manager: Node, gameboard: Node, tiles_ref: Array) -> void:
	var moved = game_manager.apply_gravity()
	print("[GRAVITY] apply_gravity returned -> ", moved)

	var gravity_tweens = []

	for x in range(game_manager.GRID_WIDTH):
		# Determine which rows are "barriers" — inactive (-1), hard unmovables, or spreaders.
		# Barriers divide the column into independent gravity segments.
		var is_barrier: Array = []
		for y in range(game_manager.GRID_HEIGHT):
			var tile = tiles_ref[x][y] if x < tiles_ref.size() and y < tiles_ref[x].size() else null
			var blocked = game_manager.is_cell_blocked(x, y)
			var unmovable = tile != null and not tile.is_queued_for_deletion() and \
				"is_unmovable_hard" in tile and tile.is_unmovable_hard
			var is_spreader_cell = game_manager.get_tile_at(Vector2(x, y)) == game_manager.SPREADER
			is_barrier.append(blocked or unmovable or is_spreader_cell)

		# Collect visual tiles per segment (contiguous non-barrier rows), top-to-bottom order.
		var segment_tiles: Array = []
		var seg_start := -1
		for y in range(game_manager.GRID_HEIGHT):
			if is_barrier[y]:
				if seg_start >= 0:
					var seg: Array = []
					for sy in range(seg_start, y):
						var tile = tiles_ref[x][sy] if x < tiles_ref.size() and sy < tiles_ref[x].size() else null
						if tile != null and not tile.is_queued_for_deletion():
							seg.append(tile)
						if x < tiles_ref.size() and sy < tiles_ref[x].size():
							tiles_ref[x][sy] = null
					segment_tiles.append(seg)
					seg_start = -1
			else:
				if seg_start < 0:
					seg_start = y
		if seg_start >= 0:
			var seg: Array = []
			for sy in range(seg_start, game_manager.GRID_HEIGHT):
				var tile = tiles_ref[x][sy] if x < tiles_ref.size() and sy < tiles_ref[x].size() else null
				if tile != null and not tile.is_queued_for_deletion():
					seg.append(tile)
				if x < tiles_ref.size() and sy < tiles_ref[x].size():
					tiles_ref[x][sy] = null
			segment_tiles.append(seg)

		# Reassign tiles top-to-bottom, advancing segment only on first barrier row of each run.
		var seg_index := 0
		var tile_index := 0
		var current_seg: Array = segment_tiles[0] if segment_tiles.size() > 0 else []
		var prev_was_barrier := true

		for y in range(game_manager.GRID_HEIGHT):
			if is_barrier[y]:
				if not prev_was_barrier:
					if tile_index < current_seg.size():
						print("[GRAVITY] Column ", x, " segment has ", current_seg.size() - tile_index, " extra tiles - freeing them")
						for i in range(tile_index, current_seg.size()):
							var extra = current_seg[i]
							if extra and not extra.is_queued_for_deletion():
								extra.queue_free()
					seg_index += 1
					tile_index = 0
					current_seg = segment_tiles[seg_index] if seg_index < segment_tiles.size() else []
				prev_was_barrier = true
				continue
			prev_was_barrier = false

			var tile_type = game_manager.get_tile_at(Vector2(x, y))
			if tile_type > 0:
				if tile_index < current_seg.size():
					var tile = current_seg[tile_index]
					if x < tiles_ref.size() and y < tiles_ref[x].size():
						tiles_ref[x][y] = tile
					tile.grid_position = Vector2(x, y)
					tile.update_type(tile_type)
					var target_pos = gameboard.grid_to_world_position(Vector2(x, y))
					if tile.position.distance_to(target_pos) > 1:
						gravity_tweens.append(tile.animate_to_position(target_pos))
					tile_index += 1
				else:
					print("[GRAVITY] Position (", x, ",", y, ") needs tile type ", tile_type, " but no visual tile available")

		if tile_index < current_seg.size():
			print("[GRAVITY] Column ", x, " last segment has ", current_seg.size() - tile_index, " extra tiles - freeing them")
			for i in range(tile_index, current_seg.size()):
				var extra = current_seg[i]
				if extra and not extra.is_queued_for_deletion():
					extra.queue_free()

	if gravity_tweens.size() > 0:
		for tween in gravity_tweens:
			if tween != null:
				await tween.finished
	else:
		await gameboard.get_tree().create_timer(0.01).timeout

	if gameboard.has_method("_check_collectibles_at_bottom"):
		gameboard._check_collectibles_at_bottom()
	print("Gravity complete")

static func animate_refill(game_manager: Node, gameboard: Node, tiles_ref: Array) -> Array:
	var new_tile_positions = game_manager.fill_empty_spaces()
	var spawn_tweens = []
	var scale_factor = gameboard.tile_size / 64.0

	# Add any positions that have grid data but no visual tile (gap-fill safety net).
	var positions_needing_tiles = []
	for x in range(game_manager.GRID_WIDTH):
		for y in range(game_manager.GRID_HEIGHT):
			if game_manager.is_cell_blocked(x, y):
				continue
			var existing = tiles_ref[x][y] if x < tiles_ref.size() and y < tiles_ref[x].size() else null
			if existing != null and not existing.is_queued_for_deletion() and \
					"is_unmovable_hard" in existing and existing.is_unmovable_hard:
				continue
			var grid_value = game_manager.get_tile_at(Vector2(x, y))
			if grid_value > 0:
				var has_visual = existing != null and is_instance_valid(existing)
				if not has_visual:
					var pos_vec = Vector2(x, y)
					if not new_tile_positions.has(pos_vec):
						print("[REFILL] Position (", x, ",", y, ") has grid value ", grid_value, " but no visual — adding to spawn list")
						positions_needing_tiles.append(pos_vec)
	for pos in positions_needing_tiles:
		if not new_tile_positions.has(pos):
			new_tile_positions.append(pos)

	for pos in new_tile_positions:
		var x = int(pos.x)
		var y = int(pos.y)
		if game_manager.is_cell_blocked(x, y):
			continue
		var cur = tiles_ref[x][y] if x < tiles_ref.size() and y < tiles_ref[x].size() else null
		if cur != null and not cur.is_queued_for_deletion() and \
				"is_unmovable_hard" in cur and cur.is_unmovable_hard:
			print("[REFILL] Skipping unmovable at (", x, ",", y, ")")
			continue
		if cur != null:
			if not cur.is_queued_for_deletion():
				print("[REFILL] WARNING: Tile already exists at (", x, ",", y, ") - freeing old tile")
				cur.queue_free()
			tiles_ref[x][y] = null

		var tile_type = game_manager.get_tile_at(pos)
		var tile = gameboard.tile_scene.instantiate()
		if tile_type == game_manager.COLLECTIBLE:
			tile.setup(0, pos, scale_factor)
			if tile.has_method("configure_collectible"):
				tile.configure_collectible(game_manager.collectible_type)
		else:
			tile.setup(tile_type, pos, scale_factor)

		# Spawn from just above the top of this tile's segment (barrier-aware).
		var segment_top_row: int = y
		for sy in range(y - 1, -1, -1):
			if game_manager.is_cell_blocked(x, sy):
				break
			var st: Node = tiles_ref[x][sy] if x < tiles_ref.size() and sy < tiles_ref[x].size() else null
			if st != null and not st.is_queued_for_deletion():
				if ("is_unmovable_hard" in st and st.is_unmovable_hard) or \
						("is_spreader" in st and st.is_spreader):
					break
			segment_top_row = sy
		tile.position = gameboard.grid_to_world_position(Vector2(x, segment_top_row - 1))
		tile.connect("tile_clicked", Callable(gameboard, "_on_tile_clicked"))
		tile.connect("tile_swiped", Callable(gameboard, "_on_tile_swiped"))
		if gameboard.board_container:
			gameboard.board_container.add_child(tile)
		else:
			gameboard.add_child(tile)
		if x < tiles_ref.size() and y < tiles_ref[x].size():
			tiles_ref[x][y] = tile
		var target_pos = gameboard.grid_to_world_position(pos)
		var pos_tween = tile.animate_to_position(target_pos)
		var spawn_tween = tile.animate_spawn()
		if pos_tween:
			spawn_tweens.append(pos_tween)
		if spawn_tween:
			spawn_tweens.append(spawn_tween)

	var valid_tweens = spawn_tweens.filter(func(tw): return tw != null)
	if valid_tweens.size() > 0:
		await valid_tweens[0].finished
	else:
		await gameboard.get_tree().create_timer(0.3).timeout

	print("Refill complete")
	return new_tile_positions

static func deferred_gravity_then_refill(game_manager: Node, gameboard: Node, tiles_ref: Array) -> void:
	if game_manager.has_method("apply_gravity"):
		game_manager.apply_gravity()
	if game_manager.has_method("fill_empty_spaces"):
		game_manager.fill_empty_spaces()
	return
