extends Node

# Level data structure
class LevelData:
	var level_number: int
	var grid_layout: Array  # 2D array where -1 = blocked, 0 = empty, 1+ = tile types
	var width: int
	var height: int
	var target_score: int
	var moves: int
	var description: String
	var theme: String = ""  # Theme name for this level
	var collectible_target: int = 0  # Number of collectibles to collect (0 = score-based level)
	var collectible_type: String = "coin"  # Type of collectible (coin, gem, star, etc.)

	func _init(num: int, layout: Array, w: int, h: int, score: int, mv: int, desc: String = "", thm: String = "", coll_target: int = 0, coll_type: String = "coin"):
		level_number = num
		grid_layout = layout
		width = w
		height = h
		target_score = score
		moves = mv
		description = desc
		theme = thm
		collectible_target = coll_target
		collectible_type = coll_type

var levels: Array[LevelData] = []
var current_level_index: int = 0

func _ready():
	print("LevelManager is ready and initializing levels...")
	load_all_levels()
	print("Debug: Levels loaded: ", levels.size())

func load_all_levels():
	"""Load all level configurations from JSON files"""
	levels.clear()

	# Try to load levels from JSON files in the levels directory
	var level_files = get_level_files()

	print("[LevelManager] Found ", level_files.size(), " level files")
	for file in level_files:
		print("[LevelManager]   - ", file)

	if level_files.size() > 0:
		for file_path in level_files:
			var level_data = load_level_from_json(file_path)
			if level_data:
				levels.append(level_data)
				var level_type = "COLLECTIBLE (%d coins)" % level_data.collectible_target if level_data.collectible_target > 0 else "SCORE"
				print("[LevelManager] Loaded level ", level_data.level_number, ": '", level_data.description, "' (theme: ", level_data.theme, ", target: ", level_data.target_score, ", type: ", level_type, ")")
			else:
				print("[LevelManager] ERROR: Failed to load level from ", file_path)
	else:
		# If no JSON files found, use built-in levels
		print("[LevelManager] No level JSON files found, using built-in levels")
		create_builtin_levels()

	print("Loaded ", levels.size(), " levels")

func get_level_files() -> Array:
	"""Get all level JSON files from the levels directory"""
	var level_files = []
	var dir = DirAccess.open("res://levels/")

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				# Skip world_map.json as it's not a game level
				if file_name != "world_map.json":
					level_files.append("res://levels/" + file_name)
			file_name = dir.get_next()

		dir.list_dir_end()

		# Sort level files by name to ensure correct order
		level_files.sort()

	return level_files

func load_level_from_json(file_path: String) -> LevelData:
	"""Load a level configuration from a JSON file"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open level file: ", file_path)
		return null

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("Failed to parse JSON in file: ", file_path)
		return null

	var data = json.get_data()

	# Use the generic parser that supports string/array/flat formats
	var width = data.get("grid_width", data.get("width", 8))
	var height = data.get("grid_height", data.get("height", 8))
	var parsed = parse_layout(data.get("layout", ""), width, height)

	# Build LevelData with parsed layout (parsed may contain ints or single-char strings)
	return LevelData.new(
		data.get("level_number", data.get("level", 0)),
		parsed,
		width,
		height,
		data.get("target_score", data.get("target", data.get("target_score", 1000))),
		data.get("max_moves", data.get("moves", 20)),
		data.get("description", ""),
		data.get("theme", ""),
		data.get("collectible_target", 0),  # Load collectible target from JSON
		data.get("collectible_type", "coin")  # Load collectible type from JSON (default: coin)
	)

func parse_layout(layout_data, width: int, height: int) -> Array:
	"""Parse layout from various formats (string grid, array of arrays, or flat array)"""
	var parsed_layout = []

	if typeof(layout_data) == TYPE_STRING:
		# String format: lines separated by newlines, values separated by spaces or commas
		return parse_string_layout(layout_data, width, height)
	elif typeof(layout_data) == TYPE_ARRAY:
		# Check if it's array of arrays or flat array
		if layout_data.size() > 0 and typeof(layout_data[0]) == TYPE_ARRAY:
			# Array of arrays format
			return parse_2d_array_layout(layout_data, width, height)
		else:
			# Flat array format
			return parse_flat_array_layout(layout_data, width, height)

	return []

func parse_string_layout(layout_str: String, width: int, height: int) -> Array:
	"""Parse layout from string format. Supports compact no-separator strings and newline/space separated formats."""
	var parsed = []
	var lines = layout_str.strip_edges().split("\n")

	# Normalize lines: if the entire layout is one long string equal to width*height, split into rows
	if lines.size() == 1 and lines[0].length() == width * height:
		var compact = lines[0]
		lines = []
		for r in range(height):
			lines.append(compact.substr(r * width, width))

	for x in range(width):
		parsed.append([])
		for _y in range(height):
			parsed[x].append(0)

	for y in range(min(lines.size(), height)):
		var line = lines[y].strip_edges()
		# If line contains separators, split by comma or space
		var values = []
		if "," in line:
			values = line.split(",")
		elif " " in line:
			values = line.split(" ")
		else:
			# No separators - treat each character as a cell token
			values = []
			for i in range(min(line.length(), width)):
				values.append(line.substr(i, 1))

		for x in range(min(values.size(), width)):
			var val_str = values[x].strip_edges()
			# Recognize blocked or empty markers and integers; otherwise store token as-is
			if val_str == "X" or val_str == "x":
				parsed[x][y] = -1
			elif val_str == "." or val_str == "_":
				parsed[x][y] = 0
			elif val_str.is_valid_int():
				parsed[x][y] = int(val_str)
			else:
				# Keep single-character tokens like 'C','U','H' as strings
				if val_str.length() == 1:
					parsed[x][y] = val_str
				else:
					parsed[x][y] = 0

	return parsed

func parse_2d_array_layout(layout_array: Array, width: int, height: int) -> Array:
	"""Parse layout from 2D array format"""
	var parsed = []

	for x in range(width):
		parsed.append([])
		for y in range(height):
			if x < layout_array.size() and y < layout_array[x].size():
				parsed[x].append(layout_array[x][y])
			else:
				parsed[x].append(0)

	return parsed

func parse_flat_array_layout(layout_array: Array, width: int, height: int) -> Array:
	"""Parse layout from flat array format (row by row)"""
	var parsed = []

	for x in range(width):
		parsed.append([])
		for y in range(height):
			var index = y * width + x
			if index < layout_array.size():
				parsed[x].append(layout_array[index])
			else:
				parsed[x].append(0)

	return parsed

func create_builtin_levels():
	"""Create built-in levels if no JSON files are found"""

	# Level 1: Standard 8x8 grid
	var level1_layout = []
	for x in range(8):
		level1_layout.append([])
		for y in range(8):
			level1_layout[x].append(0)  # 0 means fill with random tiles

	levels.append(LevelData.new(1, level1_layout, 8, 8, 5000, 30, "Welcome! Match 3 tiles to score points."))

	# Level 2: 8x8 with corners blocked
	var level2_layout = []
	for x in range(8):
		level2_layout.append([])
		for y in range(8):
			# Block corners
			if (x < 2 and y < 2) or (x > 5 and y < 2) or (x < 2 and y > 5) or (x > 5 and y > 5):
				level2_layout[x].append(-1)  # -1 means blocked
			else:
				level2_layout[x].append(0)

	levels.append(LevelData.new(2, level2_layout, 8, 8, 7000, 28, "Watch out for the corners!"))

	# Level 3: Cross shape
	var level3_layout = []
	for x in range(8):
		level3_layout.append([])
		for y in range(8):
			# Create a cross pattern
			if (x >= 2 and x <= 5) or (y >= 2 and y <= 5):
				level3_layout[x].append(0)
			else:
				level3_layout[x].append(-1)

	levels.append(LevelData.new(3, level3_layout, 8, 8, 8000, 25, "Navigate the cross!"))

	# Level 4: Diamond shape
	var level4_layout = []
	for x in range(8):
		level4_layout.append([])
		for y in range(8):
			var center = 3.5
			var distance = abs(x - center) + abs(y - center)
			if distance <= 4:
				level4_layout[x].append(0)
			else:
				level4_layout[x].append(-1)

	levels.append(LevelData.new(4, level4_layout, 8, 8, 9000, 25, "The diamond challenge!"))

	# Level 5: Donut shape (hole in middle)
	var level5_layout = []
	for x in range(8):
		level5_layout.append([])
		for y in range(8):
			# Block center
			if x >= 3 and x <= 4 and y >= 3 and y <= 4:
				level5_layout[x].append(-1)
			else:
				level5_layout[x].append(0)

	levels.append(LevelData.new(5, level5_layout, 8, 8, 10000, 22, "The donut level!"))

func get_level(level_index: int) -> LevelData:
	"""Get level data by index"""
	if level_index >= 0 and level_index < levels.size():
		return levels[level_index]
	return null

func get_current_level() -> LevelData:
	"""Get the current level data"""
	return get_level(current_level_index)

func get_current_level_data() -> LevelData:
	"""Get the current level data (alias for get_current_level)"""
	return get_current_level()

func advance_to_next_level() -> bool:
	"""Move to the next level, returns false if no more levels"""
	print("[LevelManager] advance_to_next_level called. Current index: ", current_level_index)
	if current_level_index < levels.size() - 1:
		current_level_index += 1
		print("[LevelManager] Advanced to index: ", current_level_index, " (Level ", current_level_index + 1, ")")
		return true
	print("[LevelManager] No more levels available")
	return false

func reset_to_first_level():
	"""Reset back to level 1"""
	current_level_index = 0

func get_total_levels() -> int:
	"""Get total number of levels"""
	return levels.size()

func is_cell_blocked(x: int, y: int) -> bool:
	"""Check if a cell is blocked in the current level"""
	var level = get_current_level()
	if not level:
		return false

	if x < 0 or x >= level.width or y < 0 or y >= level.height:
		return true

	return level.grid_layout[x][y] == -1

func set_current_level(index: int):
	if index >= 0 and index < levels.size():
		print("[LevelManager] set_current_level: changing from ", current_level_index, " to ", index)
		current_level_index = index
		print("[LevelManager] Current level set to index ", current_level_index, " (Level ", current_level_index + 1, ")")
	else:
		print("[LevelManager] ERROR: Invalid level index ", index)
