## BoosterSelector — pure stateless booster-selection logic.
## Call select(level, tiers, weights) to get a deterministic list of boosters for a level.

const BOOSTER_TIERS = {
	"common":   ["hammer", "shuffle", "swap"],
	"uncommon": ["chain_reaction", "bomb_3x3", "line_blast"],
	"rare":     ["row_clear", "column_clear", "tile_squasher", "extra_moves"]
}

const TIER_WEIGHTS = {
	"common":   0.60,
	"uncommon": 0.30,
	"rare":     0.10
}

static func select(level: int, tiers: Dictionary = {}, weights: Dictionary = {}) -> Array:
	## Returns a deterministic 3-5 item list of booster ids for the given level.
	## Caller may pass custom tiers/weights; falls back to the built-in constants.
	var t: Dictionary = tiers if tiers.size() > 0 else BOOSTER_TIERS
	var w: Dictionary = weights if weights.size() > 0 else TIER_WEIGHTS

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(level)
	var count = rng.randi_range(3, 5)

	var result: Array = []
	var seen: Dictionary = {}

	# Always guarantee one common booster first
	var common_pool: Array = t["common"].duplicate()
	common_pool.shuffle()
	result.append(common_pool[0])
	seen[common_pool[0]] = true

	var attempts = 0
	while result.size() < count and attempts < 50:
		attempts += 1
		var roll = rng.randf()
		var tier = "common"
		if roll < w.get("rare", 0.10):
			tier = "rare"
		elif roll < w.get("rare", 0.10) + w.get("uncommon", 0.30):
			tier = "uncommon"
		for booster in t[tier].duplicate():
			if not seen.has(booster):
				result.append(booster)
				seen[booster] = true
				break

	return result
