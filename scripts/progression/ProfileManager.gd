extends Node

# ProfileManager - aggregate statistics and profile information

var stats: Dictionary = {
	"total_play_time": 0,
	"total_matches": 0,
	"total_swaps": 0,
	"boosters_used": 0,
	"best_combo": 0
}

func _ready() -> void:
	print("[ProfileManager] ready")

func record_match(count: int = 1) -> void:
	stats.total_matches += count

func record_swap(count: int = 1) -> void:
	stats.total_swaps += count

func record_play_time(seconds: int) -> void:
	stats.total_play_time += seconds

func update_best_combo(combo: int) -> void:
	stats.best_combo = max(stats.best_combo, combo)

func get_player_stats() -> Dictionary:
	return stats.duplicate(true)
