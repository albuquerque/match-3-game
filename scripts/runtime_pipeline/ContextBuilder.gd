extends RefCounted
class_name ExecutionContextBuilder

## ExecutionContextBuilder
## Builds PipelineContext with runtime references

static func build_from_scene_tree() -> PipelineContext:
	var context = PipelineContext.new()
	var loop = Engine.get_main_loop()
	context.viewport = loop.root if loop else null

	var board = _find_game_board()
	if board:
		context.game_board = board
		print("[ExecutionContextBuilder] Found GameBoard: %s" % board.get_path())
	else:
		print("[ExecutionContextBuilder] GameBoard NOT found")

	var ui = _find_game_ui()
	if ui:
		context.game_ui = ui
		print("[ExecutionContextBuilder] Found GameUI: %s" % ui.get_path())
	else:
		print("[ExecutionContextBuilder] GameUI NOT found")

	var overlay = _find_or_create_overlay()
	if overlay:
		context.overlay_layer = overlay
		print("[ExecutionContextBuilder] Using overlay: %s" % overlay.get_path())

	return context

static func build_with_references(board: Node, ui: Node, overlay: CanvasLayer = null) -> PipelineContext:
	var context = PipelineContext.new()
	context.set_runtime_references(board, ui, overlay)
	return context

static func _find_game_board() -> Node:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	if not root:
		return null
	# Common locations tried in order
	var paths = ["MainGame/GameBoard", "MainGame/GameUI/GameBoard", "GameBoard", "MainGame/GameBoard/GameBoard"]
	for p in paths:
		var node = root.get_node_or_null(p)
		if node:
			print("[ExecutionContextBuilder] _find_game_board found node at: %s" % p)
			return node
	# Fallback: search children for a node named GameBoard
	for child in root.get_children():
		if child and child.name == "GameBoard":
			print("[ExecutionContextBuilder] _find_game_board found child GameBoard at root")
			return child
	return null

static func _find_game_ui() -> Node:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	if not root:
		return null
	var ui = root.get_node_or_null("MainGame/GameUI")
	if not ui:
		ui = root.get_node_or_null("GameUI")
	return ui

static func _find_or_create_overlay() -> CanvasLayer:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	if not root:
		return null
	var overlay = root.get_node_or_null("EffectOverlay")
	if overlay and overlay is CanvasLayer:
		return overlay
	overlay = CanvasLayer.new()
	overlay.name = "EffectOverlay"
	overlay.layer = 100
	root.add_child(overlay)
	return overlay
