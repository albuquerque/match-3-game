extends Node

# Gallery system (Phase 2 / Step 5)
# Responsibilities:
# - Track shard counts per gallery item
# - Store item state (shards collected, required, unlocked)
# - Expose methods: add_shard(item_id), get_progress(item_id), get_items()
#
# This file is intentionally minimal and self-contained so the UI or
# other systems can wire it in later.

class_name GallerySystem

signal item_unlocked(item_id)

# Internal storage: id -> dict {"id", "name", "shards_required", "shards", "unlocked", "raw"}
var items: Dictionary = {}

func _ready():
	# No automatic loading here; UI or loader should call init_from_list()
	pass

# Initialize items from an array of dictionaries (e.g., JSON loader result)
# Each entry should contain at least: "id" and "shards_required". Other fields are stored in "raw".
func init_from_list(list_items: Array) -> void:
	items.clear()
	for entry in list_items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id = str(entry.get("id", ""))
		if id == "":
			continue
		var required = int(entry.get("shards_required", 0))
		items[id] = {
			"id": id,
			"name": str(entry.get("name", "")),
			"shards_required": required,
			"shards": 0,
			"unlocked": false,
			"raw": entry
		}

# Add one shard to the item with item_id.
# Returns true if the shard caused the item to become unlocked; false otherwise.
func add_shard(item_id: String) -> bool:
	if not items.has(item_id):
		push_error("GallerySystem.add_shard: unknown item_id '%s'" % item_id)
		return false
	var it = items[item_id]
	if it["unlocked"]:
		# already unlocked
		return false
	it["shards"] += 1
	if it["shards"] >= it["shards_required"]:
		it["shards"] = it["shards_required"]
		it["unlocked"] = true
		emit_signal("item_unlocked", item_id)
		return true
	return false

# Get progress for an item. Returns a dictionary {"current": int, "required": int}
func get_progress(item_id: String) -> Dictionary:
	if not items.has(item_id):
		return {"current": 0, "required": 0}
	var it = items[item_id]
	return {"current": int(it["shards"]), "required": int(it["shards_required"])}

# Return an Array of item state dictionaries for all items.
# Each dict includes id, name, shards, shards_required, unlocked, raw
func get_items() -> Array:
	var out := []
	for k in items.keys():
		out.append(items[k])
	return out

# Utility: directly set shards (useful for tests/debug); does not emit unlock signal.
func _set_shards_for_test(item_id: String, count: int) -> void:
	if not items.has(item_id):
		return
	var it = items[item_id]
	it["shards"] = clamp(count, 0, it["shards_required"])
	it["unlocked"] = it["shards"] >= it["shards_required"]
