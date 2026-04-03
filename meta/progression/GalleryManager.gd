extends Node

## GalleryManager - tracks shard progress and unlocks for gallery items.
## Autoloaded singleton. Reads item definitions from data/gallery_items.json.
## Persists shard state through ProgressManager.

signal item_unlocked(item_id: String)
signal shard_added(item_id: String, current: int, required: int)
# Signal kept for compatibility with existing consumers
signal gallery_item_unlocked(category: String, item_id: String)
# Emits directly to consumers via signals.
signal shard_discovered(item_id: String, context: Dictionary)
signal gallery_unlocked(item_id: String)

const DATA_PATH := "res://data/gallery_items.json"

# item_id -> { id, name, rarity, shards_required, category, art_asset, silhouette_asset }
var _definitions: Dictionary = {}

# item_id -> { shards: int, unlocked: bool }  (runtime state, persisted via ProgressManager)
var _state: Dictionary = {}

# ── Deduplication guard ───────────────────────────────────────────────────────
## Tracks item_ids for which add_shard was already called this engine frame.
## Cleared at the end of each frame via _process so rapid multi-caller paths
## (CollectibleService + MatchOrchestrator + ShardDropSystem all firing for the
## same tile) only register one shard award.
var _shard_awarded_this_frame: Dictionary = {}

func _process(_delta: float) -> void:
	if not _shard_awarded_this_frame.is_empty():
		_shard_awarded_this_frame.clear()

# ── Session tracking (reset each level, used by reward summary) ───────────────
## Total shards collected since the last reset_session() call.
var session_shards_collected: int = 0
## item_ids that became fully unlocked this session.
var session_items_unlocked: Array = []

func reset_session() -> void:
	session_shards_collected = 0
	session_items_unlocked.clear()

func _ready() -> void:
	print("[GalleryManager] ready")
	_load_definitions()
	_load_state_from_progress()

	# Debug toggle: set project setting "gallery/debug_emit_immediately" = true to emit signals immediately (useful when debugging missing UI hooks)
	var _debug_immediate := false
	if ProjectSettings.has_setting("gallery/debug_emit_immediately"):
		_debug_immediate = bool(ProjectSettings.get_setting("gallery/debug_emit_immediately"))
	self.set_meta("_debug_emit_immediately", _debug_immediate)

# ── Data loading ──────────────────────────────────────────────────────────────

func _load_definitions() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_error("[GalleryManager] gallery_items.json not found at %s" % DATA_PATH)
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if not f:
		push_error("[GalleryManager] Failed to open %s" % DATA_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_error("[GalleryManager] gallery_items.json root must be an array")
		return
	_definitions.clear()
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id: String = str(entry.get("id", ""))
		if id.is_empty():
			continue
		_definitions[id] = entry
	print("[GalleryManager] Loaded %d item definitions" % _definitions.size())

func _load_state_from_progress() -> void:
	_state.clear()
	# Initialise state for every known definition
	for id in _definitions:
		_state[id] = {"shards": 0, "unlocked": false}
	# Overlay persisted data from ProgressManager
	if not ProgressManager:
		return
	var pd: Dictionary = ProgressManager.player_data
	var saved: Dictionary = pd.get("gallery_unlocks", {})
	for id in saved:
		if not _state.has(id):
			_state[id] = {"shards": 0, "unlocked": false}
		var entry = saved[id]
		_state[id]["shards"] = int(entry.get("shards", 0))
		_state[id]["unlocked"] = bool(entry.get("unlocked", false))

func _persist_state() -> void:
	if not ProgressManager:
		return
	var out: Dictionary = {}
	for id in _state:
		out[id] = {"shards": _state[id]["shards"], "unlocked": _state[id]["unlocked"]}
	ProgressManager.player_data["gallery_unlocks"] = out
	ProgressManager.save_game()

# ── Shard API ─────────────────────────────────────────────────────────────────

## Add one shard to item_id. Returns true if the item just became unlocked.
func add_shard(item_id: String) -> bool:
	if not _definitions.has(item_id):
		push_warning("[GalleryManager] add_shard: unknown item '%s'" % item_id)
		return false
	# ── Deduplication guard ───────────────────────────────────────────────────
	# Multiple code paths (CollectibleService, MatchOrchestrator, ShardDropSystem,
	# GameBoard) can all call add_shard for the same physical shard tile in the same
	# frame. Only honour the first call per item_id per frame to prevent double popups.
	if _shard_awarded_this_frame.has(item_id):
		print("[GalleryManager] add_shard: duplicate call for '%s' this frame — ignored" % item_id)
		return false
	_shard_awarded_this_frame[item_id] = true
	if not _state.has(item_id):
		_state[item_id] = {"shards": 0, "unlocked": false, "discovered": false}
	var st: Dictionary = _state[item_id]
	if st["unlocked"]:
		return false
	st["shards"] += 1
	st["discovered"] = true
	session_shards_collected += 1
	var required: int = int(_definitions[item_id].get("shards_required", 9))
	print("[GalleryManager] shard_added %s → %d/%d" % [item_id, st["shards"], required])
	# Diagnostic: immediate log that add_shard was invoked (helps trace missing toasts)
	print("[GalleryManager] add_shard invoked for %s (current=%d required=%d)" % [item_id, st["shards"], required])
	# Always emit deferred so UI listeners created later in the same frame can receive events
	call_deferred("_deferred_emit_shard_added", item_id, st["shards"], required)
	# Emit via deferred helper.
	call_deferred("_deferred_emit_shard_discovered", item_id, {"shards": st["shards"], "required": required})
	if st["shards"] >= required:
		st["unlocked"] = true
		session_items_unlocked.append(item_id)
		print("[GalleryManager] Unlocked gallery item: %s" % item_id)
		# Defer unlock-related emits to avoid interrupting gameplay logic
		call_deferred("_deferred_emit_item_unlocked", item_id)
		var cat: String = str(_definitions[item_id].get("category", "artifacts"))
		call_deferred("_deferred_emit_gallery_item_unlocked", cat, item_id)  # legacy
		call_deferred("_deferred_emit_gallery_unlocked", item_id)
		_persist_state()
		return true
	_persist_state()
	return false

## Deferred emit helpers — keep the actual signal emission in a later idle frame
func _deferred_emit_shard_added(item_id: String, current: int, required: int) -> void:
	print("[GalleryManager] _deferred_emit_shard_added firing for %s -> %d/%d" % [item_id, current, required])
	shard_added.emit(item_id, current, required)

func _deferred_emit_shard_discovered(item_id: String, context: Dictionary) -> void:
	print("[GalleryManager] _deferred_emit_shard_discovered firing for %s -> %s" % [item_id, str(context)])
	shard_discovered.emit(item_id, context)

func _deferred_emit_item_unlocked(item_id: String) -> void:
	print("[GalleryManager] _deferred_emit_item_unlocked firing for %s" % item_id)
	item_unlocked.emit(item_id)

func _deferred_emit_gallery_item_unlocked(category: String, item_id: String) -> void:
	print("[GalleryManager] _deferred_emit_gallery_item_unlocked firing for %s:%s" % [category, item_id])
	gallery_item_unlocked.emit(category, item_id)

func _deferred_emit_gallery_unlocked(item_id: String) -> void:
	print("[GalleryManager] _deferred_emit_gallery_unlocked firing for %s" % item_id)
	gallery_unlocked.emit(item_id)

func get_progress(item_id: String) -> Dictionary:
	if not _state.has(item_id):
		return {"shards": 0, "required": 0, "unlocked": false, "discovered": false}
	var st: Dictionary = _state[item_id]
	var required: int = int(_definitions.get(item_id, {}).get("shards_required", 0))
	return {
		"shards": st["shards"],
		"required": required,
		"unlocked": st["unlocked"],
		"discovered": st.get("discovered", st["shards"] > 0)
	}

func get_all_items() -> Array:
	var result: Array = []
	for id in _definitions:
		var def: Dictionary = _definitions[id].duplicate()
		var st: Dictionary = _state.get(id, {"shards": 0, "unlocked": false, "discovered": false})
		def["shards"] = st["shards"]
		def["unlocked"] = st["unlocked"]
		def["discovered"] = st.get("discovered", st["shards"] > 0)
		result.append(def)
	return result

func get_items_by_category(category: String) -> Array:
	return get_all_items().filter(func(item): return str(item.get("category", "")) == category)

func get_categories() -> Array:
	var cats: Dictionary = {}
	for id in _definitions:
		var cat: String = str(_definitions[id].get("category", "artifacts"))
		cats[cat] = true
	return cats.keys()

# ── Category-based unlock API ──────────────────────────────────────────────────

func unlock_item(category: String, item_id: String) -> void:
	if not _state.has(item_id):
		_state[item_id] = {"shards": 0, "unlocked": false}
	if _state[item_id]["unlocked"]:
		return
	_state[item_id]["unlocked"] = true
	item_unlocked.emit(item_id)
	gallery_item_unlocked.emit(category, item_id)
	_persist_state()

func is_item_unlocked(category: String, item_id: String) -> bool:
	return _state.has(item_id) and _state[item_id]["unlocked"]

func get_unlocked_items(category: String) -> Array:
	var result: Array = []
	for id in _definitions:
		var cat: String = str(_definitions[id].get("category", ""))
		if cat == category and _state.get(id, {}).get("unlocked", false):
			result.append(id)
	return result

func get_all_unlocked() -> Dictionary:
	var out: Dictionary = {}
	for id in _state:
		if _state[id]["unlocked"]:
			var cat: String = str(_definitions.get(id, {}).get("category", "artifacts"))
			if not out.has(cat):
				out[cat] = []
			out[cat].append(id)
	return out
