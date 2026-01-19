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

func get_coin_icon_path() -> String:
	"""Get the coin icon SVG path for current theme"""
	return theme_paths[current_theme] + "coin.svg"

func get_gem_icon_path() -> String:
	"""Get the gem icon SVG path for current theme"""
	return theme_paths[current_theme] + "gem.svg"

func load_coin_icon() -> Texture2D:
	"""Load and return the coin icon texture"""
	return load(get_coin_icon_path())

func load_gem_icon() -> Texture2D:
	"""Load and return the gem icon texture"""
	return load(get_gem_icon_path())

func create_currency_display(currency_type: String, amount: int, icon_size: int = 24, font_size: int = 24, color: Color = Color.WHITE) -> HBoxContainer:
	"""
	Create an HBoxContainer with currency icon and amount text
	currency_type: 'coins' or 'gems'
	amount: the number to display
	icon_size: size of the icon in pixels
	font_size: size of the text
	color: color of the text
	Returns: HBoxContainer with TextureRect (icon) and Label (amount)
	"""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 5)

	# Create icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if currency_type == "coins":
		icon.texture = load_coin_icon()
	elif currency_type == "gems":
		icon.texture = load_gem_icon()

	container.add_child(icon)

	# Create amount label
	var label = Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

	container.add_child(label)

	return container

# ========================================
# Font Management
# ========================================

# Cached Bangers font resource for performance
var _bangers_font = null

func get_bangers_font():
	"""Get the Bangers font resource (cached for performance)"""
	if _bangers_font == null:
		_bangers_font = load("res://fonts/Bangers/Bangers-Regular.ttf")
		if _bangers_font:
			print("[ThemeManager] Loaded Bangers font successfully")
		else:
			print("[ThemeManager] WARNING: Failed to load Bangers font!")
	return _bangers_font

func apply_bangers_font(label: Label, font_size: int = 24):
	"""Apply Bangers font to a label with the specified size"""
	var font = get_bangers_font()
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)

func apply_bangers_font_to_button(button: Button, font_size: int = 20):
	"""Apply Bangers font to a button with the specified size"""
	var font = get_bangers_font()
	if font:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
