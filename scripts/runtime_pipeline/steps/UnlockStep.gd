extends PipelineStep
class_name UnlockStep

# UnlockStep
# Unlocks a feature (id) and completes immediately.

var unlock_id: String = ""

func _init(id: String = ""):
	super("unlock")
	unlock_id = id

func execute(context: PipelineContext) -> bool:
	if unlock_id == "":
		push_warning("[UnlockStep] No unlock_id provided")
		step_completed.emit(true)
		return true
	print("[UnlockStep] Unlocking: %s" % unlock_id)
	# Best-effort: record unlock via EventBus custom_event if available
	if EventBus and EventBus.has_method("emit_custom"):
		EventBus.emit_custom("feature_unlocked", unlock_id, {})
	step_completed.emit(true)
	return true

func cleanup():
	pass
