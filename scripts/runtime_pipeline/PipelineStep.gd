extends Node
class_name PipelineStep

## PipelineStep
## Base class for all pipeline execution steps
## Each step does ONE thing and signals completion

signal step_completed(success: bool)

var step_name: String = "unnamed_step"

func _init(name: String = "unnamed_step"):
	step_name = name

## Execute this step with the given context
## Must be overridden by subclasses
func execute(context: PipelineContext) -> bool:
	push_error("[PipelineStep:%s] execute() not implemented" % step_name)
	return false

## Called when step execution is complete
## Subclasses can override for cleanup
func cleanup():
	pass
