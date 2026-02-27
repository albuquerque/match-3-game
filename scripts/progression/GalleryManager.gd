extends Node

# GalleryManager - manage unlockable gallery content. Minimal Phase 1 stub.

var unlocked: Dictionary = {}
var gallery_data: Dictionary = {}

signal item_unlocked(category: String, item_id: String)

func _ready() -> void:
	print("[GalleryManager] ready")
	# For now, keep unlocked as runtime-only. Persistence can be added later.

func unlock_item(category: String, item_id: String) -> void:
	if not unlocked.has(category):
		unlocked[category] = []
	if item_id in unlocked[category]:
		return
	unlocked[category].append(item_id)
	emit_signal("item_unlocked", category, item_id)
	print("[GalleryManager] Unlocked %s/%s" % [category, item_id])

func is_item_unlocked(category: String, item_id: String) -> bool:
	return unlocked.has(category) and item_id in unlocked[category]

func get_unlocked_items(category: String) -> Array:
	return unlocked.get(category, [])

func get_all_unlocked() -> Dictionary:
	return unlocked
