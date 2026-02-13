extends PipelineStep
class_name DLCFlowStep

# DLCFlowStep
# Triggers loading a DLC flow (chapter) and optionally starts it.

var dlc_id: String = ""

func _init(id: String = ""):
	super("dlc_flow")
	dlc_id = id

func execute(context: PipelineContext) -> bool:
	if dlc_id == "":
		push_warning("[DLCFlowStep] No dlc_id provided")
		step_completed.emit(true)
		return true
	print("[DLCFlowStep] Triggering DLC flow: %s" % dlc_id)
	# Best-effort: notify DLC manager if present
	var manager = DLCManager if typeof(DLCManager) != TYPE_NIL else null
	if manager and manager.has_method("trigger_flow"):
		manager.call("trigger_flow", dlc_id)
		step_completed.emit(true)
		return true
	# fallback: emit EventBus custom event
	if EventBus and EventBus.has_method("emit_custom"):
		EventBus.emit_custom("dlc_flow_triggered", dlc_id, {})
	step_completed.emit(true)
	return true

func cleanup():
	pass
