extends Node
## VisualAnchorManager - Manages visual anchor points for narrative effects
## Maps anchor IDs to scene nodes where effects should be rendered

# Dictionary mapping anchor_id -> NodePath or Node reference
var anchors: Dictionary = {}

# Reference to the main game scene
var main_scene: Node = null

func _ready():
	print("[VisualAnchorManager] Initializing visual anchors...")

	# Wait for scene tree to be ready
	await get_tree().process_frame

	# Find the main game scene
	main_scene = get_tree().current_scene
	if not main_scene:
		push_warning("[VisualAnchorManager] Main scene not found")
		return

	# Register default anchors
	_register_default_anchors()

	print("[VisualAnchorManager] Visual anchors ready")

## Register default anchor points in the game scene
func _register_default_anchors():
	print("[VisualAnchorManager] Registering default anchors...")

	# Try to find common anchor points in the scene tree
	var game_board = _find_node_by_name("GameBoard")
	var game_ui = _find_node_by_name("GameUI")
	var main_game = _find_node_by_name("MainGame")

	# Register anchors
	if game_board:
		register_anchor("board", game_board)
		register_anchor("board_center", game_board)
		print("[VisualAnchorManager] ✓ Registered board anchors")

	if game_ui:
		register_anchor("ui", game_ui)
		# Note: 'hud' anchor is now registered by GameUI's HUD container in _reorganize_hud()
		print("[VisualAnchorManager] ✓ Registered UI anchors")

	if main_game:
		register_anchor("background", main_game)
		register_anchor("world", main_game)
		print("[VisualAnchorManager] ✓ Registered world anchors")

	# Create fullscreen overlay anchor if it doesn't exist
	_ensure_fullscreen_overlay()

	print("[VisualAnchorManager] Registered %d anchors" % anchors.size())

## Find a node by name in the scene tree
func _find_node_by_name(node_name: String) -> Node:
	if not main_scene:
		return null

	# Try direct child first
	var node = main_scene.find_child(node_name, true, false)
	if node:
		return node

	# Try case-insensitive search
	return _recursive_find_node(main_scene, node_name.to_lower())

## Recursively search for a node (case-insensitive)
func _recursive_find_node(parent: Node, target_name: String) -> Node:
	if parent.name.to_lower() == target_name:
		return parent

	for child in parent.get_children():
		var result = _recursive_find_node(child, target_name)
		if result:
			return result

	return null

## Create or ensure fullscreen overlay layer exists
func _ensure_fullscreen_overlay():
	var overlay = _find_node_by_name("FullscreenOverlay")

	if not overlay and main_scene:
		# Create a CanvasLayer for fullscreen effects
		overlay = CanvasLayer.new()
		overlay.name = "FullscreenOverlay"
		overlay.layer = 100  # High layer so it's on top
		main_scene.add_child(overlay)
		print("[VisualAnchorManager] Created FullscreenOverlay layer")

	if overlay:
		register_anchor("fullscreen_overlay", overlay)
		register_anchor("overlay", overlay)

## Register a custom anchor
func register_anchor(anchor_id: String, node: Node):
	if not node:
		push_warning("[VisualAnchorManager] Cannot register null node for anchor: %s" % anchor_id)
		return

	anchors[anchor_id] = node
	print("[VisualAnchorManager] Registered anchor '%s' -> %s" % [anchor_id, node.name])

## Get an anchor node by ID
func get_anchor(anchor_id: String) -> Node:
	var anchor = anchors.get(anchor_id)

	if not anchor:
		push_warning("[VisualAnchorManager] Anchor not found: %s - using fallback" % anchor_id)
		return _get_fallback_anchor()

	if anchor is Node:
		return anchor

	if anchor is NodePath:
		var node = get_node_or_null(anchor)
		if node:
			return node

	push_warning("[VisualAnchorManager] Invalid anchor reference: %s" % anchor_id)
	return _get_fallback_anchor()

## Get fallback anchor (main scene or root)
func _get_fallback_anchor() -> Node:
	if main_scene:
		return main_scene
	return get_tree().root

## Check if an anchor exists
func has_anchor(anchor_id: String) -> bool:
	return anchors.has(anchor_id)

## Get all registered anchor IDs
func get_anchor_ids() -> Array:
	return anchors.keys()

## Clear all anchors
func clear_anchors():
	anchors.clear()
	print("[VisualAnchorManager] Cleared all anchors")

## Get the position of an anchor in world coordinates
func get_anchor_position(anchor_id: String) -> Vector2:
	var anchor = get_anchor(anchor_id)
	if not anchor:
		return Vector2.ZERO

	if anchor is Node2D:
		return anchor.global_position
	elif anchor is Control:
		return anchor.global_position

	return Vector2.ZERO

## Get the global transform of an anchor
func get_anchor_transform(anchor_id: String) -> Transform2D:
	var anchor = get_anchor(anchor_id)
	if not anchor:
		return Transform2D.IDENTITY

	if anchor is Node2D:
		return anchor.global_transform
	elif anchor is Control:
		# Convert Control position to Transform2D
		var xform = Transform2D()
		xform.origin = anchor.global_position
		return xform

	return Transform2D.IDENTITY
