extends Node

# Current active theme (stored as string for simplicity)
var current_theme: String = "modern"

# Theme configuration - maps theme name to texture folder
var theme_paths = {
	"legacy": "res://textures/legacy/",
	"modern": "res://textures/modern/"
}

func _ready():
	print("[ThemeManager] Initialized with theme: ", current_theme)

func set_theme(theme_name: String):
	"""Set the current theme by name"""
	if theme_name in theme_paths:
		current_theme = theme_name
		print("[ThemeManager] Theme changed to: ", current_theme)
	else:
		print("[ThemeManager] Unknown theme: ", theme_name, ", using modern")
		current_theme = "modern"

func set_theme_by_name(theme_name: String):
	"""Set theme by name (for JSON level loading)"""
	set_theme(theme_name.to_lower())

func get_theme_name() -> String:
	"""Get the name of the current theme"""
	return current_theme

func get_tile_texture_path(tile_type: int) -> String:
	"""Get the texture path for a tile based on current theme"""
	var base_path = theme_paths[current_theme]
	return base_path + "tile_%d.png" % tile_type

func get_current_theme_path() -> String:
	"""Get the current theme's base path"""
	return theme_paths[current_theme]

func theme_exists(theme_name: String) -> bool:
	"""Check if a theme exists"""
	return theme_name.to_lower() in theme_paths

