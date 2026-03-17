extends Node

# Simple JSON data loader for gallery items (Step 4)
# Responsibilities:
# - Load `res://data/gallery_items.json`
# - Return an Array of item dictionaries

class_name GalleryDataLoader

@export var source_path: String = "res://data/gallery_items.json"

func load_items() -> Array:
	var items: Array = []
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		push_error("GalleryDataLoader: Failed to open %s" % source_path)
		return items
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	# JSON.parse_string may return the parsed Array directly when root is an array,
	# or a Dictionary-like result depending on engine version. Handle both.
	if typeof(parsed) == TYPE_ARRAY:
		# Parsed is already the array of items
		items = parsed
		return items
	elif typeof(parsed) == TYPE_DICTIONARY:
		# Older/newer variations may return { "error": OK, "result": [...] }
		var parse_error = parsed.get("error", null)
		if parse_error != null and parse_error != OK:
			push_error("GalleryDataLoader: JSON parse error (%d)" % parse_error)
			return items
		var res = parsed.get("result", null)
		if res != null and typeof(res) == TYPE_ARRAY:
			items = res
			return items
		# If 'result' isn't present but parsed itself resembles an array, try casting
		if typeof(parsed) == TYPE_ARRAY:
			items = parsed
			return items
		push_error("GalleryDataLoader: unexpected JSON structure")
		return items
	else:
		push_error("GalleryDataLoader: JSON.parse_string returned unexpected type: %s" % typeof(parsed))
		return items
