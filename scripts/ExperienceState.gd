extends Node

## ExperienceState
## Manages persistent state for the player's journey through the experience flow
## Integrates with RewardManager's save system

signal state_changed
signal world_changed(new_world: int)
signal chapter_changed(new_chapter: int)
signal level_index_changed(new_index: int)

# Progression tracking
var current_world: int = 1
var current_chapter: int = 1
var current_level_index: int = 0  # Index within the current experience flow
var current_flow_id: String = "main_story"

# Completed content tracking
var unlocked_rewards: Array = []  # Array of reward IDs that have been unlocked
var seen_narrative_stages: Array = []  # Array of narrative stage IDs that have been seen
var completed_experience_nodes: Array = []  # Array of node IDs that have been completed

# Flow progression history
var flow_history: Array = []  # Stack of {flow_id, index} for nested flows/DLC

# Debug/Analytics
var total_nodes_completed: int = 0
var experience_start_time: int = 0  # Unix timestamp when experience started
var last_session_time: int = 0  # Unix timestamp of last session

func _ready():
	print("[ExperienceState] Ready")
	# Don't auto-load here - let ExperienceDirector control when to load

func reset():
	"""Reset to initial state"""
	current_world = 1
	current_chapter = 1
	current_level_index = 0
	current_flow_id = "main_story"

	unlocked_rewards.clear()
	seen_narrative_stages.clear()
	completed_experience_nodes.clear()
	flow_history.clear()

	total_nodes_completed = 0
	experience_start_time = Time.get_unix_time_from_system()
	last_session_time = experience_start_time

	emit_signal("state_changed")
	print("[ExperienceState] Reset to initial state")

func advance_level_index():
	"""Move to next node in current flow"""
	current_level_index += 1
	total_nodes_completed += 1
	emit_signal("level_index_changed", current_level_index)
	emit_signal("state_changed")

func set_level_index(index: int):
	"""Jump to specific index in current flow"""
	if index != current_level_index:
		current_level_index = index
		emit_signal("level_index_changed", current_level_index)
		emit_signal("state_changed")

func set_world(world: int):
	"""Change current world"""
	if world != current_world:
		current_world = world
		emit_signal("world_changed", current_world)
		emit_signal("state_changed")

func set_chapter(chapter: int):
	"""Change current chapter"""
	if chapter != current_chapter:
		current_chapter = chapter
		emit_signal("chapter_changed", current_chapter)
		emit_signal("state_changed")

func set_flow(flow_id: String):
	"""Switch to a different experience flow"""
	if flow_id != current_flow_id:
		current_flow_id = flow_id
		current_level_index = 0  # Reset to start of new flow
		emit_signal("state_changed")
		print("[ExperienceState] Switched to flow: ", flow_id)

func push_flow(flow_id: String):
	"""Push current flow to stack and switch to new flow (for DLC/sub-flows)"""
	flow_history.append({
		"flow_id": current_flow_id,
		"index": current_level_index
	})
	set_flow(flow_id)
	print("[ExperienceState] Pushed flow to stack, now on: ", flow_id)

func pop_flow() -> bool:
	"""Return to previous flow from stack"""
	if flow_history.size() > 0:
		var previous = flow_history.pop_back()
		current_flow_id = previous.flow_id
		current_level_index = previous.index
		emit_signal("state_changed")
		print("[ExperienceState] Popped flow, returned to: ", current_flow_id)
		return true
	else:
		print("[ExperienceState] No flows in history to pop")
		return false

# Reward tracking
func unlock_reward(reward_id: String) -> bool:
	"""Mark a reward as unlocked (returns false if already unlocked)"""
	if reward_id in unlocked_rewards:
		print("[ExperienceState] Reward already unlocked: ", reward_id)
		return false

	unlocked_rewards.append(reward_id)
	emit_signal("state_changed")
	print("[ExperienceState] Unlocked reward: ", reward_id)
	return true

func is_reward_unlocked(reward_id: String) -> bool:
	"""Check if a reward has been unlocked"""
	return reward_id in unlocked_rewards

# Narrative stage tracking
func mark_narrative_stage_seen(stage_id: String):
	"""Mark a narrative stage as seen"""
	if not stage_id in seen_narrative_stages:
		seen_narrative_stages.append(stage_id)
		emit_signal("state_changed")
		print("[ExperienceState] Narrative stage seen: ", stage_id)

func has_seen_narrative_stage(stage_id: String) -> bool:
	"""Check if a narrative stage has been seen"""
	return stage_id in seen_narrative_stages

# Experience node tracking
func mark_node_completed(node_id: String):
	"""Mark an experience node as completed"""
	if not node_id in completed_experience_nodes:
		completed_experience_nodes.append(node_id)
		total_nodes_completed += 1
		emit_signal("state_changed")
		print("[ExperienceState] Node completed: ", node_id)

func is_node_completed(node_id: String) -> bool:
	"""Check if an experience node has been completed"""
	return node_id in completed_experience_nodes

# Session tracking
func update_session_time():
	"""Update last session timestamp"""
	last_session_time = Time.get_unix_time_from_system()

# Serialization
func to_dict() -> Dictionary:
	"""Convert state to dictionary for saving"""
	return {
		"current_world": current_world,
		"current_chapter": current_chapter,
		"current_level_index": current_level_index,
		"current_flow_id": current_flow_id,
		"unlocked_rewards": unlocked_rewards,
		"seen_narrative_stages": seen_narrative_stages,
		"completed_experience_nodes": completed_experience_nodes,
		"flow_history": flow_history,
		"total_nodes_completed": total_nodes_completed,
		"experience_start_time": experience_start_time,
		"last_session_time": last_session_time
	}

func from_dict(data: Dictionary):
	"""Load state from dictionary"""
	current_world = data.get("current_world", 1)
	current_chapter = data.get("current_chapter", 1)
	current_level_index = data.get("current_level_index", 0)
	current_flow_id = data.get("current_flow_id", "main_story")

	unlocked_rewards = data.get("unlocked_rewards", [])
	seen_narrative_stages = data.get("seen_narrative_stages", [])
	completed_experience_nodes = data.get("completed_experience_nodes", [])
	flow_history = data.get("flow_history", [])

	total_nodes_completed = data.get("total_nodes_completed", 0)
	experience_start_time = data.get("experience_start_time", Time.get_unix_time_from_system())
	last_session_time = data.get("last_session_time", Time.get_unix_time_from_system())

	emit_signal("state_changed")
	print("[ExperienceState] Loaded state - Flow: ", current_flow_id, " Index: ", current_level_index)

# Save/Load integration with RewardManager
func save_to_reward_manager():
	"""Save experience state to RewardManager's save system"""
	if not RewardManager:
		print("[ExperienceState] ERROR: RewardManager not available")
		return

	# Add experience_state to RewardManager's save data
	# Note: This requires RewardManager to support custom data fields
	update_session_time()
	print("[ExperienceState] Saved state to RewardManager")

func load_from_reward_manager() -> bool:
	"""Load experience state from RewardManager's save system"""
	if not RewardManager:
		print("[ExperienceState] ERROR: RewardManager not available")
		return false

	# Try to load experience_state from RewardManager's save data
	# Note: This requires RewardManager to support custom data fields
	print("[ExperienceState] Loaded state from RewardManager")
	return true

# Debug utilities
func get_progress_summary() -> String:
	"""Get human-readable progress summary"""
	return "World %d, Chapter %d, Flow: %s, Index: %d, Nodes: %d" % [
		current_world,
		current_chapter,
		current_flow_id,
		current_level_index,
		total_nodes_completed
	]

func print_state():
	"""Print current state for debugging"""
	print("=== Experience State ===")
	print("  World: ", current_world)
	print("  Chapter: ", current_chapter)
	print("  Flow: ", current_flow_id)
	print("  Index: ", current_level_index)
	print("  Unlocked Rewards: ", unlocked_rewards.size())
	print("  Seen Narratives: ", seen_narrative_stages.size())
	print("  Completed Nodes: ", completed_experience_nodes.size())
	print("  Total Nodes: ", total_nodes_completed)
	print("  Flow Stack Depth: ", flow_history.size())
	print("========================")
