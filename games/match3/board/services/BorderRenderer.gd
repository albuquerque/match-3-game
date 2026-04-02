extends Node
const _GQS = preload("res://games/match3/board/services/GridQueryService.gd")

# Pure rendering helpers for drawing board borders as Line2D children under a container.
# All state read from GameRunState.
# API: BorderRenderer.draw_board_borders(board_node, border_container, grid_offset, tile_size, border_color, border_width)

static func _ensure_container(board_node: Node, border_container: Node) -> Node2D:
	if border_container != null and is_instance_valid(border_container):
		return border_container
	var bc = Node2D.new()
	bc.name = "BorderContainer"
	board_node.add_child(bc)
	return bc

static func draw_board_borders(board_node: Node, border_container: Node, game_manager = null, grid_offset: Vector2 = Vector2.ZERO, tile_size: float = 64.0, border_color: Color = Color.WHITE, border_width: float = 3.0) -> Node2D:
	# game_manager param accepted but ignored — all state read from GameRunState.
	print("[BorderRenderer] draw_board_borders called: grid=", GameRunState.GRID_WIDTH, "x", GameRunState.GRID_HEIGHT, " tile_size=", tile_size)
	if not GameRunState.initialized or GameRunState.grid == null or GameRunState.grid.size() == 0:
		print("[BorderRenderer] WARNING: GameRunState not initialized or grid empty")
		return border_container

	var bc = _ensure_container(board_node, border_container)
	for c in bc.get_children():
		c.queue_free()

	var counts = draw_simple_borders(bc, grid_offset, tile_size, border_color, border_width)
	bc.visible = board_node.visible
	print("[BorderRenderer] draw_board_borders completed: edges=", counts.get("edges", 0), " arcs=", counts.get("arcs", 0))
	return bc

static func draw_simple_borders(border_container: Node2D, grid_offset: Vector2, tile_size: float, border_color: Color, border_width: float = 3.0) -> Dictionary:
	if not GameRunState.initialized or GameRunState.grid == null or GameRunState.grid.size() == 0:
		return {"edges":0, "arcs":0}

	var corner_radius = max(4.0, border_width * 4.0)
	var edge_count = 0
	var arc_count = 0
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			if _GQS.is_cell_blocked(null, x, y):
				continue
			var left = grid_offset.x + x * tile_size
			var right = grid_offset.x + (x + 1) * tile_size
			var top = grid_offset.y + y * tile_size
			var bottom = grid_offset.y + (y + 1) * tile_size

			var has_top = (y == 0 or _GQS.is_cell_blocked(null, x, y - 1))
			var has_bottom = (y == GameRunState.GRID_HEIGHT - 1 or _GQS.is_cell_blocked(null, x, y + 1))
			var has_left = (x == 0 or _GQS.is_cell_blocked(null, x - 1, y))
			var has_right = (x == GameRunState.GRID_WIDTH - 1 or _GQS.is_cell_blocked(null, x + 1, y))

			# Top border
			if has_top:
				var start_x = left
				if has_left:
					start_x += corner_radius
				var end_x = right
				if has_right:
					end_x -= corner_radius
				if end_x > start_x:
					draw_border_edge(border_container, Vector2(start_x, top), Vector2(end_x, top), border_color, border_width)
					edge_count += 1

			# Bottom border
			if has_bottom:
				var b_start_x = left
				if has_left:
					b_start_x += corner_radius
				var b_end_x = right
				if has_right:
					b_end_x -= corner_radius
				if b_end_x > b_start_x:
					draw_border_edge(border_container, Vector2(b_start_x, bottom), Vector2(b_end_x, bottom), border_color, border_width)
					edge_count += 1

			# Left border
			if has_left:
				var start_y = top
				if has_top:
					start_y += corner_radius
				var end_y = bottom
				if has_bottom:
					end_y -= corner_radius
				if end_y > start_y:
					draw_border_edge(border_container, Vector2(left, start_y), Vector2(left, end_y), border_color, border_width)
					edge_count += 1

			# Right border
			if has_right:
				var r_start_y = top
				if has_top:
					r_start_y += corner_radius
				var r_end_y = bottom
				if has_bottom:
					r_end_y -= corner_radius
				if r_end_y > r_start_y:
					draw_border_edge(border_container, Vector2(right, r_start_y), Vector2(right, r_end_y), border_color, border_width)
					edge_count += 1

			# Corner arcs
			if has_top and has_left:
				draw_corner_arc(border_container, Vector2(left, top), "top_left", corner_radius, border_color, border_width)
				arc_count += 1
			if has_top and has_right:
				draw_corner_arc(border_container, Vector2(right, top), "top_right", corner_radius, border_color, border_width)
				arc_count += 1
			if has_bottom and has_left:
				draw_corner_arc(border_container, Vector2(left, bottom), "bottom_left", corner_radius, border_color, border_width)
				arc_count += 1
			if has_bottom and has_right:
				draw_corner_arc(border_container, Vector2(right, bottom), "bottom_right", corner_radius, border_color, border_width)
				arc_count += 1

	# final summary
	print("[BorderRenderer] draw_simple_borders: created edges=", edge_count, " arcs=", arc_count)
	return {"edges":edge_count, "arcs":arc_count}

static func draw_border_edge(border_container: Node2D, start: Vector2, end: Vector2, color: Color, width: float = 3.0) -> void:
	var l = Line2D.new()
	l.name = "BorderEdge"
	l.add_point(start)
	l.add_point(end)
	l.width = width
	l.default_color = color
	l.antialiased = true
	border_container.add_child(l)

static func draw_corner_arc(border_container: Node2D, corner_pos: Vector2, corner_type: String, radius: float, color: Color, width: float = 3.0) -> void:
	var line = Line2D.new()
	line.name = "BorderArc"
	var segments = 8
	match corner_type:
		"top_left":
			for i in range(segments + 1):
				var t = float(i) / float(segments)
				var ang = lerp(PI, PI * 1.5, t)
				line.add_point(corner_pos + Vector2(radius, radius) + Vector2(cos(ang), sin(ang)) * radius)
		"top_right":
			for i in range(segments + 1):
				var t = float(i) / float(segments)
				var ang = lerp(PI * 1.5, PI * 2.0, t)
				line.add_point(corner_pos + Vector2(-radius, radius) + Vector2(cos(ang), sin(ang)) * radius)
		"bottom_left":
			for i in range(segments + 1):
				var t = float(i) / float(segments)
				var ang = lerp(PI * 0.5, PI, t)
				line.add_point(corner_pos + Vector2(radius, -radius) + Vector2(cos(ang), sin(ang)) * radius)
		"bottom_right":
			for i in range(segments + 1):
				var t = float(i) / float(segments)
				var ang = lerp(0.0, PI * 0.5, t)
				line.add_point(corner_pos + Vector2(-radius, -radius) + Vector2(cos(ang), sin(ang)) * radius)
	line.width = width
	line.default_color = color
	line.antialiased = true
	border_container.add_child(line)

static func _rounded_rect_points(rect_pos: Vector2, rect_size: Vector2, radius: float, segments: int = 8) -> Array:
	var pts = []
	var w = rect_size.x
	var h = rect_size.y
	var r = clamp(radius, 0.0, min(w, h) * 0.5)

	var tl = rect_pos + Vector2(r, r)
	var tr = rect_pos + Vector2(w - r, r)
	var br = rect_pos + Vector2(w - r, h - r)
	var bl = rect_pos + Vector2(r, h - r)

	var corners = [
		{"center": tl, "a0": PI, "a1": PI * 1.5},
		{"center": tr, "a0": PI * 1.5, "a1": PI * 2},
		{"center": br, "a0": 0.0, "a1": PI * 0.5},
		{"center": bl, "a0": PI * 0.5, "a1": PI}
	]

	for corner in corners:
		var c = corner["center"]
		var a0 = corner["a0"]
		var a1 = corner["a1"]
		for i in range(segments + 1):
			var t = float(i) / float(segments)
			var a = lerp(a0, a1, t)
			pts.append(c + Vector2(cos(a), sin(a)) * r)

	return pts
