extends Node

## Star Rating Manager
## Calculates and tracks star ratings for levels (1-3 stars)

## Star Rating Criteria:
## 1 Star: Complete the level (reach target score)
## 2 Stars: Score >= target * 1.5 (50% above target)
## 3 Stars: Score >= target * 2.0 (100% above target) OR use <= 50% of moves

## Calculate star rating based on performance
static func calculate_stars(score: int, target_score: int, moves_used: int, total_moves: int) -> int:
	if score < target_score:
		return 0  # Level failed

	# 3 stars criteria
	if score >= target_score * 2.0:
		return 3  # Doubled the target score!

	if moves_used <= total_moves * 0.5:
		return 3  # Used 50% or less moves - efficient!

	# 2 stars criteria
	if score >= target_score * 1.5:
		return 2  # 50% above target

	# 1 star - completed the level
	return 1

## Get star rating for a specific level from save data
static func get_level_stars(level_number: int) -> int:
	var level_key = "level_%d" % level_number
	if RewardManager.level_stars.has(level_key):
		return RewardManager.level_stars[level_key]
	return 0

## Save star rating for a level (only if better than previous)
static func save_level_stars(level_number: int, stars: int) -> void:
	var level_key = "level_%d" % level_number
	var current_stars = get_level_stars(level_number)

	# Only save if new rating is better
	if stars > current_stars:
		RewardManager.level_stars[level_key] = stars
		RewardManager.save_progress()
		print("[StarRating] Level %d: New best rating %d stars (was %d)" % [level_number, stars, current_stars])
	else:
		print("[StarRating] Level %d: Rating %d stars (keeping best: %d)" % [level_number, stars, current_stars])

## Get total stars collected across all levels
static func get_total_stars() -> int:
	var total = 0
	for level_key in RewardManager.level_stars.keys():
		total += RewardManager.level_stars[level_key]
	return total

## Get stars for a specific chapter (levels in a range)
static func get_chapter_stars(start_level: int, end_level: int) -> int:
	var total = 0
	for level in range(start_level, end_level + 1):
		total += get_level_stars(level)
	return total

## Get max possible stars for a level range
static func get_max_stars(start_level: int, end_level: int) -> int:
	return (end_level - start_level + 1) * 3

## Check if a level has been completed (has at least 1 star)
static func is_level_completed(level_number: int) -> bool:
	return get_level_stars(level_number) > 0

## Get star color for display
static func get_star_color(star_index: int, earned_stars: int) -> Color:
	if star_index <= earned_stars:
		return Color(1.0, 0.9, 0.2)  # Gold for earned stars
	else:
		return Color(0.3, 0.3, 0.3, 0.5)  # Grey for unearned stars

## Get reward multiplier based on stars (for coins/gems)
static func get_reward_multiplier(stars: int) -> float:
	match stars:
		3:
			return 2.0  # Double rewards for 3 stars
		2:
			return 1.5  # 50% bonus for 2 stars
		1:
			return 1.0  # Base rewards for 1 star
		_:
			return 0.5  # Half rewards if failed (for retry bonus)

