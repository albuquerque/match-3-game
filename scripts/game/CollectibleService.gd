extends Node
# CollectibleService — loaded as a script resource (via CS var in GameBoard), not instanced directly

## CollectibleService — collectible detection, fly-to-HUD animation, and scoring.
## Step 7 of GameBoard Round 3 refactor.
## Methods are static; call with the GameBoard node as first argument.

static func check_collectibles_at_bottom(board: Node, tiles_ref: Array) -> void:
	## Scan all columns for collectibles at their bottom-most active row.
	## Plays the fly-to-HUD animation, clears the tile, and notifies GameManager.
	## After collecting, triggers gravity → refill → cascade on the board.
	var collectibles_to_remove = []

	for x in range(GameManager.GRID_WIDTH):
		var last_active_row = -1
		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
			if not GameManager.is_cell_blocked(x, y):
				last_active_row = y
				break

		if last_active_row == -1:
			continue
		if x >= tiles_ref.size() or last_active_row >= tiles_ref[x].size():
			continue

		var tile = tiles_ref[x][last_active_row]
		if tile and tile.is_collectible and not tile.collectible_collected_flag:
			print("[CollectibleService] Collectible at (", x, ",", last_active_row, ")")
			collectibles_to_remove.append({"tile": tile, "pos": Vector2(x, last_active_row)})

	if collectibles_to_remove.size() == 0:
		return

	for item in collectibles_to_remove:
		var tile            = item["tile"]
		var pos: Vector2    = item["pos"]
		var coll_type: String = tile.collectible_type if tile else "coin"

		if tile and tile.has_method("mark_collected"):
			tile.mark_collected()

		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("coin_collect")

		var particles = CPUParticles2D.new()
		particles.name         = "CollectionParticles"
		particles.position     = tile.position if tile else board.grid_to_world_position(pos)
		particles.emitting     = true
		particles.one_shot     = true
		particles.amount       = 30
		particles.lifetime     = 0.8
		particles.explosiveness = 1.0
		board.add_child(particles)

		if tile and is_instance_valid(tile):
			var viewport    = board.get_viewport()
			var screen_size = viewport.get_visible_rect().size if viewport else Vector2(720, 1280)
			var target_pos  = Vector2(screen_size.x - 100, 100)
			var tween       = board.create_tween()
			tween.set_parallel(true)
			tween.tween_property(tile, "global_position", target_pos, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			tween.tween_property(tile, "scale", Vector2(0.5, 0.5), 0.6)
			tween.tween_property(tile, "modulate:a", 0.0, 0.4).set_delay(0.2)
			board.get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
			await tween.finished
		else:
			await board.get_tree().create_timer(0.6).timeout
			particles.queue_free()

		tiles_ref[int(pos.x)][int(pos.y)] = null
		GameManager.grid[int(pos.x)][int(pos.y)] = 0

		if tile and is_instance_valid(tile):
			tile.queue_free()

		if GameManager.has_method("collectible_landed_at"):
			GameManager.collectible_landed_at(pos, coll_type)

		print("[CollectibleService] Collected ", coll_type, " at ", pos)

	if GameManager.level_transitioning:
		return

	await board.animate_gravity()
	await board.animate_refill()

	var new_matches = GameManager.find_matches() if GameManager.has_method("find_matches") else []
	if new_matches.size() > 0:
		await board.process_cascade()

static func spawn_level_collectibles() -> void:
	if GameManager.has_method("spawn_collectibles_for_targets"):
		GameManager.call("spawn_collectibles_for_targets")
		print("[CollectibleService] Spawned collectibles for level")
