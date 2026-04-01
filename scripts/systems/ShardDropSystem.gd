extends Node

## ShardDropSystem - places shard collectible tiles onto the board during gameplay
## and forwards collected shards to GalleryManager.
##
## Two placement paths:
##   • Random drop  — queued on match_cleared, injected into an empty grid cell
##                    on pre_refill (between gravity and refill), so the shard
##                    tile is spawned naturally by GravityAnimator.animate_refill.
##   • Obstacle reveal — placed synchronously on tile_destroyed, before gravity
##                       fills the now-empty cell.

const SHARD_COLLECTIBLE_TYPE := "shard"
const GLOBAL_CONFIG_PATH := "res://data/global_game_config.json"
const _GQS = preload("res://games/match3/board/services/GridQueryService.gd")
var GameStateBridge = null

# ── Tunable globals ───────────────────────────────────────────────────────────
## These defaults are overridden at runtime by data/global_game_config.json.
## Edit that file to tune values without touching code.
## Maximum shards that can drop in a single level play.
@export var max_shards_per_level: int = 2
## Shards only start dropping from this level number onward (0 = always).
@export var shard_unlock_from_level: int = 5
## Probability of spawning a shard tile on a normal match-clear.
@export var spawn_chance_per_match: float = 0.25
## Extra probability for each tile above 3 in the match.
@export var spawn_bonus_per_extra: float = 0.05
## Probability that a destroyed obstacle reveals a shard.
@export var obstacle_reveal_chance: float = 0.40

# ── Per-session state (reset on level load) ───────────────────────────────────
## Shards that have dropped (but not necessarily collected) this session.
var _session_drops: int = 0
## Pending random drops queued between match_cleared and pre_refill.
var _pending_random: int = 0

func _find_node_by_name(root: Node, name: String) -> Node:
	if root == null:
		return null
	if str(root.name) == name:
		return root
	for i in range(root.get_child_count()):
		var c = root.get_child(i)
		if c == null:
			continue
		var res = _find_node_by_name(c, name)
		if res != null:
			return res
	return null

func _ready() -> void:
	_load_config()
	# Prefer active registered board_ref (set by GameBoard._ready) to avoid scene traversal and races
	var board_node: Node = null
	if typeof(GameRunState) != TYPE_NIL and GameRunState.board_ref != null:
		board_node = GameRunState.board_ref
	else:
		if has_method("get_tree") and get_tree() != null:
			var tree = get_tree()
			var cs = tree.get_current_scene()
			if cs != null:
				board_node = _find_node_by_name(cs, "GameBoard")
			# fallback: try root search
			if board_node == null:
				var root = tree.get_root()
				board_node = _find_node_by_name(root, "GameBoard")

	if board_node != null:
		if board_node.has_signal("match_cleared"):
			board_node.connect("match_cleared", Callable(self, "_on_match_cleared"))
		if board_node.has_signal("shard_tile_collected"):
			board_node.connect("shard_tile_collected", Callable(self, "_on_shard_tile_collected"))
		if board_node.has_signal("pre_refill"):
			board_node.connect("pre_refill", Callable(self, "_on_pre_refill"))
		if board_node.has_signal("post_refill"):
			board_node.connect("post_refill", Callable(self, "_on_post_refill"))
		if board_node.has_signal("level_loaded_ctx"):
			board_node.connect("level_loaded_ctx", Callable(self, "_on_level_loaded"))
		print("[ShardDropSystem] Connected to GameBoard signals")
	else:
		# No board found — disable shard drops. Migration: do not fallback to legacy GameManager.
		push_error("[ShardDropSystem] GameBoard not found and GameRunState.board_ref is unset — shard drops disabled")
		return

	# TODO PR 6: tile_destroyed emitter (BoardActionExecutor) moves to direct GameBoard signal
	# For now connect via EventBus which still carries tile_destroyed only
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("tile_destroyed"):
		eb.connect("tile_destroyed", Callable(self, "_on_tile_destroyed"))
	print("[ShardDropSystem] ready (max_per_level=%d unlock_from=%d)" % [max_shards_per_level, shard_unlock_from_level])

func _load_config() -> void:
	if not FileAccess.file_exists(GLOBAL_CONFIG_PATH):
		push_warning("[ShardDropSystem] %s not found — using defaults" % GLOBAL_CONFIG_PATH)
		return
	var f := FileAccess.open(GLOBAL_CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_warning("[ShardDropSystem] Cannot open %s — using defaults" % GLOBAL_CONFIG_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[ShardDropSystem] %s is not a valid JSON object — using defaults" % GLOBAL_CONFIG_PATH)
		return
	var cfg: Dictionary = parsed.get("shards", {})
	if cfg.is_empty():
		return
	if cfg.has("max_shards_per_level"):
		max_shards_per_level = int(cfg["max_shards_per_level"])
	if cfg.has("shard_unlock_from_level"):
		shard_unlock_from_level = int(cfg["shard_unlock_from_level"])
	if cfg.has("spawn_chance_per_match"):
		spawn_chance_per_match = float(cfg["spawn_chance_per_match"])
	if cfg.has("spawn_bonus_per_extra"):
		spawn_bonus_per_extra = float(cfg["spawn_bonus_per_extra"])
	if cfg.has("obstacle_reveal_chance"):
		obstacle_reveal_chance = float(cfg["obstacle_reveal_chance"])
	print("[ShardDropSystem] config loaded from %s" % GLOBAL_CONFIG_PATH)

# ── Level lifecycle ───────────────────────────────────────────────────────────

func _on_level_loaded(_level_id: String, _context: Dictionary) -> void:
	_session_drops = 0
	_pending_random = 0

# ── Guards ────────────────────────────────────────────────────────────────────

## Returns true when shards are allowed to drop in the current level context.
func _can_drop() -> bool:
	# Use GameRunState for level and grid state if GameManager not present
	var current_level: int = int(GameRunState.level) if typeof(GameRunState) != TYPE_NIL else 0
	if current_level < shard_unlock_from_level:
		return false
	if _session_drops >= max_shards_per_level:
		return false
	var level_key := "level_%d" % current_level
	var collected_before := _get_level_collected_count(level_key)
	var allowed_this_session := max_shards_per_level - collected_before
	if allowed_this_session <= 0:
		return false
	if _session_drops >= allowed_this_session:
		return false
	return true

# ── Collection ───────────────────────────────────────────────────────────────

func _on_shard_tile_collected(item_id: String) -> void:
	if item_id.is_empty():
		return
	GalleryManager.add_shard(item_id)
	# Record the collection against this level so replay logic is correct
	var lvl = int(GameRunState.level) if typeof(GameRunState) != TYPE_NIL else 0
	# Use GameRunState.level exclusively (migration) — legacy GameManager-level preference removed
	_record_level_collected("level_%d" % int(lvl))
	print("[ShardDropSystem] shard collected for item: ", item_id)

# ── Random drop: queue on match_cleared, inject on pre_refill ────────────────

func _on_match_cleared(match_size: int, _context: Dictionary) -> void:
	if not _can_drop():
		return
	var chance := spawn_chance_per_match + spawn_bonus_per_extra * float(max(0, match_size - 3))
	if randf() > chance:
		return
	_pending_random += 1
	print("[ShardDropSystem] queued random shard drop (pending=%d)" % _pending_random)

func _on_pre_refill() -> void:
	if _pending_random <= 0:
		return
	# Re-check cap here in case multiple drops queued in the same cascade
	if not _can_drop():
		_pending_random = 0
		return
	_pending_random -= 1
	_inject_random_shard()

func _inject_random_shard() -> void:
	# Use GameRunState grid and constants
	var item_id := _select_item()
	if item_id.is_empty():
		print("[ShardDropSystem] _inject_random_shard: no candidates")
		return
	# Find empty cells that gravity just created and that sit in the TOP segment
	# of their column — meaning no unmovable or blocker exists above them.
	# This guarantees the shard can fall in from above and reach the bottom row.
	var empty_cells: Array = []
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			if _GQS.is_cell_blocked(null, x, y) or _GQS.is_unmovable_cell(null, x, y):
				continue
			if int(GameRunState.grid[x][y]) != 0:
				continue
			var in_top_segment := true
			for check_y in range(0, y):
				if _GQS.is_cell_blocked(null, x, check_y) or _GQS.is_unmovable_cell(null, x, check_y):
					in_top_segment = false
					break
			if in_top_segment:
				empty_cells.append(Vector2(x, y))
	if empty_cells.is_empty():
		print("[ShardDropSystem] _inject_random_shard: no reachable empty cells for shard")
		return
	var pos: Vector2 = empty_cells[randi() % empty_cells.size()]
	# Mark the grid cell as COLLECTIBLE so fill_empty_spaces skips it.
	# Do NOT spawn the visual here — animate_refill will spawn it with the
	# normal fall-in animation, just like any other new tile.
	GameRunState.grid[int(pos.x)][int(pos.y)] = GameRunState.COLLECTIBLE
	# Store item_id so animate_refill can configure the tile as a shard.
	# Previously stored on GameManager meta; now store on GameRunState.pending_shard_cells
	if not GameRunState.pending_shard_cells:
		GameRunState.pending_shard_cells = {}
	GameRunState.pending_shard_cells[str(int(pos.x)) + "," + str(int(pos.y))] = item_id
	_session_drops += 1
	_record_level_dropped("level_%d" % int(GameRunState.level))
	print("[ShardDropSystem] queued shard at %s for '%s' — will fall in via refill" % [pos, item_id])

func _on_post_refill() -> void:
	# Tag any shard tiles that animate_refill just spawned with their item_id.
	var pending: Dictionary = GameRunState.pending_shard_cells if GameRunState.pending_shard_cells else {}
	if pending == {}:
		return
	var board := _get_board()
	if board == null:
		return
	var done: Array = []
	for key in pending.keys():
		var parts: Array = key.split(",")
		if parts.size() != 2:
			continue
		var x: int = int(parts[0])
		var y: int = int(parts[1])
		if x < 0 or x >= GameRunState.GRID_WIDTH or y < 0 or y >= GameRunState.GRID_HEIGHT:
			continue
		# If visual exists at this pos, attach meta
		if x < board.tiles.size() and y < board.tiles[x].size() and board.tiles[x][y] != null:
			var t = board.tiles[x][y]
			if t and is_instance_valid(t) and t.has_method("set_meta"):
				t.set_meta("shard_item_id", str(pending[key]))
				done.append(key)
	# clean up handled keys
	for k in done:
		pending.erase(k)
	# persist back to GameRunState.pending_shard_cells
	GameRunState.pending_shard_cells = pending
	if pending.size() == 0:
		GameRunState.pending_shard_cells = {}
	print("[ShardDropSystem] post_refill tagging complete, pending_remaining=", GameRunState.pending_shard_cells.size())

# ── Obstacle reveal: synchronous, before gravity ─────────────────────────────

func _on_tile_destroyed(entity_id: String, context: Dictionary) -> void:
	if not context.get("is_obstacle", false):
		return
	if not _can_drop():
		return
	if _is_last_obstacle():
		print("[ShardDropSystem] last obstacle — skipping shard reveal")
		return
	if randf() > obstacle_reveal_chance:
		return
	var pos: Vector2 = context.get("grid_position", Vector2(-1, -1))
	if pos.x < 0:
		return
	var item_id := _select_item()
	if item_id.is_empty():
		print("[ShardDropSystem] tile_destroyed: no unlockable items, skipping")
		return
	_do_reveal_shard(pos, item_id)

func _do_reveal_shard(pos: Vector2, item_id: String) -> void:
	var board := _get_board()
	# Use GameRunState.level when GameManager not available
	var lvl = GameRunState.level if GameRunState != null else 0
	if board == null:
		return
	_session_drops += 1
	_record_level_dropped("level_%d" % int(lvl))
	_spawn_shard_tile(board, null, pos, item_id)
	print("[ShardDropSystem] revealed shard tile for '%s' under obstacle at %s" % [item_id, pos])

# ── Shared spawn helper ───────────────────────────────────────────────────────

func _spawn_shard_tile(board: Node, gm: Node, pos: Vector2, item_id: String) -> void:
	var x := int(pos.x)
	var y := int(pos.y)
	GameRunState.grid[x][y] = GameRunState.COLLECTIBLE
	if board.has_method("spawn_collectible_visual"):
		board.spawn_collectible_visual(x, y, SHARD_COLLECTIBLE_TYPE)
	else:
		push_error("[ShardDropSystem] board has no spawn_collectible_visual")
		return
	if x < board.tiles.size() and y < board.tiles[x].size():
		var tile: Node = board.tiles[x][y]
		if tile and is_instance_valid(tile):
			tile.set_meta("shard_item_id", item_id)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _is_last_obstacle() -> bool:
	var count := 0
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			if _GQS.is_unmovable_cell(null, x, y):
				count += 1
	return count <= 1

func _select_item() -> String:
	var items := GalleryManager.get_all_items()
	var candidates: Array = items.filter(func(i): return not bool(i.get("unlocked", false)))
	if candidates.is_empty():
		return ""
	var weights: Array = []
	for item in candidates:
		var req: int = max(1, int(item.get("shards_required", 9)))
		var cur: int = int(item.get("shards", 0))
		weights.append(_weight_for_ratio(float(cur) / float(req)))
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return str(candidates[randi() % candidates.size()].get("id", ""))
	var roll := randf() * total
	var running := 0.0
	for i in range(candidates.size()):
		running += weights[i]
		if roll <= running:
			return str(candidates[i].get("id", ""))
	return str(candidates[-1].get("id", ""))

func _weight_for_ratio(ratio: float) -> float:
	if ratio >= 0.9: return 10.0
	if ratio >= 0.7: return 5.0
	if ratio >= 0.3: return 2.0
	return 1.0

# ── Per-level shard persistence (via ProgressManager.player_data) ────────────
# Stored under player_data["shard_drops"][level_key] = {dropped: int, collected: int}

func _shard_entry(level_key: String) -> Dictionary:
	if not ProgressManager:
		return {}
	if not ProgressManager.player_data.has("shard_drops"):
		ProgressManager.player_data["shard_drops"] = {}
	var drops: Dictionary = ProgressManager.player_data["shard_drops"]
	if not drops.has(level_key):
		drops[level_key] = {"dropped": 0, "collected": 0}
	return drops[level_key]

func _get_level_collected_count(level_key: String) -> int:
	return int(_shard_entry(level_key).get("collected", 0))

func _record_level_dropped(level_key: String) -> void:
	var entry := _shard_entry(level_key)
	if entry.is_empty():
		return
	entry["dropped"] = int(entry.get("dropped", 0)) + 1
	ProgressManager.player_data["shard_drops"][level_key] = entry
	ProgressManager.save_game()

func _record_level_collected(level_key: String) -> void:
	var entry := _shard_entry(level_key)
	if entry.is_empty():
		return
	entry["collected"] = int(entry.get("collected", 0)) + 1
	ProgressManager.player_data["shard_drops"][level_key] = entry
	ProgressManager.save_game()

# ── Node helpers ──────────────────────────────────────────────────────────────

func _get_gm() -> Node:
	# Resolve legacy GameManager via node_resolvers helper only. Do NOT fallback to /root.
	var nr = load("res://scripts/helpers/node_resolvers.gd")
	if nr != null:
		var gm2 = nr._get_gm()
		if gm2 != null:
			return gm2
	# If unresolved, return null — migration code should rely on GameRunState instead
	return null

func _get_board() -> Node:
	if GameRunState.board_ref != null:
		return GameRunState.board_ref
	# fallback scene search
	var root = get_tree().get_root()
	return _find_node_by_name(root, "GameBoard")
