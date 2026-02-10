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
var last_daily_reward_claim: String = ""
var total_stars: int = 0
var levels_completed: int = 0
var level_stars: Dictionary = {}  # {"level_1": 3, "level_2": 2, ...}
var unlocked_themes: Array = ["legacy"]
var selected_theme: String = "legacy"
var unlocked_gallery_images: Array = []  # Array of unlocked image IDs

# Premium status
var is_premium_user: bool = false  # Premium/VIP status (removes ads, bonus content)

# Achievement tracking
var achievements_unlocked: Array = []
var total_matches: int = 0
var total_special_tiles_used: int = 0
var total_boosters_used: int = 0
var total_score_earned: int = 0
var total_gems_earned: int = 0
var total_coins_earned: int = 0
var max_combo_reached: int = 0
var total_tiles_cleared: int = 0
var perfect_levels: int = 0  # Levels completed with 3 stars

# New achievement types tracking
var achievements_progress = {
	# Match-based achievements (expanded tiers)
	"matches_100": {"progress": 0, "target": 100, "claimed": false},
	"matches_500": {"progress": 0, "target": 500, "claimed": false},
	"matches_1000": {"progress": 0, "target": 1000, "claimed": false},
	"matches_2500": {"progress": 0, "target": 2500, "claimed": false},
	"matches_5000": {"progress": 0, "target": 5000, "claimed": false},
	"matches_10000": {"progress": 0, "target": 10000, "claimed": false},

	# Level-based achievements (expanded tiers)
	"levels_10": {"progress": 0, "target": 10, "claimed": false},
	"levels_25": {"progress": 0, "target": 25, "claimed": false},
	"levels_50": {"progress": 0, "target": 50, "claimed": false},
	"levels_100": {"progress": 0, "target": 100, "claimed": false},
	"levels_250": {"progress": 0, "target": 250, "claimed": false},
	"levels_500": {"progress": 0, "target": 500, "claimed": false},

	# Star-based achievements (expanded tiers)
	"stars_10": {"progress": 0, "target": 10, "claimed": false},
	"stars_25": {"progress": 0, "target": 25, "claimed": false},
	"stars_50": {"progress": 0, "target": 50, "claimed": false},
	"stars_100": {"progress": 0, "target": 100, "claimed": false},
	"stars_250": {"progress": 0, "target": 250, "claimed": false},
	"stars_500": {"progress": 0, "target": 500, "claimed": false},

	# Special achievements (expanded and enhanced)
	"booster_explorer": {"progress": 0, "target": 5, "claimed": false},
	"perfect_streak": {"progress": 0, "target": 3, "claimed": false},
	"combo_master": {"progress": 0, "target": 10, "claimed": false},
	"score_hunter": {"progress": 0, "target": 100000, "claimed": false},
	"score_legend": {"progress": 0, "target": 1000000, "claimed": false},
	"combo_god": {"progress": 0, "target": 20, "claimed": false},
	"perfect_master": {"progress": 0, "target": 10, "claimed": false},
	"booster_addict": {"progress": 0, "target": 100, "claimed": false},

	# Weekly challenges (reset weekly)
	"weekly_matches": {"progress": 0, "target": 100, "claimed": false, "weekly": true},
	"weekly_levels": {"progress": 0, "target": 10, "claimed": false, "weekly": true},
	"weekly_perfect": {"progress": 0, "target": 5, "claimed": false, "weekly": true},
	"weekly_streak": {"progress": 0, "target": 7, "claimed": false, "weekly": true},

	# Monthly milestones (reset monthly)
	"monthly_dedication": {"progress": 0, "target": 20, "claimed": false, "monthly": true},
	"monthly_scorer": {"progress": 0, "target": 50000, "claimed": false, "monthly": true},
	"monthly_collector": {"progress": 0, "target": 25, "claimed": false, "monthly": true},

	# Seasonal events (special limited-time)
	"christmas_spirit": {"progress": 0, "target": 1, "claimed": false, "seasonal": true},
	"easter_joy": {"progress": 0, "target": 20, "claimed": false, "seasonal": true},
	"harvest_blessing": {"progress": 0, "target": 1000, "claimed": false, "seasonal": true},
}

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

	# Check for weekly/monthly resets for renewed engagement
	check_weekly_monthly_resets()

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

		# Track achievement for booster usage
		track_booster_used(booster_type)

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
	print("[RewardManager] grant_level_completion_reward called with level_number=", level_number, ", stars=", stars)
	print("[RewardManager] Current levels_completed=", levels_completed)

	# Base coin reward
	var coin_reward = 100 + (50 * level_number)
	add_coins(coin_reward)

	# Bonus gems for 3 stars (first time only)
	if stars == 3:
		var first_time = level_number > levels_completed
		if first_time:
			add_gems(5)
			print("[RewardManager] Bonus gems for first 3-star completion!")

	# Check if this level unlocks a gallery image
	print("[RewardManager] Checking gallery unlock for level ", level_number)

	# Define gallery unlock levels directly here to avoid static function issues
	var gallery_levels = {
		2: {"id": "image_01", "name": "Victory"},
		4: {"id": "image_02", "name": "Celebration"},
		6: {"id": "image_03", "name": "Achievement"},
		8: {"id": "image_04", "name": "Glory"},
		10: {"id": "image_05", "name": "Champion"},
		12: {"id": "image_06", "name": "Master"},
		14: {"id": "image_07", "name": "Legend"},
		16: {"id": "image_08", "name": "Hero"},
		18: {"id": "image_09", "name": "Elite"},
		20: {"id": "image_10", "name": "Ultimate"}
	}

	if gallery_levels.has(level_number):
		var image_info = gallery_levels[level_number]
		var image_id = image_info.get("id", "")
		var image_name = image_info.get("name", "")
		print("[RewardManager] Level ", level_number, " unlocks gallery image: ", image_name)
		if unlock_gallery_image(image_id):
			print("[RewardManager] ✨ Gallery image unlocked: %s" % image_name)
		else:
			print("[RewardManager] Image was already unlocked: ", image_id)
	else:
		print("[RewardManager] No gallery image configured for level ", level_number)

	# Update progression
	if level_number > levels_completed:
		levels_completed = level_number
		print("[RewardManager] Updated levels_completed to ", levels_completed)

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
	print("[RewardManager] Daily login streak: %d days" % daily_streak)
	save_progress()


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
# Gallery System
# ============================================

func unlock_gallery_image(image_id: String):
	"""Unlock a gallery image by its ID"""
	if not unlocked_gallery_images.has(image_id):
		unlocked_gallery_images.append(image_id)
		save_progress()
		print("[RewardManager] Gallery image unlocked: %s" % image_id)
		return true
	return false

func is_gallery_image_unlocked(image_id: String) -> bool:
	"""Check if a gallery image is unlocked"""
	return unlocked_gallery_images.has(image_id)

func get_unlocked_gallery_images() -> Array:
	"""Get all unlocked gallery image IDs"""
	return unlocked_gallery_images.duplicate()

func get_unlock_progress() -> Dictionary:
	"""Get the total gallery unlock progress"""
	# Hardcoded total gallery images (can be moved to config later)
	var total_images = 10  # One image every 2 levels: levels 2, 4, 6, 8, 10, 12, 14, 16, 18, 20
	return {
		"unlocked": unlocked_gallery_images.size(),
		"total": total_images,
		"percentage": float(unlocked_gallery_images.size()) / float(total_images) * 100.0
	}

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
		"last_daily_reward_claim": last_daily_reward_claim,
		"total_stars": total_stars,
		"levels_completed": levels_completed,
		"level_stars": level_stars,  # Individual star ratings per level
		"unlocked_themes": unlocked_themes,
		"selected_theme": selected_theme,
		"unlocked_gallery_images": unlocked_gallery_images,
		"achievements_unlocked": achievements_unlocked,
		"total_matches": total_matches,
		"total_special_tiles_used": total_special_tiles_used,
		# New achievement tracking data
		"total_boosters_used": total_boosters_used,
		"total_score_earned": total_score_earned,
		"total_gems_earned": total_gems_earned,
		"total_coins_earned": total_coins_earned,
		"max_combo_reached": max_combo_reached,
		"total_tiles_cleared": total_tiles_cleared,
		"perfect_levels": perfect_levels,
		"achievements_progress": achievements_progress,
		# Premium status
		"is_premium_user": is_premium_user,
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

		# Give starter boosters so players can try them out
		boosters = {
			"hammer": 3,
			"shuffle": 2,
			"swap": 2,
			"chain_reaction": 1,
			"bomb_3x3": 1,
			"line_blast": 1,
			"row_clear": 0,
			"column_clear": 0,
			"extra_moves": 2,
			"tile_squasher": 0
		}
		print("[RewardManager] Starter boosters granted: ", boosters)

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
			level_stars = data.get("level_stars", {})  # Load individual level stars
			unlocked_themes = data.get("unlocked_themes", ["legacy"])
			selected_theme = data.get("selected_theme", "legacy")
			unlocked_gallery_images = data.get("unlocked_gallery_images", [])
			achievements_unlocked = data.get("achievements_unlocked", [])
			total_matches = data.get("total_matches", 0)
			total_special_tiles_used = data.get("total_special_tiles_used", 0)
			last_daily_reward_claim = data.get("last_daily_reward_claim", "")

			# Load new achievement tracking data
			total_boosters_used = data.get("total_boosters_used", 0)
			total_score_earned = data.get("total_score_earned", 0)
			total_gems_earned = data.get("total_gems_earned", 0)
			total_coins_earned = data.get("total_coins_earned", 0)
			max_combo_reached = data.get("max_combo_reached", 0)
			total_tiles_cleared = data.get("total_tiles_cleared", 0)
			perfect_levels = data.get("perfect_levels", 0)
			achievements_progress = data.get("achievements_progress", achievements_progress)

			# Load premium status
			is_premium_user = data.get("is_premium_user", false)

			# Load audio settings
			var audio_data = data.get("audio", {})
			audio_music_volume = audio_data.get("music_volume", audio_music_volume)
			audio_sfx_volume = audio_data.get("sfx_volume", audio_sfx_volume)
			audio_music_enabled = audio_data.get("music_enabled", audio_music_enabled)
			audio_sfx_enabled = audio_data.get("sfx_enabled", audio_sfx_enabled)
			audio_muted = audio_data.get("muted", audio_muted)

			# Load ExperienceState data if ExperienceDirector is available
			var experience_director = get_node_or_null("/root/ExperienceDirector")
			if experience_director and experience_director.has_method("load_state_data"):
				var experience_state_data = data.get("experience_state", null)
				if experience_state_data:
					experience_director.load_state_data(experience_state_data)

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

	# Give starter boosters so players can try them out
	boosters = {
		"hammer": 3,
		"shuffle": 2,
		"swap": 2,
		"chain_reaction": 1,
		"bomb_3x3": 1,
		"line_blast": 1,
		"row_clear": 0,
		"column_clear": 0,
		"extra_moves": 2,
		"tile_squasher": 0
	}

	daily_streak = 0
	last_login_date = ""
	last_daily_reward_claim = ""
	total_stars = 0
	levels_completed = 0
	unlocked_themes = ["legacy"]
	selected_theme = "legacy"
	achievements_unlocked = []
	total_matches = 0
	total_special_tiles_used = 0

	# Reset new achievement tracking
	total_boosters_used = 0
	total_score_earned = 0
	total_gems_earned = 0
	total_coins_earned = 0
	max_combo_reached = 0
	total_tiles_cleared = 0
	perfect_levels = 0
	achievements_progress = {
		# Match-based achievements (expanded tiers)
		"matches_100": {"progress": 0, "target": 100, "claimed": false},
		"matches_500": {"progress": 0, "target": 500, "claimed": false},
		"matches_1000": {"progress": 0, "target": 1000, "claimed": false},
		"matches_2500": {"progress": 0, "target": 2500, "claimed": false},
		"matches_5000": {"progress": 0, "target": 5000, "claimed": false},
		"matches_10000": {"progress": 0, "target": 10000, "claimed": false},

		# Level-based achievements (expanded tiers)
		"levels_10": {"progress": 0, "target": 10, "claimed": false},
		"levels_25": {"progress": 0, "target": 25, "claimed": false},
		"levels_50": {"progress": 0, "target": 50, "claimed": false},
		"levels_100": {"progress": 0, "target": 100, "claimed": false},
		"levels_250": {"progress": 0, "target": 250, "claimed": false},
		"levels_500": {"progress": 0, "target": 500, "claimed": false},

		# Star-based achievements (expanded tiers)
		"stars_10": {"progress": 0, "target": 10, "claimed": false},
		"stars_25": {"progress": 0, "target": 25, "claimed": false},
		"stars_50": {"progress": 0, "target": 50, "claimed": false},
		"stars_100": {"progress": 0, "target": 100, "claimed": false},
		"stars_250": {"progress": 0, "target": 250, "claimed": false},
		"stars_500": {"progress": 0, "target": 500, "claimed": false},

		# Special achievements (expanded and enhanced)
		"booster_explorer": {"progress": 0, "target": 5, "claimed": false},
		"perfect_streak": {"progress": 0, "target": 3, "claimed": false},
		"combo_master": {"progress": 0, "target": 10, "claimed": false},
		"score_hunter": {"progress": 0, "target": 100000, "claimed": false},
		"score_legend": {"progress": 0, "target": 1000000, "claimed": false},
		"combo_god": {"progress": 0, "target": 20, "claimed": false},
		"perfect_master": {"progress": 0, "target": 10, "claimed": false},
		"booster_addict": {"progress": 0, "target": 100, "claimed": false},

		# Weekly challenges (reset weekly)
		"weekly_matches": {"progress": 0, "target": 100, "claimed": false, "weekly": true},
		"weekly_levels": {"progress": 0, "target": 10, "claimed": false, "weekly": true},
		"weekly_perfect": {"progress": 0, "target": 5, "claimed": false, "weekly": true},
		"weekly_streak": {"progress": 0, "target": 7, "claimed": false, "weekly": true},

		# Monthly milestones (reset monthly)
		"monthly_dedication": {"progress": 0, "target": 20, "claimed": false, "monthly": true},
		"monthly_scorer": {"progress": 0, "target": 50000, "claimed": false, "monthly": true},
		"monthly_collector": {"progress": 0, "target": 25, "claimed": false, "monthly": true},

		# Seasonal events (special limited-time)
		"christmas_spirit": {"progress": 0, "target": 1, "claimed": false, "seasonal": true},
		"easter_joy": {"progress": 0, "target": 20, "claimed": false, "seasonal": true},
		"harvest_blessing": {"progress": 0, "target": 1000, "claimed": false, "seasonal": true},
	}

	save_progress()

	# Emit all signals to update UI
	coins_changed.emit(coins)
	gems_changed.emit(gems)
	lives_changed.emit(lives)

	# Emit booster changed signals for all boosters
	for booster_type in boosters.keys():
		booster_changed.emit(booster_type, boosters[booster_type])

	print("[RewardManager] Progress reset with starter boosters!")

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

# ============================================================================
# ACHIEVEMENT TRACKING SYSTEM
# ============================================================================



func track_tiles_cleared(count: int):
	"""Called when tiles are cleared"""
	total_tiles_cleared += count

func _update_achievement_progress(achievement_id: String, current_value: int):
	"""Update progress for a specific achievement"""
	if achievement_id in achievements_progress:
		var achievement = achievements_progress[achievement_id]
		achievement["progress"] = current_value

		# Check if achievement is newly completed
		if current_value >= achievement["target"] and not achievement["claimed"]:
			print("[RewardManager] Achievement unlocked: %s (%d/%d)" % [achievement_id, current_value, achievement["target"]])

func _check_perfect_streak():
	"""Check for perfect streak achievement (3 levels in a row with 3 stars)"""
	# This would need more complex tracking - for now, simplified
	if perfect_levels >= 3:
		_update_achievement_progress("perfect_streak", perfect_levels)

func get_achievement_progress(achievement_id: String) -> Dictionary:
	"""Get progress for a specific achievement"""
	if achievement_id in achievements_progress:
		return achievements_progress[achievement_id]
	return {"progress": 0, "target": 1, "claimed": false}

func claim_achievement_reward(achievement_id: String) -> Dictionary:
	"""Claim reward for completed achievement"""
	if not achievement_id in achievements_progress:
		return {"success": false, "reason": "Achievement not found"}

	var achievement = achievements_progress[achievement_id]
	if achievement["progress"] < achievement["target"]:
		return {"success": false, "reason": "Achievement not completed"}

	if achievement["claimed"]:
		return {"success": false, "reason": "Already claimed"}

	# Calculate reward based on achievement difficulty
	var reward = _get_achievement_reward(achievement_id)

	# Grant reward
	add_coins(reward["coins"])
	add_gems(reward["gems"])

	# Mark as claimed
	achievement["claimed"] = true
	save_progress()

	return {"success": true, "coins": reward["coins"], "gems": reward["gems"]}

func _get_achievement_reward(achievement_id: String) -> Dictionary:
	"""Get reward amounts for specific achievements"""
	var rewards = {
		# Match-based rewards (escalating)
		"matches_100": {"coins": 100, "gems": 1},
		"matches_500": {"coins": 300, "gems": 3},
		"matches_1000": {"coins": 500, "gems": 5},
		"matches_2500": {"coins": 800, "gems": 8},
		"matches_5000": {"coins": 1200, "gems": 12},
		"matches_10000": {"coins": 2000, "gems": 20},

		# Level-based rewards (escalating)
		"levels_10": {"coins": 200, "gems": 2},
		"levels_25": {"coins": 500, "gems": 5},
		"levels_50": {"coins": 1000, "gems": 10},
		"levels_100": {"coins": 1500, "gems": 15},
		"levels_250": {"coins": 2500, "gems": 25},
		"levels_500": {"coins": 4000, "gems": 40},

		# Star-based rewards (escalating)
		"stars_10": {"coins": 150, "gems": 2},
		"stars_25": {"coins": 400, "gems": 4},
		"stars_50": {"coins": 800, "gems": 8},
		"stars_100": {"coins": 1200, "gems": 12},
		"stars_250": {"coins": 2000, "gems": 20},
		"stars_500": {"coins": 3500, "gems": 35},

		# Special achievements (high-value)
		"booster_explorer": {"coins": 300, "gems": 5},
		"perfect_streak": {"coins": 500, "gems": 10},
		"combo_master": {"coins": 250, "gems": 3},
		"score_hunter": {"coins": 600, "gems": 8},
		"score_legend": {"coins": 1200, "gems": 20},
		"combo_god": {"coins": 800, "gems": 15},
		"perfect_master": {"coins": 1000, "gems": 20},
		"booster_addict": {"coins": 400, "gems": 8},

		# Weekly challenges (renewable, medium rewards)
		"weekly_matches": {"coins": 200, "gems": 3},
		"weekly_levels": {"coins": 250, "gems": 4},
		"weekly_perfect": {"coins": 300, "gems": 5},
		"weekly_streak": {"coins": 150, "gems": 2},

		# Monthly milestones (high rewards, exclusive)
		"monthly_dedication": {"coins": 500, "gems": 10},
		"monthly_scorer": {"coins": 600, "gems": 12},
		"monthly_collector": {"coins": 400, "gems": 8},

		# Seasonal events (special limited rewards)
		"christmas_spirit": {"coins": 300, "gems": 5},
		"easter_joy": {"coins": 400, "gems": 8},
		"harvest_blessing": {"coins": 350, "gems": 6},
	}

	if achievement_id in rewards:
		return rewards[achievement_id]
	return {"coins": 50, "gems": 1}  # Default reward

# ============================================================================
# WEEKLY/MONTHLY RESET SYSTEM FOR RENEWED ENGAGEMENT
# ============================================================================

func check_weekly_monthly_resets():
	"""Check if we need to reset weekly/monthly achievements"""
	var current_time = Time.get_datetime_dict_from_system()
	var current_week = get_week_of_year(current_time)
	var current_month = current_time["month"]

	# Check for weekly resets (every Monday)
	var last_week_check = get_meta("last_weekly_reset", 0)
	if current_week != last_week_check:
		reset_weekly_achievements()
		set_meta("last_weekly_reset", current_week)
		print("[RewardManager] Weekly achievements reset!")

	# Check for monthly resets (1st of each month)
	var last_month_check = get_meta("last_monthly_reset", 0)
	if current_month != last_month_check:
		reset_monthly_achievements()
		set_meta("last_monthly_reset", current_month)
		print("[RewardManager] Monthly achievements reset!")

func reset_weekly_achievements():
	"""Reset all weekly achievements for new engagement"""
	var weekly_achievements = ["weekly_matches", "weekly_levels", "weekly_perfect", "weekly_streak"]
	for achievement_id in weekly_achievements:
		if achievement_id in achievements_progress:
			achievements_progress[achievement_id]["progress"] = 0
			achievements_progress[achievement_id]["claimed"] = false
	save_progress()

func reset_monthly_achievements():
	"""Reset all monthly achievements for new engagement"""
	var monthly_achievements = ["monthly_dedication", "monthly_scorer", "monthly_collector"]
	for achievement_id in monthly_achievements:
		if achievement_id in achievements_progress:
			achievements_progress[achievement_id]["progress"] = 0
			achievements_progress[achievement_id]["claimed"] = false
	save_progress()

func get_week_of_year(datetime: Dictionary) -> int:
	"""Calculate week of year (1-52)"""
	var day_of_year = get_day_of_year(datetime)
	return int((day_of_year - 1) / 7) + 1

func get_day_of_year(datetime: Dictionary) -> int:
	"""Calculate day of year (1-365/366)"""
	var days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

	# Check for leap year
	var year = datetime["year"]
	if (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0):
		days_in_month[1] = 29

	var day_of_year = datetime["day"]
	for i in range(datetime["month"] - 1):
		day_of_year += days_in_month[i]

	return day_of_year

# ============================================================================
# ENHANCED TRACKING FOR NEW ACHIEVEMENT TYPES
# ============================================================================

func track_weekly_progress(activity_type: String, amount: int = 1):
	"""Track weekly achievement progress"""
	var weekly_mapping = {
		"matches": "weekly_matches",
		"levels": "weekly_levels",
		"perfect": "weekly_perfect",
		"streak": "weekly_streak"
	}

	if activity_type in weekly_mapping:
		var achievement_id = weekly_mapping[activity_type]
		if achievement_id in achievements_progress:
			var achievement = achievements_progress[achievement_id]
			achievement["progress"] = min(achievement["progress"] + amount, achievement["target"])
			print("[RewardManager] Weekly progress: %s (%d/%d)" % [achievement_id, achievement["progress"], achievement["target"]])

func track_monthly_progress(activity_type: String, amount: int = 1):
	"""Track monthly achievement progress"""
	var monthly_mapping = {
		"play_days": "monthly_dedication",
		"score": "monthly_scorer",
		"stars": "monthly_collector"
	}

	if activity_type in monthly_mapping:
		var achievement_id = monthly_mapping[activity_type]
		if achievement_id in achievements_progress:
			var achievement = achievements_progress[achievement_id]
			achievement["progress"] = min(achievement["progress"] + amount, achievement["target"])
			print("[RewardManager] Monthly progress: %s (%d/%d)" % [achievement_id, achievement["progress"], achievement["target"]])

func track_seasonal_progress(season: String, progress_type: String = "participation"):
	"""Track seasonal achievement progress"""
	var current_season = get_current_season()
	if current_season == season:
		var seasonal_achievements = {
			"winter": "christmas_spirit",
			"spring": "easter_joy",
			"autumn": "harvest_blessing"
		}

		if season in seasonal_achievements:
			var achievement_id = seasonal_achievements[season]
			if achievement_id in achievements_progress:
				achievements_progress[achievement_id]["progress"] = 1
				print("[RewardManager] Seasonal progress: %s activated!" % achievement_id)

func get_current_season() -> String:
	"""Determine current season based on date"""
	var current_time = Time.get_datetime_dict_from_system()
	var month = current_time["month"]

	if month in [12, 1, 2]:
		return "winter"
	elif month in [3, 4, 5]:
		return "spring"
	elif month in [6, 7, 8]:
		return "summer"
	else:
		return "autumn"

# Enhanced tracking integration
func track_match_made():
	"""Enhanced match tracking with weekly/monthly progress"""
	total_matches += 1
	_update_achievement_progress("matches_100", total_matches)
	_update_achievement_progress("matches_500", total_matches)
	_update_achievement_progress("matches_1000", total_matches)
	_update_achievement_progress("matches_2500", total_matches)
	_update_achievement_progress("matches_5000", total_matches)
	_update_achievement_progress("matches_10000", total_matches)

	# Track weekly progress
	track_weekly_progress("matches", 1)

	save_progress()

func track_level_completed(level: int, stars: int, score: int):
	"""Enhanced level completion tracking"""
	levels_completed = max(levels_completed, level)
	total_score_earned += score

	# Track stars
	if stars == 3:
		perfect_levels += 1
		_check_perfect_streak()
		# Track weekly perfect levels
		track_weekly_progress("perfect", 1)

	# Update level-based achievements (all tiers)
	_update_achievement_progress("levels_10", levels_completed)
	_update_achievement_progress("levels_25", levels_completed)
	_update_achievement_progress("levels_50", levels_completed)
	_update_achievement_progress("levels_100", levels_completed)
	_update_achievement_progress("levels_250", levels_completed)
	_update_achievement_progress("levels_500", levels_completed)

	# Update star-based achievements (all tiers)
	_update_achievement_progress("stars_10", total_stars)
	_update_achievement_progress("stars_25", total_stars)
	_update_achievement_progress("stars_50", total_stars)
	_update_achievement_progress("stars_100", total_stars)
	_update_achievement_progress("stars_250", total_stars)
	_update_achievement_progress("stars_500", total_stars)

	# Update score achievements
	_update_achievement_progress("score_hunter", total_score_earned)
	_update_achievement_progress("score_legend", total_score_earned)

	# Track weekly/monthly progress
	track_weekly_progress("levels", 1)
	track_monthly_progress("score", score)
	track_monthly_progress("stars", stars)

	save_progress()

func track_combo_reached(combo: int):
	"""Enhanced combo tracking"""
	max_combo_reached = max(max_combo_reached, combo)
	_update_achievement_progress("combo_master", max_combo_reached)
	_update_achievement_progress("combo_god", max_combo_reached)

func track_booster_used(booster_type: String):
	"""Enhanced booster usage tracking"""
	total_boosters_used += 1
	_update_achievement_progress("booster_addict", total_boosters_used)

	# Track different booster types used
	var unique_boosters_used = []
	for key in achievements_progress.keys():
		if "booster_type_" in key:
			if achievements_progress[key]["progress"] > 0:
				unique_boosters_used.append(key)

	# Track this specific booster type
	var booster_key = "booster_type_" + booster_type
	if not booster_key in achievements_progress:
		achievements_progress[booster_key] = {"progress": 0, "target": 1, "claimed": false}
	achievements_progress[booster_key]["progress"] = 1

	# Update booster explorer achievement (use 5 different types)
	_update_achievement_progress("booster_explorer", unique_boosters_used.size())
	save_progress()

# ============================================================================
# PREMIUM STATUS MANAGEMENT
# ============================================================================

func unlock_premium():
	"""Unlock premium status for the player (removes ads, bonus content)"""
	if not is_premium_user:
		is_premium_user = true
		save_progress()
		print("[RewardManager] Premium status unlocked!")
		# TODO: Emit signal or trigger UI update if needed
	else:
		print("[RewardManager] User already has premium status")

func check_premium() -> bool:
	"""Check if player has premium status"""
	return is_premium_user

func revoke_premium():
	"""Revoke premium status (for testing or refunds)"""
	if is_premium_user:
		is_premium_user = false
		save_progress()
		print("[RewardManager] Premium status revoked")
	else:
		print("[RewardManager] User doesn't have premium status")
