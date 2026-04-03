extends RefCounted

# Simple scoring utility

static func points_for(tiles_removed: int, combo_count: int = 0) -> int:
	if tiles_removed <= 0:
		return 0
	var base = tiles_removed * 100
	# Apply combo multiplier (example: 10% per combo)
	var multiplier = 1.0 + (0.10 * float(combo_count))
	return int(base * multiplier)
