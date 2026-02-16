extends RefCounted
class_name ContainerSelectionRules

## Container Selection Rules Evaluator
## Data-driven rule evaluation for selecting reward containers
## Keeps logic separate from data (follows ARCHITECTURE_GUARDRAILS)

static var _rules: Dictionary = {}
static var _rules_loaded: bool = false

const RULES_PATH = "res://data/container_selection_rules.json"

## Evaluate rules and return container ID
static func get_container_for_context(level: int, coins: int, gems: int, stars: int) -> String:
	"""
	Evaluate container selection rules based on level completion context
	Returns: Container ID, or empty string if no rules match
	"""
	# Load rules if needed
	if not _rules_loaded:
		_load_rules()

	# Check if rules are disabled
	var rules_list = _rules.get("rules", [])
	if rules_list.is_empty():
		return ""  # No rules, use fallback

	# Evaluate each rule in order
	for rule in rules_list:
		if not rule.get("enabled", false):
			continue  # Skip disabled rules

		if _evaluate_condition(rule.get("condition", {}), level, coins, gems, stars):
			var container_id = rule.get("container", "")
			print("[ContainerSelectionRules] Rule '%s' matched → %s" % [rule.get("id"), container_id])
			return container_id

	# No rules matched
	return ""

## Load rules from JSON
static func _load_rules():
	"""Load container selection rules from JSON file"""
	_rules_loaded = true

	if not FileAccess.file_exists(RULES_PATH):
		print("[ContainerSelectionRules] No rules file found at %s" % RULES_PATH)
		return

	var file = FileAccess.open(RULES_PATH, FileAccess.READ)
	if not file:
		push_error("[ContainerSelectionRules] Failed to open rules file")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		push_error("[ContainerSelectionRules] JSON parse error: %s" % json.get_error_message())
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("[ContainerSelectionRules] Invalid rules format")
		return

	_rules = json.data
	var rules_count = _rules.get("rules", []).size()
	var enabled_count = 0
	for rule in _rules.get("rules", []):
		if rule.get("enabled", false):
			enabled_count += 1

	print("[ContainerSelectionRules] Loaded %d rules (%d enabled)" % [rules_count, enabled_count])

## Evaluate a single condition
static func _evaluate_condition(condition: Dictionary, level: int, coins: int, gems: int, stars: int) -> bool:
	"""
	Evaluate a condition against the context
	Pure data evaluation - no game logic
	"""
	var condition_type = condition.get("type", "")

	match condition_type:
		"level_modulo":
			var divisor = condition.get("divisor", 1)
			var remainder = condition.get("remainder", 0)
			return (level % divisor) == remainder

		"level_in_list":
			var levels = condition.get("levels", [])
			return level in levels

		"level_range":
			var min_level = condition.get("min", 0)
			var max_level = condition.get("max", 999999)
			return level >= min_level and level <= max_level

		"coins_earned":
			var min_coins = condition.get("min", 0)
			var max_coins = condition.get("max", 999999)
			return coins >= min_coins and coins <= max_coins

		"gems_earned":
			var min_gems = condition.get("min", 0)
			var max_gems = condition.get("max", 999999)
			return gems >= min_gems and gems <= max_gems

		"stars_earned":
			var min_stars = condition.get("min", 0)
			var max_stars = condition.get("max", 3)
			return stars >= min_stars and stars <= max_stars

		"total_value":
			# Coins + (gems * multiplier)
			var multiplier = condition.get("gem_multiplier", 100)
			var total = coins + (gems * multiplier)
			var min_value = condition.get("min", 0)
			var max_value = condition.get("max", 999999)
			return total >= min_value and total <= max_value

		_:
			push_warning("[ContainerSelectionRules] Unknown condition type: %s" % condition_type)
			return false

## Reload rules (for testing/development)
static func reload_rules():
	"""Force reload of rules from file"""
	_rules_loaded = false
	_rules.clear()
	_load_rules()
