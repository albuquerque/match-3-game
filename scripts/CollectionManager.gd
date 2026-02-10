extends Node

# CollectionManager - Manages unlockable collections (cards, gallery images, etc.)

signal collection_item_unlocked(collection_id: String, item_id: String)
signal collection_completed(collection_id: String)

# Loaded collections data from JSON files
var collections: Dictionary = {}

# Player's unlocked items per collection
# Format: { "collection_id": ["item_id1", "item_id2", ...] }
var unlocked_items: Dictionary = {}

func _ready():
	print("[CollectionManager] Initializing...")
	load_all_collections()
	load_player_progress()

func load_all_collections():
	"""Load all collection definitions from data/collections/"""
	print("[CollectionManager] Loading collection definitions...")

	var collections_dir = "res://data/collections/"
	var dir = DirAccess.open(collections_dir)

	if not dir:
		print("[CollectionManager] Collections directory not found: ", collections_dir)
		print("[CollectionManager] Creating directory...")
		DirAccess.make_dir_recursive_absolute(collections_dir)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path = collections_dir + file_name
			print("[CollectionManager] Loading collection: ", full_path)

			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				var json_text = file.get_as_text()
				file.close()

				var json = JSON.new()
				var parse_result = json.parse(json_text)

				if parse_result == OK:
					var collection_data = json.get_data()
					var collection_id = collection_data.get("collection_id", "")

					if not collection_id.is_empty():
						collections[collection_id] = collection_data
						print("[CollectionManager] ✓ Loaded collection: ", collection_id)
					else:
						print("[CollectionManager] ⚠️ Collection missing 'collection_id': ", file_name)
				else:
					print("[CollectionManager] ❌ JSON parse error in ", file_name, ": ", json.get_error_message())
			else:
				print("[CollectionManager] ❌ Could not open file: ", full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	print("[CollectionManager] Loaded ", collections.size(), " collection(s)")

func load_player_progress():
	"""Load player's unlocked items from save file"""
	print("[CollectionManager] Loading player collection progress...")

	# Collections are stored in RewardManager's save file
	# We need to load the save file directly
	var save_path = "user://player_progress.json"

	if not FileAccess.file_exists(save_path):
		print("[CollectionManager] No save file found, starting fresh")
		unlocked_items = {}
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		print("[CollectionManager] Could not open save file")
		unlocked_items = {}
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		print("[CollectionManager] Failed to parse save file")
		unlocked_items = {}
		return

	var save_data = json.get_data()
	unlocked_items = save_data.get("unlocked_collections", {})
	print("[CollectionManager] Loaded ", unlocked_items.size(), " collection(s) with unlocked items")

func save_player_progress():
	"""Save player's unlocked items to save file"""
	print("[CollectionManager] Saving collection progress...")

	# Load existing save data
	var save_path = "user://player_progress.json"
	var save_data = {}

	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_text) == OK:
				save_data = json.get_data()

	# Add/update collection data
	save_data["unlocked_collections"] = unlocked_items

	# Write back to file
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("[CollectionManager] ✓ Progress saved")
	else:
		print("[CollectionManager] ⚠️ Could not save progress")

func unlock_item(collection_id: String, item_id: String) -> bool:
	"""Unlock a specific item in a collection. Returns true if newly unlocked."""

	print("[CollectionManager] Attempting to unlock: ", collection_id, "/", item_id)

	# Check if collection exists
	if not collections.has(collection_id):
		print("[CollectionManager] ❌ Collection not found: ", collection_id)
		return false

	# Check if item exists in collection
	var collection = collections[collection_id]
	var items = collection.get("items", [])
	var item_exists = false

	for item in items:
		if item.get("id") == item_id:
			item_exists = true
			break

	if not item_exists:
		print("[CollectionManager] ❌ Item not found in collection: ", item_id)
		return false

	# Initialize collection's unlocked items if needed
	if not unlocked_items.has(collection_id):
		unlocked_items[collection_id] = []

	# Check if already unlocked
	if item_id in unlocked_items[collection_id]:
		print("[CollectionManager] ⚠️ Item already unlocked: ", item_id)
		return false

	# Unlock the item!
	unlocked_items[collection_id].append(item_id)
	print("[CollectionManager] ✅ Item unlocked: ", collection_id, "/", item_id)

	# Save progress
	save_player_progress()

	# Emit signals
	emit_signal("collection_item_unlocked", collection_id, item_id)

	# Check if collection is now complete
	if is_collection_complete(collection_id):
		print("[CollectionManager] 🎉 Collection completed: ", collection_id)
		emit_signal("collection_completed", collection_id)

	return true

func is_item_unlocked(collection_id: String, item_id: String) -> bool:
	"""Check if a specific item is unlocked"""

	if not unlocked_items.has(collection_id):
		return false

	return item_id in unlocked_items[collection_id]

func get_unlocked_items(collection_id: String) -> Array:
	"""Get list of unlocked item IDs for a collection"""

	return unlocked_items.get(collection_id, [])

func get_collection_progress(collection_id: String) -> Dictionary:
	"""Get progress info for a collection"""

	if not collections.has(collection_id):
		return {}

	var collection = collections[collection_id]
	var total_items = collection.get("items", []).size()
	var unlocked = get_unlocked_items(collection_id).size()

	return {
		"collection_id": collection_id,
		"name": collection.get("name", "Unknown Collection"),
		"total_items": total_items,
		"unlocked_items": unlocked,
		"is_complete": is_collection_complete(collection_id),
		"completion_percentage": (float(unlocked) / float(total_items) * 100.0) if total_items > 0 else 0.0
	}

func is_collection_complete(collection_id: String) -> bool:
	"""Check if all items in a collection are unlocked"""

	if not collections.has(collection_id):
		return false

	var collection = collections[collection_id]
	var total_items = collection.get("items", []).size()
	var unlocked = get_unlocked_items(collection_id).size()

	return unlocked >= total_items and total_items > 0

func get_collection_data(collection_id: String) -> Dictionary:
	"""Get the full collection definition"""

	return collections.get(collection_id, {})

func get_item_data(collection_id: String, item_id: String) -> Dictionary:
	"""Get data for a specific item in a collection"""

	if not collections.has(collection_id):
		return {}

	var collection = collections[collection_id]
	var items = collection.get("items", [])

	for item in items:
		if item.get("id") == item_id:
			return item

	return {}

func get_all_collections() -> Array:
	"""Get list of all collection IDs"""

	return collections.keys()

func get_total_progress() -> Dictionary:
	"""Get overall progress across all collections"""

	var total_items = 0
	var total_unlocked = 0
	var collections_complete = 0

	for collection_id in collections.keys():
		var progress = get_collection_progress(collection_id)
		total_items += progress.get("total_items", 0)
		total_unlocked += progress.get("unlocked_items", 0)
		if progress.get("is_complete", false):
			collections_complete += 1

	return {
		"total_collections": collections.size(),
		"collections_complete": collections_complete,
		"total_items": total_items,
		"total_unlocked": total_unlocked,
		"completion_percentage": (float(total_unlocked) / float(total_items) * 100.0) if total_items > 0 else 0.0
	}
