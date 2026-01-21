extends Node2D
class_name TransformableTile

## Transformable tile that changes state when matches occur nearby

signal transformed(new_state: int)
signal all_transformed

## Type of transformation (flower, lightbulb, egg, etc.)
@export var transformation_type: String = "flower"

## Grid position
var grid_position: Vector2 = Vector2.ZERO

## Current transformation state (0 = initial, max_states-1 = final)
var current_state: int = 0

## Maximum number of states
var max_states: int = 2

## Visual sprite
var sprite: Sprite2D

## Required matches nearby to transform
var required_matches_nearby: int = 1

## Matches that have occurred nearby (counter)
var nearby_matches: int = 0

## Reference to GameBoard
var game_board: Node2D = null

func _ready():
	# Create visual sprite
	sprite = Sprite2D.new()
	add_child(sprite)

	# Load initial texture
	load_texture()

func initialize(type: String, states: int = 2):
	"""Initialize the transformable tile"""
	transformation_type = type
	max_states = states
	current_state = 0
	nearby_matches = 0

	load_texture()

func load_texture():
	"""Load the appropriate texture for current state"""
	var theme = get_node_or_null("/root/ThemeManager")
	var theme_name = "legacy"
	if theme and theme.has_method("get_theme_name"):
		theme_name = theme.get_theme_name()

	var texture_path = ""

	match transformation_type:
		"flower":
			var state_names = ["bud", "bloom"]
			var state_name = state_names[current_state] if current_state < state_names.size() else "bloom"
			texture_path = "res://textures/%s/transformable_flower_%s.png" % [theme_name, state_name]
		"lightbulb":
			var state_name = "on" if current_state > 0 else "off"
			texture_path = "res://textures/%s/transformable_lightbulb_%s.png" % [theme_name, state_name]
		"egg":
			var state_names = ["whole", "cracked", "hatched"]
			var state_name = state_names[current_state] if current_state < state_names.size() else "hatched"
			texture_path = "res://textures/%s/transformable_egg_%s.png" % [theme_name, state_name]
		_:
			texture_path = "res://textures/%s/transformable_flower_bud.png" % theme_name

	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	else:
		create_fallback_visual()

func create_fallback_visual():
	"""Create a simple visual if texture not found"""
	# Use different colors for different states
	var brightness = 0.3 + (float(current_state) / float(max_states - 1)) * 0.7
	sprite.modulate = Color(brightness, brightness, 1.0)

func set_grid_position(pos: Vector2):
	"""Set the grid position and update visual position"""
	grid_position = pos

	if game_board:
		update_visual_position()

func update_visual_position():
	"""Update visual position based on grid position"""
	if not game_board:
		return

	var tile_size = 64
	if "tile_size" in game_board:
		tile_size = game_board.tile_size

	var pixel_pos = Vector2(
		grid_position.x * tile_size + tile_size / 2,
		grid_position.y * tile_size + tile_size / 2
	)

	position = pixel_pos

func notify_nearby_match():
	"""Notify that a match occurred nearby"""
	nearby_matches += 1

	if nearby_matches >= required_matches_nearby:
		transform_next()

func transform_next() -> bool:
	"""Transform to the next state"""
	if current_state >= max_states - 1:
		return false  # Already at final state

	current_state += 1
	nearby_matches = 0  # Reset counter

	print("[TransformableTile] %s at %s transformed to state %d" % [transformation_type, grid_position, current_state])

	# Update visual
	load_texture()

	# Play transformation animation
	play_transform_animation()

	# Emit signal
	transformed.emit(current_state)

	# Check if fully transformed
	if current_state >= max_states - 1:
		all_transformed.emit()

	return true

func play_transform_animation():
	"""Play transformation animation"""
	var tween = create_tween()

	# Pulse effect
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)

func is_fully_transformed() -> bool:
	"""Check if this tile is fully transformed"""
	return current_state >= max_states - 1

func _to_string() -> String:
	return "TransformableTile(%s at %s, state %d/%d)" % [transformation_type, grid_position, current_state, max_states - 1]
