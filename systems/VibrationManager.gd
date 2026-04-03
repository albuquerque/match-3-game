extends Node

## Global vibration/haptic feedback manager for mobile devices
## Provides configurable haptic feedback for various game events

signal vibration_enabled_changed(enabled: bool)

# Vibration patterns (duration in milliseconds)
const PATTERNS = {
	"light": 20,        # Light tap (UI interactions)
	"medium": 40,       # Standard feedback (tile matches)
	"heavy": 60,        # Strong feedback (special tiles, combos)
	"double": [30, 20, 30],  # Double pulse (level complete)
	"triple": [20, 15, 20, 15, 20],  # Triple pulse (big combos)
}

# Setting key for persistent storage
const SETTING_KEY = "vibration_enabled"

# Current state
var vibration_enabled: bool = true

func _ready():
	print("[VibrationManager] Initializing haptic feedback system")

	# Load saved preference
	_load_setting()

	# Check if running on mobile (Android or iOS)
	var is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	if not is_mobile:
		print("[VibrationManager] Not a mobile device - vibration disabled")
		vibration_enabled = false
	else:
		print("[VibrationManager] Mobile device detected: android=%s, ios=%s" % [OS.has_feature("android"), OS.has_feature("ios")])

func _load_setting():
	"""Load vibration preference from save file"""
	var save_path = "user://game_save.json"
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_string)

			if parse_result == OK:
				var data = json.data
				if data is Dictionary and data.has("settings"):
					if data.settings.has(SETTING_KEY):
						vibration_enabled = data.settings[SETTING_KEY]
						print("[VibrationManager] Loaded setting: vibration_enabled = %s" % vibration_enabled)
						return

	# Default: enabled
	vibration_enabled = true
	print("[VibrationManager] Using default: vibration_enabled = true")

func save_setting():
	"""Save vibration preference to save file"""
	var save_path = "user://game_save.json"
	var data = {}

	# Load existing save data
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(json_string)

			if parse_result == OK:
				data = json.data

	# Ensure settings dictionary exists
	if not data.has("settings"):
		data["settings"] = {}

	# Update vibration setting
	data.settings[SETTING_KEY] = vibration_enabled

	# Save back to file
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[VibrationManager] Saved setting: vibration_enabled = %s" % vibration_enabled)

func set_vibration_enabled(enabled: bool):
	"""Enable or disable vibration"""
	if vibration_enabled != enabled:
		vibration_enabled = enabled
		save_setting()
		vibration_enabled_changed.emit(enabled)
		print("[VibrationManager] Vibration %s" % ("enabled" if enabled else "disabled"))

func is_vibration_enabled() -> bool:
	"""Check if vibration is enabled"""
	var is_mobile = OS.has_feature("android") or OS.has_feature("ios")
	return vibration_enabled and is_mobile

func vibrate(pattern: String = "medium"):
	"""Trigger haptic vibration with specified pattern"""
	print("[VibrationManager] vibrate() called with pattern: %s" % pattern)
	print("[VibrationManager] vibration_enabled: %s" % vibration_enabled)
	print("[VibrationManager] is_vibration_enabled(): %s" % is_vibration_enabled())

	if not is_vibration_enabled():
		print("[VibrationManager] Vibration disabled, skipping")
		return

	if not PATTERNS.has(pattern):
		print("[VibrationManager] WARNING: Unknown pattern '%s', using 'medium'" % pattern)
		pattern = "medium"

	var pattern_data = PATTERNS[pattern]

	if pattern_data is int:
		# Single vibration
		print("[VibrationManager] Calling Input.vibrate_handheld(%d)" % pattern_data)
		Input.vibrate_handheld(pattern_data)
		print("[VibrationManager] ✓ Vibrate: %s (%dms)" % [pattern, pattern_data])
	elif pattern_data is Array:
		# Pattern of vibrations
		print("[VibrationManager] Starting vibration pattern: %s" % str(pattern_data))
		_vibrate_pattern(pattern_data)
		print("[VibrationManager] ✓ Vibrate pattern: %s" % pattern)

func _vibrate_pattern(durations: Array):
	"""Execute a pattern of vibrations with delays"""
	for i in range(durations.size()):
		var duration = durations[i]

		# Odd indices are delays, even indices are vibrations
		if i % 2 == 0:
			Input.vibrate_handheld(duration)

		# Wait for duration
		await get_tree().create_timer(duration / 1000.0).timeout

# Convenience methods for common game events
func vibrate_light():
	"""Light vibration for UI interactions"""
	vibrate("light")

func vibrate_medium():
	"""Medium vibration for standard game events"""
	vibrate("medium")

func vibrate_heavy():
	"""Heavy vibration for impactful events"""
	vibrate("heavy")

func vibrate_double():
	"""Double pulse for special events"""
	vibrate("double")

func vibrate_triple():
	"""Triple pulse for big combos"""
	vibrate("triple")

# Event-specific vibrations
func vibrate_match():
	"""Vibration for tile match"""
	vibrate("light")

func vibrate_special_tile():
	"""Vibration for creating special tile"""
	vibrate("medium")

func vibrate_special_activated():
	"""Vibration for activating special tile"""
	vibrate("heavy")

func vibrate_combo():
	"""Vibration for combo"""
	vibrate("double")

func vibrate_big_combo():
	"""Vibration for big combo (5+ cascade)"""
	vibrate("triple")

func vibrate_booster():
	"""Vibration for using booster"""
	vibrate("heavy")

func vibrate_level_complete():
	"""Vibration for level complete"""
	vibrate("double")

func vibrate_screenshake():
	"""Vibration accompanying screen shake effect"""
	vibrate("heavy")

func vibrate_lightning():
	"""Vibration for lightning effect"""
	vibrate("medium")

func vibrate_button_press():
	"""Vibration for button press"""
	vibrate("light")
