extends Node
const _GQS = preload("res://games/match3/board/services/GridQueryService.gd")
const SHARD_COLLECTIBLE_TYPE := "shard"

static var _Bridge = null
static func _get_bridge():
	if _Bridge == null:
		_Bridge = load("res://games/match3/services/GameStateBridge.gd")
		if _Bridge != null:
			print("[CollectibleService] GameStateBridge loaded")
	return _Bridge

## CollectibleService — collectible detection, fly-to-HUD animation, and scoring.
## Step 7 of GameBoard Round 3 refactor.
## Methods are static; call with the GameBoard node as first argument.

static func check_collectibles_at_bottom(board: Node, tiles_ref: Array) -> void:
	## Scan all columns for collectibles at their bottom-most active row.
	## Plays the fly-to-HUD animation, clears the tile, and updates GameRunState.
	## After collecting, triggers gravity → refill → cascade on the board.
	var collectibles_to_remove = []

	for x in range(GameRunState.GRID_WIDTH):
		var last_active_row = -1
		for y in range(GameRunState.GRID_HEIGHT - 1, -1, -1):
			if not _GQS.is_cell_blocked(null, x, y):
				last_active_row = y
				break

		if last_active_row == -1:
			continue
		# Diagnostic: log per-column last_active_row and tiles array sizes
		print("[CollectibleService] Column %d last_active_row=%d tiles_ref.size=%d row_size=%d" % [x, last_active_row, tiles_ref.size(), (tiles_ref[x].size() if x < tiles_ref.size() else 0)])
		if x >= tiles_ref.size() or last_active_row >= tiles_ref[x].size():
			continue

		var tile = tiles_ref[x][last_active_row]
		# Diagnostic: log tile collectible status even if not collectible so we can trace failed collections
		if tile:
			var meta_shard = ""
			if tile.has_meta("shard_item_id"):
				meta_shard = str(tile.get_meta("shard_item_id"))
			print("[CollectibleService] Tile at (%d,%d): is_collectible=%s collectible_type=%s collected_flag=%s shard_meta=%s" % [x, last_active_row, str(tile.is_collectible), str(tile.collectible_type), str(tile.collectible_collected_flag), meta_shard])
		else:
			print("[CollectibleService] No tile instance at (%d,%d)" % [x, last_active_row])
			# Fallback: if model says this cell is a collectible, create a visual so it can be collected
			var grid_val = _GQS.get_tile_at(null, Vector2(x, last_active_row))
			if grid_val == GameRunState.COLLECTIBLE:
				print("[CollectibleService] Fallback: spawning collectible visual at (%d,%d) due to model flag" % [x, last_active_row])
				if board and board.has_method("spawn_collectible_visual"):
					board.spawn_collectible_visual(x, last_active_row, SHARD_COLLECTIBLE_TYPE)
					# attempt to re-resolve tile reference
					if x < tiles_ref.size() and last_active_row < tiles_ref[x].size():
						tile = tiles_ref[x][last_active_row]
				else:
					# try to find the tile from board.tiles if available
					if board and board.tiles and x < board.tiles.size() and last_active_row < board.tiles[x].size():
						tile = board.tiles[x][last_active_row]
				# if still null, attempt manual instantiate as last resort
				if tile == null and board and board.tile_scene:
					var new_tile = board.tile_scene.instantiate()
					new_tile.setup(0, Vector2(x, last_active_row), board.tile_size / 64.0)
					if new_tile.has_method("configure_collectible"):
						new_tile.configure_collectible(SHARD_COLLECTIBLE_TYPE)
					if board.board_container:
						board.board_container.add_child(new_tile)
					else:
						board.add_child(new_tile)
					while tiles_ref.size() <= x:
						tiles_ref.append([])
					while tiles_ref[x].size() <= last_active_row:
						tiles_ref[x].append(null)
					tiles_ref[x][last_active_row] = new_tile
					tile = new_tile
					# If GameRunState has pending_shard_cells mapping, attach the item_id to the new tile
					if GameRunState.pending_shard_cells and typeof(GameRunState.pending_shard_cells) == TYPE_DICTIONARY:
						var pend_map: Dictionary = GameRunState.pending_shard_cells
						var key_str := str(int(x)) + "," + str(int(last_active_row))
						if pend_map.has(key_str):
							var pending_id := str(pend_map[key_str])
							new_tile.set_meta("shard_item_id", pending_id)
							print("[CollectibleService] Attached pending shard_item_id=%s to spawned tile at (%d,%d)" % [pending_id, x, last_active_row])
							# remove pending key to avoid future duplication
							pend_map.erase(key_str)
							GameRunState.pending_shard_cells = pend_map
							print("[CollectibleService] Updated GameRunState.pending_shard_cells after attach")
					print("[CollectibleService] Fallback spawned tile instance at (%d,%d) -> %s" % [x, last_active_row, str(tile)])

		if tile and tile.is_collectible and not tile.collectible_collected_flag:
			print("[CollectibleService] Collectible at (", x, ",", last_active_row, ")")
			collectibles_to_remove.append({"tile": tile, "pos": Vector2(x, last_active_row)})

	if collectibles_to_remove.size() == 0:
		# No visual collectibles detected; perform a model-based fallback to collect any bottom-row collectibles
		for x2 in range(GameRunState.GRID_WIDTH):
			var last_row = -1
			for y2 in range(GameRunState.GRID_HEIGHT - 1, -1, -1):
				if not _GQS.is_cell_blocked(null, x2, y2):
					last_row = y2
					break
			if last_row == -1:
				continue
			# If model indicates a collectible here but no visual was appended, process it logically
			var gv = _GQS.get_tile_at(null, Vector2(x2, last_row))
			if gv == GameRunState.COLLECTIBLE:
				print("[CollectibleService] Fallback model-collect at (%d,%d) detected (no visual)" % [x2, last_row])
				# Clear grid model immediately
				GameRunState.grid[x2][last_row] = 0
				# Notify bridge/game manager for parity
				var br2 = _get_bridge()
				if br2 != null:
					br2.collectible_landed_at(Vector2(x2, last_row), "shard")
				# Try to resolve item_id from pending_shard_cells on GameRunState
				var item_id_fallback := ""
				if GameRunState.pending_shard_cells and typeof(GameRunState.pending_shard_cells) == TYPE_DICTIONARY:
					var pend = GameRunState.pending_shard_cells
					var key2 = str(x2) + "," + str(last_row)
					if pend.has(key2):
						item_id_fallback = str(pend[key2])
						pend.erase(key2)
						GameRunState.pending_shard_cells = pend
				# Directly notify GalleryManager if we have an item id
				if item_id_fallback != "" and typeof(GalleryManager) != TYPE_NIL and GalleryManager != null:
					print("[CollectibleService] Fallback: directly adding shard to GalleryManager for %s at %s" % [item_id_fallback, str(Vector2(x2, last_row))])
					GalleryManager.add_shard(item_id_fallback)
		# End fallback loop
		return

	for item in collectibles_to_remove:
		var tile            = item["tile"]
		var pos: Vector2    = item["pos"]
		var coll_type: String = tile.collectible_type if tile else "coin"

		if tile and tile.has_method("mark_collected"):
			tile.mark_collected()
		else:
			# ensure flag is set to avoid duplicate collects
			if tile:
				tile.collectible_collected_flag = true

		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("coin_collect")

		# Clear grid state immediately — don't wait for the animation
		tiles_ref[int(pos.x)][int(pos.y)] = null
		GameRunState.grid[int(pos.x)][int(pos.y)] = 0

		# Notify game systems immediately so shard/objective logic fires at once
		if coll_type == "shard":
			var item_id: String = ""
			if tile and tile.has_meta("shard_item_id"):
				item_id = str(tile.get_meta("shard_item_id"))
			# Fallback: try to resolve item_id from GameRunState.pending_shard_cells if not present on the tile
			if item_id.is_empty() and GameRunState.pending_shard_cells and typeof(GameRunState.pending_shard_cells) == TYPE_DICTIONARY:
				var pend_map: Dictionary = GameRunState.pending_shard_cells
				var key_str := str(int(pos.x)) + "," + str(int(pos.y))
				if pend_map.has(key_str):
					item_id = str(pend_map[key_str])
					pend_map.erase(key_str)
					GameRunState.pending_shard_cells = pend_map
					print("[CollectibleService] Fallback resolved item_id=%s from GameRunState.pending_shard_cells for pos=%s" % [item_id, str(pos)])
			# If we're currently mid-cascade, defer the GalleryManager/add_shard call until cascade completes
			if GameRunState.processing_moves:
				print("[CollectibleService] Collected shard during cascade; deferring GalleryManager.add_shard and setting pending_collectible_refill")
				# mark pending so MatchOrchestrator/GameBoard can process when cascade ends
				GameRunState.pending_collectible_refill = true
				# store item id on GameRunState for post-cascade processing if available
				if item_id != "":
					if not GameRunState.pending_shard_cells:
						GameRunState.pending_shard_cells = {}
					GameRunState.pending_shard_cells[str(int(pos.x)) + "," + str(int(pos.y))] = item_id
				# do not call GalleryManager here to avoid duplicate popups
			else:
				# Not processing_moves — safe to notify now
				if not item_id.is_empty():
					print("[CollectibleService] Emitting shard notification immediately for %s" % item_id)
					if board and board.has_signal and board.has_signal("shard_tile_collected"):
						board.emit_signal("shard_tile_collected", item_id)
					if typeof(GalleryManager) != TYPE_NIL and GalleryManager != null:
						GalleryManager.add_shard(item_id)
			# end shard handling
		else:
			# Coin/non-shard collectible — increment objective counter immediately
			GameRunState.collectibles_collected += 1
			print("[CollectibleService] Coin collected (%d/%d)" % [GameRunState.collectibles_collected, GameRunState.collectible_target])
			# Emit collectibles_changed so HUD updates
			if GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("collectibles_changed"):
				GameRunState.board_ref.emit_signal("collectibles_changed", GameRunState.collectibles_collected, GameRunState.collectible_target)
			# Notify via bridge for any legacy consumers
			var br2 = _get_bridge()
			if br2 != null and br2.has_method("collectible_landed_at"):
				br2.collectible_landed_at(pos, coll_type)
			elif GameRunState.board_ref != null and GameRunState.board_ref.has_signal and GameRunState.board_ref.has_signal("collectible_landed"):
				GameRunState.board_ref.emit_signal("collectible_landed", pos, coll_type)
			# Check for level completion after collecting — do this regardless of processing_moves
			# so boosters that clear the flag before calling us still trigger the pipeline.
			var gsb = _get_bridge()
			if gsb != null and gsb.has_method("attempt_level_complete"):
				gsb.attempt_level_complete()

		print("[CollectibleService] Collected ", coll_type, " at ", pos)

		# Schedule a deferred gravity+refill so the empty cell is filled immediately
		if board != null and board.has_method("deferred_gravity_then_refill"):
			# Avoid scheduling a separate gravity/refill while MatchOrchestrator is processing cascades
			if not GameRunState.processing_moves:
				print("[CollectibleService] Scheduling board.deferred_gravity_then_refill() to fill empties")
				board.call_deferred("deferred_gravity_then_refill")
			else:
				print("[CollectibleService] Skipping deferred_gravity_then_refill because processing_moves is true")

		# Play fly-to-HUD animation concurrently (fire-and-forget)
		var particles = CPUParticles2D.new()
		particles.name         = "CollectionParticles"
		particles.position     = tile.position if tile else board.grid_to_world_position(pos)
		particles.emitting     = true
		particles.one_shot     = true
		particles.amount       = 30
		particles.lifetime     = 0.8
		particles.explosiveness = 1.0
		board.add_child(particles)
		board.get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

		if tile and is_instance_valid(tile):
			var viewport    = board.get_viewport()
			var screen_size = viewport.get_visible_rect().size if viewport else Vector2(720, 1280)
			var target_pos  = Vector2(screen_size.x - 100, 100)
			var tween       = board.create_tween()
			tween.set_parallel(true)
			tween.tween_property(tile, "global_position", target_pos, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			tween.tween_property(tile, "scale", Vector2(0.5, 0.5), 0.6)
			tween.tween_property(tile, "modulate:a", 0.0, 0.4).set_delay(0.2)
			# Free tile after animation — no await so cascade continues immediately
			tween.finished.connect(tile.queue_free)
		else:
			if tile and is_instance_valid(tile):
				tile.queue_free()


	if GameRunState.level_transitioning:
		return
	# NOTE: Do NOT call animate_gravity/animate_refill here.
	# MatchOrchestrator's while-loop handles all gravity, refill, and cascade detection
	# after _check_collectibles_at_bottom returns. Calling them here causes re-entrant
	# cascade execution and freezes the board.

	# Final safety sweep (model-first): catch any bottom-row collectibles present in the model
	# that were missed by visual detection above. This ensures a collectible that reached the
	# bottom is collected immediately even if the visual wasn't attached or flags were stale.
	for col in range(GameRunState.GRID_WIDTH):
		# find bottom-most active row for this column (robust - prefer GridQueryService but fallback to scanning)
		var bottom_row := -1
		for ry in range(GameRunState.GRID_HEIGHT - 1, -1, -1):
			# Use GridQueryService if available to determine blocked cells (GridQueryService exposes static methods)
			var blocked := false
			if _GQS != null:
				blocked = _GQS.is_cell_blocked(null, col, ry)
			else:
				# Fallback heuristic: look for unmovable in grid
				if GameRunState.grid.size() > col and GameRunState.grid[col].size() > ry:
					if GameRunState.grid[col][ry] == GameRunState.UNMOVABLE:
						blocked = true
			if not blocked:
				bottom_row = ry
				break
		if bottom_row == -1:
			continue
		# If model says this bottom cell is a collectible, handle it
		if GameRunState.grid.size() > col and GameRunState.grid[col].size() > bottom_row and GameRunState.grid[col][bottom_row] == GameRunState.COLLECTIBLE:
			var pos := Vector2(col, bottom_row)
			# Resolve item_id from tile meta or GameRunState.pending_shard_cells
			var resolved_id := ""
			if col < tiles_ref.size() and bottom_row < tiles_ref[col].size():
				var tv = tiles_ref[col][bottom_row]
				if tv and tv.has_meta("shard_item_id"):
					resolved_id = str(tv.get_meta("shard_item_id"))
			if resolved_id == "" and GameRunState.pending_shard_cells and typeof(GameRunState.pending_shard_cells) == TYPE_DICTIONARY:
				var pend = GameRunState.pending_shard_cells
				var k = str(col) + "," + str(bottom_row)
				if pend.has(k):
					resolved_id = str(pend[k])
					pend.erase(k)
					GameRunState.pending_shard_cells = pend
			# If we have an item id, notify; else fallback-award one shard
			if resolved_id != "":
				print("[CollectibleService] Model-sweep: emitting shard_tile_collected for %s at %s" % [resolved_id, str(pos)])
				if board and board.has_signal and board.has_signal("shard_tile_collected"):
					board.emit_signal("shard_tile_collected", resolved_id)
				var brf = _get_bridge()
				if brf != null:
					brf.collectible_landed_at(pos, "shard")
				if typeof(GalleryManager) != TYPE_NIL and GalleryManager != null:
					GalleryManager.add_shard(resolved_id)
				# Clear model and schedule refill
				GameRunState.grid[int(pos.x)][int(pos.y)] = 0
				if board != null and board.has_method("deferred_gravity_then_refill"):
					if not GameRunState.processing_moves:
						board.call_deferred("deferred_gravity_then_refill")
					else:
						print("[CollectibleService] Skipping deferred_gravity_then_refill (model-sweep) because processing_moves is true")
			else:
				# No resolved id — award first available candidate so UI shows toast
				if typeof(GalleryManager) != TYPE_NIL and GalleryManager != null:
					var cand := GalleryManager.get_all_items().filter(func(it): return not bool(it.get("unlocked", false)))
					if cand and cand.size() > 0:
						var fid := str(cand[0].get("id", ""))
						print("[CollectibleService] Model-sweep fallback awarding shard to %s at %s" % [fid, str(pos)])
						GalleryManager.add_shard(fid)
						GameRunState.grid[int(pos.x)][int(pos.y)] = 0
						if board != null and board.has_method("deferred_gravity_then_refill"):
							if not GameRunState.processing_moves:
								board.call_deferred("deferred_gravity_then_refill")
							else:
								print("[CollectibleService] Skipping deferred_gravity_then_refill (model-sweep fallback) because processing_moves is true")
			# end model-sweep replacement

static func spawn_level_collectibles() -> void:
	var br = _get_bridge()
	if br != null:
		br.spawn_level_collectibles()
		print("[CollectibleService] Spawned collectibles for level via bridge")
