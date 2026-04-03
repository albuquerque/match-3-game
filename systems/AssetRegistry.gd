extends Node
## AssetRegistry - Maps string IDs to runtime assets
## Supports downloadable DLC content loaded from user:// directory
## Falls back to base game assets when DLC not available

# Cache of loaded assets
var asset_cache: Dictionary = {}

# Base game asset paths (fallback - baked into game)
var base_assets: Dictionary = {}

# Current chapter asset paths (from DLC)
var chapter_assets: Dictionary = {}

# DLC base directory (external, writable)
const DLC_BASE_DIR = "user://dlc/chapters/"

# Installed DLC chapters
var installed_chapters: Dictionary = {}

func _ready():
	print("[AssetRegistry] ========================================")
	print("[AssetRegistry] Initialized asset registry for DLC support")
	print("[AssetRegistry] Instance ID: %d" % get_instance_id())
	print("[AssetRegistry] ========================================")
	_ensure_dlc_directory()
	_load_base_assets()
	_scan_installed_dlc()

## Ensure DLC directory exists
func _ensure_dlc_directory():
	if not DirAccess.dir_exists_absolute(DLC_BASE_DIR):
		DirAccess.make_dir_recursive_absolute(DLC_BASE_DIR)
		print("[AssetRegistry] Created DLC directory: ", DLC_BASE_DIR)

## Scan for installed DLC chapters
func _scan_installed_dlc():
	print("[AssetRegistry] ========== SCAN START ==========")
	print("[AssetRegistry] Instance ID: %d" % get_instance_id())
	print("[AssetRegistry] Scanning for installed DLC...")
	print("[AssetRegistry] DLC_BASE_DIR: %s" % DLC_BASE_DIR)
	print("[AssetRegistry] installed_chapters BEFORE clear: %d" % installed_chapters.size())
	print("[AssetRegistry] installed_chapters keys: %s" % str(installed_chapters.keys()))
	installed_chapters.clear()
	print("[AssetRegistry] installed_chapters AFTER clear: %d" % installed_chapters.size())

	var dir = DirAccess.open(DLC_BASE_DIR)
	if not dir:
		print("[AssetRegistry] ⚠️ Failed to open DLC directory: %s" % DLC_BASE_DIR)
		return

	print("[AssetRegistry] Successfully opened DLC directory")
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		print("[AssetRegistry] Found item: %s (is_dir: %s)" % [file_name, dir.current_is_dir()])

		if dir.current_is_dir() and not file_name.begins_with("."):
			# Found a chapter directory
			var chapter_path = DLC_BASE_DIR + file_name + "/"
			var manifest_path = chapter_path + "manifest.json"

			print("[AssetRegistry] Checking chapter directory: %s" % file_name)
			print("[AssetRegistry] Manifest path: %s" % manifest_path)
			print("[AssetRegistry] Manifest exists: %s" % FileAccess.file_exists(manifest_path))

			if FileAccess.file_exists(manifest_path):
				var manifest = _load_chapter_manifest(manifest_path)
				print("[AssetRegistry] Manifest loaded, size: %d, empty: %s" % [manifest.size(), manifest.is_empty()])

				if not manifest.is_empty():
					var chapter_id = manifest.get("chapter_id", file_name)
					installed_chapters[chapter_id] = {
						"path": chapter_path,
						"manifest": manifest
					}
					print("[AssetRegistry] ✓ Added DLC chapter: %s" % manifest.get("name", file_name))
				else:
					print("[AssetRegistry] ⚠️ Skipping - manifest is empty")

		file_name = dir.get_next()

	dir.list_dir_end()

	print("[AssetRegistry] ========== SCAN END ==========")
	print("[AssetRegistry] Found %d installed DLC chapters" % installed_chapters.size())
	print("[AssetRegistry] Final installed_chapters keys: %s" % str(installed_chapters.keys()))
	print("[AssetRegistry] ===============================")

## Load chapter manifest JSON
func _load_chapter_manifest(path: String) -> Dictionary:
	print("[AssetRegistry] Loading manifest from: %s" % path)

	if not FileAccess.file_exists(path):
		push_warning("[AssetRegistry] Manifest file does not exist: ", path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[AssetRegistry] Failed to open manifest file: ", path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	print("[AssetRegistry] Manifest file size: %d bytes" % json_text.length())
	print("[AssetRegistry] First 100 chars: %s" % json_text.substr(0, 100))

	var json = JSON.new()
	var error = json.parse(json_text)

	print("[AssetRegistry] Parse error code: %d (0=OK)" % error)
	print("[AssetRegistry] json.data type: %d" % typeof(json.data))
	print("[AssetRegistry] json.data is Dictionary: %s" % (json.data is Dictionary))

	if error == OK:
		print("[AssetRegistry] Parse returned OK")
		if json.data is Dictionary:
			print("[AssetRegistry] ✓ Manifest parsed successfully")
			print("[AssetRegistry] Manifest has %d keys" % json.data.size())
			return json.data
		else:
			push_warning("[AssetRegistry] Manifest is not a Dictionary, got type: %d" % typeof(json.data))
			return {}
	else:
		push_warning("[AssetRegistry] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		push_warning("[AssetRegistry] Failed to parse manifest: ", path)
		return {}

## Load base game fallback assets
func _load_base_assets():
	print("[AssetRegistry] Loading base game assets...")

	# Define base game fallback paths
	base_assets = {
		"sprites": {
			"placeholder": "res://textures/placeholder.png"
		},
		"animations": {
			"default": "res://animations/default.tres"
		},
		"particles": {
			"default": "res://particles/default.tres"
		},
		"shaders": {},
		"textures": {
			"white": "res://textures/white.png"
		}
	}

	print("[AssetRegistry] Base assets registered")

## Load chapter assets from chapter data or DLC
func load_chapter_assets(chapter_data: Dictionary):
	print("[AssetRegistry] Loading chapter assets...")

	var chapter_id = chapter_data.get("chapter_id", "")

	# Check if this is an installed DLC chapter
	if installed_chapters.has(chapter_id):
		var dlc_info = installed_chapters[chapter_id]
		var dlc_path = dlc_info["path"]

		# Load assets from DLC directory
		chapter_assets = chapter_data.get("assets", {})

		# Convert relative paths to absolute user:// paths
		_convert_asset_paths_to_dlc(chapter_assets, dlc_path)

		print("[AssetRegistry] Loaded DLC chapter assets from: ", dlc_path)
	else:
		# Chapter not installed as DLC, try res:// paths (legacy/test)
		chapter_assets = chapter_data.get("assets", {})
		print("[AssetRegistry] Using bundled chapter assets (non-DLC)")

	# Clear asset cache to force reload
	asset_cache.clear()

## Convert relative asset paths to full DLC paths
func _convert_asset_paths_to_dlc(assets: Dictionary, dlc_base: String):
	for category in assets.keys():
		var category_dict = assets[category]
		if category_dict is Dictionary:
			for asset_id in category_dict.keys():
				var relative_path = category_dict[asset_id]
				# Convert to absolute DLC path
				category_dict[asset_id] = dlc_base + relative_path

## Get asset by category and ID
func get_asset(category: String, asset_id: String):
	# Check cache first
	var cache_key = "%s:%s" % [category, asset_id]
	if asset_cache.has(cache_key):
		return asset_cache[cache_key]

	# Try chapter assets first
	var path = _get_asset_path(chapter_assets, category, asset_id)

	# Fallback to base assets if not found
	if path.is_empty():
		path = _get_asset_path(base_assets, category, asset_id)

	# Load asset if path exists
	if not path.is_empty():
		var asset = _load_asset_from_path(path, category)
		if asset:
			asset_cache[cache_key] = asset
			print("[AssetRegistry] Loaded asset: %s/%s from %s" % [category, asset_id, path])
			return asset

	# Return null if asset not found (fail-safe)
	push_warning("[AssetRegistry] Asset not found: %s/%s - using fallback" % [category, asset_id])
	return _get_fallback_asset(category)

## Load asset from path (supports both res:// and user://)
func _load_asset_from_path(path: String, category: String):
	# For res:// paths, use standard ResourceLoader
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			return load(path)
		return null

	# For user:// paths (DLC), need to load differently
	if path.begins_with("user://"):
		if not FileAccess.file_exists(path):
			return null

		# Handle different asset types
		match category:
			"sprites", "textures":
				# Load image from file
				var image = Image.new()
				var error = image.load(path)
				if error == OK:
					return ImageTexture.create_from_image(image)

			"animations":
				# Load JSON-based animation definition
				return _load_json_animation(path)

			"particles":
				# Load JSON-based particle definition
				return _load_json_particle(path)

			"shaders":
				# Load shader code from file
				return _load_shader_from_file(path)

		return null

	return null

## Load animation from JSON file (DLC format)
func _load_json_animation(path: String) -> Animation:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK or not json.data is Dictionary:
		return null

	# Create Animation from JSON definition
	var anim = Animation.new()
	var data = json.data

	anim.length = data.get("length", 1.0)
	anim.loop_mode = Animation.LOOP_NONE if not data.get("loop", false) else Animation.LOOP_LINEAR

	# Add tracks from JSON
	for track_data in data.get("tracks", []):
		_add_track_to_animation(anim, track_data)

	return anim

## Add track to animation from JSON data
func _add_track_to_animation(anim: Animation, track_data: Dictionary):
	var track_type = track_data.get("type", "value")
	var track_idx = -1

	match track_type:
		"value":
			track_idx = anim.add_track(Animation.TYPE_VALUE)
		"position":
			track_idx = anim.add_track(Animation.TYPE_POSITION_3D)
		"rotation":
			track_idx = anim.add_track(Animation.TYPE_ROTATION_3D)
		"scale":
			track_idx = anim.add_track(Animation.TYPE_SCALE_3D)

	if track_idx >= 0:
		anim.track_set_path(track_idx, track_data.get("path", ""))

		for key in track_data.get("keys", []):
			var time = key.get("time", 0.0)
			var value = key.get("value")
			anim.track_insert_key(track_idx, time, value)

## Load particle definition from JSON
func _load_json_particle(path: String) -> ParticleProcessMaterial:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK or not json.data is Dictionary:
		return null

	var material = ParticleProcessMaterial.new()
	var data = json.data

	# Configure from JSON
	if data.has("gravity"):
		var gravity = data["gravity"]
		material.gravity = Vector3(gravity.get("x", 0), gravity.get("y", 98), gravity.get("z", 0))

	if data.has("initial_velocity_min"):
		material.initial_velocity_min = data["initial_velocity_min"]

	if data.has("initial_velocity_max"):
		material.initial_velocity_max = data["initial_velocity_max"]

	# Add more properties as needed

	return material

## Load shader from file
func _load_shader_from_file(path: String) -> Shader:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null

	var shader_code = file.get_as_text()
	file.close()

	var shader = Shader.new()
	shader.code = shader_code

	return shader

## Get asset path from asset dictionary
func _get_asset_path(assets: Dictionary, category: String, asset_id: String) -> String:
	var category_dict = assets.get(category, {})
	if category_dict is Dictionary:
		return category_dict.get(asset_id, "")
	return ""

## Get fallback asset for category
func _get_fallback_asset(category: String):
	match category:
		"sprites", "textures":
			# Return a placeholder texture
			return null
		"animations":
			return null
		"particles":
			return null
		_:
			return null

## Clear asset cache
func clear_cache():
	asset_cache.clear()
	print("[AssetRegistry] Asset cache cleared")

## Preload assets for a chapter (optional optimization)
func preload_chapter_assets(chapter_data: Dictionary):
	print("[AssetRegistry] Preloading chapter assets...")

	var assets = chapter_data.get("assets", {})
	var count = 0

	for category in assets.keys():
		var category_dict = assets[category]
		if category_dict is Dictionary:
			for asset_id in category_dict.keys():
				get_asset(category, asset_id)
				count += 1

	print("[AssetRegistry] Preloaded %d assets" % count)

## Check if a DLC chapter is installed
func is_chapter_installed(chapter_id: String) -> bool:
	return installed_chapters.has(chapter_id)

## Get list of installed chapter IDs
func get_installed_chapters() -> Array:
	print("[AssetRegistry] get_installed_chapters() called")
	print("[AssetRegistry] installed_chapters size: %d" % installed_chapters.size())
	print("[AssetRegistry] installed_chapters keys: %s" % str(installed_chapters.keys()))
	return installed_chapters.keys()

## Get DLC chapter info
func get_chapter_info(chapter_id: String) -> Dictionary:
	print("[AssetRegistry] get_chapter_info called for: %s" % chapter_id)
	print("[AssetRegistry] installed_chapters has chapter: %s" % str(installed_chapters.has(chapter_id)))

	if installed_chapters.has(chapter_id):
		var manifest = installed_chapters[chapter_id]["manifest"]
		print("[AssetRegistry] Returning manifest with %d keys" % manifest.size())
		print("[AssetRegistry] Manifest keys: %s" % str(manifest.keys()))
		return manifest

	print("[AssetRegistry] Chapter not found, returning empty dict")
	return {}

## Install a DLC chapter from a downloaded package
## package_path should be a .zip or directory containing chapter files
func install_chapter(package_path: String, chapter_id: String) -> bool:
	print("[AssetRegistry] Installing DLC chapter: ", chapter_id)

	var dest_path = DLC_BASE_DIR + chapter_id + "/"

	# Create chapter directory
	if not DirAccess.dir_exists_absolute(dest_path):
		DirAccess.make_dir_recursive_absolute(dest_path)

	# TODO: Extract/copy files from package_path to dest_path
	# This would typically involve:
	# 1. Unzipping if .zip
	# 2. Copying files if directory
	# 3. Validating manifest.json

	# For now, assume package_path is already extracted
	if DirAccess.dir_exists_absolute(package_path):
		_copy_directory(package_path, dest_path)

	# Rescan installed DLC
	_scan_installed_dlc()

	return is_chapter_installed(chapter_id)

## Copy directory recursively
func _copy_directory(from_path: String, to_path: String):
	var dir = DirAccess.open(from_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var source = from_path + file_name
		var dest = to_path + file_name

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				DirAccess.make_dir_absolute(dest)
				_copy_directory(source + "/", dest + "/")
		else:
			# Copy file
			var source_file = FileAccess.open(source, FileAccess.READ)
			var dest_file = FileAccess.open(dest, FileAccess.WRITE)

			if source_file and dest_file:
				dest_file.store_buffer(source_file.get_buffer(source_file.get_length()))
				dest_file.close()
				source_file.close()

		file_name = dir.get_next()

	dir.list_dir_end()

## Uninstall a DLC chapter
func uninstall_chapter(chapter_id: String) -> bool:
	if not installed_chapters.has(chapter_id):
		return false

	var chapter_path = installed_chapters[chapter_id]["path"]

	# Remove directory
	_remove_directory_recursive(chapter_path)

	# Rescan
	_scan_installed_dlc()

	return true

## Remove directory recursively
func _remove_directory_recursive(path: String):
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_remove_directory_recursive(path + file_name + "/")
		else:
			dir.remove(file_name)

		file_name = dir.get_next()

	dir.list_dir_end()

	# Remove the directory itself
	DirAccess.remove_absolute(path)
