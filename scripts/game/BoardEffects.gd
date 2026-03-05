extends Node
class_name BoardEffects

# No module-level mutable VE; load VisualEffects locally within static functions to avoid static access errors

static func create_special_activation_particles(gameboard: Node, world_pos: Vector2) -> void:
	var ve_local = load("res://scripts/game/VisualEffects.gd")
	if ve_local != null and ve_local.has_method("create_special_activation_particles"):
		ve_local.call("create_special_activation_particles", gameboard, world_pos)
		return
	var particles = CPUParticles2D.new()
	particles.name = "SpecialActivationParticles"
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 1.2
	particles.explosiveness = 1.0
	gameboard.add_child(particles)
	var tree = gameboard.get_tree()
	if tree:
		tree.create_timer(1.5).timeout.connect(Callable(particles, "queue_free"))

static func create_impact_particles(gameboard: Node, pos: Vector2, color: Color = Color(1,1,1,1)) -> void:
	var ve_local = load("res://scripts/game/VisualEffects.gd")
	if ve_local != null and ve_local.has_method("create_impact_particles"):
		ve_local.call("create_impact_particles", gameboard, pos, color)
		return
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	gameboard.add_child(particles)
	var tree = gameboard.get_tree()
	if tree:
		tree.create_timer(0.6).timeout.connect(Callable(particles, "queue_free"))

static func create_lightning_beam(border_parent: Node, start_pos: Vector2, end_pos: Vector2, tile_size: float, color: Color, vertical: bool=false, width: float = 12.0) -> Tween:
	var ve_local = load("res://scripts/game/VisualEffects.gd")
	if ve_local != null and ve_local.has_method("create_lightning_beam"):
		return ve_local.call("create_lightning_beam", border_parent, start_pos, end_pos, tile_size, color, vertical, width)
	var beam = Line2D.new()
	beam.name = vertical and "LightningBeamV" or "LightningBeamH"
	beam.z_index = 100
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
		return tween
	return null

static func show_combo_text(gameboard: Node, match_count: int, positions: Array, combo_multiplier: int = 1) -> void:
	var ve_local = load("res://scripts/game/VisualEffects.gd")
	if ve_local != null and ve_local.has_method("show_combo_text"):
		ve_local.call("show_combo_text", gameboard, match_count, positions, combo_multiplier)
		return
	var combo_label = Label.new()
	combo_label.name = "ComboText"
	combo_label.z_index = 200
	var combo_text = ""
	if combo_multiplier >= 3:
		combo_text = "SUPER x" + str(combo_multiplier)
	elif combo_multiplier == 2:
		combo_text = "COMBO x2"
	else:
		combo_text = "NICE!"
	combo_label.text = combo_text
	combo_label.add_theme_font_size_override("font_size", 48)
	combo_label.modulate = Color(1,1,1,0)
	var vp = Vector2(720,1280)
	if gameboard and gameboard.get_viewport():
		vp = gameboard.get_viewport().get_visible_rect().size
	combo_label.position = vp / 2 - Vector2(200, 50)
	gameboard.add_child(combo_label)
	var t = gameboard.create_tween()
	t.tween_property(combo_label, "modulate", Color(1,1,1,1), 0.18)
	t.tween_property(combo_label, "scale", Vector2(1.2,1.2), 0.18)

static func apply_screen_shake(gameboard: Node, duration: float, intensity: float) -> void:
	# Use a short tween-based shake that loops for the requested duration.
	if not gameboard:
		return
	# Ensure minimums
	if duration <= 0 or intensity <= 0:
		return
	var step = 0.08
	var loops = int(max(1, duration / (step * 3)))
	var original_pos = gameboard.position
	var tw = gameboard.create_tween()
	tw.set_parallel(false)
	tw.set_loops(loops)
	# small sequence: right, left, center per loop
	tw.tween_property(gameboard, "position", original_pos + Vector2(intensity, 0), step).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gameboard, "position", original_pos + Vector2(-intensity, 0), step).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gameboard, "position", original_pos, step).set_trans(Tween.TRANS_SINE)
	# cleanup after finished
	tw.finished.connect(Callable(tw, "queue_free"))
	# Also ensure gameboard position reset after the full duration
	var tree = gameboard.get_tree()
	if tree:
		var cb = Callable(BoardEffects, "_restore_position").bind(gameboard, original_pos)
		tree.create_timer(max(duration, step * 3)).timeout.connect(cb)
	return

static func _restore_position(gameboard: Node, original_pos: Vector2) -> void:
	if is_instance_valid(gameboard):
		gameboard.position = original_pos
