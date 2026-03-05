extends Node
## F4: Unit tests for ObjectiveManager — covers all public methods.

func _ready():
	print("[TEST] test_objective_manager starting")

	var OMScript = load("res://scripts/game/ObjectiveManager.gd")
	assert(OMScript != null, "ObjectiveManager script must load")

	# ── Test 1: report_unmovable_cleared increments counter ──────────────────
	var om = OMScript.new()
	om.initialize({"unmovable_target": 2})
	assert(om.unmovables_cleared == 0, "T1: should start at 0")
	om.report_unmovable_cleared(1)
	assert(om.unmovables_cleared == 1, "T1: should be 1 after one call")
	om.report_unmovable_cleared(1)
	assert(om.unmovables_cleared == 2, "T1: should be 2 after two calls")
	print("[TEST] T1 passed: report_unmovable_cleared")
	om.free()

	# ── Test 2: report_spreader_destroyed decrements spreaders_remaining ─────
	var om2 = OMScript.new()
	om2.initialize({"spreader_target": 3, "spreader_count": 3})
	assert(om2.spreaders_remaining == 3, "T2: should start at 3")
	om2.report_spreader_destroyed(1)
	assert(om2.spreaders_remaining == 2, "T2: should be 2 after one destroy")
	om2.report_spreader_destroyed(2)
	assert(om2.spreaders_remaining == 0, "T2: should clamp to 0, not go negative")
	om2.report_spreader_destroyed(1)
	assert(om2.spreaders_remaining == 0, "T2: should stay at 0 when already 0")
	print("[TEST] T2 passed: report_spreader_destroyed")
	om2.free()

	# ── Test 3: report_collectible_collected increments counter ───────────────
	var om3 = OMScript.new()
	om3.initialize({"collectible_target": 5})
	assert(om3.collectibles_collected == 0, "T3: should start at 0")
	om3.report_collectible_collected(1)
	om3.report_collectible_collected(1)
	assert(om3.collectibles_collected == 2, "T3: should be 2 after two calls")
	print("[TEST] T3 passed: report_collectible_collected")
	om3.free()

	# ── Test 4: is_complete returns false when goals unmet ────────────────────
	var om4 = OMScript.new()
	om4.initialize({"collectible_target": 3, "unmovable_target": 2, "spreader_target": 1, "spreader_count": 1})
	assert(not om4.is_complete(), "T4: should be false — no goals met")
	om4.report_collectible_collected(3)
	assert(not om4.is_complete(), "T4: should be false — unmovables/spreaders still unmet")
	om4.report_unmovable_cleared(2)
	assert(not om4.is_complete(), "T4: should be false — spreader still unmet")
	print("[TEST] T4 passed: is_complete false when goals unmet")
	om4.free()

	# ── Test 5: is_complete returns true when ALL goals met ───────────────────
	var om5 = OMScript.new()
	om5.initialize({"collectible_target": 2, "unmovable_target": 1, "spreader_target": 1, "spreader_count": 1})
	om5.report_collectible_collected(2)
	om5.report_unmovable_cleared(1)
	om5.report_spreader_destroyed(1)
	assert(om5.is_complete(), "T5: should be true when all goals met")
	print("[TEST] T5 passed: is_complete true when all met")
	om5.free()

	# ── Test 6: is_complete returns false when NO goals set (score-only level) ─
	var om6 = OMScript.new()
	om6.initialize({})
	assert(not om6.is_complete(), "T6: no primary goals → score-only, should return false")
	print("[TEST] T6 passed: is_complete false for score-only level")
	om6.free()

	# ── Test 7: get_status returns correct dictionary structure ───────────────
	var om7 = OMScript.new()
	om7.initialize({"collectible_target": 4, "unmovable_target": 3, "spreader_target": 2, "spreader_count": 2})
	om7.report_collectible_collected(2)
	om7.report_unmovable_cleared(1)
	om7.report_spreader_destroyed(1)
	var status = om7.get_status()
	assert(typeof(status) == TYPE_DICTIONARY, "T7: status must be a Dictionary")
	assert(status.has("collectibles"), "T7: must have 'collectibles' key")
	assert(status.has("unmovables"), "T7: must have 'unmovables' key")
	assert(status.has("spreaders"), "T7: must have 'spreaders' key")
	assert(status["collectibles"]["collected"] == 2, "T7: collectibles.collected should be 2")
	assert(status["collectibles"]["goal"] == 4, "T7: collectibles.goal should be 4")
	assert(status["unmovables"]["cleared"] == 1, "T7: unmovables.cleared should be 1")
	assert(status["unmovables"]["goal"] == 3, "T7: unmovables.goal should be 3")
	assert(status["spreaders"]["remaining"] == 1, "T7: spreaders.remaining should be 1")
	assert(status["spreaders"]["goal"] == 2, "T7: spreaders.goal should be 2")
	print("[TEST] T7 passed: get_status structure and values")
	om7.free()

	print("[TEST] test_objective_manager ALL PASSED")
	get_tree().quit()
