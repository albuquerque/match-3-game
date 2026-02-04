extends Node
class_name EffectExecutorStateSwap

# Simplified StateSwapExecutor: robust, minimal implementation to avoid parser issues.
# Supports 'position' and 'visibility' swap modes. Animated swap is simplified to instant swap for now.
func execute(context):
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	var board_node = context.get("board", null)

	if not viewport:
		print("[StateSwapExecutor] No viewport - skipping")
		return

	var a = params.get("anchor_a", "")
	var b = params.get("anchor_b", "")
	var mode = params.get("mode", "visibility")
	# duration is accepted but currently behaves as instant swap; animation can be added later
	var duration = float(params.get("duration", 0.0))

	if a == "" or b == "":
		print("[StateSwapExecutor] Missing anchors - skipping")
		return

	print("[StateSwapExecutor] Resolving anchor_a: '%s'" % a)
	var node_a = _resolve_node(a, viewport, board_node)
	print("[StateSwapExecutor] Resolving anchor_b: '%s'" % b)
	var node_b = _resolve_node(b, viewport, board_node)

	if not node_a or not is_instance_valid(node_a):
		print("[StateSwapExecutor] Node A not found: " + str(a))
		return
	if not node_b or not is_instance_valid(node_b):
		print("[StateSwapExecutor] Node B not found: " + str(b))
		return

	print("[StateSwapExecutor] Executing swap %s <-> %s mode=%s" % [a, b, mode])
	print("[StateSwapExecutor] Node A: %s (visible=%s)" % [node_a.name, node_a.visible if node_a is CanvasItem else "N/A"])
	print("[StateSwapExecutor] Node B: %s (visible=%s)" % [node_b.name, node_b.visible if node_b is CanvasItem else "N/A"])

	if mode == "position":
		# Swap positions if Node2D
		if node_a is Node2D and node_b is Node2D:
			var pa = node_a.position
			var pb = node_b.position
			node_a.position = pb
			node_b.position = pa
			print("[StateSwapExecutor] Swapped positions: %s -> %s, %s -> %s" % [a, pb, b, pa])
		else:
			print("[StateSwapExecutor] One of the nodes is not Node2D; skipping position swap")
	else:
		# Swap visibility
		var va = true
		var vb = true
		if node_a is CanvasItem:
			va = node_a.visible
		if node_b is CanvasItem:
			vb = node_b.visible

		print("[StateSwapExecutor] Before swap: %s.visible=%s, %s.visible=%s" % [a, va, b, vb])

		if node_a is CanvasItem:
			node_a.visible = vb
		if node_b is CanvasItem:
			node_b.visible = va

		print("[StateSwapExecutor] After swap: %s.visible=%s, %s.visible=%s" % [a, vb, b, va])

	print("[StateSwapExecutor] Swap completed")

func _resolve_node(name: String, viewport: Node, board_node: Node) -> Node:
	if name == "":
		return null

	# Get root from viewport to avoid "not in scene tree" error
	var root = null
	if viewport and viewport is Node:
		var tree = viewport.get_tree()
		if tree:
			root = tree.get_root()

	# Try VisualAnchorManager first
	if root:
		var vam = root.get_node_or_null("VisualAnchorManager")
		if vam and vam.has_method("get_anchor"):
			var anchor_node = vam.get_anchor(name)
			if anchor_node:
				print("[StateSwapExecutor] Resolved '%s' via VisualAnchorManager -> %s" % [name, anchor_node.name])
				return anchor_node

	# Try direct path under viewport
	if viewport and viewport.has_node(name):
		var node = viewport.get_node(name)
		print("[StateSwapExecutor] Resolved '%s' via viewport.get_node -> %s" % [name, node.name])
		return node

	# Try recursive search under viewport
	if viewport:
		var found = _find_node_recursive(viewport, name)
		if found:
			print("[StateSwapExecutor] Resolved '%s' via recursive search -> %s" % [name, found.name])
			return found

	# Try global paths using root
	if root:
		var g = root.get_node_or_null(name)
		if g:
			print("[StateSwapExecutor] Resolved '%s' via root.get_node -> %s" % [name, g.name])
			return g
		var gr = root.get_node_or_null("/root/" + name)
		if gr:
			print("[StateSwapExecutor] Resolved '%s' via /root/ path -> %s" % [name, gr.name])
			return gr

	print("[StateSwapExecutor] Could not resolve '%s'" % name)
	return null

# Recursive node search by name (Godot 4 compatible)
func _find_node_recursive(root: Node, name: String) -> Node:
	if not root:
		return null
	if str(root.name) == name:
		return root
	for child in root.get_children():
		var found = _find_node_recursive(child, name)
		if found:
			return found
	return null
