extends Node
## F5: Coroutine-aware unit tests for GravityAnimator.
## Uses minimal stub Nodes to avoid requiring the full game scene.
## Depends on A2 being complete (GravityAnimator has the barrier/segment logic).

# ── Stub GameManager ──────────────────────────────────────────────────────────
class StubGameManager extends Node:
	const GRID_WIDTH  = 2
	const GRID_HEIGHT = 2
	const SPREADER    = 12
	const COLLECTIBLE = 10

	func apply_gravity() -> bool:
		return false

	func fill_empty_spaces() -> Array:
		return []

	func is_cell_blocked(_x: int, _y: int) -> bool:
		return false

	func get_tile_at(_pos: Vector2) -> int:
		return 0

# ── Stub GameBoard ────────────────────────────────────────────────────────────
class StubGameBoard extends Node:
	var tile_size: float = 64.0
	var grid_offset: Vector2 = Vector2.ZERO
	var board_container: Node = null
	var tile_scene = null

	func grid_to_world_position(grid_pos: Vector2) -> Vector2:
		return grid_pos * tile_size

	func _check_collectibles_at_bottom() -> void:
		pass

# ── Test runner ───────────────────────────────────────────────────────────────
func _ready():
	print("[TEST] test_gravity_animator starting")
	await _run_tests()

func _run_tests():
	# ── Test 1: animate_gravity no-op when apply_gravity returns false ────────
	var gm1 = StubGameManager.new()
	add_child(gm1)
	var gb1 = StubGameBoard.new()
	add_child(gb1)
	var tiles1: Array = [
		[null, null],
		[null, null]
	]

	await GravityAnimator.animate_gravity(gm1, gb1, tiles1)
	print("[TEST] T1 passed: animate_gravity completes on empty board without crash")
	gm1.queue_free()
	gb1.queue_free()

	# ── Test 2: animate_refill returns empty array when fill_empty_spaces returns [] ──
	var gm2 = StubGameManager.new()
	add_child(gm2)
	var gb2 = StubGameBoard.new()
	add_child(gb2)
	var tiles2: Array = [
		[null, null],
		[null, null]
	]

	var result = await GravityAnimator.animate_refill(gm2, gb2, tiles2)
	assert(typeof(result) == TYPE_ARRAY, "T2: animate_refill must return Array")
	assert(result.size() == 0, "T2: result must be empty when fill_empty_spaces returns []")
	print("[TEST] T2 passed: animate_refill returns empty array for empty fill")
	gm2.queue_free()
	gb2.queue_free()

	# ── Test 3: animate_gravity + animate_refill chained on empty board ────────
	var gm3 = StubGameManager.new()
	add_child(gm3)
	var gb3 = StubGameBoard.new()
	add_child(gb3)
	var tiles3: Array = [
		[null, null],
		[null, null]
	]

	await GravityAnimator.animate_gravity(gm3, gb3, tiles3)
	var result3 = await GravityAnimator.animate_refill(gm3, gb3, tiles3)
	assert(typeof(result3) == TYPE_ARRAY, "T3: chained refill must return Array")
	print("[TEST] T3 passed: animate_gravity + animate_refill chained without crash")
	gm3.queue_free()
	gb3.queue_free()

	print("[TEST] test_gravity_animator ALL PASSED")
	get_tree().quit()
