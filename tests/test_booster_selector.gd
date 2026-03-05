extends Node
## Unit tests for scripts/game/BoosterSelector.gd
## Run standalone: Godot --headless --script tests/test_booster_selector.gd

var BS = null

func _ready():
	BS = load("res://scripts/game/BoosterSelector.gd")
	assert(BS != null, "BoosterSelector script must load")
	print("[TEST] test_booster_selector starting")

	_test_returns_array()
	_test_count_range()
	_test_deterministic()
	_test_always_includes_common()
	_test_no_duplicates()
	_test_custom_tiers()

	print("[TEST] ✅ All BoosterSelector tests passed")
	get_tree().quit(0)

# ── Tests ─────────────────────────────────────────────────────────────────────

func _test_returns_array():
	var result = BS.select(1)
	assert(typeof(result) == TYPE_ARRAY, "select() must return an Array")
	print("[TEST] _test_returns_array passed")

func _test_count_range():
	# Run across several levels — count must always be 3–5
	for lvl in [1, 2, 5, 10, 31, 99]:
		var result = BS.select(lvl)
		assert(result.size() >= 3 and result.size() <= 5,
			"Level %d: expected 3-5 boosters, got %d" % [lvl, result.size()])
	print("[TEST] _test_count_range passed")

func _test_deterministic():
	# Same level must always produce the same list
	var a = BS.select(7)
	var b = BS.select(7)
	assert(a.size() == b.size(), "Determinism: size must match for same level")
	for i in range(a.size()):
		assert(a[i] == b[i], "Determinism: element %d must match" % i)
	print("[TEST] _test_deterministic passed")

func _test_always_includes_common():
	# At least one booster from the common tier must be present
	var common = ["hammer", "shuffle", "swap"]
	for lvl in [1, 3, 7, 15, 42]:
		var result = BS.select(lvl)
		var found = false
		for b in result:
			if b in common:
				found = true
				break
		assert(found, "Level %d: must include at least one common booster" % lvl)
	print("[TEST] _test_always_includes_common passed")

func _test_no_duplicates():
	for lvl in [1, 5, 20, 50]:
		var result = BS.select(lvl)
		var seen: Dictionary = {}
		for b in result:
			assert(not seen.has(b), "Level %d: duplicate booster '%s'" % [lvl, b])
			seen[b] = true
	print("[TEST] _test_no_duplicates passed")

func _test_custom_tiers():
	# Passing custom tiers overrides the built-in ones
	var custom_tiers = {
		"common":   ["alpha", "beta"],
		"uncommon": ["gamma"],
		"rare":     ["delta"]
	}
	var custom_weights = {"common": 0.80, "uncommon": 0.15, "rare": 0.05}
	var result = BS.select(1, custom_tiers, custom_weights)
	assert(result.size() >= 3 and result.size() <= 5,
		"Custom tiers: expected 3-5 results, got %d" % result.size())
	for b in result:
		var all_known = ["alpha", "beta", "gamma", "delta"]
		assert(b in all_known, "Custom tiers: unknown booster '%s'" % b)
	print("[TEST] _test_custom_tiers passed")
