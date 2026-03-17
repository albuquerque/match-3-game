extends Node

## GalleryImageLoader — fetches gallery art from HTTP URLs and caches to disk.
## Autoloaded singleton. Callers await load_image(url) which returns a Texture2D or null.
## Cache lives at user://gallery_cache/<md5_of_url>.png

const CACHE_DIR := "user://gallery_cache/"

# url -> Texture2D (in-memory cache for this session)
var _mem_cache: Dictionary = {}
# url -> Array of Callables waiting for it
var _pending: Dictionary = {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	print("[GalleryImageLoader] ready — cache: ", CACHE_DIR)

## Load image from url. Returns Texture2D on success, null on failure.
## Usage:  var tex = await GalleryImageLoader.load_image(url)
func load_image(url: String) -> Texture2D:
	if url.is_empty():
		return null

	# Local res:// or user:// paths
	if url.begins_with("res://") or url.begins_with("user://"):
		# Imported asset — fastest path
		if ResourceLoader.exists(url):
			return load(url) as Texture2D
		# Raw file (not yet imported) — read bytes via FileAccess
		if FileAccess.file_exists(url):
			var bytes := FileAccess.get_file_as_bytes(url)
			if bytes.size() > 0:
				var img := Image.new()
				var lower := url.to_lower()
				var err: int
				if lower.ends_with(".jpg") or lower.ends_with(".jpeg"):
					err = img.load_jpg_from_buffer(bytes)
				elif lower.ends_with(".webp"):
					err = img.load_webp_from_buffer(bytes)
				else:
					err = img.load_png_from_buffer(bytes)
				if err == OK and not img.is_empty():
					return ImageTexture.create_from_image(img)
		# File simply doesn't exist — return null silently
		return null

	# Memory cache hit
	if _mem_cache.has(url):
		return _mem_cache[url]

	# Disk cache hit
	var cached_tex := _load_from_disk_cache(url)
	if cached_tex:
		_mem_cache[url] = cached_tex
		return cached_tex

	# Already being fetched — wait for it
	if _pending.has(url):
		var result = await _wait_for_pending(url)
		return result

	# Kick off HTTP fetch
	return await _fetch(url)

# ── Private ────────────────────────────────────────────────────────────────

func _cache_path(url: String) -> String:
	return CACHE_DIR + url.md5_text() + ".png"

func _load_from_disk_cache(url: String) -> Texture2D:
	var path := _cache_path(url)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) == OK and not img.is_empty():
		return ImageTexture.create_from_image(img)
	return null

func _save_to_disk_cache(url: String, img: Image) -> void:
	img.save_png(ProjectSettings.globalize_path(_cache_path(url)))

signal fetch_done(url: String)

func _wait_for_pending(url: String) -> Texture2D:
	while _pending.has(url):
		await fetch_done
	return _mem_cache.get(url, null)

func _fetch(url: String) -> Texture2D:
	_pending[url] = true

	var http := HTTPRequest.new()
	add_child(http)

	var err := http.request(url)
	if err != OK:
		push_warning("[GalleryImageLoader] HTTPRequest error %d for: %s" % [err, url])
		http.queue_free()
		_pending.erase(url)
		fetch_done.emit(url)
		return null

	var response = await http.request_completed
	http.queue_free()

	var result_code: int  = response[0]
	var http_code: int    = response[1]
	var body: PackedByteArray = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS or http_code != 200:
		push_warning("[GalleryImageLoader] HTTP %d for: %s" % [http_code, url])
		_pending.erase(url)
		fetch_done.emit(url)
		return null

	var img := Image.new()
	# Detect format from URL extension
	var lower_url := url.to_lower()
	var load_err: int
	if lower_url.ends_with(".jpg") or lower_url.ends_with(".jpeg"):
		load_err = img.load_jpg_from_buffer(body)
	elif lower_url.ends_with(".webp"):
		load_err = img.load_webp_from_buffer(body)
	else:
		load_err = img.load_png_from_buffer(body)

	if load_err != OK or img.is_empty():
		push_warning("[GalleryImageLoader] Failed to decode image from: %s" % url)
		_pending.erase(url)
		fetch_done.emit(url)
		return null

	_save_to_disk_cache(url, img)
	var tex := ImageTexture.create_from_image(img)
	_mem_cache[url] = tex
	_pending.erase(url)
	fetch_done.emit(url)
	return tex

## Returns the absolute OS path where download_image() would save this item.
## Use this to check existence before deciding whether to show an ad.
func get_download_path(item_name: String) -> String:
	var safe_name := item_name.to_lower().replace(" ", "_").strip_edges()
	safe_name = safe_name.replace("/", "")
	safe_name = safe_name.replace(str(char(92)), "")
	safe_name = safe_name.replace(":", "")
	var filename := safe_name + ".png"
	var platform := OS.get_name()
	var save_dir: String
	if platform == "Android":
		save_dir = OS.get_system_dir(OS.SYSTEM_DIR_DCIM).path_join("Match3Gallery")
	elif platform in ["macOS", "Windows", "Linux", "FreeBSD"]:
		save_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("Match3Gallery")
	else:
		save_dir = ProjectSettings.globalize_path("user://gallery_downloads")
	return save_dir.path_join(filename)

## Download image — saves to platform Pictures/DCIM folder.
## Returns the absolute path written, or "" on failure.
## macOS/Linux : ~/Pictures/Match3Gallery/
## Windows     : ~/Pictures/Match3Gallery/
## Android     : DCIM/Match3Gallery/ (visible in Photos)
## iOS         : not supported (sandboxed — falls back to user://)
func download_image(url: String, item_name: String) -> String:
	var tex: Texture2D = await load_image(url)
	if not tex:
		return ""
	var img := tex.get_image()

	# Sanitise filename
	var safe_name := item_name.to_lower().replace(" ", "_").strip_edges()
	safe_name = safe_name.replace("/", "")
	safe_name = safe_name.replace(str(char(92)), "")
	safe_name = safe_name.replace(":", "")
	var filename := safe_name + ".png"

	# Resolve platform-appropriate save directory
	var save_dir: String
	var platform := OS.get_name()
	if platform in ["Android"]:
		# OS.SYSTEM_DIR_DCIM puts it in the camera roll — visible in Photos app
		save_dir = OS.get_system_dir(OS.SYSTEM_DIR_DCIM).path_join("Match3Gallery")
	elif platform in ["macOS", "Windows", "Linux", "FreeBSD"]:
		save_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("Match3Gallery")
	else:
		# iOS and unknown — fall back to user:// (sandboxed but at least saves)
		save_dir = ProjectSettings.globalize_path("user://gallery_downloads")

	DirAccess.make_dir_recursive_absolute(save_dir)
	var abs_out := save_dir.path_join(filename)

	if img.save_png(abs_out) == OK:
		print("[GalleryImageLoader] Saved to: ", abs_out)
		return abs_out
	push_warning("[GalleryImageLoader] Failed to save to: %s" % abs_out)
	return ""
