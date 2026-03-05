extends Node

# ProgressManager: responsible for loading/saving player progress and exposing queries
# Use JSON in user:// for storage (project preference noted by user). Keep API small and testable.

signal progress_loaded(progress: Dictionary)
signal progress_saved(success: bool)

var _progress: Dictionary = {}
var _save_path: String = "user://player_progress.json"

func _ready() -> void:
	# Load on startup; emit loaded (even if default)
	load_progress()

func get_progress() -> Dictionary:
	return _progress

func set_progress(data: Dictionary) -> void:
	_progress = data

func load_progress() -> Dictionary:
	var fa = FileAccess
	if FileAccess.file_exists(_save_path):
		var f = FileAccess.open(_save_path, FileAccess.READ)
		if f:
			var raw = f.get_as_text()
			f.close()
			if raw == null or raw == "":
				_progress = {}
				emit_signal("progress_loaded", _progress)
				return _progress
			# parse JSON safely
			var parsed = JSON.parse_string(raw)
			if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
				_progress = parsed.result
			else:
				# corrupted or unexpected format => backup and reset
				var bak = _save_path + ".bak"
				OS.rename(_save_path, bak)
				_progress = {}
				print("[ProgressManager] Corrupt save file moved to %s" % bak)
			emit_signal("progress_loaded", _progress)
			return _progress
	# no file -> start with defaults
	_progress = {"coins": 0, "gems": 0, "levels_completed": 0}
	emit_signal("progress_loaded", _progress)
	return _progress

func save_progress(reason: String = "manual") -> bool:
	# write JSON to user://
	var raw = to_json(_progress)
	var err = FileAccess.write_file(_save_path, raw)
	if err == OK:
		emit_signal("progress_saved", true)
		print("[ProgressManager] Saved progress (reason=%s)" % reason)
		return true
	else:
		print("[ProgressManager] Failed to write progress: %s" % str(err))
		emit_signal("progress_saved", false)
		return false

func update_coins(delta: int) -> void:
	_progress["coins"] = int(_progress.get("coins", 0)) + delta

func update_gems(delta: int) -> void:
	_progress["gems"] = int(_progress.get("gems", 0)) + delta

func mark_level_completed(level_num: int) -> void:
	var completed = int(_progress.get("levels_completed", 0))
	if level_num > completed:
		_progress["levels_completed"] = level_num
