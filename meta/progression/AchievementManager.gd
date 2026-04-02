extends Node

# AchievementManager - basic achievement tracking stub for Phase 1/2

var achievements: Dictionary = {}

signal achievement_unlocked(id: String)

func _ready() -> void:
	print("[AchievementManager] ready")
	# load achievement definitions from data if needed (deferred)

func register_achievement(id: String, definition: Dictionary) -> void:
	achievements[id] = {"def": definition, "progress": 0, "unlocked": false}

func add_progress(id: String, amount: int = 1) -> void:
	if not achievements.has(id):
		print("[AchievementManager] Unknown achievement: %s" % id)
		return
	if achievements[id].unlocked:
		return
	achievements[id].progress += amount
	var target = achievements[id].def.get("progress_max", 1)
	if achievements[id].progress >= target:
		achievements[id].unlocked = true
		emit_signal("achievement_unlocked", id)
		print("[AchievementManager] Achievement unlocked: %s" % id)

func is_unlocked(id: String) -> bool:
	return achievements.has(id) and achievements[id].unlocked

func get_progress(id: String) -> int:
	return achievements.get(id, {}).get("progress", 0)
