extends PipelineStep
class_name ConditionalStep

# ConditionalStep
# Evaluates a condition expression in the node and either executes a child flow or skips.

var condition_expr: String = ""
var true_branch: Dictionary = {}
var false_branch: Dictionary = {}

func _init(cond: String = "", t_branch: Dictionary = {}, f_branch: Dictionary = {}):
	super("conditional")
	condition_expr = cond
	true_branch = t_branch
	false_branch = f_branch

func execute(context: PipelineContext) -> bool:
	print("[ConditionalStep] Evaluating condition: %s" % condition_expr)
	# Very simple condition evaluator: check a flag in experience_state or context
	var result = false
	if condition_expr == "always_true":
		result = true
	elif context and context.has("experience_state"):
		var exp_state = context.experience_state if context.has("experience_state") else null
		if exp_state and exp_state.has_method("get"):
			result = exp_state.get(condition_expr)

	if result:
		print("[ConditionalStep] Condition true - executing true branch")
	else:
		print("[ConditionalStep] Condition false - skipping or executing false branch")
	# Default behaviour: don't expand child nodes here; just continue
	step_completed.emit(true)
	return true

func cleanup():
	pass
