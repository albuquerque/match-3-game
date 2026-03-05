extends Node

# GalleryManager: tracks unlocked images and provides async-ready API for adapters
signal gallery_updated(image_id: String)
signal gallery_image_ready(image_id: String, path: String)

var _unlocked: Array = []
var _images_config: Dictionary = {}

func _ready() -> void:
	# Load gallery config from data folder (JSON) if available
	var cfg_path = "res://data/gallery_config.json"
	if FileAccess.file_exists(cfg_path):
		var f = FileAccess.open(cfg_path, FileAccess.READ)
		if f:
			var raw = f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(raw)
			if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
				_images_config = parsed.result
			else:
				print("[GalleryManager] Failed to parse gallery_config.json")

func is_unlocked(image_id: String) -> bool:
	return _unlocked.has(image_id)

func unlock_image(image_id: String) -> void:
	if not _unlocked.has(image_id):
		_unlocked.append(image_id)
		emit_signal("gallery_updated", image_id)

func request_image(image_id: String) -> void:
	# For now, image paths are defined in _images_config.images dict by id
	var path = null
	if _images_config.has("images") and _images_config["images"].has(image_id):
		path = _images_config["images"][image_id].get("path", null)
	# emit ready (adapters subscribe)
	emit_signal("gallery_image_ready", image_id, path)

func get_all_images() -> Array:
	if _images_config.has("images"):
		return _images_config["images"].keys()
	return []
