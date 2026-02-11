extends PipelineStep
class_name ShowNarrativeStep

## ShowNarrativeStep
## Shows a narrative stage and waits for completion

var stage_id: String = ""
var auto_advance_delay: float = 3.0
var skippable: bool = true

func _init(stg_id: String = "", delay: float = 3.0, skip: bool = true):
	super("show_narrative")
	stage_id = stg_id
	auto_advance_delay = delay
	skippable = skip

func execute(context: PipelineContext) -> bool:
	if stage_id.is_empty():
		push_error("[ShowNarrativeStep] No stage_id provided")
		return false

	print("[ShowNarrativeStep] Showing narrative: %s (delay: %.1fs)" % [stage_id, auto_advance_delay])

	context.waiting_for_completion = true
	context.completion_type = "narrative"

	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	if not root:
		push_error("[ShowNarrativeStep] Cannot access scene tree")
		return false

	var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
	if not narrative_manager:
		push_error("[ShowNarrativeStep] NarrativeStageManager not found")
		return false

	var event_bus = root.get_node_or_null("/root/EventBus")

	if event_bus and event_bus.has_signal("narrative_stage_complete"):
		if not event_bus.narrative_stage_complete.is_connected(_on_narrative_complete):
			event_bus.narrative_stage_complete.connect(_on_narrative_complete)

	if narrative_manager.has_method("load_stage_by_id"):
		if narrative_manager.load_stage_by_id(stage_id):
			if auto_advance_delay > 0:
				_start_auto_advance_timer()
			return true
		else:
			push_warning("[ShowNarrativeStep] Failed to load narrative: %s" % stage_id)
			return false

	return false

func _start_auto_advance_timer():
	var tree: SceneTree = get_tree()
	if tree:
		var timer = tree.create_timer(auto_advance_delay)
		timer.timeout.connect(_on_auto_advance_timeout)

func _on_auto_advance_timeout():
	print("[ShowNarrativeStep] Auto-advance timeout")
	step_completed.emit(true)

func _on_narrative_complete(stg_id: String):
	if stg_id == stage_id:
		print("[ShowNarrativeStep] Narrative completed: %s" % stg_id)
		step_completed.emit(true)

func cleanup():
	var root = Engine.get_main_loop().root if Engine.get_main_loop() else null
	if not root:
		return

	var event_bus = root.get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("narrative_stage_complete"):
		if event_bus.narrative_stage_complete.is_connected(_on_narrative_complete):
			event_bus.narrative_stage_complete.disconnect(_on_narrative_complete)
