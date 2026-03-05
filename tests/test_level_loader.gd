extends Node
## Unit tests for scripts/game/LevelLoader.gd
## Uses mock objects — no autoloads needed.

class MockLevelData:
	var level_number: int        = 5
	var width: int               = 7
	var height: int              = 6
	var target_score: int        = 8000
	var moves: int               = 28
	var theme: String            = "legacy"
	var collectible_target: int  = 2
	var collectible_type: String = "coin"
	var unmovable_type: String   = "snow"
	var unmovable_target: int    = 3
	var spreader_target: int     = 0
	var spreader_type: String    = "virus"
	var spreader_grace_moves: int = 2
	var max_spreaders: int       = 20
	var spreader_spread_limit: int = 0
	var spreader_textures: Dictionary = {}
	var hard_textures: Dictionary = {}
	var hard_reveals: Dictionary  = {}
	var grid_layout: Array        = []

class MockGM extends Node:
	var GRID_WIDTH: int = 8
	var GRID_HEIGHT: int = 8
	var target_score: int = 0
	var moves_left: int = 0
	var level: int = 0
	var collectible_target: int = 0
	var collectible_type: String = "coin"
	var collectibles_collected: int = 0
	var unmovable_type: String = "snow"
	var unmovable_target: int = 0
	var unmovables_cleared: int = 0
	var spreader_grace_default: int = 2
	var max_spreaders: int = 20
	var spreader_spread_limit: int = 0
	var use_spreader_objective: bool = false
	var spreader_type: String = "virus"
	var spreader_count: int = 0
	var spreader_textures_map: Dictionary = {}
	var unmovable_map: Dictionary = {}
	var initialized: bool = false
	var theme_manager = null
	var ObjectiveManagerScript = null
	var objective_manager_ref = null
	var NodeResolverAPI = null
	var level_manager = null
	var _grid_called := false
	var _layout_called := false
	var _initial_called := false
	func create_empty_grid() -> void:
		_grid_called = true
	func fill_grid_from_layout(_l) -> void:
		_layout_called = true
	func fill_initial_grid() -> void:
		_initial_called = true

func _make_layout(w: int, h: int) -> Array:
	var layout = []
	for x in range(w):
		layout.append([])
		for y in range(h):
			layout[x].append(1)
	return layout

func _make_loader(gm_node: Node) -> Node:
	var script = load("res://scripts/game/LevelLoader.gd")
	var loader = script.new()
	loader.setup(gm_node)
	return loader

func _ready():
	print("[TEST] test_level_loader starting")
	_test_fields()
	_test_grid_calls()
	_test_fallback()
	_test_hard_textures()
	_test_spreader_textures()
	print("[TEST] All LevelLoader tests passed")
	get_tree().quit(0)

func _test_fields():
	var gm = MockGM.new()
	add_child(gm)
	var ld = MockLevelData.new()
	ld.grid_layout = _make_layout(7, 6)
	var loader = _make_loader(gm)
	add_child(loader)
	loader._apply_level_data(ld)
	assert(gm.GRID_WIDTH == 7, "width mismatch")
	assert(gm.GRID_HEIGHT == 6, "height mismatch")
	assert(gm.target_score == 8000, "target_score mismatch")
	assert(gm.moves_left == 28, "moves_left mismatch")
	assert(gm.level == 5, "level mismatch")
	assert(gm.collectible_target == 2, "collectible_target mismatch")
	assert(gm.collectibles_collected == 0, "collectibles not reset")
	assert(gm.unmovable_target == 3, "unmovable_target mismatch")
	assert(gm.unmovables_cleared == 0, "unmovables not reset")
	assert(gm.spreader_count == 0, "spreader_count not reset")
	assert(gm.initialized == true, "initialized must be true")
	print("[TEST] _test_fields passed")
	loader.queue_free()
	gm.queue_free()

func _test_grid_calls():
	var gm = MockGM.new()
	add_child(gm)
	var ld = MockLevelData.new()
	ld.grid_layout = _make_layout(7, 6)
	var loader = _make_loader(gm)
	add_child(loader)
	loader._apply_level_data(ld)
	assert(gm._grid_called, "create_empty_grid must be called")
	assert(gm._layout_called, "fill_grid_from_layout must be called")
	print("[TEST] _test_grid_calls passed")
	loader.queue_free()
	gm.queue_free()

func _test_fallback():
	var gm = MockGM.new()
	add_child(gm)
	var loader = _make_loader(gm)
	add_child(loader)
	loader._apply_fallback()
	assert(gm.GRID_WIDTH == 8, "fallback width must be 8")
	assert(gm.GRID_HEIGHT == 8, "fallback height must be 8")
	assert(gm.target_score == 10000, "fallback target_score must be 10000")
	assert(gm.moves_left == 30, "fallback moves_left must be 30")
	assert(gm.initialized == true, "initialized must be true after fallback")
	assert(gm._initial_called, "fill_initial_grid must be called in fallback")
	print("[TEST] _test_fallback passed")
	loader.queue_free()
	gm.queue_free()

func _test_hard_textures():
	var gm = MockGM.new()
	add_child(gm)
	gm.unmovable_map["2,3"] = {"hard": true, "type": "rock"}
	var loader = _make_loader(gm)
	add_child(loader)
	var ht: Dictionary = {"rock": ["rock_1.png"]}
	var hr: Dictionary = {"rock": ["reveal.png"]}
	loader._attach_hard_textures(ht, hr)
	var entry = gm.unmovable_map["2,3"]
	assert(entry.has("textures"), "textures must be attached")
	assert(entry["textures"][0] == "rock_1.png", "first texture must match")
	assert(entry.has("reveals"), "reveals must be attached")
	assert(entry["reveals"][0] == "reveal.png", "first reveal must match")
	print("[TEST] _test_hard_textures passed")
	loader.queue_free()
	gm.queue_free()

func _test_spreader_textures():
	var gm = MockGM.new()
	add_child(gm)
	var ld = MockLevelData.new()
	ld.grid_layout = _make_layout(7, 6)
	ld.spreader_textures = {"virus": ["virus_1.png"]}
	var loader = _make_loader(gm)
	add_child(loader)
	loader._apply_level_data(ld)
	assert(gm.spreader_textures_map.has("virus"), "spreader_textures_map must be populated")
	assert(gm.spreader_textures_map["virus"][0] == "virus_1.png", "spreader texture must match")
	print("[TEST] _test_spreader_textures passed")
	loader.queue_free()
	gm.queue_free()
