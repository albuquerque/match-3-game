extends Node2D
class_name ContainerParticleSpawner

## Generic Particle Spawner for Reward Containers
## Theme-aware particle effects with configurable patterns

# Particle pool for performance
static var _particle_pool: Array[CPUParticles2D] = []
const MAX_POOL_SIZE = 20

## Spawn particles based on configuration
static func spawn_particles(parent: Node, config: Dictionary, position: Vector2 = Vector2.ZERO):
	"""
	Spawn particles with theme-aware colors and patterns
	Args:
		parent: Node to attach particles to
		config: Particle configuration dictionary
		position: Spawn position (relative to parent)
	"""
	if config.is_empty():
		return

	# Get or create particle emitter
	var particles = _get_particle_emitter()

	# Configure particle system
	_configure_particles(particles, config)

	# Set position
	particles.position = position

	# Add to parent
	parent.add_child(particles)

	# Start emission
	particles.emitting = true

	# Auto-cleanup after lifetime
	var lifetime = config.get("lifetime", 1.0)
	var cleanup_delay = lifetime + 0.5

	await parent.get_tree().create_timer(cleanup_delay).timeout

	if is_instance_valid(particles):
		_return_to_pool(particles)

## Get particle emitter from pool or create new
static func _get_particle_emitter() -> CPUParticles2D:
	"""
	Get particle emitter from pool or create new one
	"""
	# Try to get from pool
	for particles in _particle_pool:
		if not particles.emitting and is_instance_valid(particles):
			_particle_pool.erase(particles)
			return particles

	# Create new
	var particles = CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.8

	return particles

## Return particle emitter to pool
static func _return_to_pool(particles: CPUParticles2D):
	"""
	Return particle emitter to pool for reuse
	"""
	if particles.get_parent():
		particles.get_parent().remove_child(particles)

	if _particle_pool.size() < MAX_POOL_SIZE:
		particles.emitting = false
		_particle_pool.append(particles)
	else:
		particles.queue_free()

## Configure particle system from config
static func _configure_particles(particles: CPUParticles2D, config: Dictionary):
	"""
	Configure particle emitter based on JSON config
	"""
	# Texture
	var texture_path = config.get("texture", "")
	if texture_path and ResourceLoader.exists(texture_path):
		particles.texture = load(texture_path)
	else:
		# Use simple circle as fallback
		particles.texture = _create_circle_texture(8)

	# Amount
	particles.amount = config.get("count", 10)

	# Lifetime
	particles.lifetime = config.get("lifetime", 1.0)

	# Spread
	var spread = config.get("spread", 180)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.0
	particles.spread = spread / 2.0  # Godot uses half-spread

	# Speed
	var speed = config.get("speed", 100)
	particles.initial_velocity_min = speed * 0.8
	particles.initial_velocity_max = speed * 1.2

	# Color (with theme variable resolution)
	var color_value = config.get("color", "FFFFFF")
	var color = _resolve_color(color_value)
	particles.color = color

	# Gravity
	particles.gravity = Vector2(0, config.get("gravity", 98.0))

	# Scale
	particles.scale_amount_min = config.get("scale_min", 0.5)
	particles.scale_amount_max = config.get("scale_max", 1.5)

	# Fade out at end
	particles.color_ramp = _create_fade_gradient()

## Resolve color value (supports theme variables)
static func _resolve_color(value: String) -> Color:
	"""
	Resolve color from string or theme variable
	"""
	if value.begins_with("${theme."):
		# Extract variable name
		var var_name = value.trim_prefix("${theme.").trim_suffix("}")

		# Try to get from ThemeManager
		if ThemeManager:
			# Use call to avoid static analysis errors
			if ThemeManager.has_method("get_color"):
				return ThemeManager.call("get_color", var_name)
			elif ThemeManager.has_method("get_theme_color"):
				return ThemeManager.call("get_theme_color", var_name)

		# Fallback to defaults
		return _get_default_color(var_name)
	else:
		# Parse as hex color
		return Color(value) if value.begins_with("#") else Color.WHITE

## Get default color fallback
static func _get_default_color(color_name: String) -> Color:
	match color_name:
		"primary_color": return Color(1.0, 0.9, 0.3, 1.0)
		"accent_color": return Color(1.0, 0.6, 0.0, 1.0)
		"particle_color": return Color(1.0, 1.0, 0.5, 1.0)
		"gold_color": return Color(1.0, 0.84, 0.0, 1.0)
	return Color.WHITE

## Create fade gradient for particles
static func _create_fade_gradient() -> Gradient:
	"""
	Create gradient that fades particles at the end
	"""
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.7, Color.WHITE)
	gradient.add_point(1.0, Color(1, 1, 1, 0))  # Fade to transparent
	return gradient

## Create simple circle texture as fallback
static func _create_circle_texture(radius: int) -> ImageTexture:
	"""
	Create a simple circular texture for particles
	"""
	var size = radius * 2
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)

	# Fill with circle
	for x in range(size):
		for y in range(size):
			var dx = x - radius
			var dy = y - radius
			var dist = sqrt(dx * dx + dy * dy)

			if dist <= radius:
				var alpha = 1.0 - (dist / radius) * 0.3  # Soften edges
				img.set_pixel(x, y, Color(1, 1, 1, alpha))

	return ImageTexture.create_from_image(img)

## Spawn particles with pattern
static func spawn_with_pattern(parent: Node, config: Dictionary, pattern: String, center: Vector2):
	"""
	Spawn particles in specific patterns
	Args:
		parent: Parent node
		config: Particle config
		pattern: Pattern type (burst, spiral, rain, ring)
		center: Center position
	"""
	match pattern:
		"burst":
			# Single burst from center
			await spawn_particles(parent, config, center)

		"ring":
			# Ring of particles around center
			var count = 8
			var radius = 50
			for i in range(count):
				var angle = (TAU / count) * i
				var offset = Vector2(cos(angle), sin(angle)) * radius
				await spawn_particles(parent, config, center + offset)

		"spiral":
			# Spiral pattern
			var count = 12
			for i in range(count):
				var angle = (TAU / count) * i
				var radius = i * 10
				var offset = Vector2(cos(angle), sin(angle)) * radius
				spawn_particles(parent, config, center + offset)
				await parent.get_tree().create_timer(0.05).timeout

		"rain":
			# Particles fall from above
			var rain_config = config.duplicate()
			rain_config["gravity"] = 200
			rain_config["spread"] = 20
			var count = config.get("count", 10)
			for i in range(count):
				var x_offset = randf_range(-100, 100)
				spawn_particles(parent, rain_config, center + Vector2(x_offset, -100))
				await parent.get_tree().create_timer(0.1).timeout
