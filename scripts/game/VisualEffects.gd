extends Node
class_name VisualEffects

# VisualEffects: centralized visual helpers for GameBoard
# Provides static functions so GameBoard can delegate particle/beam/combo text creation.

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
	particles.direction = Vector2(0,0)
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
	gradient.add_point(0.0, Color(1.5,1.5,0.8,1))
	gradient.add_point(0.3, Color(1.3,1.3,1.0,1))
	gradient.add_point(0.6, Color(1.0,1.0,0.8,0.8))
	gradient.add_point(1.0, Color(1,1,1,0))
	particles.color_ramp = gradient

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1.3))
	scale_curve.add_point(Vector2(0.4, 1.0))
	scale_curve.add_point(Vector2(0.8, 0.5))
	scale_curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = scale_curve

	if board_node != null:
		board_node.add_child(particles)
		var tree = board_node.get_tree()
		if tree:
			tree.create_timer(1.5).timeout.connect(Callable(particles, "queue_free"))

static func create_impact_particles(board_node: Node, world_pos: Vector2, color: Color=Color(1,1,1,1)) -> void:
	var particles = CPUParticles2D.new()
	particles.name = "ImpactParticles"
	particles.position = world_pos
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

	# Build a simple color ramp from color to transparent
	var grad = Gradient.new()
	grad.add_point(0.0, color)
	var tcol = color
	tcol.a = 0.0
	grad.add_point(1.0, tcol)
	particles.color_ramp = grad

	if board_node != null:
		board_node.add_child(particles)
		var tree = board_node.get_tree()
		if tree:
			tree.create_timer(0.6).timeout.connect(Callable(particles, "queue_free"))

static func create_lightning_beam(border_parent: Node, start_pos: Vector2, end_pos: Vector2, tile_size: float, color: Color, vertical: bool=false, width: float = 12.0) -> Tween:
	var beam = Line2D.new()
	beam.name = vertical and "LightningBeamV" or "LightningBeamH"
	beam.z_index = 100
	beam.visible = true
	beam.add_point(start_pos)

	var num_segments = 8
	for i in range(1, num_segments):
		var t = float(i) / float(num_segments)
		var x = lerp(start_pos.x, end_pos.x, t)
		var y = lerp(start_pos.y, end_pos.y, t)
		var perp = Vector2(-(end_pos - start_pos).y, (end_pos - start_pos).x)
		if perp.length() > 0:
			perp = perp.normalized()
		var jitter = randf_range(-tile_size * 0.3, tile_size * 0.3)
		beam.add_point(Vector2(x, y) + perp * jitter)
	beam.add_point(end_pos)
	beam.width = width
	beam.default_color = color
	beam.antialiased = true
	if border_parent != null:
		border_parent.add_child(beam)
		var tween = border_parent.create_tween()
		tween.tween_property(beam, "modulate", Color(3,3,3,1), 0.05)
		tween.tween_property(beam, "width", width * 1.5, 0.05)
		tween.tween_property(beam, "width", width * 0.9, 0.15).set_delay(0.05)
		tween.tween_property(beam, "modulate", Color(1,1,1,0), 0.25).set_delay(0.05)
		# Free beam when tween finishes
		tween.finished.connect(Callable(beam, "queue_free"))
		# Also free the tween itself
		tween.finished.connect(Callable(tween, "queue_free"))
		return tween
	return null

static func show_combo_text(board_node: Node, match_count: int, positions: Array, combo_multiplier: int = 1) -> void:
	var combo_label = Label.new()
	combo_label.name = "ComboText"
	combo_label.z_index = 200
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Determine text and color based on combo chain then match size (mirrors original GameBoard logic)
	var combo_text = ""
	var combo_color = Color.WHITE
	if combo_multiplier >= 5:
		combo_text = "INCREDIBLE!"
		combo_color = Color(1.0, 0.0, 1.0)
	elif combo_multiplier >= 4:
		combo_text = "AMAZING!"
		combo_color = Color(1.0, 0.2, 1.0)
	elif combo_multiplier >= 3:
		combo_text = "SUPER!"
		combo_color = Color(1.0, 0.5, 0.0)
	elif combo_multiplier >= 2:
		combo_text = "COMBO!"
		combo_color = Color(0.2, 1.0, 0.2)
	elif match_count >= 7:
		combo_text = "AMAZING!"
		combo_color = Color(1.0, 0.2, 1.0)
	elif match_count >= 6:
		combo_text = "SUPER!"
		combo_color = Color(1.0, 0.5, 0.0)
	elif match_count >= 5:
		combo_text = "GREAT!"
		combo_color = Color(0.2, 1.0, 0.2)
	elif match_count >= 4:
		combo_text = "GOOD!"
		combo_color = Color(0.3, 0.7, 1.0)
	else:
		combo_text = "NICE!"
		combo_color = Color(0.5, 0.5, 1.0)

	if combo_multiplier > 1:
		combo_text = combo_text + " x" + str(combo_multiplier)
	combo_label.text = combo_text

	# Bangers font for impactful display
	var custom_font = load("res://fonts/Bangers/Bangers-Regular.ttf")
	if custom_font == null:
		custom_font = load("res://fonts/Bangers-Regular.ttf")
	if custom_font:
		combo_label.add_theme_font_override("font", custom_font)
	combo_label.add_theme_font_size_override("font_size", 72)

	# Main text color + black outline for contrast
	combo_label.add_theme_color_override("font_color", combo_color)
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	combo_label.add_theme_constant_override("outline_size", 8)

	# Glow via centered shadow (large shadow_outline_size = halo glow)
	var shadow_color = combo_color
	shadow_color.a = 0.6
	combo_label.add_theme_color_override("font_shadow_color", shadow_color)
	combo_label.add_theme_constant_override("shadow_offset_x", 0)
	combo_label.add_theme_constant_override("shadow_offset_y", 0)
	combo_label.add_theme_constant_override("shadow_outline_size", 20)

	combo_label.modulate = Color(1, 1, 1, 0)

	# Fixed label size, centered on screen
	var label_width = 600.0
	var label_height = 100.0
	combo_label.size = Vector2(label_width, label_height)
	combo_label.custom_minimum_size = Vector2(label_width, label_height)
	combo_label.pivot_offset = Vector2(label_width / 2.0, label_height / 2.0)

	var vp = Vector2(720, 1280)
	if board_node and board_node.get_viewport():
		vp = board_node.get_viewport().get_visible_rect().size
	combo_label.position = Vector2((vp.x - label_width) / 2.0, vp.y * 0.4)

	if board_node:
		board_node.add_child(combo_label)
		var t = board_node.create_tween()
		t.set_parallel(true)
		t.tween_property(combo_label, "modulate", Color(1, 1, 1, 1), 0.18)
		t.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.set_parallel(false)
		t.tween_interval(0.5)
		t.set_parallel(true)
		t.tween_property(combo_label, "modulate", Color(1, 1, 1, 0), 0.35)
		t.tween_property(combo_label, "position:y", combo_label.position.y - 40, 0.35)
		t.set_parallel(false)
		t.finished.connect(Callable(combo_label, "queue_free"))
		t.finished.connect(Callable(t, "queue_free"))
