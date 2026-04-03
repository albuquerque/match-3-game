extends Node
class_name EffectExecutorSpawnParticles

# Helper: recursive search for a descendant node by name using safe Node APIs
func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	var child_count := root.get_child_count()
	for i in range(child_count):
		var child = root.get_child(i)
		if not child:
			continue
		if str(child.name) == target_name:
			return child
		var found = _find_descendant_by_name(child, target_name)
		if found:
			return found
	return null

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	if not viewport:
		print("[SpawnParticlesExecutor] No viewport - skipping")
		return

	var event_ctx = context.get("event_context", {})
	var particle_id = params.get("particle", "")
	var count = int(params.get("count", 1))
	var duration = float(params.get("duration", 1.0))
	var anchor = context.get("anchor", "")
	var entity_id = context.get("entity_id", "")
	var board = context.get("board", null)
	var board_name_str = "NULL"
	if board != null:
		board_name_str = board.name

	print("[SpawnParticlesExecutor] Spawn particle '%s' x%d for %ss (anchor=%s, entity=%s) | board=%s" % [particle_id, count, duration, anchor, entity_id, board_name_str])

	# Resolve particle resource from chapter assets or direct path
	var part_res = null
	var chapter = context.get("chapter", null)
	if chapter and chapter.has("assets"):
		var assets = chapter.get("assets", {})
		if typeof(assets) == TYPE_DICTIONARY and assets.has("particles"):
			var parts = assets.get("particles", {})
			if parts.has(particle_id):
				var path = parts.get(particle_id)
				if path and ResourceLoader.exists(path):
					part_res = ResourceLoader.load(path)

	if not part_res and typeof(particle_id) == TYPE_STRING and particle_id.begins_with("res://"):
		if ResourceLoader.exists(particle_id):
			part_res = ResourceLoader.load(particle_id)

	# Determine spawn positions
	var spawn_positions: Array = []

	# Try to ensure we have a board reference
	if board == null:
		# Find GameBoard under viewport
		board = _find_descendant_by_name(viewport, "GameBoard")

	# Priority 1: event_context.tiles (array of {x,y})
	if event_ctx and event_ctx.has("tiles"):
		var tiles = event_ctx.get("tiles")
		for t in tiles:
			if typeof(t) == TYPE_DICTIONARY and t.has("x") and t.has("y"):
				var gx = int(t.get("x"))
				var gy = int(t.get("y"))
				var world_pos = Vector2.ZERO
				var resolved_by = "none"
				# Try board tiles array first
				if board and typeof(board.tiles) != TYPE_NIL:
					if gx >= 0 and gx < board.tiles.size() and gy >= 0 and gy < board.tiles[gx].size():
						var tile_node = board.tiles[gx][gy]
						if tile_node and is_instance_valid(tile_node) and tile_node is Node2D:
							world_pos = tile_node.global_position
							resolved_by = "tile_node"
				# Then try board.grid_to_world
				if world_pos == Vector2.ZERO and board and board.has_method("grid_to_world"):
					world_pos = board.grid_to_world(Vector2(gx, gy))
					if world_pos != Vector2.ZERO:
						resolved_by = "grid_to_world"
				# Fallback: entity_id or anchor or viewport center
				if world_pos == Vector2.ZERO and entity_id != "":
					var found = viewport.find_node(entity_id, true, false) if viewport.has_method("find_node") else null
					if found and found is Node2D:
						world_pos = found.global_position
						resolved_by = "entity_node"
				if world_pos == Vector2.ZERO and anchor != "":
					var an = viewport.get_node_or_null(anchor) if viewport.has_method("get_node_or_null") else null
					if an and an is Node2D:
						world_pos = an.global_position
						resolved_by = "anchor"
				if world_pos == Vector2.ZERO:
					# last resort: viewport center
					if viewport and viewport is Viewport and viewport.has_method("get_visible_rect"):
						world_pos = viewport.get_visible_rect().size * 0.5
					else:
						world_pos = Vector2.ZERO
					resolved_by = "fallback"

				spawn_positions.append(world_pos)
				print("[SpawnParticlesExecutor] Resolved tile (%d,%d) -> pos=%s via=%s" % [gx, gy, str(world_pos), resolved_by])

	# Priority 2: entity_id lookup (if no tiles)
	if spawn_positions.size() == 0 and entity_id != "":
		var found = viewport.find_node(entity_id, true, false) if viewport.has_method("find_node") else null
		if found and found is Node2D:
			spawn_positions.append(found.global_position)

	# Priority 3: anchor node position
	var parent_node: Node = null
	if anchor != "" and viewport and viewport.has_method("get_node_or_null"):
		parent_node = viewport.get_node_or_null(anchor)

	# If still no positions, fallback to viewport center
	if spawn_positions.size() == 0:
		if parent_node and parent_node is Node2D:
			spawn_positions.append((parent_node as Node2D).global_position)
		elif viewport and viewport is Viewport and viewport.has_method("get_visible_rect"):
			spawn_positions.append(viewport.get_visible_rect().size * 0.5)
		else:
			spawn_positions.append(Vector2.ZERO)

	# Spawn particles
	var spawned_nodes = []
	# Prefer parenting under board's parent so particles appear in game canvas
	var prefer_parent_node: Node = null
	if board and board is Node:
		prefer_parent_node = board.get_parent() if board.get_parent() else board
	elif viewport and viewport is Node:
		prefer_parent_node = viewport

	for pos in spawn_positions:
		# compute local/global positioning based on chosen parent
		for i in range(max(1, int(count / max(1, spawn_positions.size())))):
			var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
			var world_pos = pos + offset
			var node: Node = null
			if part_res:
				if part_res is PackedScene:
					var inst = part_res.instantiate()
					if inst and inst is Node2D:
						if prefer_parent_node and prefer_parent_node is Node2D:
							inst.position = (prefer_parent_node as Node2D).to_local(world_pos)
							prefer_parent_node.add_child(inst)
						else:
							inst.global_position = world_pos
							if prefer_parent_node and prefer_parent_node is Node:
								prefer_parent_node.add_child(inst)
							else:
								if viewport and viewport is Node:
									viewport.add_child(inst)
					node = inst
				else:
					var pnode = CPUParticles2D.new()
					if typeof(part_res) == TYPE_OBJECT:
						pnode.process_material = part_res
					pnode.one_shot = true
					pnode.amount = 4
					pnode.lifetime = duration
					if prefer_parent_node and prefer_parent_node is Node2D:
						pnode.position = (prefer_parent_node as Node2D).to_local(world_pos)
						prefer_parent_node.add_child(pnode)
					else:
						pnode.global_position = world_pos
						if prefer_parent_node and prefer_parent_node is Node:
							prefer_parent_node.add_child(pnode)
						elif viewport and viewport is Node:
							viewport.add_child(pnode)
					pnode.emitting = true
					node = pnode
			else:
				# Fallback programmatic particle
				var pnode = CPUParticles2D.new()
				if prefer_parent_node and prefer_parent_node is Node2D:
					pnode.position = (prefer_parent_node as Node2D).to_local(world_pos)
					prefer_parent_node.add_child(pnode)
				else:
					pnode.global_position = world_pos
					if prefer_parent_node and prefer_parent_node is Node:
						prefer_parent_node.add_child(pnode)
					elif viewport and viewport is Node:
						viewport.add_child(pnode)
				pnode.amount = 8
				pnode.lifetime = duration
				pnode.one_shot = true
				pnode.emitting = true
				node = pnode

			if node:
				spawned_nodes.append(node)

	# Cleanup
	for n in spawned_nodes:
		if n and is_instance_valid(n):
			var tree = null
			if prefer_parent_node and prefer_parent_node.has_method("get_tree") and prefer_parent_node.get_tree() != null:
				tree = prefer_parent_node.get_tree()
			elif viewport and viewport.has_method("get_tree") and viewport.get_tree() != null:
				tree = viewport.get_tree()
			elif has_method("get_tree") and get_tree() != null:
				tree = get_tree()
			if tree:
				var tw = tree.create_tween()
				tw.tween_interval(duration + 0.05)
				tw.tween_callback(Callable(n, "queue_free"))
			else:
				if prefer_parent_node and prefer_parent_node is Node:
					var tmp = Timer.new()
					tmp.wait_time = duration + 0.05
					tmp.one_shot = true
					prefer_parent_node.add_child(tmp)
					tmp.start()
					if tmp.has_signal("timeout"):
						tmp.timeout.connect(Callable(n, "queue_free"))
						tmp.timeout.connect(Callable(tmp, "queue_free"))

	print("[SpawnParticlesExecutor] Spawned %d particle nodes" % spawned_nodes.size())
	return
