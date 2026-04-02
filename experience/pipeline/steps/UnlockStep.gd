extends "res://experience/pipeline/PipelineStep.gd"
class_name UnlockStep

# UnlockStep
# Unlocks a feature (id) and completes immediately.

var unlock_id: String = ""

func _init(id: String = ""):
	super("unlock")
	unlock_id = id

func execute(context) -> bool:
	if unlock_id == "":
		push_warning("[UnlockStep] No unlock_id provided")
		step_completed.emit(true)
		return true
	print("[UnlockStep] Unlocking: %s" % unlock_id)
	step_completed.emit(true)
	return true

func cleanup():
	pass
