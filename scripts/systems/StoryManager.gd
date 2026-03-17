extends Node

## StoryManager — tracks which narrative stages the player has seen.
## Listens to NarrativeStageManager.stage_shown, persists to ProgressManager.
## Provides get_seen_stages() for the Gallery Story tab.
## No UI logic — pure state tracking.

signal story_stage_seen(stage_id: String)

# All narrative stage JSON files discovered at startup
var _all_stages: Dictionary = {}   # stage_id -> metadata dict

const NARRATIVE_DIR := "res://data/narrative_stages/"

func _ready() -> void:
	_scan_stages()
	# Hook into NarrativeStageManager after all autoloads are ready
	call_deferred("_connect_signals")
	print("[StoryManager] ready — found %d narrative stages" % _all_stages.size())

func _connect_signals() -> void:
	if NarrativeStageManager:
		NarrativeStageManager.stage_shown.connect(_on_stage_shown)

# ── Stage scanning ─────────────────────────────────────────────────────────

func _scan_stages() -> void:
	_all_stages.clear()
	_scan_dir(NARRATIVE_DIR)

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir() and not fname.begins_with("."):
			_scan_dir(path + fname + "/")
		elif fname.ends_with(".json"):
			_load_stage_meta(path + fname)
		fname = dir.get_next()
	dir.list_dir_end()

func _load_stage_meta(full_path: String) -> void:
	var f := FileAccess.open(full_path, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var id: String = str(parsed.get("id", ""))
	if id.is_empty():
		return
	# Store lightweight metadata only
	_all_stages[id] = {
		"id": id,
		"name": str(parsed.get("name", id)),
		"description": str(parsed.get("description", "")),
		"background_color": str(parsed.get("background_color", "#1a1a2e")),
		"text_color": str(parsed.get("text_color", "#ffffff")),
		"art_asset": _resolve_art_asset(parsed),
		"states": parsed.get("states", []),
	}

func _resolve_art_asset(stage_data: Dictionary) -> String:
	# Check states for an asset field — use the first one found
	for state in stage_data.get("states", []):
		var asset: String = str(state.get("asset", ""))
		if not asset.is_empty():
			# If it looks like a bare filename, try common texture paths
			if not asset.contains("/"):
				for prefix in ["res://textures/narrative/", "res://assets/narrative/"]:
					if ResourceLoader.exists(prefix + asset):
						return prefix + asset
			elif ResourceLoader.exists(asset):
				return asset
	return ""

# ── Signal handler ─────────────────────────────────────────────────────────

func _on_stage_shown(stage_id: String, _fullscreen: bool) -> void:
	if stage_id.is_empty():
		return
	var seen: Array = _get_seen_array()
	if stage_id in seen:
		return
	seen.append(stage_id)
	ProgressManager.player_data["narratives_seen"] = seen
	ProgressManager.save_game()
	story_stage_seen.emit(stage_id)
	print("[StoryManager] Marked stage seen: %s (total seen: %d)" % [stage_id, seen.size()])

# ── Public API ─────────────────────────────────────────────────────────────

## Returns array of metadata dicts for all seen stages, in seen order.
func get_seen_stages() -> Array:
	var seen := _get_seen_array()
	var result: Array = []
	for id in seen:
		if _all_stages.has(id):
			result.append(_all_stages[id])
		else:
			# Stage was seen but JSON not found — include minimal entry
			result.append({"id": id, "name": id, "description": "", "art_asset": "",
				"background_color": "#1a1a2e", "text_color": "#ffffff", "states": []})
	return result

## Returns metadata for one stage, or empty dict if unknown.
func get_stage_meta(stage_id: String) -> Dictionary:
	return _all_stages.get(stage_id, {})

## Total number of narrative stages available (seen + unseen).
func get_total_stage_count() -> int:
	return _all_stages.size()

func _get_seen_array() -> Array:
	if not ProgressManager or not ProgressManager.player_data.has("narratives_seen"):
		return []
	var v = ProgressManager.player_data["narratives_seen"]
	if typeof(v) == TYPE_ARRAY:
		return v
	return []
