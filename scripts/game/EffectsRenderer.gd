extends Node
class_name EffectsRenderer

# EffectsRenderer: pure visual effect helpers moved out of GameBoard
# API (static):
# - create_lightning_beam_horizontal(board_node, row:int, color:Color, tile_size:float) -> Tween
# - create_lightning_beam_vertical(board_node, col:int, color:Color, tile_size:float) -> Tween
# - create_impact_particles(board_node, pos:Vector2, color:Color) -> void
# - create_special_activation_particles(board_node, world_pos:Vector2) -> void

static func create_lightning_beam_horizontal(board_node: Node, row: int, color: Color, tile_size: float) -> Tween:
	var start_pos = board_node.grid_to_world_position(Vector2(0, row))
	var end_pos = board_node.grid_to_world_position(Vector2(GameManager.GRID_WIDTH - 1, row))

	var beam = Line2D.new()
	beam.name = "LightningBeamH"
	beam.z_index = 100
	beam.visible = true
	beam.add_point(Vector2(start_pos.x - tile_size/2, start_pos.y))

	var num_segments = 8
	var segment_length = (end_pos.x - start_pos.x) / num_segments if num_segments != 0 else end_pos.x - start_pos.x
	for i in range(1, num_segments):
		var x = start_pos.x + (i * segment_length)
		var y = start_pos.y + randf_range(-tile_size * 0.3, tile_size * 0.3)
		beam.add_point(Vector2(x, y))
	beam.add_point(Vector2(end_pos.x + tile_size/2, end_pos.y))

	beam.width = 12
	beam.default_color = color
	beam.modulate = Color(1, 1, 1, 0)
	beam.antialiased = true
	beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam.joint_mode = Line2D.LINE_JOINT_ROUND

	board_node.add_child(beam)

	var tween = board_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam, "modulate", Color(3, 3, 3, 1), 0.05)
	tween.tween_property(beam, "width", 20, 0.05)

	tween.set_parallel(false)
	tween.tween_property(beam, "width", 15, 0.1)
	tween.tween_property(beam, "width", 18, 0.1)

	tween.tween_property(beam, "modulate", Color(1,1,1,0), 0.2)

	tween.finished.connect(beam.queue_free)
	return tween

static func create_lightning_beam_vertical(board_node: Node, col: int, color: Color, tile_size: float) -> Tween:
	var start_pos = board_node.grid_to_world_position(Vector2(col, 0))
	var end_pos = board_node.grid_to_world_position(Vector2(col, GameManager.GRID_HEIGHT - 1))

	var beam = Line2D.new()
	beam.name = "LightningBeamV"
	beam.z_index = 100
	beam.visible = true
	beam.add_point(Vector2(start_pos.x, start_pos.y - tile_size/2))

	var num_segments = 8
	var segment_length = (end_pos.y - start_pos.y) / num_segments if num_segments != 0 else end_pos.y - start_pos.y
	for i in range(1, num_segments):
		var x = start_pos.x + randf_range(-tile_size * 0.3, tile_size * 0.3)
		var y = start_pos.y + (i * segment_length)
		beam.add_point(Vector2(x, y))
	beam.add_point(Vector2(end_pos.x, end_pos.y + tile_size/2))

	beam.width = 12
	beam.default_color = color
	beam.modulate = Color(1, 1, 1, 0)
	beam.antialiased = true
	beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam.joint_mode = Line2D.LINE_JOINT_ROUND

	board_node.add_child(beam)

	var tween = board_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam, "modulate", Color(3, 3, 3, 1), 0.05)
	tween.tween_property(beam, "width", 20, 0.05)

	tween.set_parallel(false)
	tween.tween_property(beam, "width", 15, 0.1)
	tween.tween_property(beam, "width", 18, 0.1)

	tween.tween_property(beam, "modulate", Color(1,1,1,0), 0.2)

	tween.finished.connect(beam.queue_free)
	return tween

static func create_impact_particles(board_node: Node, pos: Vector2, color: Color) -> void:
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.spread = 180
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.5
	# Old code used particles.color = color; keep a lightweight ramp
	particles.color = color

	board_node.add_child(particles)
	# Cleanup after lifetime
	board_node.get_tree().create_timer(0.6).timeout.connect(particles.queue_free)

static func create_special_activation_particles(board_node: Node, world_pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.name = "SpecialActivationParticles"
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 1.2
	particles.explosiveness = 1.0
	particles.speed_scale = 2.0

	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.direction = Vector2(0, 0)
	particles.spread = 180
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 350.0
	particles.angular_velocity_min = -360
	particles.angular_velocity_max = 360
	particles.radial_accel_min = 80
	particles.radial_accel_max = 150
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.5, 1.5, 0.8, 1))
	gradient.add_point(0.3, Color(1.3, 1.3, 1.0, 1.0))
	gradient.add_point(0.6, Color(1.0, 1.0, 0.8, 0.8))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	particles.color_ramp = gradient

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1.3))
	scale_curve.add_point(Vector2(0.4, 1.0))
	scale_curve.add_point(Vector2(0.8, 0.5))
	scale_curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = scale_curve

	board_node.add_child(particles)
	board_node.get_tree().create_timer(1.5).timeout.connect(particles.queue_free)

static func animate_destroy_tiles(board_node: Node, positions: Array, tiles: Array) -> void:
	# Defensive: ensure inputs are valid
	if board_node == null or positions == null or positions.size() == 0:
		return

	var tweens = []
	# Spawn simple effects for each position
	for pos in positions:
		var gx = int(pos.x)
		var gy = int(pos.y)
		# Get tile instance if available
		var tile_inst = null
		if tiles != null and gx >= 0 and gx < tiles.size() and tiles[gx] and gy >= 0 and gy < tiles[gx].size():
			tile_inst = tiles[gx][gy]

		# Spawn impact particles at tile world pos
		var world_pos = null
		if tile_inst and is_instance_valid(tile_inst) and tile_inst.has_method("global_position"):
			world_pos = tile_inst.global_position if "global_position" in tile_inst else tile_inst.position
		else:
			if board_node.has_method("grid_to_world_position"):
				world_pos = board_node.grid_to_world_position(Vector2(gx, gy))
			else:
				world_pos = Vector2(gx * 10, gy * 10)

		# Particles
		var p = CPUParticles2D.new()
		p.position = world_pos
		p.one_shot = true
		p.amount = 20
		p.lifetime = 0.7
		p.initial_velocity_min = 70
		p.initial_velocity_max = 160
		var g = Gradient.new()
		g.add_point(0.0, Color(1,0.9,0.6,1))
		g.add_point(1.0, Color(1,1,1,0))
		p.color_ramp = g
		board_node.add_child(p)
		p.emitting = true
		board_node.get_tree().create_timer(0.85).timeout.connect(Callable(p, "queue_free"))

		# Fade out tile visual if available
		if tile_inst and is_instance_valid(tile_inst):
			var tw = board_node.create_tween()
			tw.tween_property(tile_inst, "modulate:a", 0.0, 0.18)
			tw.tween_property(tile_inst, "scale", Vector2(0.6, 0.6), 0.18)
			tweens.append(tw)
			# mark for freeing after tween
			board_node.get_tree().create_timer(0.22).timeout.connect(Callable(tile_inst, "queue_free"))

	# Wait for tweens to finish (if any)
	if tweens.size() > 0:
		for t in tweens:
			if t:
				await t.finished
	else:
		# Small safety delay
		await board_node.get_tree().create_timer(0.18).timeout

	# Done
	return
