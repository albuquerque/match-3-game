extends PipelineStep
class_name PremiumGateStep

# PremiumGateStep
# Shows a premium gate and waits for user decision; default behavior is to skip.

var gate_id: String = ""

func _init(id: String = ""):
	super("premium_gate")
	gate_id = id

func execute(context: PipelineContext) -> bool:
	print("[PremiumGateStep] Premium gate encountered: %s" % gate_id)
	# Default: do nothing and continue
	step_completed.emit(true)
	return true

func cleanup():
	pass
