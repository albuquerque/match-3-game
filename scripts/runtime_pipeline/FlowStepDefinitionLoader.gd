extends RefCounted
class_name FlowStepDefinitionLoader

# Lightweight loader and cache for external flow step definitions
# Definitions live in res://data/flow_step_definitions/<id>.json

static var _cache: Dictionary = {}

static func load_definition(def_id: String) -> Dictionary:
	if def_id == null or def_id == "":
		return {}
	if _cache.has(def_id):
		return _cache[def_id]

	var paths = ["res://data/flow_step_definitions/%s.json" % def_id, "user://flow_step_definitions/%s.json" % def_id]
	for p in paths:
		if FileAccess.file_exists(p):
			var f = FileAccess.open(p, FileAccess.READ)
			if f:
				var txt = f.get_as_text()
				f.close()
				var json = JSON.new()
				var parse_result = json.parse(txt)
				if parse_result == OK and typeof(json.data) == TYPE_DICTIONARY:
					_cache[def_id] = json.data
					return json.data
				else:
					push_error("[FlowStepDefinitionLoader] Failed to parse JSON for %s: %s" % [p, json.get_error_message()])
			else:
				push_error("[FlowStepDefinitionLoader] Failed to open file: %s" % p)

	# Not found
	push_warning("[FlowStepDefinitionLoader] Definition not found: %s" % def_id)
	_cache[def_id] = {}
	return {}
