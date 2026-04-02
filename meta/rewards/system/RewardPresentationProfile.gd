extends Node

## Loads and manages reward presentation configurations from JSON

static var _cache: Dictionary = {}

static func load_profile(profile_id: String) -> Dictionary:
	if _cache.has(profile_id):
		return _cache[profile_id]

	var path = "res://data/reward_profiles/%s.json" % profile_id
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			file.close()

			var json = JSON.new()
			var parse_result = json.parse(text)

			if parse_result == OK:
				var profile = json.get_data()
				_cache[profile_id] = profile
				return profile

	return get_default_profile()

static func get_default_profile() -> Dictionary:
	return {
		"profile_id": "default",
		"container_type": "CHEST",
		"open_method": "tap",
		"stages": ["spawn_container", "interaction", "reward_reveal", "summary"],
		"reward_reveal": {
			"spawn_pattern": "simple",
			"delay_between_rewards_ms": 200,
			"hud_fly_animation": true
		}
	}

static func get_profile_for_theme(theme_name: String) -> String:
	match theme_name:
		"legacy", "biblical":
			return "biblical_scroll"
		_:
			return "default_chest"
