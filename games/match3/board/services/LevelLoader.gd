extends Node
## LevelLoader — owns level-data fetching, field extraction, theme application,
## unmovable/spreader texture mapping, and ObjectiveManager wiring.
## Works with LevelManager.LevelData objects (typed inner class — NOT a Dictionary).


# Public API
func load_level() -> bool:
	# Fetch and apply current level data. Returns true on success, false on fallback.
	var level_data = await _fetch_level_data()
	if level_data:
		_apply_level_data(level_data)
		return true
	else:
		_apply_fallback()
		return false

# Private: fetch
func _fetch_level_data():
	# Try to resolve LevelManager via NodeResolvers (preferred). Wait for it to become available.
	var nr = load("res://scripts/helpers/node_resolvers.gd")
	var lm = null
	if nr != null:
		lm = nr._get_lm()
	# Wait briefly for LevelManager readiness (up to ~2s)
	var attempts = 0
	while (lm == null or not lm.has_method("get_current_level")) and attempts < 40:
		if nr != null:
			lm = nr._get_lm()
		await get_tree().create_timer(0.05).timeout
		attempts += 1
	if lm == null:
		return null
	return lm.get_current_level()

# Private: apply
func _apply_level_data(ld) -> void:
	# Populate GameRunState with LevelData fields.
	GameRunState.GRID_WIDTH = int(ld.width)
	GameRunState.GRID_HEIGHT = int(ld.height)
	GameRunState.target_score = int(ld.target_score)
	GameRunState.moves_left = int(ld.moves)
	GameRunState.level = int(ld.level_number)

	# Collectible config
	GameRunState.collectible_target = int(ld.collectible_target)
	GameRunState.collectible_type = str(ld.collectible_type)
	GameRunState.collectibles_collected = 0

	# Unmovable config
	GameRunState.unmovable_type = str(ld.unmovable_type)
	GameRunState.unmovable_target = int(ld.unmovable_target)
	GameRunState.unmovables_cleared = 0

	# Spreader config
	GameRunState.spreader_grace_default = int(ld.spreader_grace_moves)
	GameRunState.max_spreaders = int(ld.max_spreaders)
	GameRunState.spreader_spread_limit = int(ld.spreader_spread_limit)
	GameRunState.use_spreader_objective = (int(ld.spreader_target) > 0)
	GameRunState.spreader_type = str(ld.spreader_type)
	GameRunState.spreader_count = 0

	# Apply theme via ThemeManager (resolve via NodeResolvers)
	_apply_theme(ld.theme)

	# Build grid using GameState.fill_from_layout() so 0-cells get randomised tile types
	# and collectibles/unmovables/spreaders are populated correctly.
	var gs_script = load("res://meta/profile/GameState.gd")
	if gs_script != null:
		var gs = gs_script.new(GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.TILE_TYPES)
		if ld.grid_layout != null:
			var _result = gs.fill_from_layout(ld.grid_layout)
			GameRunState.grid = gs.grid
			# Merge unmovable_map: take entries from GameState fill, then overlay hard textures
			GameRunState.unmovable_map = gs.unmovable_map
			# Copy spreader tracking arrays — without this spreader_count stays 0 and
			# the first destroy immediately (incorrectly) triggers level completion.
			GameRunState.spreader_positions = gs.spreader_positions.duplicate()
			GameRunState.spreader_count    = gs.spreader_count
		else:
			# No layout — generate a fully random grid
			gs.create_empty_grid()
			for x in range(GameRunState.GRID_WIDTH):
				for y in range(GameRunState.GRID_HEIGHT):
					gs.grid[x][y] = gs.get_safe_random_tile(x, y)
			GameRunState.grid = gs.grid
	else:
		# Fallback: plain copy (tile types remain 0, but at least grid exists)
		push_error("[LevelLoader] Could not load GameState script for grid randomisation")
		GameRunState.grid = []
		for x in range(GameRunState.GRID_WIDTH):
			var col = []
			for y in range(GameRunState.GRID_HEIGHT):
				col.append(0)
			GameRunState.grid.append(col)
		if ld.grid_layout != null:
			for x in range(min(GameRunState.GRID_WIDTH, ld.grid_layout.size())):
				for y in range(min(GameRunState.GRID_HEIGHT, ld.grid_layout[x].size())):
					GameRunState.grid[x][y] = int(ld.grid_layout[x][y])

	# Wire ObjectiveManager (attach as child of GameRunState for lifecycle)
	_init_objective_manager(ld)

	# Attach hard_textures / hard_reveals to unmovable_map entries
	_attach_hard_textures(ld.hard_textures, ld.hard_reveals)

	# Spreader textures map
	GameRunState.spreader_textures_map = ld.spreader_textures if typeof(ld.spreader_textures) == TYPE_DICTIONARY else {}

	GameRunState.initialized = true
	# Select boosters for this level using BoosterSelector
	var bs_script = load("res://games/match3/board/services/BoosterSelector.gd")
	if bs_script != null:
		GameRunState.available_boosters = bs_script.select(GameRunState.level)
	else:
		GameRunState.available_boosters = ["hammer", "shuffle", "swap"]
	print("[LevelLoader] Level %d loaded — %dx%d, target=%d, moves=%d, boosters=%s" % [GameRunState.level, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.target_score, GameRunState.moves_left, str(GameRunState.available_boosters)])

func _apply_fallback() -> void:
	# Apply hard-coded defaults when no level data is available.
	GameRunState.GRID_WIDTH = 8
	GameRunState.GRID_HEIGHT = 8
	GameRunState.target_score = 10000
	GameRunState.moves_left = 30
	var nr = load("res://scripts/helpers/node_resolvers.gd")
	var tm = null
	if nr != null:
		tm = nr._get_tm()
	if tm:
		tm.set_theme_by_name("modern")
	# create empty grid
	GameRunState.grid = []
	for x in range(GameRunState.GRID_WIDTH):
		var col = []
		for y in range(GameRunState.GRID_HEIGHT):
			col.append(0)
		GameRunState.grid.append(col)
	GameRunState.initialized = true
	print("[LevelLoader] No level data — using fallback 8x8 grid")

# Helpers
func _apply_theme(theme_name: String) -> void:
	# Minimal no-op to avoid parse-time complexity during migration.
	# Theme application will be handled by ThemeManager elsewhere.
	return

func _init_objective_manager(ld) -> void:
	var omscript = load("res://games/match3/board/services/ObjectiveManager.gd")
	if omscript == null:
		return
	var om = null
	if omscript is PackedScene:
		om = omscript.instantiate()
	elif omscript is Script:
		om = omscript.new()
	if om == null:
		push_error("[LevelLoader] Failed to instantiate ObjectiveManager")
		return
	# Attach ObjectiveManager under GameRunState so it lives in the autoload tree
	if om is Node:
		var prev = GameRunState.get_node_or_null("ObjectiveManager")
		if prev:
			prev.queue_free()
		om.name = "ObjectiveManager"
		GameRunState.add_child(om)
	if om.has_method("initialize"):
		om.initialize(ld)
	GameRunState.objective_manager_ref = om
	print("[LevelLoader] ObjectiveManager initialized")

func _attach_hard_textures(ht_map: Dictionary, hr_map: Dictionary) -> void:
	if ht_map == null or hr_map == null:
		return
	# Apply to GameRunState.unmovable_map (primary)
	for key in GameRunState.unmovable_map.keys():
		var entry = GameRunState.unmovable_map[key]
		if typeof(entry) != TYPE_DICTIONARY or not entry.get("hard", false):
			continue
		var htype: String = entry.get("type", "")
		if htype == "":
			continue
		if ht_map.has(htype):
			entry["textures"] = ht_map[htype]
		if hr_map.has(htype):
			entry["reveals"] = hr_map[htype]
	return
