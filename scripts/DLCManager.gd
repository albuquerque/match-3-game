extends Node
## DLCManager - Handles downloading and updating of narrative DLC chapters
## Manages version checking, downloads, and installation

# Signal emitted when DLC list is updated
signal dlc_list_updated(available_chapters: Array)

# Signal emitted when download progresses
signal download_progress(chapter_id: String, bytes_downloaded: int, total_bytes: int)

# Signal emitted when download completes
signal download_complete(chapter_id: String, success: bool)

# Signal emitted when chapter is installed
signal chapter_installed(chapter_id: String)

# DLC server URL (loaded from DLCConfig)
var dlc_server_url: String = ""

# HTTPRequest node for downloads
var http_request: HTTPRequest = null

# Currently downloading chapter
var current_download: Dictionary = {}

# Available chapters from server
var available_chapters: Array = []

func _ready():
	print("[DLCManager] Initializing DLC manager...")

	# Load server URL from config
	dlc_server_url = DLCConfig.get_dlc_server_url()
	DLCConfig.print_config()

	# Create HTTPRequest node for downloads
	http_request = HTTPRequest.new()
	http_request.name = "DLCDownloader"
	add_child(http_request)

	http_request.request_completed.connect(_on_request_completed)

	print("[DLCManager] DLC manager ready")

## Fetch list of available DLC chapters from server
func fetch_available_chapters():
	print("[DLCManager] Fetching available DLC chapters...")

	var url = dlc_server_url + "manifest_list.json"
	var error = http_request.request(url)

	if error != OK:
		push_error("[DLCManager] Failed to start request: ", error)
		return

	current_download = {
		"type": "manifest_list",
		"url": url
	}

## Download a DLC chapter
func download_chapter(chapter_id: String):
	print("[DLCManager] Starting download for chapter: ", chapter_id)

	# Find chapter in available list
	var chapter_info = null
	for chapter in available_chapters:
		if chapter.get("chapter_id") == chapter_id:
			chapter_info = chapter
			break

	if not chapter_info:
		push_error("[DLCManager] Chapter not found in available list: ", chapter_id)
		download_complete.emit(chapter_id, false)
		return

	# Download chapter package
	var download_url = chapter_info.get("download_url", "")
	if download_url.is_empty():
		push_error("[DLCManager] No download URL for chapter: ", chapter_id)
		download_complete.emit(chapter_id, false)
		return

	var error = http_request.request(download_url)
	if error != OK:
		push_error("[DLCManager] Failed to start download: ", error)
		download_complete.emit(chapter_id, false)
		return

	current_download = {
		"type": "chapter_package",
		"chapter_id": chapter_id,
		"url": download_url,
		"info": chapter_info
	}

## Check for DLC updates
func check_for_updates():
	print("[DLCManager] Checking for DLC updates...")

	fetch_available_chapters()

## Get list of available chapters
func get_available_chapters() -> Array:
	return available_chapters

## Check if a chapter needs an update
func is_update_available(chapter_id: String) -> bool:
	if not AssetRegistry.is_chapter_installed(chapter_id):
		return false

	var installed_info = AssetRegistry.get_chapter_info(chapter_id)
	var installed_version = installed_info.get("version", "0.0.0")

	# Find in available chapters
	for chapter in available_chapters:
		if chapter.get("chapter_id") == chapter_id:
			var server_version = chapter.get("version", "0.0.0")
			return _is_version_newer(server_version, installed_version)

	return false

## Compare versions (returns true if v1 > v2)
func _is_version_newer(v1: String, v2: String) -> bool:
	var parts1 = v1.split(".")
	var parts2 = v2.split(".")

	for i in range(max(parts1.size(), parts2.size())):
		var p1 = int(parts1[i]) if i < parts1.size() else 0
		var p2 = int(parts2[i]) if i < parts2.size() else 0

		if p1 > p2:
			return true
		elif p1 < p2:
			return false

	return false

## Handle HTTP request completion
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("[DLCManager] Request completed: result=%d, response_code=%d, body_size=%d" % [result, response_code, body.size()])

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[DLCManager] Request failed with result: ", result)
		_handle_download_failure()
		return

	if response_code != 200:
		push_error("[DLCManager] Server returned error code: ", response_code)
		_handle_download_failure()
		return

	var download_type = current_download.get("type", "")
	print("[DLCManager] Processing download type: %s" % download_type)

	match download_type:
		"manifest_list":
			_process_manifest_list(body)
		"chapter_package":
			_process_chapter_package(body)

## Process manifest list from server
func _process_manifest_list(body: PackedByteArray):
	print("[DLCManager] Processing manifest list...")

	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())

	if error != OK:
		push_error("[DLCManager] Failed to parse manifest list")
		return

	if json.data is Dictionary and json.data.has("chapters"):
		available_chapters = json.data["chapters"]
		print("[DLCManager] Found %d available chapters" % available_chapters.size())
		dlc_list_updated.emit(available_chapters)
	else:
		push_error("[DLCManager] Invalid manifest list format")

## Process downloaded chapter package
func _process_chapter_package(body: PackedByteArray):
	var chapter_id = current_download.get("chapter_id", "")
	print("[DLCManager] Processing chapter package: %s (size: %d bytes)" % [chapter_id, body.size()])

	# Save package to temporary location
	var temp_path = "user://dlc_temp/" + chapter_id + ".zip"
	DirAccess.make_dir_recursive_absolute("user://dlc_temp/")

	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("[DLCManager] Failed to save package")
		_handle_download_failure()
		return

	file.store_buffer(body)
	file.close()

	print("[DLCManager] Package saved: ", temp_path)

	# Extract and install
	print("[DLCManager] Starting installation...")
	_install_chapter_package(chapter_id, temp_path)

## Install chapter from downloaded package
func _install_chapter_package(chapter_id: String, package_path: String):
	print("[DLCManager] Installing chapter: ", chapter_id)

	# Extract zip to chapter directory
	var extract_path = AssetRegistry.DLC_BASE_DIR + chapter_id + "/"

	# TODO: Implement ZIP extraction
	# For now, assume package is already extracted or use a plugin
	# In production, you'd use:
	# 1. ZIPReader class (if available)
	# 2. External zip library
	# 3. Pre-extracted files

	# For demonstration, we'll assume direct file copy
	var success = _extract_package(package_path, extract_path)

	if success:
		# Rescan DLC
		AssetRegistry._scan_installed_dlc()

		print("[DLCManager] Chapter installed successfully: ", chapter_id)
		chapter_installed.emit(chapter_id)
		download_complete.emit(chapter_id, true)
	else:
		push_error("[DLCManager] Failed to install chapter: ", chapter_id)
		_handle_download_failure()

	# Clean up temp file
	DirAccess.remove_absolute(package_path)

## Extract package using ZIPReader
func _extract_package(zip_path: String, dest_path: String) -> bool:
	print("[DLCManager] Extracting package: %s -> %s" % [zip_path, dest_path])

	# Create destination directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if not dir:
		push_error("[DLCManager] Failed to access user:// directory")
		return false

	# Ensure DLC base directory exists
	if not DirAccess.dir_exists_absolute(dest_path.get_base_dir()):
		var err = DirAccess.make_dir_recursive_absolute(dest_path.get_base_dir())
		if err != OK:
			push_error("[DLCManager] Failed to create DLC directory: ", err)
			return false

	# Use ZIPReader to extract files
	var zip_reader = ZIPReader.new()
	var err = zip_reader.open(zip_path)

	if err != OK:
		push_error("[DLCManager] Failed to open ZIP file: ", err)
		return false

	var files = zip_reader.get_files()
	print("[DLCManager] Found %d files in package" % files.size())

	for file_path in files:
		# Skip directories
		if file_path.ends_with("/"):
			continue

		# Read file from ZIP
		var file_data = zip_reader.read_file(file_path)
		if file_data == null:
			push_error("[DLCManager] Failed to read file from ZIP: ", file_path)
			continue

		# Construct destination path
		var full_dest_path = dest_path.path_join(file_path)

		# Create parent directories
		var parent_dir = full_dest_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(parent_dir):
			DirAccess.make_dir_recursive_absolute(parent_dir)

		# Write file
		var dest_file = FileAccess.open(full_dest_path, FileAccess.WRITE)
		if dest_file:
			dest_file.store_buffer(file_data)
			dest_file.close()
			print("[DLCManager]   Extracted: %s" % file_path)
		else:
			push_error("[DLCManager] Failed to write file: ", full_dest_path)

	zip_reader.close()
	print("[DLCManager] Package extraction complete!")
	return true

## Handle download failure
func _handle_download_failure():
	var chapter_id = current_download.get("chapter_id", "unknown")
	download_complete.emit(chapter_id, false)
	current_download.clear()

## Process download progress
func _process(_delta: float):
	if http_request and current_download.get("type") == "chapter_package":
		var bytes_downloaded = http_request.get_downloaded_bytes()
		var total_bytes = http_request.get_body_size()

		if total_bytes > 0:
			var chapter_id = current_download.get("chapter_id", "")
			download_progress.emit(chapter_id, bytes_downloaded, total_bytes)
