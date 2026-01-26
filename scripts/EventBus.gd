extends Node
## EventBus - Central event dispatcher for narrative animation system
## Broadcasts gameplay events that can trigger visual effects via JSON config

# Signal declarations for all required gameplay events
signal level_loaded(level_id: String, context: Dictionary)
signal level_start(level_id: String, context: Dictionary)
signal level_complete(level_id: String, context: Dictionary)
signal level_failed(level_id: String, context: Dictionary)
signal tile_spawned(entity_id: String, context: Dictionary)
signal tile_matched(entity_id: String, context: Dictionary)
signal tile_destroyed(entity_id: String, context: Dictionary)
signal match_cleared(match_size: int, context: Dictionary)
signal special_tile_activated(entity_id: String, context: Dictionary)
signal spreader_tick(entity_id: String, context: Dictionary)
signal spreader_destroyed(entity_id: String, context: Dictionary)

# Generic event emission for extensibility
signal custom_event(event_name: String, entity_id: String, context: Dictionary)

func _ready():
	print("[EventBus] Initialized - ready to broadcast gameplay events")

## Emit level_loaded event
func emit_level_loaded(level_id: String, context: Dictionary = {}):
	print("[EventBus] level_loaded: ", level_id)
	level_loaded.emit(level_id, context)

## Emit level_start event
func emit_level_start(level_id: String, context: Dictionary = {}):
	print("[EventBus] level_start: ", level_id)
	level_start.emit(level_id, context)

## Emit level_complete event
func emit_level_complete(level_id: String, context: Dictionary = {}):
	print("[EventBus] level_complete: ", level_id)
	level_complete.emit(level_id, context)

## Emit level_failed event
func emit_level_failed(level_id: String, context: Dictionary = {}):
	print("[EventBus] level_failed: ", level_id)
	level_failed.emit(level_id, context)

## Emit tile_spawned event
func emit_tile_spawned(entity_id: String = "", context: Dictionary = {}):
	print("[EventBus] tile_spawned: ", entity_id)
	tile_spawned.emit(entity_id, context)

## Emit tile_matched event
func emit_tile_matched(entity_id: String = "", context: Dictionary = {}):
	print("[EventBus] tile_matched: ", entity_id)
	tile_matched.emit(entity_id, context)

## Emit tile_destroyed event
func emit_tile_destroyed(entity_id: String = "", context: Dictionary = {}):
	print("[EventBus] tile_destroyed: ", entity_id)
	tile_destroyed.emit(entity_id, context)

## Emit match_cleared event
func emit_match_cleared(match_size: int = 0, context: Dictionary = {}):
	print("[EventBus] match_cleared: %d tiles" % match_size)
	match_cleared.emit(match_size, context)

## Emit special_tile_activated event
func emit_special_tile_activated(entity_id: String = "", context: Dictionary = {}):
	print("[EventBus] special_tile_activated: ", entity_id)
	special_tile_activated.emit(entity_id, context)

## Emit spreader_tick event
func emit_spreader_tick(entity_id: String = "", context: Dictionary = {}):
	print("[EventBus] spreader_tick: ", entity_id)
	spreader_tick.emit(entity_id, context)

## Emit spreader_destroyed event
func emit_spreader_destroyed(entity_id: String = "", context: Dictionary = {}):
	print("[EventBus] spreader_destroyed: ", entity_id)
	spreader_destroyed.emit(entity_id, context)

## Emit custom/extensible event
func emit_custom(event_name: String, entity_id: String = "", context: Dictionary = {}):
	print("[EventBus] custom_event: ", event_name, " entity: ", entity_id)
	custom_event.emit(event_name, entity_id, context)
