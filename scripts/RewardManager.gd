extends Node

# Singleton for managing all reward systems, currencies, and player progression

# Signals
signal coins_changed(new_amount: int)
signal gems_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal booster_changed(booster_type: String, new_amount: int)

# Currency constants
const MAX_LIVES = 5
const LIFE_REGEN_TIME = 1800.0  # 30 minutes in seconds
const SAVE_FILE_PATH = "user://player_progress.json"

# Player data
var coins: int = 0
var gems: int = 0
var lives: int = MAX_LIVES
var last_life_regen_time: float = 0.0

# Boosters inventory
var boosters = {
	"hammer": 0,
	"shuffle": 0,
	"swap": 0,
	"chain_reaction": 0,
	"bomb_3x3": 0,
	"line_blast": 0,
	"row_clear": 0,
	"column_clear": 0,
	"extra_moves": 0,
	"tile_squasher": 0
}

# Progression data
var daily_streak: int = 0
var last_login_date: String = ""
var total_stars: int = 0
var levels_completed: int = 0
var unlocked_themes: Array = ["legacy"]
var selected_theme: String = "legacy"

# Achievement tracking
var achievements_unlocked: Array = []
var total_matches: int = 0
var total_special_tiles_used: int = 0

# Audio settings (persisted in player progress)
var audio_music_volume: float = 0.7
var audio_sfx_volume: float = 0.8
var audio_music_enabled: bool = true
var audio_sfx_enabled: bool = true
var audio_muted: bool = false

func _ready():
	print("[RewardManager] Initializing...")
	load_progress()

	# Start life regeneration timer
	var timer = Timer.new()
	timer.wait_time = 60.0  # Check every minute
	timer.timeout.connect(_on_life_regen_check)
	add_child(timer)
	timer.start()

	# Check daily login streak
	check_daily_login()

	print("[RewardManager] Initialized - Coins: %d, Gems: %d, Lives: %d" % [coins, gems, lives])

# ============================================
# Currency Management
# ============================================

func add_coins(amount: int):
	coins += amount
	coins_changed.emit(coins)
	save_progress()
	print("[RewardManager] +%d coins. Total: %d" % [amount, coins])

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coins_changed.emit(coins)
		save_progress()
		print("[RewardManager] -%d coins. Remaining: %d" % [amount, coins])
		return true
	else:
		print("[RewardManager] Not enough coins! Need: %d, Have: %d" % [amount, coins])
		return false

func add_gems(amount: int):
	gems += amount
	gems_changed.emit(gems)
	save_progress()
	print("[RewardManager] +%d gems. Total: %d" % [amount, gems])

func spend_gems(amount: int) -> bool:
	if gems >= amount:
		gems -= amount
		gems_changed.emit(gems)
		save_progress()
		print("[RewardManager] -%d gems. Remaining: %d" % [amount, gems])
		return true
	else:
		print("[RewardManager] Not enough gems! Need: %d, Have: %d" % [amount, gems])
		return false

func get_coins() -> int:
	return coins

func get_gems() -> int:
	return gems

# ============================================
# Lives Management
# ============================================

func get_lives() -> int:
	return lives

func add_life(amount: int = 1):
	lives = min(lives + amount, MAX_LIVES)
	lives_changed.emit(lives)
	save_progress()
	print("[RewardManager] +%d lives. Total: %d/%d" % [amount, lives, MAX_LIVES])

func use_life() -> bool:
	if lives > 0:
		lives -= 1
		last_life_regen_time = Time.get_unix_time_from_system()
		lives_changed.emit(lives)
		save_progress()
		print("[RewardManager] -1 life. Remaining: %d/%d" % [lives, MAX_LIVES])
		return true
	else:
		print("[RewardManager] No lives remaining!")
		return false

func refill_lives():
	lives = MAX_LIVES
	lives_changed.emit(lives)
	save_progress()
	print("[RewardManager] Lives refilled to %d" % MAX_LIVES)

func _on_life_regen_check():
	if lives < MAX_LIVES:
		var current_time = Time.get_unix_time_from_system()
		var time_passed = current_time - last_life_regen_time
		var lives_to_add = int(time_passed / LIFE_REGEN_TIME)

		if lives_to_add > 0:
			add_life(lives_to_add)
			last_life_regen_time = current_time

func get_time_until_next_life() -> float:
	if lives >= MAX_LIVES:
		return 0.0

	var current_time = Time.get_unix_time_from_system()
	var time_passed = current_time - last_life_regen_time
	var time_until_next = LIFE_REGEN_TIME - fmod(time_passed, LIFE_REGEN_TIME)
	return time_until_next

# ============================================
# Booster Management
# ============================================

func add_booster(booster_type: String, amount: int = 1):
	print("[RewardManager] add_booster called: ", booster_type, " amount: ", amount)
	print("[RewardManager] boosters.has(", booster_type, "): ", boosters.has(booster_type))
	if boosters.has(booster_type):
		boosters[booster_type] += amount
		print("[RewardManager] Emitting booster_changed signal for: ", booster_type, " new value: ", boosters[booster_type])
		booster_changed.emit(booster_type, boosters[booster_type])
		save_progress()
		print("[RewardManager] +%d %s. Total: %d" % [amount, booster_type, boosters[booster_type]])
	else:
		print("[RewardManager] ERROR: Booster type not found: ", booster_type)

func use_booster(booster_type: String) -> bool:
	if boosters.has(booster_type) and boosters[booster_type] > 0:
		boosters[booster_type] -= 1
		booster_changed.emit(booster_type, boosters[booster_type])
		save_progress()
		print("[RewardManager] Used %s. Remaining: %d" % [booster_type, boosters[booster_type]])
		return true
	else:
		print("[RewardManager] No %s available!" % booster_type)
		return false

func get_booster_count(booster_type: String) -> int:
	if boosters.has(booster_type):
		return boosters[booster_type]
	return 0

# ============================================
# Level Completion Rewards
# ============================================

func grant_level_completion_reward(level_number: int, stars: int):
	# Base coin reward
	var coin_reward = 100 + (50 * level_number)
	add_coins(coin_reward)

	# Bonus gems for 3 stars (first time only)
	if stars == 3:
		var first_time = level_number > levels_completed
		if first_time:
			add_gems(5)
			print("[RewardManager] Bonus gems for first 3-star completion!")

	# Update progression
	if level_number > levels_completed:
		levels_completed = level_number

	total_stars += stars
	save_progress()

	print("[RewardManager] Level %d completed with %d stars. Reward: %d coins" % [level_number, stars, coin_reward])

# ============================================
# Daily Login System
# ============================================

func check_daily_login():
	var today = Time.get_date_string_from_system()

	if last_login_date == "":
		# First time login
		daily_streak = 1
		last_login_date = today
		save_progress()
		print("[RewardManager] Welcome! Daily streak started.")
		return

	if last_login_date == today:
		# Already logged in today
		return

	var yesterday = _get_yesterday_date()
	if last_login_date == yesterday:
		# Consecutive login
		daily_streak += 1
	else:
		# Streak broken
		daily_streak = 1

	last_login_date = today

	# Grant daily reward
	grant_daily_login_reward()
	save_progress()

func grant_daily_login_reward():
	var day = daily_streak % 7
	if day == 0:
		day = 7

	match day:
		1:
			add_coins(50)
		2:
			add_coins(75)
		3:
			add_coins(100)
			add_gems(5)
		4:
			add_coins(125)
		5:
			add_coins(150)
		6:
			add_coins(175)
		7:
			add_coins(200)
			add_gems(25)
			add_booster("hammer", 1)
			print("[RewardManager] Week completed! Bonus rewards granted!")

	print("[RewardManager] Daily login reward (Day %d): Claimed!" % day)

func _get_yesterday_date() -> String:
	var unix_time = Time.get_unix_time_from_system()
	var yesterday_unix = unix_time - 86400  # 24 hours in seconds
	var yesterday_dict = Time.get_date_dict_from_unix_time(yesterday_unix)
	return "%04d-%02d-%02d" % [yesterday_dict.year, yesterday_dict.month, yesterday_dict.day]

# ============================================
# Theme Management
# ============================================

func unlock_theme(theme_name: String):
	if not unlocked_themes.has(theme_name):
		unlocked_themes.append(theme_name)
		save_progress()
		print("[RewardManager] Theme unlocked: %s" % theme_name)

func is_theme_unlocked(theme_name: String) -> bool:
	return unlocked_themes.has(theme_name)

func set_selected_theme(theme_name: String):
	if is_theme_unlocked(theme_name):
		selected_theme = theme_name
		save_progress()
		print("[RewardManager] Theme changed to: %s" % theme_name)
		return true
	return false

# ============================================
# Achievement System
# ============================================

func unlock_achievement(achievement_id: String):
	if not achievements_unlocked.has(achievement_id):
		achievements_unlocked.append(achievement_id)
		save_progress()
		print("[RewardManager] Achievement unlocked: %s" % achievement_id)
		# TODO: Show achievement notification

# ============================================
# Save/Load System
# ============================================

func save_progress():
	var save_data = {
		"coins": coins,
		"gems": gems,
		"lives": lives,
		"last_life_regen_time": last_life_regen_time,
		"boosters": boosters,
		"daily_streak": daily_streak,
		"last_login_date": last_login_date,
		"total_stars": total_stars,
		"levels_completed": levels_completed,
		"unlocked_themes": unlocked_themes,
		"selected_theme": selected_theme,
		"achievements_unlocked": achievements_unlocked,
		"total_matches": total_matches,
		"total_special_tiles_used": total_special_tiles_used,
		"audio": {
			"music_volume": audio_music_volume,
			"sfx_volume": audio_sfx_volume,
			"music_enabled": audio_music_enabled,
			"sfx_enabled": audio_sfx_enabled,
			"muted": audio_muted
		}
	}

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		print("[RewardManager] Progress saved")
	else:
		print("[RewardManager] ERROR: Could not save progress")

func load_progress():
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[RewardManager] No save file found. Starting fresh.")
		# Give starter rewards
		coins = 500
		gems = 50
		lives = MAX_LIVES
		last_life_regen_time = Time.get_unix_time_from_system()
		save_progress()
		return

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			var data = json.data
			coins = data.get("coins", 0)
			gems = data.get("gems", 0)
			lives = data.get("lives", MAX_LIVES)
			last_life_regen_time = data.get("last_life_regen_time", Time.get_unix_time_from_system())
			boosters = data.get("boosters", boosters)
			daily_streak = data.get("daily_streak", 0)
			last_login_date = data.get("last_login_date", "")
			total_stars = data.get("total_stars", 0)
			levels_completed = data.get("levels_completed", 0)
			unlocked_themes = data.get("unlocked_themes", ["legacy"])
			selected_theme = data.get("selected_theme", "legacy")
			achievements_unlocked = data.get("achievements_unlocked", [])
			total_matches = data.get("total_matches", 0)
			total_special_tiles_used = data.get("total_special_tiles_used", 0)

			# Load audio settings
			var audio_data = data.get("audio", {})
			audio_music_volume = audio_data.get("music_volume", audio_music_volume)
			audio_sfx_volume = audio_data.get("sfx_volume", audio_sfx_volume)
			audio_music_enabled = audio_data.get("music_enabled", audio_music_enabled)
			audio_sfx_enabled = audio_data.get("sfx_enabled", audio_sfx_enabled)
			audio_muted = audio_data.get("muted", audio_muted)

			print("[RewardManager] Progress loaded successfully")
		else:
			print("[RewardManager] ERROR: Failed to parse save file")
	else:
		print("[RewardManager] ERROR: Could not open save file")

func reset_progress():
	coins = 500
	gems = 50
	lives = MAX_LIVES
	last_life_regen_time = Time.get_unix_time_from_system()
	boosters = {
		"hammer": 0,
		"shuffle": 0,
		"swap": 0,
		"chain_reaction": 0,
		"bomb_3x3": 0,
		"line_blast": 0,
		"row_clear": 0,
		"column_clear": 0,
		"extra_moves": 0,
		"tile_squasher": 0
	}
	daily_streak = 0
	last_login_date = ""
	total_stars = 0
	levels_completed = 0
	unlocked_themes = ["legacy"]
	selected_theme = "legacy"
	achievements_unlocked = []
	total_matches = 0
	total_special_tiles_used = 0

	save_progress()

	# Emit all signals to update UI
	coins_changed.emit(coins)
	gems_changed.emit(gems)
	lives_changed.emit(lives)

	print("[RewardManager] Progress reset!")

func set_audio_muted(muted: bool):
	audio_muted = muted
	# If muted, disable both streams; if unmuted, restore enabled flags
	if muted:
		audio_music_enabled = false
		audio_sfx_enabled = false
	else:
		# Default to true when unmuting unless stored otherwise
		audio_music_enabled = true
		audio_sfx_enabled = true
	save_progress()
