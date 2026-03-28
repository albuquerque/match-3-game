extends Node
# BoardInputHandler — loaded and instantiated via script resource in GameBoard._ready()

## BoardInputHandler — handles all tile click/swipe input, selection state,
## and the perform_swap coroutine.
## Step 5 of GameBoard Round 3 refactor.
## Instantiated as a child Node of GameBoard in _ready.

var board: Node = null  # Set by GameBoard after adding as child

func setup(gameboard: Node) -> void:
	board = gameboard
	print("[BoardInputHandler] setup() called — board=", board)

# ── Click handling ────────────────────────────────────────────────────────────

func handle_tile_clicked(tile) -> void:
	if not tile or not is_instance_valid(tile) or tile.is_queued_for_deletion():
		return
	print("BoardInputHandler: tile_clicked at ", tile.grid_position)

	if tile.is_unmovable:
		print("[BoardInputHandler] Clicked tile is unmovable, ignoring")
		return

	if GameRunState.processing_moves:
		print("[BoardInputHandler] Move processing blocked")
		return

	if GameRunState.level_transitioning:
		print("[BoardInputHandler] Level transitioning, clicks blocked")
		return

	# Booster mode — delegate action back to GameBoard
	var game_ui = board.get_node_or_null("../GameUI")
	if game_ui and game_ui is GameUI and game_ui.booster_mode_active:
		await _handle_booster_click(tile, game_ui)
		return

	# Special tile tap
	var tile_type = GameManager.get_tile_at(tile.grid_position)
	if tile_type >= 7 and tile_type <= 9:
		print("[BoardInputHandler] Special tile tapped at ", tile.grid_position)
		if board.selected_tile:
			board.selected_tile.set_selected(false)
			board.selected_tile = null
		await board.activate_special_tile(tile.grid_position)
		return

	# Normal selection / swap
	if board.selected_tile == null:
		board.selected_tile = tile
		tile.set_selected(true)
	elif board.selected_tile == tile:
		tile.set_selected(false)
		board.selected_tile = null
	else:
		if GameManager.can_swap(board.selected_tile.grid_position, tile.grid_position):
			await perform_swap(board.selected_tile, tile)
		else:
			board.selected_tile.set_selected(false)
			board.selected_tile = tile
			tile.set_selected(true)

func _handle_booster_click(tile, game_ui) -> void:
	var booster_type = game_ui.active_booster_type
	var gx = int(tile.grid_position.x)
	var gy = int(tile.grid_position.y)

	if booster_type == "shuffle":
		pass  # Handled by button press
	elif booster_type == "swap":
		if game_ui.swap_first_tile == null:
			game_ui.swap_first_tile = tile.grid_position
			tile.set_selected(true)
			print("[BoardInputHandler] Swap: first tile selected, waiting for second")
			return
		else:
			var first_pos  = game_ui.swap_first_tile
			var first_tile = board.tiles[int(first_pos.x)][int(first_pos.y)]
			if first_tile:
				first_tile.set_selected(false)
			await board.activate_swap_booster(int(first_pos.x), int(first_pos.y), gx, gy)
			game_ui.swap_first_tile = null
	elif booster_type == "hammer":
		await board.activate_hammer_booster(gx, gy)
	elif booster_type == "chain_reaction":
		await board.activate_chain_reaction_booster(gx, gy)
	elif booster_type == "bomb_3x3":
		await board.activate_bomb_3x3_booster(gx, gy)
	elif booster_type == "line_blast":
		await board.activate_line_blast_booster(game_ui.line_blast_direction, gx, gy)
	elif booster_type == "tile_squasher":
		await board.activate_tile_squasher_booster(gx, gy)
	elif booster_type == "row_clear":
		await board.activate_row_clear_booster(gy)
	elif booster_type == "column_clear":
		await board.activate_column_clear_booster(gx)

	# Reset booster mode unless swap is still waiting for its second tile
	if not (booster_type == "swap" and game_ui.swap_first_tile != null):
		game_ui.booster_mode_active = false
		game_ui.active_booster_type = ""
		if game_ui.has_method("deactivate_booster"):
			game_ui.deactivate_booster()
		game_ui.update_booster_ui()

# ── Swipe handling ────────────────────────────────────────────────────────────

func handle_tile_swiped(tile, direction: Vector2) -> void:
	if not tile or not is_instance_valid(tile) or tile.is_queued_for_deletion():
		return

	print("[BoardInputHandler] tile_swiped at ", tile.grid_position, " dir: ", direction)

	if tile.is_unmovable:
		return
	if GameRunState.processing_moves:
		return
	if GameRunState.level_transitioning:
		return

	if board.selected_tile:
		board.selected_tile.set_selected(false)
		board.selected_tile = null

	var target_pos = tile.grid_position + direction
	if not GameManager.is_valid_position(target_pos):
		return

	var target_tile = board.tiles[int(target_pos.x)][int(target_pos.y)]
	if not target_tile:
		return
	if target_tile.is_unmovable:
		return

	await perform_swap(tile, target_tile)

# ── Swap execution ────────────────────────────────────────────────────────────

func perform_swap(tile1, tile2) -> void:
	GameRunState.processing_moves = true
	print("[BoardInputHandler] perform_swap: start")

	tile1.set_selected(false)
	tile2.set_selected(false)
	board.selected_tile = null

	var pos1 = tile1.grid_position
	var pos2 = tile2.grid_position

	var swapped = GameManager.swap_tiles(pos1, pos2)
	if not swapped:
		AudioManager.play_sfx("invalid_move")
		var tw = board.create_tween()
		tw.tween_property(tile1, "position", tile1.position + Vector2(6, 0), 0.06)
		tw.tween_property(tile1, "position", tile1.position, 0.08)
		tw.tween_property(tile2, "position", tile2.position + Vector2(-6, 0), 0.06)
		tw.tween_property(tile2, "position", tile2.position, 0.08)
		if tw:
			await tw.finished
		GameRunState.processing_moves = false
		print("[BoardInputHandler] perform_swap: denied")
		return

	AudioManager.play_sfx("tile_swap")

	var target_pos1 = board.grid_to_world_position(pos2)
	var target_pos2 = board.grid_to_world_position(pos1)

	var tween1 = tile1.animate_swap_to(target_pos1)
	var tween2 = tile2.animate_swap_to(target_pos2)

	board.tiles[pos1.x][pos1.y] = tile2
	board.tiles[pos2.x][pos2.y] = tile1
	tile1.grid_position = pos2
	tile2.grid_position = pos1

	if tween1: await tween1.finished
	if tween2: await tween2.finished

	var matches = GameManager.find_matches()
	if matches.size() > 0:
		GameManager.use_move()

		var swap_pos_in_match = Vector2(-1, -1)
		if pos1 in matches:
			swap_pos_in_match = pos1
		elif pos2 in matches:
			swap_pos_in_match = pos2
		else:
			var fallback = board.find_special_tile_position_in_matches(matches)
			if fallback.x >= 0:
				swap_pos_in_match = fallback

		await board.process_cascade(swap_pos_in_match)
		GameRunState.processing_moves = false
		print("[BoardInputHandler] perform_swap: matched, cascade done")
	else:
		# Revert
		GameManager.swap_tiles(pos1, pos2)

		var rt1 = tile1.animate_swap_to(target_pos2)
		var rt2 = tile2.animate_swap_to(target_pos1)

		board.tiles[pos1.x][pos1.y] = tile1
		board.tiles[pos2.x][pos2.y] = tile2
		tile1.grid_position = pos1
		tile2.grid_position = pos2

		if rt1: await rt1.finished
		if rt2: await rt2.finished

		GameRunState.processing_moves = false
		print("[BoardInputHandler] perform_swap: no match, reverted")
