extends Node

# Note: GameManager is exposed via autoload (project settings). Avoid declaring `class_name GameManager` here
# to prevent hiding the autoload singleton during script parsing.

signal score_changed(new_score)
signal level_changed(new_level)
signal moves_changed(moves_left)
signal game_over
signal level_complete
signal level_failed(level_id: String, context: Dictionary)
signal level_loaded
signal level_loaded_ctx(level_id: String, context: Dictionary)  # PR 5c: carries context
signal collectibles_changed(collected, target)
signal remove_matches_done(tiles_removed)
signal gravity_applied(moved)
signal fill_complete(created_positions)
# PR 5c: direct signals replacing EventBus traffic
signal match_cleared(match_size: int, context: Dictionary)
signal special_tile_activated(entity_id: String, context: Dictionary)
signal pre_refill()
signal post_refill()
signal shard_tile_collected(item_id: String)

# Game configuration
var NodeResolverAPI = null
var SpecialFactory = null
var MatchProcessor = null
var GravityService = null
var GQS = null  # GridQueryService

# ObjectiveManager integration
var ObjectiveManagerScript = null
var objective_manager_ref: Node = null

# C1: GameFlowController — owns level-complete / fail / bonus-cascade logic
var _flow_ctrl: Node = null

# D1: LevelLoader — owns level data fetching and field extraction
var _level_loader: Node = null

# D2: BoosterSelector script reference (static methods only)
var _booster_selector = null

func _init_resolvers():
	if NodeResolverAPI == null:
		NodeResolverAPI = load("res://scripts/helpers/node_resolvers_api.gd")
	if SpecialFactory == null:
		SpecialFactory = load("res://scripts/game/SpecialFactory.gd")
	if MatchProcessor == null:
		MatchProcessor = load("res://scripts/game/MatchProcessor.gd")
	if typeof(GravityService) == TYPE_NIL:
		GravityService = load("res://scripts/game/GravityService.gd")
	if GQS == null:
		GQS = load("res://scripts/game/GridQueryService.gd")
	if ObjectiveManagerScript == null:
		ObjectiveManagerScript = load("res://scripts/game/ObjectiveManager.gd")
	# C1: Instantiate GameFlowController
	if _flow_ctrl == null:
		var gfc_script = load("res://scripts/game/GameFlowController.gd")
		if gfc_script and gfc_script is Script:
			_flow_ctrl = gfc_script.new()
			_flow_ctrl.setup(self)
			add_child(_flow_ctrl)
	# D1: Instantiate LevelLoader
	if _level_loader == null:
		var ll_script = load("res://scripts/game/LevelLoader.gd")
		if ll_script and ll_script is Script:
			_level_loader = ll_script.new()
			_level_loader.setup(self)
			add_child(_level_loader)
	# D2: Load BoosterSelector (static methods only, no Node needed)
	if _booster_selector == null:
		_booster_selector = load("res://scripts/game/BoosterSelector.gd")

var GRID_WIDTH = 8
var GRID_HEIGHT = 8
const TILE_TYPES = 6
const MIN_MATCH_SIZE = 3
const HORIZTONAL_ARROW = 7
const VERTICAL_ARROW = 8
const FOUR_WAY_ARROW = 9
const COLLECTIBLE = 10  # Special type for collectibles - won't match with regular tiles
const UNMOVABLE = 11    # Sentinel stored in grid cells occupied by unmovable tiles
const SPREADER = 12     # Special type for spreader tiles - convert adjacent tiles

# Scoring
const POINTS_PER_TILE = 100
const COMBO_MULTIPLIER = 1.5

# Game state
var score = 0
var level = 1
var moves_left = 30
var target_score = 10000
var grid = []
var combo_count = 0
var processing_moves = false

var _pending_in_level_stage: int = -1  # deferred load_stage_for_level when NSM is locked

# Collectible tracking
var collectibles_collected = 0
var collectible_target = 0  # 0 = score-based level, >0 = collectible-based level
var collectible_type: String = "coin"  # Type of collectible for current level

# Unmovable tracking
var unmovable_type: String = "snow"  # Type of unmovable_soft for current level
var unmovables_cleared = 0  # Number of unmovable tiles destroyed
var unmovable_target = 0  # 0 = not required, >0 = must clear this many unmovables

signal unmovables_changed(cleared, target)

# Spreader clearing tracking
var use_spreader_objective: bool = false  # If true, level completes when spreader_count reaches 0
var spreader_count: int = 0  # Current number of spreaders on the board

signal spreaders_changed(current_count)

# Level system
var level_manager: Node = null

# Theme system
var theme_manager: Node = null

# Add a flag to prevent multiple triggers of level completion
var level_transitioning = false

# Level completion state
var last_level_won = false
var last_level_score = 0
var last_level_target = 0
var last_level_number = 0
var last_level_moves_left = 0

# Add a flag to request level completion when score threshold is reached but animations are still running
var pending_level_complete = false

# Add a flag to request level failure when moves reach zero but cascades are still in progress
var pending_level_failed = false

# Bonus conversion tracking
var in_bonus_conversion = false

# Skip bonus tracking
var bonus_skipped = false  # Tracks if player requested to skip bonus animation

# Debugging
var DEBUG_LOGGING = true

# Flag to check if the game manager has been initialized
var initialized = false

# Booster selection system
var available_boosters: Array = []  # Boosters available for current level

# Collectibles & special layout markers
var collectible_positions: Array = []
var unmovable_map: Dictionary = {}

# Spreader tracking
var spreader_positions: Array = []  # Tracks all active spreader positions
var spreaders_destroyed_this_turn: Array = []  # Positions cleared this turn — immune from re-infection
var spreader_grace_default: int = 2  # Default grace period from level configuration
var max_spreaders: int = 20  # Maximum number of spreaders allowed on board
var spreader_spread_limit: int = 0  # Max new spreaders per move (0 = unlimited, 1 = slow spread)
var spreader_textures_map: Dictionary = {}  # Maps spreader types to texture arrays from level data
var spreader_type: String = "virus"  # Type of spreader for current level

# Booster tier definitions (for random selection)
const BOOSTER_TIERS = {
	"common": ["hammer", "shuffle", "swap"],
	"uncommon": ["chain_reaction", "bomb_3x3", "line_blast"],
	"rare": ["row_clear", "column_clear", "tile_squasher", "extra_moves"]
}

# Booster selection weights (probability distribution)
const TIER_WEIGHTS = {
	"common": 0.60,      # 60% chance
	"uncommon": 0.30,    # 30% chance
	"rare": 0.10         # 10% chance
}

# Board reference - set by GameBoard at runtime to avoid repeated get_node lookups
var board_ref: Node = null

# ── PR 5a: GameRunState delegation ───────────────────────────────────────────
## Resolve the GameRunState autoload safely (available after _ready).
func _grs() -> Node:
	return get_node_or_null("/root/GameRunState")

## Push all mutable game data to GameRunState so PR-5b call sites can read
## from GameRunState directly without any other changes.
## Call this after any batch of field mutations.
func _push_to_grs() -> void:
	var grs = _grs()
	if grs == null:
		return
	# Grid dimensions
	grs.GRID_WIDTH  = GRID_WIDTH
	grs.GRID_HEIGHT = GRID_HEIGHT
	# Core state
	grs.score        = score
	grs.level        = level
	grs.moves_left   = moves_left
	grs.target_score = target_score
	grs.grid         = grid
	grs.combo_count  = combo_count
	grs.initialized  = initialized
	# Flow flags
	grs.processing_moves       = processing_moves
	grs.level_transitioning    = level_transitioning
	grs.pending_level_complete = pending_level_complete
	grs.pending_level_failed   = pending_level_failed
	grs.in_bonus_conversion    = in_bonus_conversion
	grs.bonus_skipped          = bonus_skipped
	# Last-level snapshot
	grs.last_level_won        = last_level_won
	grs.last_level_score      = last_level_score
	grs.last_level_target     = last_level_target
	grs.last_level_number     = last_level_number
	grs.last_level_moves_left = last_level_moves_left
	# Collectibles
	grs.collectibles_collected = collectibles_collected
	grs.collectible_target     = collectible_target
	grs.collectible_type       = collectible_type
	grs.collectible_positions  = collectible_positions
	# Unmovables
	grs.unmovable_type     = unmovable_type
	grs.unmovables_cleared = unmovables_cleared
	grs.unmovable_target   = unmovable_target
	grs.unmovable_map      = unmovable_map
	# Spreaders
	grs.use_spreader_objective       = use_spreader_objective
	grs.spreader_count               = spreader_count
	grs.spreader_positions           = spreader_positions
	grs.spreaders_destroyed_this_turn = spreaders_destroyed_this_turn
	grs.spreader_grace_default       = spreader_grace_default
	grs.max_spreaders                = max_spreaders
	grs.spreader_spread_limit        = spreader_spread_limit
	grs.spreader_textures_map        = spreader_textures_map
	grs.spreader_type                = spreader_type
	# Boosters
	grs.available_boosters = available_boosters
	# Special tile request
	grs.requested_special_tile = requested_special_tile

func register_board(board: Node) -> void:
	"""Register the active GameBoard instance so GameManager can use it without scene-tree lookups.
	Also connect to board request signals to accept delegated responsibilities (remove_matches, gravity, refill).
	"""
	board_ref = board
	print("[GameManager] register_board: ", board)

	# Connect request signals from board to local handlers so GameBoard can delegate logic safely
	if board_ref:
		if board_ref.has_signal("request_remove_matches"):
			board_ref.connect("request_remove_matches", Callable(self, "_on_board_request_remove_matches"))
		if board_ref.has_signal("request_apply_gravity"):
			board_ref.connect("request_apply_gravity", Callable(self, "_on_board_request_apply_gravity"))
		if board_ref.has_signal("request_fill_empty"):
			board_ref.connect("request_fill_empty", Callable(self, "_on_board_request_fill_empty"))

func unregister_board(board: Node) -> void:
	"""Unregister the GameBoard if it matches the current registered instance and disconnect signals."""
	if board_ref == board:
		# Disconnect signals defensively
		if board_ref.has_signal("request_remove_matches") and board_ref.is_connected("request_remove_matches", Callable(self, "_on_board_request_remove_matches")):
			board_ref.disconnect("request_remove_matches", Callable(self, "_on_board_request_remove_matches"))
		if board_ref.has_signal("request_apply_gravity") and board_ref.is_connected("request_apply_gravity", Callable(self, "_on_board_request_apply_gravity")):
			board_ref.disconnect("request_apply_gravity", Callable(self, "_on_board_request_apply_gravity"))
		if board_ref.has_signal("request_fill_empty") and board_ref.is_connected("request_fill_empty", Callable(self, "_on_board_request_fill_empty")):
			board_ref.disconnect("request_fill_empty", Callable(self, "_on_board_request_fill_empty"))

		board_ref = null
		print("[GameManager] unregister_board: cleared board_ref")

func get_board() -> Node:
	# Preferred: return registered board_ref; fallback to direct scene root lookup only
	if board_ref != null:
		return board_ref
	# Fallback: try to find GameBoard node on the scene tree root
	var ml = Engine.get_main_loop()
	if ml != null and ml is SceneTree:
		var rt = ml.root
		if rt:
			var gb = rt.get_node_or_null("GameBoard")
			if gb:
				return gb
	# No reliable resolver found
	return null

func _ready():
	print("[GameManager] _ready() - initializing")
	# Initialize resolver helper at runtime (avoid parse-time preload)
	_init_resolvers()
	# Get the autoloaded LevelManager via resolver
	if typeof(NodeResolverAPI) != TYPE_NIL:
		level_manager = NodeResolverAPI._get_lm()
	else:
		# fallback to root lookup
		if has_method("get_tree"):
			var rt = get_tree().root
			if rt:
				level_manager = rt.get_node_or_null("LevelManager")
	if not level_manager:
		print("[GameManager] WARNING: LevelManager autoload not found via NodeResolvers!")

	# Get the autoloaded ThemeManager via resolver
	if typeof(NodeResolverAPI) != TYPE_NIL:
		theme_manager = NodeResolverAPI._get_tm()
	else:
		if has_method("get_tree"):
			var rt2 = get_tree().root
			if rt2:
				theme_manager = rt2.get_node_or_null("ThemeManager")
	if not theme_manager:
		print("[GameManager] WARNING: ThemeManager autoload not found via NodeResolvers!")

	# Do NOT auto-initialize the game here. The UI will present a StartPage and call initialize_game() when the
	# player explicitly starts the level
	# initialize_game()

func initialize_game():
	score = 0
	# Don't hardcode level - let load_current_level() set it from LevelManager
	combo_count = 0
	processing_moves = false
	level_transitioning = false
	# Do NOT set initialized here; set it after a level is actually loaded in load_current_level()

	print("[GameManager] initialize_game() - current score=", score, ", moves_left=", moves_left)

	# Load the first level and wait for it to finish so callers can rely on initialized
	await load_current_level()

	emit_signal("score_changed", score)
	emit_signal("level_changed", level)
	emit_signal("moves_changed", moves_left)

	print("[GameManager] ✓ initialize_game() completed, initialized =", initialized, ", grid size =", grid.size())

func reset_state_for_new_level():
	"""Reset transient state flags that may block user input when starting/advancing levels."""
	processing_moves = false
	level_transitioning = false
	pending_level_complete = false
	pending_level_failed = false
	in_bonus_conversion = false
	bonus_skipped = false
	# Reset per-level shard session counters so the reward summary shows this level's drops only
	if GalleryManager and GalleryManager.has_method("reset_session"):
		GalleryManager.reset_session()
	print("[GameManager] reset_state_for_new_level: cleared transient flags")
	_push_to_grs()

func load_current_level():
	# D1: Data loading delegated to LevelLoader; post-load signals emitted here.
	reset_state_for_new_level()
	score = 0
	combo_count = 0

	if _level_loader:
		await _level_loader.load_level()
	else:
		# Fallback if LevelLoader not yet instantiated
		await _load_current_level_inline()

	# D2: Booster selection
	select_level_boosters()

	# Load the unified level narrative file (data/narrative_stages/levels/level_N.json).
	# This single file feeds both EffectResolver (effects key) and NarrativeStageManager (states/transitions keys).
	_load_level_narrative()

	emit_signal("level_loaded")

	# PR 5a: push all level data to GameRunState so sub-services can migrate to it in PR 5b
	_push_to_grs()

	# PR 5c: emit direct signal with context — EventBus no longer carries level_loaded traffic
	emit_signal("level_loaded_ctx", "level_%d" % GameRunState.level, {"level": GameRunState.level, "target": GameRunState.target_score})

	# Deferred HUD signals — UI may not be ready at load_level call time
	if unmovable_target > 0:
		call_deferred("emit_signal", "unmovables_changed", unmovables_cleared, unmovable_target)
	if collectible_target > 0:
		call_deferred("emit_signal", "collectibles_changed", collectibles_collected, collectible_target)

func _load_level_narrative() -> void:
	## Single entry point for all in-level narrative and visual-effect data.
	##
	## Looks for  data/narrative_stages/levels/level_N.json  first.
	## Falls back to  data/narrative_stages/levels/default.json  when no level-specific
	## file exists (replaces the old chapter_builtin.json role).
	##
	## The unified JSON schema supports both keys:
	##   "effects"     → loaded into EffectResolver (screen-shake, brightness, etc.)
	##   "states" / "transitions" → loaded into NarrativeStageManager (image sequences)
	## Either key may be absent; the loaders silently skip missing keys.

	var level_path    = "res://data/narrative_stages/levels/level_%d.json" % level
	var default_path  = "res://data/narrative_stages/levels/default.json"
	var chosen_path   = level_path if FileAccess.file_exists(level_path) else \
	                   (default_path if FileAccess.file_exists(default_path) else "")

	# --- EffectResolver ---
	var er = get_node_or_null("/root/EffectResolver")
	if er:
		er.clear_effects()
		er.cleanup_visual_overlays()
		if chosen_path != "":
			print("[GameManager] Loading level effects: %s" % chosen_path)
			er.load_effects_from_file(chosen_path)
		else:
			print("[GameManager] No effects file found for level %d" % level)

	# --- NarrativeStageManager ---
	var nsm = get_node_or_null("/root/NarrativeStageManager")
	if nsm:
		# Only force-clear active_stage_id when the manager is NOT locked.
		# When locked, ShowNarrativeStep is actively displaying a narrative and
		# owns the lifecycle — force-clearing would destroy the visible content.
		var is_locked: bool = nsm.get("_locked") == true
		if not is_locked:
			if nsm.has_method("clear_stage"):
				nsm.clear_stage(true)
			nsm.load_stage_for_level(level)
		else:
			# ShowNarrativeStep owns the manager right now.
			# Defer load_stage_for_level until stage_cleared fires (after unlock).
			_pending_in_level_stage = level
			if not nsm.stage_cleared.is_connected(_on_narrative_cleared_load_level_stage):
				nsm.stage_cleared.connect(_on_narrative_cleared_load_level_stage, CONNECT_ONE_SHOT)



## Called via CONNECT_ONE_SHOT on stage_cleared when NSM was locked during initialize_game.
## Loads the in-level narrative stage once ShowNarrativeStep has finished and unlocked.
func _on_narrative_cleared_load_level_stage() -> void:
	if _pending_in_level_stage < 0:
		return
	var nsm := get_node_or_null("/root/NarrativeStageManager")
	if nsm:
		nsm.load_stage_for_level(_pending_in_level_stage)
	_pending_in_level_stage = -1


func _load_current_level_inline():
	## Emergency inline fallback used only when LevelLoader is unavailable.
	if not level_manager or level_manager.levels.size() == 0:
		var attempts = 0
		while (not level_manager or level_manager.levels.size() == 0) and attempts < 40:
			level_manager = NodeResolverAPI._get_lm()
			await get_tree().create_timer(0.05).timeout
			attempts += 1
	var ld = level_manager.get_current_level() if level_manager else null
	if ld:
		# LevelData is a typed object — use direct property access
		GRID_WIDTH = ld.width
		GRID_HEIGHT = ld.height
		target_score = ld.target_score
		moves_left = ld.moves
		level = ld.level_number
		collectible_target = ld.collectible_target
		collectibles_collected = 0
		unmovable_target = ld.unmovable_target
		unmovables_cleared = 0
		spreader_count = 0
		create_empty_grid()
		fill_grid_from_layout(ld.grid_layout)
		initialized = true
	else:
		GRID_WIDTH = 8; GRID_HEIGHT = 8; target_score = 10000; moves_left = 30
		create_empty_grid(); fill_initial_grid(); initialized = true


func select_level_boosters() -> Array:
	# D2: Delegated to BoosterSelector — deterministic per-level selection
	if _booster_selector and _booster_selector.has_method("select"):
		available_boosters = _booster_selector.select(level)
	else:
		# Inline fallback using the constants still declared on GameManager
		available_boosters = _select_boosters_inline()
	return available_boosters

func _select_boosters_inline() -> Array:
	# Fallback if BoosterSelector fails to load
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(level)
	var count = rng.randi_range(3, 5)
	var result: Array = []
	var seen: Dictionary = {}
	var common = BOOSTER_TIERS["common"].duplicate()
	common.shuffle()
	result.append(common[0]); seen[common[0]] = true
	var attempts = 0
	while result.size() < count and attempts < 50:
		attempts += 1
		var roll = rng.randf()
		var tier = "rare" if roll < TIER_WEIGHTS["rare"] else ("uncommon" if roll < TIER_WEIGHTS["rare"] + TIER_WEIGHTS["uncommon"] else "common")
		for b in BOOSTER_TIERS[tier].duplicate():
			if not seen.has(b): result.append(b); seen[b] = true; break
	return result

func _new_game_state() -> Object:
	# B3: Factory helper — instantiate GameState model (no class_name, so load().new() always)
	var gs_script = load("res://scripts/model/GameState.gd")
	if gs_script and gs_script is Script:
		return gs_script.new(GRID_WIDTH, GRID_HEIGHT, TILE_TYPES)
	return null

func _apply_game_state(gs: Object) -> void:
	# B3: Copy fields out of a GameState instance — use get() since gs has no class_name
	grid = gs.get("grid") if gs.get("grid") != null else []
	collectible_positions = gs.get("collectible_positions") if gs.get("collectible_positions") != null else []
	unmovable_map = gs.get("unmovable_map") if gs.get("unmovable_map") != null else {}
	spreader_positions = gs.get("spreader_positions") if gs.get("spreader_positions") != null else []
	spreader_count = gs.get("spreader_count") if gs.get("spreader_count") != null else 0

func create_empty_grid():
	# B3: Delegated to GameState model
	var gs = _new_game_state()
	if gs:
		_apply_game_state(gs)
	else:
		create_empty_grid_fallback(GRID_WIDTH, GRID_HEIGHT)

func create_empty_grid_fallback(w: int, h: int):
	# Emergency fallback if GameState script fails to load
	grid = []
	for x in range(w):
		grid.append([])
		for y in range(h):
			grid[x].append(0)
	collectible_positions = []
	unmovable_map = {}
	spreader_positions = []
	spreader_count = 0

func fill_grid_from_layout(layout: Array):
	# B3: Delegated to GameState model
	var gs = _new_game_state()
	if gs == null or not gs.has_method("fill_from_layout"):
		create_empty_grid_fallback(GRID_WIDTH, GRID_HEIGHT)
		return
	_apply_layout_result(gs, layout)

func _apply_layout_result(gs: Object, layout: Array) -> void:
	# Helper: calls fill_from_layout and copies results out, isolating dynamic dispatch
	var result = gs.call("fill_from_layout", layout)
	if not (result is Dictionary) or (result as Dictionary).get("grid", []).size() == 0:
		create_empty_grid_fallback(GRID_WIDTH, GRID_HEIGHT)
		return
	var d := result as Dictionary
	grid = d.get("grid", [])
	collectible_positions = d.get("collectible_positions", [])
	unmovable_map = d.get("unmovable_map", {})
	spreader_positions = d.get("spreader_positions", [])
	spreader_count = d.get("spreader_count", 0)

func fill_initial_grid():
	# Legacy fallback — fill grid with random non-matching tiles
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid[x][y] != -1:
				grid[x][y] = randi() % TILE_TYPES + 1

func is_cell_blocked(x: int, y: int) -> bool:
	if GQS != null: return GQS.is_cell_blocked(self, x, y)
	# inline fallback
	if x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT: return true
	if grid.size() <= x or grid[x].size() <= y: return true
	return grid[x][y] == -1

func is_valid_position(pos: Vector2) -> bool:
	if GQS != null: return GQS.is_valid_position(self, pos)
	if pos.x < 0 or pos.x >= GRID_WIDTH or pos.y < 0 or pos.y >= GRID_HEIGHT: return false
	return not is_cell_blocked(int(pos.x), int(pos.y))

func are_adjacent(pos1: Vector2, pos2: Vector2) -> bool:
	if GQS != null: return GQS.are_adjacent(pos1, pos2)
	var dx = abs(pos1.x - pos2.x); var dy = abs(pos1.y - pos2.y)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

func is_cell_movable(x: int, y: int) -> bool:
	if GQS != null: return GQS.is_cell_movable(self, x, y)
	if x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT: return false
	if grid.size() <= x or grid[x].size() <= y: return false
	var v = grid[x][y]
	# Blocked, empty, collectibles (coins/shards), and spreaders cannot be moved by the player
	if v == -1 or v == 0 or v == COLLECTIBLE or v == SPREADER or v == UNMOVABLE: return false
	var b = get_board()
	if b and b.tiles and x < b.tiles.size() and y < b.tiles[x].size():
		var tile = b.tiles[x][y]
		if tile and "is_unmovable_hard" in tile and tile.is_unmovable_hard: return false
	return true

func can_swap(pos1: Vector2, pos2: Vector2) -> bool:
	if GQS != null: return GQS.can_swap(self, pos1, pos2)
	if not is_valid_position(pos1) or not is_valid_position(pos2): return false
	if not is_cell_movable(int(pos1.x), int(pos1.y)) or not is_cell_movable(int(pos2.x), int(pos2.y)): return false
	return are_adjacent(pos1, pos2)

func get_tile_at(pos: Vector2) -> int:
	if GQS != null: return GQS.get_tile_at(self, pos)
	var gx = int(pos.x); var gy = int(pos.y)
	if gx < 0 or gx >= GRID_WIDTH or gy < 0 or gy >= GRID_HEIGHT: return -1
	if grid.size() <= gx or grid[gx].size() <= gy: return -1
	return int(grid[gx][gy])

func _is_unmovable_cell(x: int, y: int) -> bool:
	if GQS != null: return GQS.is_unmovable_cell(self, x, y)
	return unmovable_map.has(str(x) + "," + str(y))

func swap_tiles(pos1: Vector2, pos2: Vector2) -> bool:
	if not can_swap(pos1, pos2):
		return false
	var temp = grid[pos1.x][pos1.y]
	grid[pos1.x][pos1.y] = grid[pos2.x][pos2.y]
	grid[pos2.x][pos2.y] = temp
	return true

func find_matches() -> Array:
	# Exclude special tiles and unmovable sentinel so they never match as normal tiles.
	# UNMOVABLE (11) is excluded rather than used as blocked_value so that runs of regular
	# tiles on either side of an unmovable are detected independently and correctly.
	var exclude = [HORIZTONAL_ARROW, VERTICAL_ARROW, FOUR_WAY_ARROW, COLLECTIBLE, SPREADER, UNMOVABLE]
	return MatchFinder.find_matches(grid, GRID_WIDTH, GRID_HEIGHT, MIN_MATCH_SIZE, exclude, -1)

func calculate_points(tiles_removed: int) -> int:
	if tiles_removed <= 0:
		return 0
	if typeof(Scoring) == TYPE_NIL:
		return int(tiles_removed * POINTS_PER_TILE * (1.0 + (0.1 * float(combo_count))))
	return Scoring.points_for(tiles_removed, combo_count)

func add_score(points: int) -> void:
	if points == null or points <= 0:
		return
	score += int(points)
	print("[GameManager] add_score: added ", points, " new total=", score)
	emit_signal("score_changed", score)
	var grs = _grs(); if grs: grs.score = score

func report_spreader_destroyed(pos: Vector2) -> void:
	# B4: Delegate count tracking to ObjectiveManager; keep spreader_positions/count in sync
	spreader_count = max(0, spreader_count - 1)
	if spreader_positions.has(pos):
		spreader_positions.erase(pos)
	if not spreaders_destroyed_this_turn.has(pos):
		spreaders_destroyed_this_turn.append(pos)
	if objective_manager_ref != null and objective_manager_ref.has_method("report_spreader_destroyed"):
		objective_manager_ref.report_spreader_destroyed(1)
	call_deferred("emit_signal", "spreaders_changed", spreader_count)
	var grs = _grs(); if grs: grs.spreader_count = spreader_count; grs.spreader_positions = spreader_positions; grs.spreaders_destroyed_this_turn = spreaders_destroyed_this_turn

func report_unmovable_destroyed(pos, skip_clear: bool = false) -> void:
	# B4: Delegate count tracking to ObjectiveManager; keep unmovable_map in sync
	var key = pos if typeof(pos) == TYPE_STRING else str(int(pos.x)) + "," + str(int(pos.y))
	if unmovable_map.has(key):
		unmovable_map.erase(key)
		unmovables_cleared += 1
		if objective_manager_ref != null and objective_manager_ref.has_method("report_unmovable_cleared"):
			objective_manager_ref.report_unmovable_cleared(1)
		call_deferred("emit_signal", "unmovables_changed", unmovables_cleared, unmovable_target)
	if not skip_clear:
		var parts = key.split(",")
		if parts.size() == 2:
			var gx = int(parts[0])
			var gy = int(parts[1])
			if gx >= 0 and gx < GRID_WIDTH and gy >= 0 and gy < GRID_HEIGHT:
				grid[gx][gy] = 0
	var grs = _grs(); if grs: grs.unmovable_map = unmovable_map; grs.unmovables_cleared = unmovables_cleared; grs.grid = grid

# Add var to record requested special creation
var requested_special_tile: Dictionary = {}  # {"pos": Vector2, "type": String}

func request_special_tile_creation(pos: Vector2, special_type: String = "bomb") -> void:
	requested_special_tile = {"pos": pos, "type": special_type}
	print("[GameManager] request_special_tile_creation registered:", requested_special_tile)

func get_and_clear_requested_special() -> Dictionary:
	var out = requested_special_tile
	requested_special_tile = {}
	return out

func remove_matches(matches: Array, swapped_pos: Vector2 = Vector2(-1, -1)) -> int:
	"""Remove matched tiles from the grid, handle spreaders/unmovables/collectibles, compute scoring."""
	if matches == null or matches.size() == 0:
		return 0

	print("[SCORING] ========== remove_matches called ==========")
	print("[SCORING] Input matches count: ", matches.size())
	print("[SCORING] Swapped position: ", swapped_pos)
	print("[SCORING] Current combo_count: ", combo_count)

	# Normalize and deduplicate matches — shared by both delegate and fallback paths
	var norm_matches: Array = []
	for m in matches:
		var pos = m
		if typeof(m) == TYPE_DICTIONARY and m.has("x") and m.has("y"):
			pos = Vector2(float(m["x"]), float(m["y"]))
		elif typeof(m) == TYPE_STRING:
			var parts = m.split(",")
			if parts.size() == 2:
				pos = Vector2(int(parts[0]), int(parts[1]))
		if typeof(pos) == TYPE_VECTOR2 and is_valid_position(pos):
			norm_matches.append(pos)

	var unique = []
	for p in norm_matches:
		var found = false
		for q in unique:
			if int(p.x) == int(q.x) and int(p.y) == int(q.y):
				found = true; break
		if not found and not is_cell_blocked(int(p.x), int(p.y)):
			unique.append(p)

	# Lazy-reload MatchProcessor in case _init_resolvers ran before the script was ready
	if MatchProcessor == null:
		MatchProcessor = load("res://scripts/game/MatchProcessor.gd")

	# Delegate clearing to MatchProcessor
	var tiles_removed = 0
	if MatchProcessor != null:
		var res = MatchProcessor.process_matches(grid, unique, swapped_pos, GRID_WIDTH, GRID_HEIGHT, self)
		if typeof(res) == TYPE_DICTIONARY and res.has("tiles_removed"):
			tiles_removed = int(res["tiles_removed"])
	else:
		# Inline fallback — should never be reached, but guarantees grid is cleared
		push_error("[GameManager] MatchProcessor unavailable — using inline fallback")
		for p in unique:
			var gx = int(p.x)
			var gy = int(p.y)
			var val = int(grid[gx][gy])
			if val == COLLECTIBLE:
				grid[gx][gy] = 0
				continue
			if swapped_pos.x >= 0 and int(swapped_pos.x) == gx and int(swapped_pos.y) == gy:
				tiles_removed += 1
				continue
			if val > 0:
				tiles_removed += 1
				grid[gx][gy] = 0

	# Scoring and combo
	var points = calculate_points(tiles_removed)
	if points > 0:
		add_score(points)
	combo_count = combo_count + 1 if tiles_removed > 0 else 0

	print("[SCORING] remove_matches: tiles_removed=", tiles_removed, ", points=", points, ", combo_count=", combo_count)

	# Resolve pending special-tile creation (delegated to MatchProcessor)
	var req = get_and_clear_requested_special()
	if MatchProcessor != null and req.has("pos"):
		MatchProcessor.resolve_special_tile(req, unique, grid, self)

	# Check objectives after scoring
	if objective_manager_ref != null and objective_manager_ref.has_method("is_complete"):
		if objective_manager_ref.is_complete():
			print("[GameManager] Objectives complete detected by ObjectiveManager")
			pending_level_complete = true
			call_deferred("_perform_level_completion_check")

	# PR 5c: emit direct signal — EventBus no longer carries match_cleared traffic
	if tiles_removed > 0:
		emit_signal("match_cleared", tiles_removed, {"level": GameRunState.level, "score": GameRunState.score, "target": GameRunState.target_score})

	var grs = _grs(); if grs: grs.grid = grid; grs.combo_count = combo_count

	return tiles_removed


func apply_gravity() -> bool:
	## Step 1: Delegated to GravityService (barrier-aware version).
	if GravityService == null:
		GravityService = load("res://scripts/game/GravityService.gd")
	if GravityService != null:
		return GravityService.apply_gravity(grid, self)
	# Emergency fallback — should never be reached at runtime
	push_error("[GameManager] GravityService unavailable")
	return false

func fill_empty_spaces() -> Array:
	## Step 1: Delegated to GravityService (barrier-aware version).
	if GravityService == null:
		GravityService = load("res://scripts/game/GravityService.gd")
	if GravityService != null:
		return GravityService.fill_empty_spaces(grid, self)
	return []

func collectible_landed_at(pos: Vector2, c_type: String = "coin") -> void:
	# B4: Delegate count tracking to ObjectiveManager
	collectibles_collected += 1
	if collectible_positions.has(pos):
		collectible_positions.erase(pos)
	if objective_manager_ref != null and objective_manager_ref.has_method("report_collectible_collected"):
		objective_manager_ref.report_collectible_collected(1)
	call_deferred("emit_signal", "collectibles_changed", collectibles_collected, collectible_target)
	var grs = _grs(); if grs: grs.collectibles_collected = collectibles_collected; grs.collectible_positions = collectible_positions

	# Check if all objectives are now met — mirrors the check in remove_matches() so
	# collecting the final coin via landing (not just tile removal) triggers level completion.
	if objective_manager_ref != null and objective_manager_ref.has_method("is_complete"):
		if objective_manager_ref.is_complete():
			print("[GameManager] Objectives complete detected (collectible_landed_at)")
			pending_level_complete = true
			call_deferred("_perform_level_completion_check")

func _attempt_level_complete() -> void:
	# C1: Delegated to GameFlowController
	if _flow_ctrl: _flow_ctrl.attempt_level_complete()
	else:
		if pending_level_complete: return
		pending_level_complete = true
		call_deferred("_perform_level_completion_check")

func _perform_level_completion_check() -> void:
	# C1: Delegated to GameFlowController
	if _flow_ctrl: _flow_ctrl.perform_level_completion_check()

func on_level_complete():
	# C1: Delegated to GameFlowController
	if _flow_ctrl: _flow_ctrl.on_level_complete()

func _convert_remaining_moves_to_bonus(remaining_moves: int):
	# C1: Delegated to GameFlowController
	if _flow_ctrl: await _flow_ctrl.convert_remaining_moves_to_bonus(remaining_moves)

func skip_bonus_animation():
	# C1: Delegated to GameFlowController
	if _flow_ctrl: _flow_ctrl.skip_bonus_animation()

func _perform_level_failed_check() -> void:
	# C1: Delegated to GameFlowController
	if _flow_ctrl: _flow_ctrl.perform_level_failed_check()

func _emit_eventbus_level_complete_with(stars: int, coins_earned: int, gems_earned: int) -> void:
	if _flow_ctrl: _flow_ctrl._emit_eventbus_level_complete(stars, coins_earned, gems_earned)

func _emit_eventbus_level_complete() -> void:
	var stars = 1
	if score >= int(target_score * 1.5): stars = 3
	elif score >= int(target_score * 1.2): stars = 2
	_emit_eventbus_level_complete_with(stars, 100 + (50 * level), 5 if stars == 3 else 0)

func _emit_eventbus_level_failed() -> void:
	if _flow_ctrl: _flow_ctrl._emit_eventbus_level_failed()

func reset_combo() -> void:
	combo_count = 0

func use_move() -> void:
	if moves_left > 0:
		moves_left -= 1
		emit_signal("moves_changed", moves_left)
	if moves_left <= 0:
		pending_level_failed = true
		call_deferred("_perform_level_failed_check")
	var grs = _grs(); if grs: grs.moves_left = moves_left; grs.pending_level_failed = pending_level_failed

func has_possible_moves() -> bool:
	# C3: Check if any swap yields a match. Uses MatchFinder on a shallow grid copy.
	# Only considers regular tiles (1-TILE_TYPES) as candidates for swapping —
	# collectibles, special tiles, and spreaders never form colour matches.
	if grid == null or grid.size() == 0:
		return false
	var exclude = [COLLECTIBLE, SPREADER]
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if not is_cell_movable(x, y): continue
			# Skip non-regular tiles — special tiles activate on swap but don't form matches
			var v = int(grid[x][y])
			if v < 1 or v > TILE_TYPES: continue
			if x + 1 < GRID_WIDTH and is_cell_movable(x + 1, y):
				var v2 = int(grid[x + 1][y])
				if v2 < 1 or v2 > TILE_TYPES: continue
				if v != v2:
					var tg = _copy_grid()
					var t = tg[x][y]; tg[x][y] = tg[x+1][y]; tg[x+1][y] = t
					if MatchFinder.find_matches(tg, GRID_WIDTH, GRID_HEIGHT, MIN_MATCH_SIZE, exclude, -1).size() > 0:
						return true
			if y + 1 < GRID_HEIGHT and is_cell_movable(x, y + 1):
				var v3 = int(grid[x][y + 1])
				if v3 < 1 or v3 > TILE_TYPES: continue
				if v != v3:
					var tg2 = _copy_grid()
					var t2 = tg2[x][y]; tg2[x][y] = tg2[x][y+1]; tg2[x][y+1] = t2
					if MatchFinder.find_matches(tg2, GRID_WIDTH, GRID_HEIGHT, MIN_MATCH_SIZE, exclude, -1).size() > 0:
						return true
	return false

func _copy_grid() -> Array:
	var copy = []
	for cx in range(GRID_WIDTH):
		var col = []
		for cy in range(GRID_HEIGHT):
			col.append(grid[cx][cy])
		copy.append(col)
	return copy

func shuffle_until_moves_available(max_attempts: int = 100) -> bool:
	# C3: Shuffle grid values until has_possible_moves() returns true.
	# Only regular tile types (1-TILE_TYPES) are shuffled — collectibles, special tiles,
	# and spreaders stay in place so they are never corrupted.
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var cells: Array = []
	var values: Array = []
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid.size() > x and grid[x].size() > y:
				var v = int(grid[x][y])
				# Only include regular movable tiles — skip blocked(-1), empty(0),
				# special tiles (7-9), collectibles (10), spreaders (12)
				if v >= 1 and v <= TILE_TYPES:
					cells.append(Vector2(x, y))
					values.append(v)
	if cells.size() == 0:
		return false
	for attempt in range(max_attempts):
		values.shuffle()
		for i in range(cells.size()):
			var p = cells[i]
			grid[int(p.x)][int(p.y)] = values[i]
		if has_possible_moves():
			return true
	return false

var SpreaderService = null

func _init_spreader_service():
	if SpreaderService == null:
		SpreaderService = load("res://scripts/game/SpreaderService.gd")

func check_and_spread_tiles() -> Array:
	## B5: Delegated to SpreaderService. Returns newly infected positions.
	_init_spreader_service()
	if spreaders_destroyed_this_turn.size() > 0:
		spreaders_destroyed_this_turn.clear()
		return []
	spreaders_destroyed_this_turn.clear()
	if SpreaderService == null or not SpreaderService.has_method("spread"):
		return []
	var res = SpreaderService.spread(
		spreader_positions, grid, GRID_WIDTH, GRID_HEIGHT,
		spreader_spread_limit, spreader_type
	)
	if typeof(res) == TYPE_DICTIONARY and res.has("new_spreaders"):
		var new_list: Array = res["new_spreaders"]
		for np in new_list:
			if not spreader_positions.has(np):
				spreader_positions.append(np)
		spreader_count = spreader_positions.size()
		grid = res.get("grid", grid)
		call_deferred("emit_signal", "spreaders_changed", spreader_count)
		var grs = _grs(); if grs: grs.spreader_positions = spreader_positions; grs.spreader_count = spreader_count; grs.grid = grid
		return new_list
	return []

