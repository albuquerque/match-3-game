extends Node
## LevelLoader — owns all level-data fetching, field extraction, theme application,
## unmovable/spreader texture mapping, and ObjectiveManager wiring.
## Works with LevelManager.LevelData objects (typed inner class — NOT a Dictionary).

# Injected by GameManager
var gm: Node = null

func setup(game_manager: Node) -> void:
	gm = game_manager

# ─── Public API ──────────────────────────────────────────────────────────────

func load_level() -> bool:
	## Fetch and apply current level data. Returns true on success, false on fallback.
	var level_data = await _fetch_level_data()
	if level_data:
		_apply_level_data(level_data)
		return true
	else:
		_apply_fallback()
		return false

# ─── Private: fetch ───────────────────────────────────────────────────────────

func _fetch_level_data():
	## Wait for LevelManager to be ready then fetch current level. Returns null on timeout.
	var lm = gm.level_manager
	if not lm or lm.levels.size() == 0:
		var attempts = 0
		while (not lm or lm.levels.size() == 0) and attempts < 40:
			lm = gm.NodeResolverAPI._get_lm()
			gm.level_manager = lm
			await gm.get_tree().create_timer(0.05).timeout
			attempts += 1
		if not lm:
			return null
	return lm.get_current_level()

# ─── Private: apply ───────────────────────────────────────────────────────────

func _apply_level_data(ld) -> void:
	## Write all LevelData fields onto GameManager vars, build grid, init objectives.
	## ld is a LevelManager.LevelData object — access fields directly, not via .get()/.has()
	gm.GRID_WIDTH   = ld.width
	gm.GRID_HEIGHT  = ld.height
	gm.target_score = ld.target_score
	gm.moves_left   = ld.moves
	gm.level        = ld.level_number

	# Collectible config — all fields exist on LevelData with defaults
	gm.collectible_target     = ld.collectible_target
	gm.collectible_type       = ld.collectible_type
	gm.collectibles_collected = 0

	# Unmovable config
	gm.unmovable_type    = ld.unmovable_type
	gm.unmovable_target  = ld.unmovable_target
	gm.unmovables_cleared = 0

	# Spreader config
	gm.spreader_grace_default = ld.spreader_grace_moves
	gm.max_spreaders          = ld.max_spreaders
	gm.spreader_spread_limit  = ld.spreader_spread_limit
	gm.use_spreader_objective = ld.spreader_target > 0
	gm.spreader_type          = ld.spreader_type
	gm.spreader_count         = 0

	# Apply theme
	_apply_theme(ld.theme)

	# Build grid from layout
	gm.create_empty_grid()
	gm.fill_grid_from_layout(ld.grid_layout)

	# Wire ObjectiveManager
	_init_objective_manager(ld)

	# Attach hard_textures / hard_reveals to unmovable_map entries
	_attach_hard_textures(ld.hard_textures, ld.hard_reveals)

	# Spreader textures map
	gm.spreader_textures_map = ld.spreader_textures if typeof(ld.spreader_textures) == TYPE_DICTIONARY else {}

	gm.initialized = true
	print("[LevelLoader] Level %d loaded — %dx%d, target=%d, moves=%d" % [
		gm.level, gm.GRID_WIDTH, gm.GRID_HEIGHT, gm.target_score, gm.moves_left])

func _apply_fallback() -> void:
	## Apply hard-coded defaults when no level data is available.
	gm.GRID_WIDTH    = 8
	gm.GRID_HEIGHT   = 8
	gm.target_score  = 10000
	gm.moves_left    = 30
	if gm.theme_manager:
		gm.theme_manager.set_theme_by_name("modern")
	gm.create_empty_grid()
	gm.fill_initial_grid()
	gm.initialized = true
	print("[LevelLoader] No level data — using fallback 8x8 grid")

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _apply_theme(theme_name: String) -> void:
	if not gm.theme_manager:
		return
	if theme_name != "" and theme_name != null:
		gm.theme_manager.set_theme_by_name(theme_name)
	else:
		gm.theme_manager.set_theme_by_name("legacy" if gm.level % 2 == 1 else "modern")

func _init_objective_manager(ld) -> void:
	if gm.ObjectiveManagerScript == null:
		return
	var omscript = gm.ObjectiveManagerScript
	var om = null
	if omscript is Script and omscript.has_method("new"):
		om = omscript.new()
	elif omscript is PackedScene:
		om = omscript.instantiate()
	if om != null and om.has_method("initialize"):
		om.initialize(ld)
		gm.objective_manager_ref = om
		print("[LevelLoader] ObjectiveManager initialized")

func _attach_hard_textures(ht_map: Dictionary, hr_map: Dictionary) -> void:
	if ht_map.size() == 0 and hr_map.size() == 0:
		return
	for key in gm.unmovable_map.keys():
		var entry = gm.unmovable_map[key]
		if typeof(entry) != TYPE_DICTIONARY or not entry.get("hard", false):
			continue
		var htype: String = entry.get("type", "")
		if htype == "":
			continue
		if ht_map.has(htype):
			entry["textures"] = ht_map[htype]
		if hr_map.has(htype):
			entry["reveals"] = hr_map[htype]
