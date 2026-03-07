extends Node

# ProgressManager - central persistence and level progression tracker
# Minimal Phase 1 implementation with save/load and a few helper APIs.

const SAVE_PATH := "user://progress.save"

var player_data: Dictionary = {}

signal level_completed(level_id: String, stars: int)
signal level_unlocked(level_id: String)

func _ready() -> void:
	print("[ProgressManager] ready - loading progress")
	load_game()

func get_next_incomplete_level() -> String:
	# Return next level id; simple fallback to level_1 if none known
	if player_data.has("levels"):
		for i in range(1, 100):
			var lid = "level_%03d" % i
			if not player_data.levels.has(lid) or not player_data.levels[lid].get("completed", false):
				return lid
	# default
	return "level_001"

func complete_level(level_id: String, stars: int, score: int, moves: int) -> void:
	if not player_data.has("levels"):
		player_data.levels = {}
	var entry = player_data.levels.get(level_id, {})
	entry.completed = true
	entry.stars = max(entry.get("stars", 0), stars)
	entry.high_score = max(entry.get("high_score", 0), score)
	entry.moves_used = moves
	entry.play_count = entry.get("play_count", 0) + 1
	player_data.levels[level_id] = entry
	save_game()
	emit_signal("level_completed", level_id, stars)

func is_level_unlocked(level_id: String) -> bool:
	# Basic rule: level_001 is unlocked by default; further logic can be added
	if not player_data.has("levels"):
		return level_id == "level_001"
	if player_data.levels.has(level_id):
		return player_data.levels[level_id].get("unlocked", false) or player_data.levels[level_id].get("completed", false)
	# fallback simple mapping: unlock first level
	return level_id == "level_001"

func unlock_level(level_id: String) -> void:
	if not player_data.has("levels"):
		player_data.levels = {}
	var entry = player_data.levels.get(level_id, {})
	entry.unlocked = true
	player_data.levels[level_id] = entry
	save_game()
	emit_signal("level_unlocked", level_id)

func save_game() -> void:
	var ok = true
	var json = JSON.stringify(player_data)
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(json)
		f.close()
		print("[ProgressManager] Progress saved to %s" % SAVE_PATH)
	else:
		push_error("[ProgressManager] Failed to open save file for writing: %s" % SAVE_PATH)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		create_new_player_data()
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		print("[ProgressManager] Failed to open save file; creating new data")
		create_new_player_data()
		return
	var txt = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		# Godot 3 legacy format: {"result": {...}, "error": 0, ...}
		if parsed.has("result") and typeof(parsed["result"]) == TYPE_DICTIONARY:
			player_data = parsed["result"]
			print("[ProgressManager] Loaded progress (migrated from Godot 3 format)")
			save_game()  # Re-save in clean Godot 4 format
		else:
			# Godot 4 format: the dictionary IS the data
			player_data = parsed
			print("[ProgressManager] Loaded progress")
	else:
		print("[ProgressManager] Save parse error or unexpected format; creating new data")
		create_new_player_data()

func create_new_player_data() -> void:
	player_data = {
		"levels": {
			"level_001": {"unlocked": true, "completed": false, "stars": 0}
		},
		"narratives_seen": [],
		"gallery_unlocks": {},
		"achievements": {},
		"statistics": {
			"total_play_time": 0,
			"total_matches": 0,
			"total_swaps": 0,
			"boosters_used": 0,
			"best_combo": 0
		}
	}
	save_game()
	print("[ProgressManager] Initialized new player data")
