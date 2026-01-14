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

	func _init(num: int, layout: Array, w: int, h: int, score: int, mv: int, desc: String = "", thm: String = ""):
		level_number = num
		grid_layout = layout
		width = w
		height = h
		target_score = score
		moves = mv
		description = desc
		theme = thm

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
				print("[LevelManager] Loaded level ", level_data.level_number, ": '", level_data.description, "' (theme: ", level_data.theme, ", target: ", level_data.target_score, ")")
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
	var layout_lines = data["layout"].split("\n")

	# Parse the layout correctly: each line is a Y row, we need to convert to [x][y] format
	var width = data["width"]
	var height = data["height"]
	var grid_layout = []

	# Initialize the grid with proper dimensions [x][y]
	for x in range(width):
		grid_layout.append([])
		for y in range(height):
			grid_layout[x].append(0)

	# Parse each line (Y row) and fill the grid
	for y in range(min(layout_lines.size(), height)):
		var line = layout_lines[y].strip_edges()
		var cells = line.split(" ")

		for x in range(min(cells.size(), width)):
			var cell_value = cells[x].strip_edges()

			if cell_value == "X" or cell_value == "x":
				grid_layout[x][y] = -1  # Blocked cell
			elif cell_value == "." or cell_value == "_":
				grid_layout[x][y] = 0  # Empty cell
			elif cell_value.is_valid_int():
				grid_layout[x][y] = int(cell_value)
			else:
				grid_layout[x][y] = 0  # Default to empty

	# Extract theme if present
	var theme = data.get("theme", "")

	return LevelData.new(
		data["level"],
		grid_layout,
		data["width"],
		data["height"],
		data["target_score"],
		data["moves"],
		data["description"],
		theme
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
	"""Parse layout from string format"""
	var parsed = []
	var lines = layout_str.strip_edges().split("\n")

	for x in range(width):
		parsed.append([])
		for _y in range(height):
			parsed[x].append(0)

	for y in range(min(lines.size(), height)):
		var line = lines[y].strip_edges()
		# Support both space and comma separation
		var values = []
		if "," in line:
			values = line.split(",")
		else:
			values = line.split(" ")

		for x in range(min(values.size(), width)):
			var val_str = values[x].strip_edges()
			if val_str == "X" or val_str == "x":
				parsed[x][y] = -1  # Blocked cell
			elif val_str == "." or val_str == "_":
				parsed[x][y] = 0  # Empty cell
			elif val_str.is_valid_int():
				parsed[x][y] = int(val_str)
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

