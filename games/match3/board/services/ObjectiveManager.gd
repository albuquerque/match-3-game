extends Node

# Tracks level objectives: collectibles, unmovables, spreaders
var collectible_goal: int = 0
var collectibles_collected: int = 0
var unmovable_goal: int = 0
var unmovables_cleared: int = 0
var spreader_goal: int = 0
var spreaders_remaining: int = 0

func initialize(level_data) -> void:
	# Accept both Dictionary and object-like level_data
	var ld = level_data
	if typeof(level_data) != TYPE_DICTIONARY:
		# Try to coerce common properties from an object
		var tmp = {}
		if level_data == null:
			ld = tmp
		else:
			# Safely read expected attributes if present
			if "collectible_target" in level_data:
				tmp["collectible_target"] = level_data.collectible_target
			if "unmovable_target" in level_data:
				tmp["unmovable_target"] = level_data.unmovable_target
			if "spreader_target" in level_data:
				tmp["spreader_target"] = level_data.spreader_target
			if "spreader_count" in level_data:
				tmp["spreader_count"] = level_data.spreader_count
			ld = tmp

	collectible_goal = int(ld.get("collectible_target", 0))
	collectibles_collected = 0
	unmovable_goal = int(ld.get("unmovable_target", 0))
	unmovables_cleared = 0
	spreader_goal = int(ld.get("spreader_target", 0))
	spreaders_remaining = int(ld.get("spreader_count", 0))
	print("[ObjectiveManager] initialized: collectibles=", collectible_goal, " unmovables=", unmovable_goal, " spreaders=", spreader_goal)

func report_collectible_collected(count: int = 1) -> void:
	collectibles_collected += int(count)
	print("[ObjectiveManager] report_collectible_collected -> ", collectibles_collected, "/", collectible_goal)

func report_unmovable_cleared(count: int = 1) -> void:
	unmovables_cleared += int(count)
	print("[ObjectiveManager] report_unmovable_cleared -> ", unmovables_cleared, "/", unmovable_goal)

func report_spreader_destroyed(count: int = 1) -> void:
	spreaders_remaining = max(0, spreaders_remaining - int(count))
	print("[ObjectiveManager] report_spreader_destroyed -> remaining=", spreaders_remaining)

func is_complete() -> bool:
	## Returns true only when ALL active primary objectives are met.
	## If no primary objectives are set, returns false (score-only levels
	## are handled directly by GameFlowController.
	var has_any = collectible_goal > 0 or unmovable_goal > 0 or spreader_goal > 0
	if not has_any:
		return false

	if collectible_goal > 0 and collectibles_collected < collectible_goal:
		return false
	if unmovable_goal > 0 and unmovables_cleared < unmovable_goal:
		return false
	if spreader_goal > 0 and spreaders_remaining > 0:
		return false
	return true

func get_status() -> Dictionary:
	return {
		"collectibles": {"collected": collectibles_collected, "goal": collectible_goal},
		"unmovables": {"cleared": unmovables_cleared, "goal": unmovable_goal},
		"spreaders": {"remaining": spreaders_remaining, "goal": spreader_goal}
	}
