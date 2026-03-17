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

# Narrative system signals
signal narrative_stage_complete(stage_id: String)

# Language/localization signals
signal language_changed(locale: String)

# Generic event emission for extensibility
signal custom_event(event_name: String, entity_id: String, context: Dictionary)

## Fired between gravity and refill each cascade iteration.
## Listeners can inject COLLECTIBLE values into empty grid cells before fill runs.
signal pre_refill()
## Fired after animate_refill completes each cascade iteration.
## Listeners can tag freshly spawned tile nodes (e.g. shard_item_id meta).
signal post_refill()

# Gallery / shard signals
signal shard_discovered(item_id: String, context: Dictionary)
signal gallery_item_unlocked(item_id: String)
## Fired when a shard collectible tile reaches the bottom row and is collected.
signal shard_tile_collected(item_id: String)

# Navigation signals used by PageManager / UI wiring
signal open_page(page_name: String, params: Dictionary)
signal close_page(page_name: String)

var _node_resolvers = null

func _init_resolvers():
	if _node_resolvers == null:
		var s = load("res://scripts/helpers/node_resolvers_api.gd")
		if s != null and typeof(s) != TYPE_NIL and s.has_method("_get_gm"):
			_node_resolvers = s
		else:
			_node_resolvers = load("res://scripts/helpers/node_resolvers_shim.gd")

func _ready():
	_init_resolvers()
	print("[EventBus] Initialized - ready to broadcast gameplay events")
	# Development-only: run a quick page open/close sequence if environment var is set.
	# Set MATCH3_RUN_PAGE_TESTS=1 in environment when starting Godot to enable.
	var run_tests_env = ""
	if OS.has_method("get_environment"):
		run_tests_env = OS.get_environment("MATCH3_RUN_PAGE_TESTS")
	if run_tests_env == "1":
		print("[EventBus] Running dev page open/close tests (MATCH3_RUN_PAGE_TESTS=1)")
		call_deferred("_run_page_tests")

# Development helper: open then close a sequence of pages to validate PageManager stack behavior
func _run_page_tests() -> void:
	var pages = ["SettingsDialog", "WorldMap", "GalleryPage", "AchievementsPage", "ShopUI", "Game"]
	# Small delay to allow other systems to initialize
	await get_tree().create_timer(0.55).timeout
	for p in pages:
		print("[EventBus][DEVTEST] Emitting open_page -> %s" % p)
		emit_open_page(p, {})
		# Wait some time for PageManager to load and show
		await get_tree().create_timer(0.35).timeout
	# Allow some time with all pages open stacked
	await get_tree().create_timer(0.8).timeout
	for i in range(pages.size() - 1, -1, -1):
		var name = pages[i]
		print("[EventBus][DEVTEST] Emitting close_page -> %s" % name)
		emit_close_page(name)
		await get_tree().create_timer(0.30).timeout
	# Final sanity: ensure StartPage open
	print("[EventBus][DEVTEST] Completed page open/close sequence")

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

## Emit pre_refill — called between gravity and refill each cascade step
func emit_pre_refill():
	pre_refill.emit()

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

## Emit language_changed event
func emit_language_changed(locale: String):
	print("[EventBus] language_changed: ", locale)
	language_changed.emit(locale)

## Emit open_page event (navigation)
func emit_open_page(page_name: String, params: Dictionary = {}):
	print("[EventBus] open_page: ", page_name)
	open_page.emit(page_name, params)
	# If PageManager is available and already handling signals, avoid direct open to prevent duplicates
	var pm = null
	if typeof(_node_resolvers) != TYPE_NIL:
		pm = _node_resolvers._get_pm()
	if pm == null and has_method("get_tree"):
		var rt = get_tree().root
		if rt:
			pm = rt.get_node_or_null("PageManager")
	# If we found a PageManager via resolver/root and it is already open for this page, skip direct open
	if pm:
		if pm.has_method("is_open") and pm.is_open(page_name):
			print("[EventBus] PageManager already open for %s - skipping direct open" % page_name)
			return
		# If not connected via signal (no listeners), it's safe to call open directly
		if pm.has_method("open"):
			pm.open(page_name, params)
			return

## Emit close_page event (navigation)
func emit_close_page(page_name: String):
	print("[EventBus] close_page: ", page_name)
	close_page.emit(page_name)

## Emit shard_tile_collected — fired by CollectibleService when a shard tile is collected
func emit_shard_tile_collected(item_id: String):
	print("[EventBus] shard_tile_collected: ", item_id)
	shard_tile_collected.emit(item_id)

## Emit shard_discovered (gallery reward)
func emit_shard_discovered(item_id: String, context: Dictionary = {}):
	print("[EventBus] shard_discovered: ", item_id)
	shard_discovered.emit(item_id, context)

## Emit gallery_item_unlocked
func emit_gallery_item_unlocked(item_id: String):
	print("[EventBus] gallery_item_unlocked: ", item_id)
	gallery_item_unlocked.emit(item_id)
