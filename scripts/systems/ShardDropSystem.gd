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

func _ready() -> void:
	_load_config()
	EventBus.match_cleared.connect(_on_match_cleared)
	EventBus.tile_destroyed.connect(_on_tile_destroyed)
	EventBus.shard_tile_collected.connect(_on_shard_tile_collected)
	EventBus.pre_refill.connect(_on_pre_refill)
	EventBus.post_refill.connect(_on_post_refill)
	EventBus.level_loaded.connect(_on_level_loaded)
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
	var gm := _get_gm()
	if gm == null:
		return false

	# Respect the minimum level gate
	var current_level: int = int(gm.level) if "level" in gm else 0
	if current_level < shard_unlock_from_level:
		return false

	# Never exceed the per-level cap
	if _session_drops >= max_shards_per_level:
		return false

	# On a replay, only allow drops for shards that were NOT collected last time.
	# i.e. if the player already collected max_shards_per_level shards on a
	# previous play of this level, there is nothing left to chase.
	var level_key := "level_%d" % current_level
	var collected_before := _get_level_collected_count(level_key)
	# Total slots available this session = cap minus already-collected on prior runs
	var allowed_this_session := max_shards_per_level - collected_before
	if allowed_this_session <= 0:
		# All collectible shards for this level were already picked up previously
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
	var gm := _get_gm()
	if gm and "level" in gm:
		_record_level_collected("level_%d" % int(gm.level))
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
	var gm := _get_gm()
	if gm == null:
		return
	var item_id := _select_item()
	if item_id.is_empty():
		print("[ShardDropSystem] _inject_random_shard: no candidates")
		return
	# Find empty cells that gravity just created and that sit in the TOP segment
	# of their column — meaning no unmovable or blocker exists above them.
	# This guarantees the shard can fall in from above and reach the bottom row.
	var empty_cells: Array = []
	for x in range(gm.GRID_WIDTH):
		for y in range(gm.GRID_HEIGHT):
			if gm.is_cell_blocked(x, y) or gm._is_unmovable_cell(x, y):
				continue
			if int(gm.grid[x][y]) != 0:
				continue
			# Check that no unmovable or hard blocker sits above this cell
			# in the same column (which would make it an isolated lower segment).
			var in_top_segment := true
			for check_y in range(0, y):
				if gm.is_cell_blocked(x, check_y) or gm._is_unmovable_cell(x, check_y):
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
	gm.grid[int(pos.x)][int(pos.y)] = gm.COLLECTIBLE
	# Store item_id so animate_refill can configure the tile as a shard.
	if not gm.has_meta("pending_shard_cells"):
		gm.set_meta("pending_shard_cells", {})
	var pending: Dictionary = gm.get_meta("pending_shard_cells")
	pending[str(int(pos.x)) + "," + str(int(pos.y))] = item_id
	gm.set_meta("pending_shard_cells", pending)
	_session_drops += 1
	_record_level_dropped("level_%d" % int(gm.level))
	print("[ShardDropSystem] queued shard at %s for '%s' — will fall in via refill" % [pos, item_id])

func _on_post_refill() -> void:
	# Tag any shard tiles that animate_refill just spawned with their item_id.
	var gm := _get_gm()
	if gm == null or not gm.has_meta("pending_shard_cells"):
		return
	var pending: Dictionary = gm.get_meta("pending_shard_cells")
	if pending.is_empty():
		return
	var board := _get_board()
	if board == null:
		return
	var done: Array = []
	for key in pending:
		var parts: Array = key.split(",")
		if parts.size() != 2:
			continue
		var x: int = int(parts[0])
		var y: int = int(parts[1])
		var item_id: String = pending[key]
		if x < board.tiles.size() and y < board.tiles[x].size():
			var tile: Node = board.tiles[x][y]
			if tile and is_instance_valid(tile) and not tile.is_queued_for_deletion():
				tile.set_meta("shard_item_id", item_id)
				done.append(key)
				print("[ShardDropSystem] tagged spawned shard at (%d,%d) for '%s'" % [x, y, item_id])
	for key in done:
		pending.erase(key)
	if pending.is_empty():
		gm.remove_meta("pending_shard_cells")
	else:
		gm.set_meta("pending_shard_cells", pending)

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
	var gm := _get_gm()
	if board == null or gm == null:
		return
	_session_drops += 1
	_record_level_dropped("level_%d" % int(gm.level))
	_spawn_shard_tile(board, gm, pos, item_id)
	print("[ShardDropSystem] revealed shard tile for '%s' under obstacle at %s" % [item_id, pos])

# ── Shared spawn helper ───────────────────────────────────────────────────────

func _spawn_shard_tile(board: Node, gm: Node, pos: Vector2, item_id: String) -> void:
	var x := int(pos.x)
	var y := int(pos.y)
	gm.grid[x][y] = gm.COLLECTIBLE
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
	var gm := _get_gm()
	if gm == null:
		return false
	var count := 0
	if gm.has_method("get_unmovable_count"):
		count = gm.get_unmovable_count()
	else:
		for x in range(gm.GRID_WIDTH):
			for y in range(gm.GRID_HEIGHT):
				if gm._is_unmovable_cell(x, y):
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
	return get_node_or_null("/root/GameManager")

func _get_board() -> Node:
	var gm := _get_gm()
	if gm == null:
		return null
	if "board_ref" in gm and gm.board_ref != null and is_instance_valid(gm.board_ref):
		return gm.board_ref
	if gm.has_method("get_board"):
		return gm.get_board()
	return null
