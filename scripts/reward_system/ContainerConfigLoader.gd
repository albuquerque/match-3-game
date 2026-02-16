extends RefCounted
class_name ContainerConfigLoader

## Container Configuration Loader
## Loads and caches reward container configurations from JSON files

# Configuration cache
static var _config_cache: Dictionary = {}

# Theme mappings cache
static var _theme_mappings: Dictionary = {}
static var _theme_mappings_loaded: bool = false

# Default container fallback
const DEFAULT_CONTAINER = "simple_box"
const THEME_MAPPINGS_PATH = "res://data/theme_container_mappings.json"

## Load container configuration for a specific theme
static func load_for_theme(theme_name: String) -> Dictionary:
	"""
	Load the appropriate container configuration for the given theme
	Returns: Dictionary with container configuration, or empty dict if not found
	"""
	print("[ContainerConfigLoader] Loading container for theme: %s" % theme_name)

	# Check if theme has a preferred container
	var container_id = _get_theme_container_id(theme_name)

	# Load the container config
	return load_container(container_id)

## Load a specific container by ID
static func load_container(container_id: String) -> Dictionary:
	"""
	Load a container configuration by its ID
	"""
	# Check cache first
	if _config_cache.has(container_id):
		print("[ContainerConfigLoader] Using cached config: %s" % container_id)
		return _config_cache[container_id]

	# Build file path
	var config_path = "res://data/reward_containers/%s.json" % container_id

	# Check if file exists
	if not FileAccess.file_exists(config_path):
		push_warning("[ContainerConfigLoader] Container config not found: %s" % config_path)
		return {}

	# Load and parse JSON
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error("[ContainerConfigLoader] Failed to open: %s" % config_path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		push_error("[ContainerConfigLoader] JSON parse error in %s: %s" % [config_path, json.get_error_message()])
		return {}

	var config = json.data

	if typeof(config) != TYPE_DICTIONARY:
		push_error("[ContainerConfigLoader] Invalid JSON format in %s" % config_path)
		return {}

	# Validate config
	if not _validate_config(config):
		push_error("[ContainerConfigLoader] Invalid container config: %s" % container_id)
		return {}

	# Cache and return
	_config_cache[container_id] = config
	print("[ContainerConfigLoader] Loaded container config: %s" % container_id)

	return config

## Get the container ID for a theme
static func _get_theme_container_id(theme_name: String) -> String:
	"""
	Determine which container to use for the given theme
	Reads from theme_container_mappings.json
	Supports DLC themes via _default fallback
	"""
	# Load theme mappings if not already loaded
	if not _theme_mappings_loaded:
		_load_theme_mappings()

	# Look up container for specific theme
	if _theme_mappings.has(theme_name):
		var theme_config = _theme_mappings[theme_name]
		if theme_config is Dictionary and theme_config.has("reward_container"):
			return theme_config["reward_container"]

	# Use _default fallback for unknown themes (DLC, custom themes)
	if _theme_mappings.has("_default"):
		var default_config = _theme_mappings["_default"]
		if default_config is Dictionary and default_config.has("reward_container"):
			print("[ContainerConfigLoader] Theme '%s' not found, using _default" % theme_name)
			return default_config["reward_container"]

	# Final fallback
	print("[ContainerConfigLoader] No mapping found for theme '%s', using hardcoded default" % theme_name)
	return DEFAULT_CONTAINER

## Load theme-to-container mappings from JSON
static func _load_theme_mappings():
	"""
	Load theme container mappings from JSON configuration file
	"""
	_theme_mappings_loaded = true

	if not FileAccess.file_exists(THEME_MAPPINGS_PATH):
		push_warning("[ContainerConfigLoader] Theme mappings file not found: %s" % THEME_MAPPINGS_PATH)
		return

	var file = FileAccess.open(THEME_MAPPINGS_PATH, FileAccess.READ)
	if not file:
		push_error("[ContainerConfigLoader] Failed to open theme mappings: %s" % THEME_MAPPINGS_PATH)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		push_error("[ContainerConfigLoader] JSON parse error in theme mappings: %s" % json.get_error_message())
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("[ContainerConfigLoader] Invalid theme mappings format")
		return

	_theme_mappings = json.data
	print("[ContainerConfigLoader] Loaded mappings for %d themes" % _theme_mappings.size())

## Validate container configuration
static func _validate_config(config: Dictionary) -> bool:
	"""
	Basic validation of container configuration
	Returns: true if valid, false otherwise
	"""
	# Must have container_id
	if not config.has("container_id"):
		push_error("[ContainerConfigLoader] Missing container_id")
		return false

	# Must have visual section
	if not config.has("visual"):
		push_warning("[ContainerConfigLoader] Missing visual section - using defaults")

	# Must have at least one layer
	var layers = config.get("visual", {}).get("layers", [])
	if layers.is_empty():
		push_warning("[ContainerConfigLoader] No visual layers defined")

	return true

## Clear configuration cache
static func clear_cache():
	"""
	Clear the configuration cache (useful for development/testing)
	"""
	_config_cache.clear()
	print("[ContainerConfigLoader] Cache cleared")

## Preload all container configs
static func preload_all():
	"""
	Preload all container configurations for faster runtime access
	"""
	var containers_dir = "res://data/reward_containers/"

	if not DirAccess.dir_exists_absolute(containers_dir):
		print("[ContainerConfigLoader] Container directory not found: %s" % containers_dir)
		return

	var dir = DirAccess.open(containers_dir)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var loaded_count = 0

	while file_name != "":
		if file_name.ends_with(".json"):
			var container_id = file_name.trim_suffix(".json")
			load_container(container_id)
			loaded_count += 1
		file_name = dir.get_next()

	dir.list_dir_end()
	print("[ContainerConfigLoader] Preloaded %d container configs" % loaded_count)
