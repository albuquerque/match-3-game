extends Node2D
class_name RewardContainer

## Generalized Reward Container
## Theme-agnostic container that can represent any reward presentation style
## Configured via JSON, adaptable to any theme without code changes

signal state_changed(new_state: String)
signal opening_started
signal opening_complete
signal revealing_started
signal revealing_complete
signal closing_started
signal closing_complete
signal all_complete

# Container states
enum State {
	IDLE,
	OPENING,
	OPENED,
	REVEALING,
	CLOSING,
	COMPLETE
}

# Current state
var current_state: State = State.IDLE

# Configuration
var container_config: Dictionary = {}

# Visual layers (sprites, animations, etc.)
var visual_layers: Array = []

# Reward reveal system
var reward_revealer: RewardRevealSystem = null

# Reward data
var rewards_data: Dictionary = {
	"coins": 0,
	"gems": 0,
	"boosters": []
}

# Theme colors resolved from config
var resolved_colors: Dictionary = {}

func _ready():
	print("[RewardContainer] Initialized")

## Setup container with configuration
func setup(config: Dictionary):
	"""
	Configure the container with JSON configuration
	Args:
		config: Dictionary containing visual, animation, particle configs
	"""
	container_config = config
	print("[RewardContainer] Setup with config: ", config.get("container_id", "unknown"))

	# Resolve theme variables
	_resolve_theme_variables()

	# Build visual layers from config
	_build_visual_layers()

	# Create reward reveal system
	reward_revealer = RewardRevealSystem.new()
	add_child(reward_revealer)

	# Set HUD target positions (screen coordinates)
	# These are typical positions for coin/gem counters in top area
	# Coins typically on left, gems on right
	var viewport_size = get_viewport_rect().size
	var coin_pos = Vector2(120, 50)  # Top-left area
	var gem_pos = Vector2(viewport_size.x - 120, 50)  # Top-right area

	reward_revealer.set_coin_target(coin_pos)
	reward_revealer.set_gem_target(gem_pos)

	print("[RewardContainer] HUD targets set - Coins: %s, Gems: %s" % [coin_pos, gem_pos])

	# Enter idle state
	_change_state(State.IDLE)

## Set reward amounts to display
func set_rewards(coins: int, gems: int, boosters: Array = []):
	"""
	Set the rewards that will be revealed
	"""
	rewards_data.coins = coins
	rewards_data.gems = gems
	rewards_data.boosters = boosters
	print("[RewardContainer] Rewards set: %d coins, %d gems, %d boosters" % [coins, gems, boosters.size()])

## Start the opening animation
func play_opening_animation():
	"""
	Trigger the container opening sequence
	"""
	if current_state != State.IDLE:
		push_warning("[RewardContainer] Cannot open - not in IDLE state")
		return

	_change_state(State.OPENING)
	opening_started.emit()

	# Get opening animation config
	var opening_config = container_config.get("animations", {}).get("opening", {})

	if opening_config.is_empty():
		# No animation defined, skip to opened
		_on_opening_complete()
	else:
		# Execute opening animation
		await _execute_animation(opening_config)
		_on_opening_complete()

## Execute reveal animation (rewards fly out)
func play_reveal_animation():
	"""
	Reveal the rewards with animation
	"""
	if current_state != State.OPENED:
		push_warning("[RewardContainer] Cannot reveal - not in OPENED state")
		return

	_change_state(State.REVEALING)
	revealing_started.emit()

	# Get reveal animation config
	var reveal_config = container_config.get("animations", {}).get("reveal", {})

	# TODO: Implement reward spawning and fly-to-HUD
	await _reveal_rewards(reveal_config)

	_on_revealing_complete()

## Play closing animation
func play_closing_animation():
	"""
	Close the container with animation
	"""
	if current_state == State.COMPLETE:
		return

	_change_state(State.CLOSING)
	closing_started.emit()

	# Get closing animation config
	var closing_config = container_config.get("animations", {}).get("closing", {})

	if closing_config.is_empty():
		# No animation, just complete
		_on_closing_complete()
	else:
		await _execute_animation(closing_config)
		_on_closing_complete()

## Internal: Change state
func _change_state(new_state: State):
	"""
	Change container state and emit signal
	"""
	var old_state = current_state
	current_state = new_state

	var state_name = _get_state_name(new_state)
	print("[RewardContainer] State: %s → %s" % [_get_state_name(old_state), state_name])
	state_changed.emit(state_name)

## Internal: Get state name for logging
func _get_state_name(state: State) -> String:
	match state:
		State.IDLE: return "IDLE"
		State.OPENING: return "OPENING"
		State.OPENED: return "OPENED"
		State.REVEALING: return "REVEALING"
		State.CLOSING: return "CLOSING"
		State.COMPLETE: return "COMPLETE"
	return "UNKNOWN"

## Internal: Resolve theme color variables
func _resolve_theme_variables():
	"""
	Resolve ${theme.xxx} variables to actual colors
	"""
	var colors = container_config.get("visual", {}).get("colors", {})

	for key in colors:
		var value = colors[key]
		if typeof(value) == TYPE_STRING and value.begins_with("${theme."):
			# Extract variable name
			var var_name = value.trim_prefix("${theme.").trim_suffix("}")

			# Resolve from ThemeManager
			if ThemeManager and ThemeManager.has_method("get_color"):
				resolved_colors[key] = ThemeManager.get_color(var_name)
			else:
				# Fallback to default colors
				resolved_colors[key] = _get_default_color(var_name)
		else:
			# Direct color value
			resolved_colors[key] = Color(value) if typeof(value) == TYPE_STRING else value

	print("[RewardContainer] Resolved theme colors: ", resolved_colors)

## Internal: Get default color fallback
func _get_default_color(color_name: String) -> Color:
	match color_name:
		"primary_color": return Color(1.0, 0.9, 0.3, 1.0)  # Gold
		"accent_color": return Color(1.0, 0.6, 0.0, 1.0)   # Orange
		"particle_color": return Color(1.0, 1.0, 0.5, 1.0) # Light yellow
		"gold_color": return Color(1.0, 0.84, 0.0, 1.0)    # Gold
	return Color.WHITE

## Internal: Build visual layers from config
func _build_visual_layers():
	"""
	Create sprites/nodes for each visual layer defined in config
	"""
	var layers_config = container_config.get("visual", {}).get("layers", [])

	for layer_config in layers_config:
		var layer = _create_visual_layer(layer_config)
		if layer:
			visual_layers.append(layer)
			add_child(layer)

	print("[RewardContainer] Created %d visual layers" % visual_layers.size())

## Internal: Create a single visual layer
func _create_visual_layer(layer_config: Dictionary) -> Node2D:
	"""
	Create a visual layer (Sprite2D, AnimatedSprite2D, etc.)
	"""
	var layer_type = layer_config.get("type", "sprite")
	var layer: Node2D = null

	match layer_type:
		"sprite":
			layer = Sprite2D.new()
			var texture_path = layer_config.get("texture", "")
			if texture_path and ResourceLoader.exists(texture_path):
				layer.texture = load(texture_path)
			else:
				push_warning("[RewardContainer] Texture not found: %s" % texture_path)
				return null

		"animated_sprite":
			layer = AnimatedSprite2D.new()
			# TODO: Load sprite frames

		_:
			push_warning("[RewardContainer] Unknown layer type: %s" % layer_type)
			return null

	# Apply layer properties
	layer.z_index = layer_config.get("z_index", 0)
	layer.scale = Vector2.ONE * layer_config.get("scale", 1.0)

	# Apply initial alpha if specified
	if layer_config.has("alpha"):
		var alpha = layer_config.get("alpha", 1.0)
		layer.modulate.a = alpha

	# Apply custom position if specified
	if layer_config.has("position"):
		var pos_array = layer_config.get("position")
		if pos_array is Array and pos_array.size() >= 2:
			layer.position = Vector2(pos_array[0], pos_array[1])

	# Set pivot if specified
	var pivot = layer_config.get("pivot", "center")
	_set_layer_pivot(layer, pivot)

	return layer

## Internal: Set layer pivot point
func _set_layer_pivot(layer: Node2D, pivot: String):
	"""
	Set the pivot/offset for rotation
	For proper hinging, we set the layer's position and use offset/centered
	Supports edges and corners for realistic hinge points
	"""
	if layer is Sprite2D:
		var texture = layer.texture
		if texture:
			var size = texture.get_size()

			# For hinged rotation, we need to:
			# 1. Set sprite as non-centered
			# 2. Position the sprite so its hinge point is at the layer's origin
			match pivot:
				# Edge pivots
				"top":
					# Hinge at top edge center
					layer.centered = false
					layer.offset = Vector2(-size.x / 2, 0)
				"bottom":
					# Hinge at bottom edge center
					layer.centered = false
					layer.offset = Vector2(-size.x / 2, -size.y)
				"left":
					# Hinge at left edge center
					layer.centered = false
					layer.offset = Vector2(0, -size.y / 2)
				"right":
					# Hinge at right edge center
					layer.centered = false
					layer.offset = Vector2(-size.x, -size.y / 2)

				# Corner pivots (for more realistic box lids!)
				"top-left":
					# Hinge at top-left corner (back-left of box)
					layer.centered = false
					layer.offset = Vector2(0, 0)
				"top-right":
					# Hinge at top-right corner (back-right of box)
					layer.centered = false
					layer.offset = Vector2(-size.x, 0)
				"bottom-left":
					# Hinge at bottom-left corner
					layer.centered = false
					layer.offset = Vector2(0, -size.y)
				"bottom-right":
					# Hinge at bottom-right corner
					layer.centered = false
					layer.offset = Vector2(-size.x, -size.y)

				"center", _:
					# Default centered
					layer.centered = true
					layer.offset = Vector2.ZERO

## Internal: Execute animation from config
func _execute_animation(animation_config: Dictionary):
	"""
	Execute an animation based on config
	Supports: float, shake, rotate_layer, scale_layer, sequence, etc.
	"""
	var anim_type = animation_config.get("type", "")

	match anim_type:
		"float":
			await _animate_float(animation_config)
		"shake":
			await _animate_shake(animation_config)
		"rotate_layer":
			await _animate_rotate_layer(animation_config)
		"scale_layer":
			await _animate_scale_layer(animation_config)
		"fade_layer":
			await _animate_fade_layer(animation_config)
		"sequence":
			await _animate_sequence(animation_config.get("steps", []))
		"scale":
			await _animate_scale_all(animation_config)
		_:
			push_warning("[RewardContainer] Unknown animation type: %s" % anim_type)
			await get_tree().create_timer(0.1).timeout

## Internal: Float animation (gentle bobbing)
func _animate_float(config: Dictionary):
	var amplitude = config.get("amplitude", 5)
	var duration = config.get("duration", 2.0)

	var tween = create_tween()
	tween.set_loops(-1)
	tween.tween_property(self, "position:y", position.y - amplitude, duration / 2)
	tween.tween_property(self, "position:y", position.y + amplitude, duration / 2)

## Internal: Shake animation
func _animate_shake(config: Dictionary):
	var intensity = config.get("intensity", 10)
	var duration = config.get("duration", 0.3)

	var original_pos = position
	var steps = 10
	var step_duration = duration / steps

	for i in range(steps):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		position = original_pos + offset
		await get_tree().create_timer(step_duration).timeout

	position = original_pos

## Internal: Rotate layer animation
func _animate_rotate_layer(config: Dictionary):
	var layer_index = config.get("layer", 0)
	var angle_deg = config.get("angle", 45)
	var duration = config.get("duration", 0.5)

	if layer_index >= visual_layers.size():
		return

	var layer = visual_layers[layer_index]
	var target_rotation = deg_to_rad(angle_deg)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(layer, "rotation", target_rotation, duration)
	await tween.finished

## Internal: Scale layer animation
func _animate_scale_layer(config: Dictionary):
	var layer_index = config.get("layer", 0)
	var target_scale = config.get("scale", 1.2)
	var duration = config.get("duration", 0.3)

	if layer_index >= visual_layers.size():
		return

	var layer = visual_layers[layer_index]
	var scale_vec = Vector2.ONE * target_scale

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(layer, "scale", scale_vec, duration)
	await tween.finished

## Internal: Fade layer animation
func _animate_fade_layer(config: Dictionary):
	"""
	Fade a layer in or out by changing its alpha/transparency
	Perfect for transitioning between closed/open chest images
	"""
	var layer_index = config.get("layer", 0)
	var from_alpha = config.get("from", 1.0)
	var to_alpha = config.get("to", 0.0)
	var duration = config.get("duration", 0.4)

	if layer_index >= visual_layers.size():
		return

	var layer = visual_layers[layer_index]

	# Set initial alpha
	layer.modulate.a = from_alpha

	# Create tween for smooth fade
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Tween the alpha component
	var target_modulate = layer.modulate
	target_modulate.a = to_alpha
	tween.tween_property(layer, "modulate", target_modulate, duration)

	await tween.finished

## Internal: Scale all animation
func _animate_scale_all(config: Dictionary):
	var from_scale = config.get("from", 1.0)
	var to_scale = config.get("to", 1.3)
	var duration = config.get("duration", 0.5)

	scale = Vector2.ONE * from_scale

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE * to_scale, duration)
	await tween.finished

## Internal: Sequence animation
func _animate_sequence(steps: Array):
	"""
	Execute multiple animations in sequence
	"""
	for step in steps:
		var action = step.get("action", "")

		match action:
			"shake":
				await _animate_shake(step)
			"rotate_layer":
				await _animate_rotate_layer(step)
			"scale_layer":
				await _animate_scale_layer(step)
			"fade_layer":
				await _animate_fade_layer(step)
			_:
				push_warning("[RewardContainer] Unknown sequence action: %s" % action)

## Internal: Reveal rewards
func _reveal_rewards(config: Dictionary):
	"""
	Spawn reward icons and animate them to HUD
	Supports configurable anchor point for spawn position
	"""
	if not reward_revealer:
		print("[RewardContainer] No reward revealer available")
		await get_tree().create_timer(1.0).timeout
		return

	# Get reveal pattern from config
	var pattern = config.get("pattern", "arc")

	# Get anchor point from config
	# Anchor determines where rewards spawn from (relative to container center)
	# Examples: [0, -50] = 50px above center (inside chest opening)
	#           [0, 0] = exact center (default)
	var anchor = config.get("anchor", [0, 0])
	var anchor_pos = Vector2.ZERO

	if anchor is Array and anchor.size() >= 2:
		anchor_pos = Vector2(anchor[0], anchor[1])
		print("[RewardContainer] Reveal anchor: ", anchor_pos)

	# Reveal rewards from anchor position
	await reward_revealer.reveal_rewards(rewards_data, anchor_pos, pattern)

	print("[RewardContainer] Rewards revealed")

## Event handlers
func _on_opening_complete():
	_change_state(State.OPENED)
	opening_complete.emit()

	# Spawn particles on open
	_spawn_particles("on_open")

func _on_revealing_complete():
	revealing_complete.emit()

	# Spawn particles on reveal
	_spawn_particles("on_reveal")

func _on_closing_complete():
	_change_state(State.COMPLETE)
	closing_complete.emit()
	all_complete.emit()

## Internal: Spawn particles based on config
func _spawn_particles(particle_key: String):
	"""
	Spawn particles from configuration
	"""
	var particles_config = container_config.get("particles", {}).get(particle_key, {})

	if particles_config.is_empty():
		return

	# Spawn particles at container center
	ContainerParticleSpawner.spawn_particles(self, particles_config, Vector2.ZERO)

## Cleanup
func cleanup():
	"""
	Clean up container resources
	"""
	# Clean up reward revealer
	if reward_revealer and is_instance_valid(reward_revealer):
		reward_revealer.cleanup()
		reward_revealer.queue_free()
		reward_revealer = null

	# Clean up visual layers
	for layer in visual_layers:
		if is_instance_valid(layer):
			layer.queue_free()
	visual_layers.clear()

	queue_free()
