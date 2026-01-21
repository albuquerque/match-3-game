extends Node2D
class_name ObstacleTile

## Obstacle tile that blocks movement and requires hits to destroy

signal destroyed(obstacle_type: String)
signal damaged(remaining_hits: int)

## Type of obstacle (crate_soft, rock_hard, etc.)
@export var obstacle_type: String = "crate_soft"

## Grid position
var grid_position: Vector2 = Vector2.ZERO

## Number of hits remaining before destruction
var hits_remaining: int = 1

## Maximum hits (for visual state calculation)
var max_hits: int = 1

## Visual sprite
var sprite: Sprite2D

## Is this obstacle chained?
var is_chained: bool = false

## Chain anchor position (where the chain leads to)
var chain_anchor: Vector2 = Vector2.ZERO

## Chain direction
var chain_direction: String = "down"  # up, down, left, right

## Required distance to move for chained obstacles
var required_distance: int = 0

## Current distance moved
var distance_moved: int = 0

## Reference to GameBoard
var game_board: Node2D = null

func _ready():
	# Create visual sprite
	sprite = Sprite2D.new()
	add_child(sprite)

	# Load texture based on type
	load_texture()

	# Set initial scale
	sprite.scale = Vector2(1.0, 1.0)

func initialize(type: String, hits: int = 1, chained: bool = false):
	"""Initialize the obstacle with type and hit count"""
	obstacle_type = type
	hits_remaining = hits
	max_hits = hits
	is_chained = chained

	load_texture()
	update_visual_state()

func load_texture():
	"""Load the appropriate texture for this obstacle type"""
	var theme = get_node_or_null("/root/ThemeManager")
	var theme_name = "legacy"
	if theme and theme.has_method("get_theme_name"):
		theme_name = theme.get_theme_name()

	var texture_path = ""

	match obstacle_type:
		"crate_soft":
			texture_path = "res://textures/%s/obstacle_crate_soft.png" % theme_name
		"crate_hard":
			texture_path = "res://textures/%s/obstacle_crate_hard.png" % theme_name
		"rock_hard":
			texture_path = "res://textures/%s/obstacle_rock.png" % theme_name
		"ice":
			texture_path = "res://textures/%s/obstacle_ice.png" % theme_name
		"chained":
			texture_path = "res://textures/%s/obstacle_chained.png" % theme_name
		_:
			texture_path = "res://textures/%s/obstacle_crate_soft.png" % theme_name

	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	else:
		# Fallback: create visual based on type
		create_fallback_visual()

func create_fallback_visual():
	"""Create a simple visual if texture not found"""
	var color_map = {
		"crate_soft": Color(0.6, 0.4, 0.2),   # Brown
		"crate_hard": Color(0.5, 0.5, 0.5),   # Gray
		"rock_hard": Color(0.3, 0.3, 0.3),    # Dark gray
		"ice": Color(0.7, 0.9, 1.0),          # Light blue
		"chained": Color(0.8, 0.6, 0.0)       # Gold
	}

	var color = color_map.get(obstacle_type, Color(0.5, 0.5, 0.5))
	sprite.modulate = color

func set_grid_position(pos: Vector2):
	"""Set the grid position and update visual position"""
	grid_position = pos

	if game_board:
		update_visual_position()

func update_visual_position():
	"""Update visual position based on grid position"""
	if not game_board:
		return

	# Default tile size if game_board doesn't have it
	var tile_size = 64
	if "tile_size" in game_board:
		tile_size = game_board.tile_size

	var pixel_pos = Vector2(
		grid_position.x * tile_size + tile_size / 2,
		grid_position.y * tile_size + tile_size / 2
	)

	position = pixel_pos

func take_damage(amount: int = 1):
	"""Take damage and potentially be destroyed"""
	if hits_remaining <= 0:
		return

	hits_remaining -= amount

	print("[ObstacleTile] %s at %s took %d damage, %d hits remaining" % [obstacle_type, grid_position, amount, hits_remaining])

	if hits_remaining <= 0:
		destroy()
	else:
		update_visual_state()
		damaged.emit(hits_remaining)

func update_visual_state():
	"""Update visual appearance based on damage"""
	if not sprite:
		return

	# Calculate damage percentage
	var damage_percent = 1.0 - (float(hits_remaining) / float(max_hits))

	# Darken sprite based on damage
	var brightness = 1.0 - (damage_percent * 0.4)
	sprite.modulate = Color(brightness, brightness, brightness, 1.0)

	# Add slight shake for damaged state
	if hits_remaining < max_hits:
		var shake_offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		sprite.position = shake_offset

func destroy():
	"""Destroy this obstacle with animation"""
	print("[ObstacleTile] Destroying %s at %s" % [obstacle_type, grid_position])

	# Play destruction animation
	var tween = create_tween()
	tween.set_parallel(true)

	# Scale down and fade out
	tween.tween_property(sprite, "scale", Vector2(0.0, 0.0), 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)

	# Emit signal
	destroyed.emit(obstacle_type)

	# Remove after animation
	tween.tween_callback(queue_free)

func is_destroyed() -> bool:
	"""Check if this obstacle has been destroyed"""
	return hits_remaining <= 0

func move_toward_anchor():
	"""Move chained obstacle one step toward anchor"""
	if not is_chained:
		return false

	var move_delta = Vector2.ZERO

	match chain_direction:
		"down":
			if grid_position.y < chain_anchor.y:
				move_delta = Vector2(0, 1)
		"up":
			if grid_position.y > chain_anchor.y:
				move_delta = Vector2(0, -1)
		"left":
			if grid_position.x > chain_anchor.x:
				move_delta = Vector2(-1, 0)
		"right":
			if grid_position.x < chain_anchor.x:
				move_delta = Vector2(1, 0)

	if move_delta != Vector2.ZERO:
		grid_position += move_delta
		distance_moved += 1
		update_visual_position()

		# Check if reached required distance
		if distance_moved >= required_distance:
			# Successfully moved to goal
			destroy()
			return true

	return false

func _to_string() -> String:
	return "ObstacleTile(%s at %s, %d hits)" % [obstacle_type, grid_position, hits_remaining]
