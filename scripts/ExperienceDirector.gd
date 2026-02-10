extends Node

## ExperienceDirector
## High-level orchestrator for player journey
## Manages story progression, reward delivery, narrative triggers, and level transitions

signal experience_node_started(node: Dictionary)
signal experience_node_completed(node: Dictionary)
signal experience_flow_complete(flow_id: String)
signal experience_flow_changed(flow_id: String)
signal reward_processing_complete()  # Emitted when a reward node finishes processing

# Components
var state: Node = null  # ExperienceState
var parser: Node = null  # ExperienceFlowParser
var reward_orchestrator: Node = null  # RewardOrchestrator

# Current flow data
var current_flow: Dictionary = {}
var current_node: Dictionary = {}

# State flags
var processing_node: bool = false
var auto_advance: bool = true  # Automatically advance to next node on completion

# Node completion tracking
var waiting_for_level_complete: bool = false
var waiting_for_narrative_complete: bool = false
var waiting_for_ad_complete: bool = false

func _ready():
	print("============================================================")
	print("[ExperienceDirector] *** STARTING INITIALIZATION ***")
	print("============================================================")
	print("[ExperienceDirector] Initializing...")

	# Create components
	_create_components()

	# Connect to EventBus signals
	_connect_events()

	print("============================================================")
	print("[ExperienceDirector] *** READY AND ACTIVE ***")
	print("============================================================")

func _create_components():
	"""Create ExperienceState and ExperienceFlowParser"""

	# Create ExperienceState
	state = Node.new()
	state.name = "ExperienceState"
	state.set_script(preload("res://scripts/ExperienceState.gd"))
	add_child(state)

	# Create ExperienceFlowParser
	parser = Node.new()
	parser.name = "ExperienceFlowParser"
	parser.set_script(preload("res://scripts/ExperienceFlowParser.gd"))
	add_child(parser)

	# Create RewardOrchestrator
	reward_orchestrator = Node.new()
	reward_orchestrator.name = "RewardOrchestrator"
	reward_orchestrator.set_script(preload("res://scripts/RewardOrchestrator.gd"))
	add_child(reward_orchestrator)

	print("[ExperienceDirector] Components created")

func _connect_events():
	"""Connect to EventBus signals for automatic progression"""

	var eb = get_node_or_null("/root/EventBus")
	if not eb:
		print("[ExperienceDirector] WARNING: EventBus not available")
		return

	# Listen to game events safely using has_signal and connect
	if eb.has_signal("level_complete"):
		eb.connect("level_complete", Callable(self, "_on_level_complete"))

	if eb.has_signal("level_failed"):
		eb.connect("level_failed", Callable(self, "_on_level_failed"))

	if eb.has_signal("narrative_stage_complete"):
		eb.connect("narrative_stage_complete", Callable(self, "_on_narrative_stage_complete"))

	print("[ExperienceDirector] Connected to EventBus")

# Phase 12.3: Migration for existing players
func migrate_existing_save_to_experience_state() -> bool:
	"""
	Migrates existing save file to ExperienceState.
	Called on first run to detect and convert legacy progress.
	Returns true if migration was performed.
	"""

	# Check if we've already migrated
	if state.load_from_reward_manager():
		var loaded_flow = state.current_flow_id
		if not loaded_flow.is_empty():
			print("[ExperienceDirector] ExperienceState already initialized - no migration needed")
			return false

	# Check if there's an existing save with progress
	if not RewardManager:
		print("[ExperienceDirector] RewardManager not available - cannot migrate")
		return false

	var levels_completed = RewardManager.levels_completed

	if levels_completed == 0:
		print("[ExperienceDirector] No existing progress found - fresh start")
		return false

	print("=".repeat(60))
	print("[ExperienceDirector] *** MIGRATING EXISTING SAVE ***")
	print("=".repeat(60))
	print("[ExperienceDirector] Found existing progress: %d levels completed" % levels_completed)

	# Load the main_story flow to find where to resume
	if not load_flow("main_story"):
		print("[ExperienceDirector] ERROR: Cannot migrate - main_story flow not found")
		return false

	# Find the level node that corresponds to the next level to play
	var next_level_num = levels_completed + 1
	var resume_index = -1

	for i in range(current_flow.size()):
		var node = current_flow[i]
		if node.get("type") == "level":
			var level_id = node.get("id", "")
			var level_num = _extract_level_number(level_id)
			if level_num == next_level_num:
				resume_index = i
				print("[ExperienceDirector] Found resume point at index %d (level_%02d)" % [i, level_num])
				break

	if resume_index == -1:
		# Player completed all available levels - set to end
		resume_index = current_flow.size() - 1
		print("[ExperienceDirector] Player completed all levels - setting to end of flow")

	# Initialize ExperienceState with the correct position
	state.current_flow_id = "main_story"
	state.current_node_index = resume_index
	state.level_index = levels_completed

	# Mark all previous nodes as completed
	for i in range(resume_index):
		var node = current_flow[i]
		var node_id = node.get("id", "node_%d" % i)
		state.mark_node_completed(node_id)

		# Mark narrative stages as seen
		if node.get("type") == "narrative_stage":
			state.mark_narrative_stage_seen(node_id)

	# Save the migrated state
	state.save_to_reward_manager()

	print("[ExperienceDirector] Migration complete!")
	print("[ExperienceDirector]   Resume index: %d" % resume_index)
	print("[ExperienceDirector]   Level index: %d" % levels_completed)
	print("[ExperienceDirector]   Nodes marked complete: %d" % resume_index)
	print("=".repeat(60))

	return true

# Flow management
func load_flow(flow_id: String) -> bool:
	"""Load an experience flow by ID"""

	var flow_path = "res://data/experience_flows/%s.json" % flow_id

	print("[ExperienceDirector] Loading flow: ", flow_id, " from ", flow_path)

	current_flow = parser.parse_flow_file(flow_path)

	if current_flow.is_empty():
		print("[ExperienceDirector] ERROR: Failed to load flow: ", flow_id)
		return false

	# Update state
	state.set_flow(flow_id)

	# Debug: Print flow summary
	parser.print_flow_summary(current_flow)

	emit_signal("experience_flow_changed", flow_id)
	print("[ExperienceDirector] Flow loaded: ", flow_id)

	return true

func reset_flow():
	"""Reset the current flow to start from the beginning"""
	print("[ExperienceDirector] Resetting flow to beginning")

	# Reset waiting flags
	waiting_for_level_complete = false
	waiting_for_narrative_complete = false

	# Reset processing flag - CRITICAL for restart!
	processing_node = false

	# Reset state to beginning of current flow
	if not state.current_flow_id.is_empty():
		state.current_level_index = 0
		print("[ExperienceDirector] Flow reset to index 0, ready for restart")
	else:
		print("[ExperienceDirector] WARNING: No flow loaded to reset")

func start_flow():
	"""Start the current flow from the beginning or resume from saved position"""

	print("============================================================")
	print("[ExperienceDirector] *** START_FLOW CALLED ***")
	print("============================================================")

	if current_flow.is_empty():
		print("[ExperienceDirector] ERROR: No flow loaded")
		return

	print("[ExperienceDirector] Starting flow at index: ", state.current_level_index)
	print("[ExperienceDirector] Current flow ID: ", state.current_flow_id)
	print("[ExperienceDirector] Total nodes in flow: ", parser.get_flow_length(current_flow))

	# Process current node
	print("[ExperienceDirector] About to call _process_current_node()...")
	_process_current_node()
	print("[ExperienceDirector] Returned from _process_current_node()")

func get_next_node_rewards() -> Dictionary:
	"""Get reward info from the next node if it's a reward node, otherwise return empty"""

	if current_flow.is_empty():
		return {}

	var flow_data = current_flow.get("flow", [])
	var next_index = state.current_level_index + 1

	if next_index >= flow_data.size():
		return {}

	var next_node = flow_data[next_index]
	if next_node.get("type") != "reward":
		return {}

	# It's a reward node! Return the rewards info
	return {
		"has_rewards": true,
		"rewards": next_node.get("rewards", []),
		"reward_id": next_node.get("id", "unknown")
	}

func start_flow_at_level(level_num: int):
	"""Start the flow at a specific level number (for world map selection)"""

	print("============================================================")
	print("[ExperienceDirector] *** START_FLOW_AT_LEVEL CALLED ***")
	print("[ExperienceDirector] Target level: ", level_num)
	print("============================================================")

	if current_flow.is_empty():
		print("[ExperienceDirector] ERROR: No flow loaded")
		return

	# Find the node index for this level
	var level_id = "level_%02d" % level_num  # Format as level_01, level_02, etc.
	var target_index = -1

	var flow_data = current_flow.get("flow", [])
	for i in range(flow_data.size()):
		var node = flow_data[i]
		if node.get("type") == "level" and node.get("id") == level_id:
			target_index = i
			break

	if target_index >= 0:
		print("[ExperienceDirector] Found level ", level_id, " at index ", target_index)

		# Check if there's a narrative_stage immediately before this level
		# If so, start from the narrative instead to give full context
		var start_index = target_index
		if target_index > 0:
			var previous_node = flow_data[target_index - 1]
			if previous_node.get("type") == "narrative_stage":
				start_index = target_index - 1
				print("[ExperienceDirector] Found narrative_stage before level at index ", start_index)
				print("[ExperienceDirector] Will start from narrative: ", previous_node.get("id"))

		# CRITICAL: Reset processing_node flag to allow the new level to load
		# This is intentional - we're interrupting the current flow to jump to a new level
		if processing_node:
			print("[ExperienceDirector] Resetting processing_node flag (was: true)")
		processing_node = false

		# Reset wait flags to ensure we're not stuck waiting for a previous node
		waiting_for_level_complete = false
		waiting_for_narrative_complete = false

		state.current_level_index = start_index
		print("[ExperienceDirector] Starting flow from index: ", state.current_level_index)
		_process_current_node()
	else:
		print("[ExperienceDirector] WARNING: Level ", level_id, " not found in flow")
		print("[ExperienceDirector] Available level nodes:")
		for i in range(flow_data.size()):
			var node = flow_data[i]
			if node.get("type") == "level":
				print("  [", i, "] ", node.get("id"))
		print("[ExperienceDirector] Falling back to start of flow")
		start_flow()

func advance_to_next_node():
	"""Move to the next node in the flow"""

	print("============================================================")
	print("[ExperienceDirector] *** ADVANCE TO NEXT NODE ***")
	print("============================================================")

	if current_flow.is_empty():
		print("[ExperienceDirector] ERROR: No flow loaded")
		return

	# Safety check: if we're still processing, this is likely a bug
	if processing_node:
		print("[ExperienceDirector] WARNING: Still processing previous node when advance_to_next_node called")
		print("[ExperienceDirector] Current node: ", parser.node_to_string(current_node) if not current_node.is_empty() else "none")
		print("[ExperienceDirector] Forcing processing_node = false to recover")
		processing_node = false

	var flow_length = parser.get_flow_length(current_flow)
	print("[ExperienceDirector] Current index: ", state.current_level_index)
	print("[ExperienceDirector] Flow length: ", flow_length)

	# Check if we've reached the end
	if state.current_level_index >= flow_length - 1:
		print("[ExperienceDirector] Flow complete!")
		emit_signal("experience_flow_complete", current_flow.get("experience_id", "unknown"))
		return

	# Advance index
	print("[ExperienceDirector] Advancing from index ", state.current_level_index, "...")
	state.advance_level_index()
	print("[ExperienceDirector] New index: ", state.current_level_index)

	# Process next node
	print("[ExperienceDirector] Processing next node...")
	_process_current_node()

func _process_current_node():
	"""Process the current node based on its type"""

	print("============================================================")
	print("[ExperienceDirector] *** PROCESSING CURRENT NODE ***")
	print("============================================================")

	if processing_node:
		print("[ExperienceDirector] ERROR: Already processing a node - aborting to prevent infinite loop")
		print("[ExperienceDirector] Current node: ", parser.node_to_string(current_node) if not current_node.is_empty() else "none")
		print("[ExperienceDirector] This indicates a logic error - node should complete before processing next")
		return

	print("[ExperienceDirector] Getting node at index: ", state.current_level_index)
	current_node = parser.get_node_at_index(current_flow, state.current_level_index)

	if current_node.is_empty():
		print("[ExperienceDirector] ERROR: Invalid node at index: ", state.current_level_index)
		return

	processing_node = true

	print("[ExperienceDirector] Processing node [%d]: %s" % [state.current_level_index, parser.node_to_string(current_node)])
	print("[ExperienceDirector] Node data: ", JSON.stringify(current_node, "\t"))

	emit_signal("experience_node_started", current_node)

	# Process based on type
	var node_type = parser.get_node_type(current_node)
	print("[ExperienceDirector] Node type: ", node_type)

	match node_type:
		"level":
			print("[ExperienceDirector] → Calling _process_level_node()")
			_process_level_node(current_node)
		"narrative_stage":
			print("[ExperienceDirector] → Calling _process_narrative_stage_node()")
			_process_narrative_stage_node(current_node)
		"reward":
			print("[ExperienceDirector] → Calling _process_reward_node()")
			_process_reward_node(current_node)
		"cutscene":
			print("[ExperienceDirector] → Calling _process_cutscene_node()")
			_process_cutscene_node(current_node)
		"unlock":
			_process_unlock_node(current_node)
		"ad_reward":
			_process_ad_reward_node(current_node)
		"premium_gate":
			_process_premium_gate_node(current_node)
		"dlc_flow":
			_process_dlc_flow_node(current_node)
		"conditional":
			_process_conditional_node(current_node)
		_:
			print("[ExperienceDirector] ERROR: Unknown node type: ", node_type)
			_complete_current_node()

# Node processors
func _process_level_node(node: Dictionary):
	"""Process a level node"""

	var level_id = node.get("id", "")
	print("[ExperienceDirector] Triggering level: ", level_id)

	# Extract level number from ID (e.g., "level_01" -> 1)
	var level_num = _extract_level_number(level_id)

	if level_num > 0:
		# Set flag to wait for level completion
		waiting_for_level_complete = true

		# Trigger level load via GameUI
		var game_ui = get_node_or_null("/root/MainGame/GameUI")
		if game_ui and game_ui.has_method("_load_level_by_number"):
			print("[ExperienceDirector] Loading level %d via GameUI" % level_num)
			# Call the level loader directly - it's async so will handle everything
			game_ui._load_level_by_number(level_num)
		elif GameManager:
			# Fallback: set level number (old behavior)
			print("[ExperienceDirector] WARNING: GameUI not available, using fallback")
			GameManager.level = level_num
		else:
			print("[ExperienceDirector] ERROR: Cannot load level - no GameUI or GameManager")
			_complete_current_node()
	else:
		print("[ExperienceDirector] ERROR: Invalid level ID: ", level_id)
		_complete_current_node()

func _process_narrative_stage_node(node: Dictionary):
	"""Process a narrative stage node"""

	var stage_id = node.get("id", "")
	var auto_advance_delay = node.get("auto_advance_delay", 3.0)  # Default 3 seconds
	var skippable = node.get("skippable", true)  # Allow skip by default

	print("[ExperienceDirector] Triggering narrative stage: ", stage_id)
	print("[ExperienceDirector]   Auto-advance delay: ", auto_advance_delay, "s")
	print("[ExperienceDirector]   Skippable: ", skippable)

	# Set flag to wait for narrative completion
	waiting_for_narrative_complete = true

	# Trigger narrative stage via NarrativeStageManager
	var narrative_manager = get_node_or_null("/root/NarrativeStageManager")
	if narrative_manager and narrative_manager.has_method("load_stage_by_id"):
		if narrative_manager.load_stage_by_id(stage_id):
			# Mark as seen in state
			state.mark_narrative_stage_seen(stage_id)
			print("[ExperienceDirector] Narrative stage loaded successfully")

			# If auto-advance is enabled, set a timer
			if auto_advance_delay > 0:
				print("[ExperienceDirector] Setting auto-advance timer for ", auto_advance_delay, "s")
				await get_tree().create_timer(auto_advance_delay).timeout

				# Check if still waiting (user might have skipped)
				if waiting_for_narrative_complete:
					print("[ExperienceDirector] Auto-advancing from narrative stage")
					waiting_for_narrative_complete = false
					_complete_current_node()
		else:
			print("[ExperienceDirector] WARNING: Failed to load narrative stage: ", stage_id)
			print("[ExperienceDirector] Skipping missing narrative stage")
			_complete_current_node()
	else:
		print("[ExperienceDirector] ERROR: NarrativeStageManager not available")
		_complete_current_node()

func _process_reward_node(node: Dictionary):
	"""Process a reward node"""

	print("============================================================")
	print("[ExperienceDirector] *** PROCESSING REWARD NODE ***")
	print("============================================================")

	var reward_id = node.get("id", "")
	print("[ExperienceDirector] Granting reward: ", reward_id)
	print("[ExperienceDirector] Reward data: ", JSON.stringify(node, "\t"))

	# Check if already unlocked
	if state.is_reward_unlocked(reward_id):
		print("[ExperienceDirector] Reward already unlocked: ", reward_id)
		_complete_current_node()
		return

	# Mark as unlocked
	state.unlock_reward(reward_id)
	print("[ExperienceDirector] Reward marked as unlocked in state")

	# Grant rewards directly WITHOUT showing notification popup
	# (Rewards are displayed on the transition screen instead)
	var rewards_list = node.get("rewards", [])
	print("[ExperienceDirector] Granting %d reward(s) directly (no popup)" % rewards_list.size())

	for reward in rewards_list:
		var reward_type = reward.get("type", "")
		var amount = reward.get("amount", 0)

		match reward_type:
			"coins":
				if RewardManager:
					RewardManager.add_coins(amount)
					print("[ExperienceDirector] Granted %d coins" % amount)
			"gems":
				if RewardManager:
					RewardManager.add_gems(amount)
					print("[ExperienceDirector] Granted %d gems" % amount)
			"booster":
				var booster_type = reward.get("booster_type", "")
				if RewardManager and RewardManager.has_method("add_booster"):
					RewardManager.add_booster(booster_type, amount)
					print("[ExperienceDirector] Granted %d x %s booster" % [amount, booster_type])
			"card":
				var collection_id = reward.get("collection_id", "")
				var card_id = reward.get("card_id", "")
				if CollectionManager and not collection_id.is_empty() and not card_id.is_empty():
					var unlocked = CollectionManager.unlock_item(collection_id, card_id)
					if unlocked:
						print("[ExperienceDirector] ✅ Unlocked card: %s/%s" % [collection_id, card_id])
					else:
						print("[ExperienceDirector] Card already unlocked or not found: %s/%s" % [collection_id, card_id])
				else:
					print("[ExperienceDirector] ⚠️ Card reward missing collection_id or card_id")
			"gallery_image":
				# Keep existing gallery_image handling
				var image_name = reward.get("image_name", "")
				print("[ExperienceDirector] Gallery image unlock: %s" % image_name)
			"theme":
				# Keep existing theme handling
				var theme_name = reward.get("theme_name", "")
				print("[ExperienceDirector] Theme unlock: %s" % theme_name)
			"video":
				# Video unlock handling
				var video_name = reward.get("video_name", "")
				print("[ExperienceDirector] Video unlock: %s" % video_name)
			_:
				print("[ExperienceDirector] Unknown reward type: ", reward_type)

	print("[ExperienceDirector] Completing reward node")

	# Emit signal that reward processing is complete
	emit_signal("reward_processing_complete")
	print("[ExperienceDirector] Emitted reward_processing_complete signal")

	_complete_current_node()

func _process_cutscene_node(node: Dictionary):
	"""Process a cutscene node"""

	var cutscene_id = node.get("id", "")
	print("[ExperienceDirector] Playing cutscene: ", cutscene_id)

	# Use CutsceneExecutor if available
	var executor = CutsceneExecutor.new()
	add_child(executor)  # CRITICAL: Must add to tree for await to work

	var context = {
		"params": node.get("params", {})
	}

	# Run executor asynchronously and wait for completion
	await executor.execute(context)

	# Clean up executor
	if is_instance_valid(executor):
		remove_child(executor)
		executor.queue_free()

	_complete_current_node()

func _evaluate_condition(condition: Dictionary) -> bool:
	"""Evaluate a simple condition dictionary.

	Supported conditions:
	- has_seen_narrative: {"has_seen_narrative": "stage_id"}
	- reward_unlocked: {"reward_unlocked": "reward_id"}
	- state_flag: {"state_flag": "flag_name", "value": true}
	- custom: placeholder for future custom checks
	"""
	if condition is Dictionary:
		# has_seen_narrative
		if condition.has("has_seen_narrative"):
			var stage_id = condition.get("has_seen_narrative", "")
			if stage_id == "":
				return false
			return state.has_seen_narrative_stage(stage_id)

		# reward_unlocked
		if condition.has("reward_unlocked"):
			var reward_id = condition.get("reward_unlocked", "")
			if reward_id == "":
				return false
			return state.is_reward_unlocked(reward_id)

		# state_flag (generic) - check for boolean flags on state
		if condition.has("state_flag"):
			var flag_name = condition.get("state_flag", "")
			var desired = condition.get("value", true)
			# allow checking known flags: auto_advance, waiting_for_level_complete
			if flag_name == "auto_advance":
				return auto_advance == desired
			if flag_name == "waiting_for_level_complete":
				return waiting_for_level_complete == desired
			# Unknown flags return false for safety
			return false

		# custom checks - always false for now
		if condition.has("custom"):
			return false

	# Unknown condition type
	return false

func _process_conditional_node(node: Dictionary):
	"""Process a conditional node with 'condition', 'then' and optional 'else' branches"""

	var condition = node.get("condition", {})
	var then_branch = node.get("then", null)
	var else_branch = node.get("else", null)

	print("[ExperienceDirector] Evaluating conditional node")

	var result = _evaluate_condition(condition)
	print("[ExperienceDirector] Condition result: ", result)

	# If result true, insert 'then' branch nodes after current index else insert 'else' branch
	var branch = then_branch if result else else_branch

	if branch == null:
		print("[ExperienceDirector] No branch to execute - completing node")
		_complete_current_node()
		return

	# Branch can be a single node or an array of nodes
	var branch_nodes = []
	if typeof(branch) == TYPE_ARRAY:
		branch_nodes = branch
	elif typeof(branch) == TYPE_DICTIONARY:
		branch_nodes = [branch]
	else:
		print("[ExperienceDirector] Invalid branch type, skipping")
		_complete_current_node()
		return

	# Insert branch nodes into current_flow after current index
	var insert_index = state.current_level_index + 1
	for i in range(branch_nodes.size()):
		current_flow["flow"].insert(insert_index + i, branch_nodes[i])

	print("[ExperienceDirector] Inserted %d branch node(s) at index %d" % [branch_nodes.size(), insert_index])

	# Complete the conditional node and continue (which will process inserted nodes next)
	_complete_current_node()
# Node completion
func _complete_current_node():
	"""Mark current node as complete and advance if auto_advance is enabled"""

	print("============================================================")
	print("[ExperienceDirector] *** COMPLETING CURRENT NODE ***")
	print("============================================================")

	if not processing_node:
		print("[ExperienceDirector] WARNING: Not currently processing a node")
		return

	processing_node = false

	# Mark node as completed in state
	var node_id = parser.get_node_id(current_node)
	if not node_id.is_empty():
		state.mark_node_completed(node_id)
		print("[ExperienceDirector] Marked node as completed: ", node_id)

	emit_signal("experience_node_completed", current_node)

	print("[ExperienceDirector] Node completed: ", parser.node_to_string(current_node))
	print("[ExperienceDirector] auto_advance: ", auto_advance)

	# Prevent auto-advance ONLY for level nodes
	# Level nodes need to wait for user to click Continue on transition screen
	var node_type = parser.get_node_type(current_node)

	if node_type == "level":
		print("[ExperienceDirector] Level node completed - NOT auto-advancing (waiting for user Continue)")
		return

	# Reward nodes SHOULD auto-advance because:
	# - User already clicked Continue on the transition screen
	# - Rewards are granted silently (no popup)
	# - Need to proceed to next level immediately
	if node_type == "reward":
		print("[ExperienceDirector] Reward node completed - auto-advancing to next node")
		# Don't return - let it continue to auto-advance below

	# Auto-advance for reward nodes and other node types (narrative, etc.)
	if auto_advance:
		print("[ExperienceDirector] Auto-advance enabled - advancing immediately...")
		advance_to_next_node()
	else:
		print("[ExperienceDirector] Auto-advance disabled - waiting for manual advance")

# State persistence (called by RewardManager)
func get_state_data() -> Dictionary:
	"""Get state data for saving"""
	if state:
		return state.to_dict()
	return {}

func load_state_data(data: Dictionary):
	"""Load state data from save file"""
	if state:
		state.from_dict(data)

		# Reload current flow
		if not state.current_flow_id.is_empty():
			load_flow(state.current_flow_id)

# Utility methods
func _extract_level_number(level_id: String) -> int:
	"""Extract level number from level ID (e.g., 'level_001' -> 1)"""

	# Try to extract number from various formats
	# Format: "level_001", "level_1", "001", "1"

	var num_str = level_id.replace("level_", "").replace("level", "")
	return int(num_str)

# Debug methods
func print_current_state():
	"""Print current director state for debugging"""
	print("=== Experience Director State ===")
	print("  Current Flow: ", current_flow.get("experience_id", "none"))
	print("  Current Index: ", state.current_level_index if state else 0)
	print("  Processing Node: ", processing_node)
	print("  Waiting for Level: ", waiting_for_level_complete)
	print("  Waiting for Narrative: ", waiting_for_narrative_complete)
	print("  Auto Advance: ", auto_advance)
	if state:
		state.print_state()
	print("=================================")

func debug_skip_to_level(level_num: int):
	"""DEBUG: Skip directly to a specific level (bypasses flow)"""
	print("[DEBUG] Skipping to level ", level_num)
	start_flow_at_level(level_num)

func debug_unlock_all_cards():
	"""DEBUG: Unlock all cards in all collections"""
	print("[DEBUG] Unlocking all cards...")
	for collection_id in CollectionManager.get_all_collections():
		var collection = CollectionManager.get_collection_data(collection_id)
		var items = collection.get("items", [])
		for item in items:
			CollectionManager.unlock_item(collection_id, item.get("id", ""))
	print("[DEBUG] All cards unlocked!")

func debug_reset_progress():
	"""DEBUG: Reset all experience progress"""
	print("[DEBUG] Resetting all progress...")
	if state:
		state.current_level_index = 0
		state.completed_experience_nodes.clear()
		state.unlocked_rewards.clear()
		state.seen_narrative_stages.clear()
	reset_flow()
	print("[DEBUG] Progress reset!")

func debug_info():
	"""DEBUG: Print useful debug information"""
	print("\n" + "=".repeat(60))
	print("EXPERIENCE DIRECTOR DEBUG INFO")
	print("=".repeat(60))

	# Flow info
	print("\n[CURRENT FLOW]")
	print("  ID: ", current_flow.get("experience_id", "none"))
	print("  Name: ", current_flow.get("name", "none"))
	var flow_data = current_flow.get("flow", [])
	print("  Total Nodes: ", flow_data.size())
	print("  Current Index: ", state.current_level_index if state else 0)

	# Current node
	print("\n[CURRENT NODE]")
	if not current_node.is_empty():
		print("  Type: ", parser.get_node_type(current_node))
		print("  ID: ", parser.get_node_id(current_node))
		print("  Processing: ", processing_node)
	else:
		print("  No current node")

	# State flags
	print("\n[STATE FLAGS]")
	print("  Waiting for Level: ", waiting_for_level_complete)
	print("  Waiting for Narrative: ", waiting_for_narrative_complete)
	print("  Auto Advance: ", auto_advance)

	# Progress
	if state:
		print("\n[PROGRESS]")
		print("  Completed Nodes: ", state.completed_experience_nodes.size())
		print("  Unlocked Rewards: ", state.unlocked_rewards.size())
		print("  Seen Narratives: ", state.seen_narrative_stages.size())

	# Collections
	print("\n[COLLECTIONS]")
	var total_progress = CollectionManager.get_total_progress()
	print("  Total Collections: ", total_progress.total_collections)
	print("  Items Unlocked: ", total_progress.total_unlocked, "/", total_progress.total_items)
	print("  Completion: ", "%.1f%%" % total_progress.completion_percentage)

	print("\n" + "=".repeat(60) + "\n")

func _process_unlock_node(node: Dictionary):
	"""Process an unlock node (basic implementation)."""
	var unlock_id = node.get("id", "")
	print("[ExperienceDirector] Processing unlock: ", unlock_id)
	# Example: unlock a theme or feature - placeholder
	# If integrating with ThemeManager or RewardManager, call necessary APIs
	_complete_current_node()

func _process_ad_reward_node(node: Dictionary):
	"""Process an ad reward node - shows ad and grants reward on completion (basic)."""
	print("[ExperienceDirector] Processing ad_reward node: ", JSON.stringify(node, "\t"))

	var ad_id = node.get("id", "")
	var ad_type = node.get("ad_type", "rewarded")
	var reward_data = node.get("reward", {})
	var required = node.get("required", false)

	# If AdMobManager isn't available, just skip
	var admob_manager = get_node_or_null("/root/AdMobManager")
	if not admob_manager:
		print("[ExperienceDirector] AdMobManager not available - skipping ad node")
		_complete_current_node()
		return

	waiting_for_ad_complete = true

	if ad_type == "rewarded":
		if not admob_manager.rewarded_ad_closed.is_connected(Callable(self, "_on_ad_closed")):
			admob_manager.rewarded_ad_closed.connect(Callable(self, "_on_ad_closed"), CONNECT_ONE_SHOT)
		if reward_data and not reward_data.is_empty():
			if not admob_manager.user_earned_reward.is_connected(Callable(self, "_on_ad_reward_earned")):
				admob_manager.user_earned_reward.connect(Callable(self, "_on_ad_reward_earned"), CONNECT_ONE_SHOT)
		print("[ExperienceDirector] Showing rewarded ad...")
		admob_manager.show_rewarded_ad()
	else:
		if not admob_manager.interstitial_ad_closed.is_connected(Callable(self, "_on_ad_closed")):
			admob_manager.interstitial_ad_closed.connect(Callable(self, "_on_ad_closed"), CONNECT_ONE_SHOT)
		print("[ExperienceDirector] Showing interstitial ad...")
		admob_manager.show_interstitial_ad()

func _on_ad_closed():
	"""Called when ad is closed (for both rewarded and interstitial)"""
	print("[ExperienceDirector] Ad closed")

	if waiting_for_ad_complete:
		waiting_for_ad_complete = false
		_complete_current_node()

func _on_ad_reward_earned(reward_type: String, reward_amount: int):
	"""Called when user earns reward from watching ad"""
	print("[ExperienceDirector] Ad reward earned: ", reward_type, " x", reward_amount)

	# Grant the reward specified in the node
	var reward_data = current_node.get("reward", {})
	if not reward_data.is_empty():
		var type = reward_data.get("type", "")
		var amount = reward_data.get("amount", 0)

		match type:
			"coins":
				if RewardManager:
					RewardManager.add_coins(amount)
					print("[ExperienceDirector] Granted %d coins from ad" % amount)
			"gems":
				if RewardManager:
					RewardManager.add_gems(amount)
					print("[ExperienceDirector] Granted %d gems from ad" % amount)
			"booster":
				var booster_type = reward_data.get("booster_type", "")
				if RewardManager and not booster_type.is_empty():
					RewardManager.add_booster(booster_type, amount)
					print("[ExperienceDirector] Granted %d x %s from ad" % [amount, booster_type])
			_:
				print("[ExperienceDirector] Unknown reward type: ", type)

func _process_premium_gate_node(node: Dictionary):
	"""Process a premium gate node - checks if user has premium access (basic)."""
	var gate_id = node.get("id", "")
	var required_status = node.get("required_status", "premium")
	var on_fail = node.get("on_fail", "skip")

	print("[ExperienceDirector] Processing premium gate: ", gate_id)

	var has_premium = false
	if RewardManager and RewardManager.has_method("check_premium"):
		has_premium = RewardManager.check_premium()

	if required_status == "premium" and has_premium:
		print("[ExperienceDirector] Premium gate passed")
		_complete_current_node()
	elif required_status == "free" and not has_premium:
		print("[ExperienceDirector] Free gate passed")
		_complete_current_node()
	else:
		print("[ExperienceDirector] Premium gate failed - behavior: ", on_fail)
		match on_fail:
			"skip":
				advance_to_next_node()
			"block":
				processing_node = false
				# optionally display UI
			"offer":
				# TODO: show offer UI
				_complete_current_node()
			_:
				advance_to_next_node()

func _process_dlc_flow_node(node: Dictionary):
	"""Process a DLC flow node - basic fallback behavior."""
	var dlc_flow_id = node.get("id", "")
	var required = node.get("required", false)
	print("[ExperienceDirector] Processing DLC flow: ", dlc_flow_id)

	var dlc_path = "res://data/experience_flows/%s.json" % dlc_flow_id
	if FileAccess.file_exists(dlc_path):
		# Push and load new DLC flow
		state.push_flow(dlc_flow_id)
		load_flow(dlc_flow_id)
		start_flow()
	else:
		print("[ExperienceDirector] DLC flow not found: ", dlc_flow_id)
		if required:
			print("[ExperienceDirector] ERROR: Required DLC missing")
		# Continue
		_complete_current_node()
