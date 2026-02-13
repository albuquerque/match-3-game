extends Node
class_name ExperiencePipeline

## ExperiencePipeline
## Central runtime flow execution coordinator
## Executes steps in sequence, propagates context, emits lifecycle events
## Contains NO gameplay logic - only coordinates step execution

signal pipeline_started(flow_id: String)
signal pipeline_step_started(step_name: String)
signal pipeline_step_completed(step_name: String, success: bool)
signal pipeline_completed(flow_id: String)
signal pipeline_failed(flow_id: String, reason: String)

# Execution state
var context: PipelineContext = null
var current_steps: Array = []
var current_step_index: int = 0
var is_running: bool = false

func _init():
	name = "ExperiencePipeline"

## Start pipeline execution with the given context and steps
func start(ctx: PipelineContext, steps: Array) -> void:
	if is_running:
		print("[ExperiencePipeline] Pipeline already running - stopping existing pipeline and restarting")
		stop()
		# fall through to start new pipeline

	if not ctx or not ctx.is_valid():
		push_error("[ExperiencePipeline] Invalid context - cannot start pipeline")
		emit_signal("pipeline_failed", "", "invalid_context")
		return

	context = ctx
	current_steps = steps
	current_step_index = 0
	is_running = true

	print("[ExperiencePipeline] Starting pipeline: %s with %d steps" % [context.flow_id, steps.size()])
	emit_signal("pipeline_started", context.flow_id)

	_execute_next_step()

## Execute the next step in the sequence
func _execute_next_step() -> void:
	if current_step_index >= current_steps.size():
		_complete_pipeline()
		return

	var step: PipelineStep = current_steps[current_step_index]
	if not step:
		push_error("[ExperiencePipeline] Invalid step at index %d" % current_step_index)
		_fail_pipeline("invalid_step")
		return

	print("[ExperiencePipeline] Executing step %d/%d: %s" % [current_step_index + 1, current_steps.size(), step.step_name])
	emit_signal("pipeline_step_started", step.step_name)

	# Add step as child so it can access get_tree()
	if not step.is_inside_tree():
		add_child(step)

	# Connect to step completion signal using Callable to ensure Godot 4 binds correctly
	var handler = Callable(self, "_on_step_completed")
	if not step.step_completed.is_connected(handler):
		step.step_completed.connect(handler)

	# Execute step
	var success = step.execute(context)

	# If step completed synchronously
	if not context.waiting_for_completion:
		# If step completed synchronously, call the handler directly with the success flag
		_on_step_completed(success)

## Called when a step signals completion
func _on_step_completed(success: bool) -> void:
	# Defensive: ensure current index is valid
	if current_step_index < 0 or current_step_index >= current_steps.size():
		print("[ExperiencePipeline] _on_step_completed called but current_step_index out of range")
		return

	var step: PipelineStep = current_steps[current_step_index]

	print("[ExperiencePipeline] Step completed: %s (success: %s)" % [step.step_name, success])
	emit_signal("pipeline_step_completed", step.step_name, success)

	# Cleanup step
	step.cleanup()

	# Reset waiting flag
	if context:
		context.waiting_for_completion = false
		context.completion_type = ""

	# Disconnect the completion handler for this step
	var handler = Callable(self, "_on_step_completed")
	if step and step.step_completed.is_connected(handler):
		step.step_completed.disconnect(handler)

	if not success:
		_fail_pipeline("step_failed: %s" % step.step_name)
		return

	# Move to next step
	current_step_index += 1
	_execute_next_step()

## Complete the pipeline successfully
func _complete_pipeline() -> void:
	print("[ExperiencePipeline] Pipeline completed: %s" % context.flow_id)
	emit_signal("pipeline_completed", context.flow_id)
	is_running = false
	_cleanup()

## Fail the pipeline with reason
func _fail_pipeline(reason: String) -> void:
	push_error("[ExperiencePipeline] Pipeline failed: %s - %s" % [context.flow_id, reason])
	emit_signal("pipeline_failed", context.flow_id, reason)
	is_running = false
	_cleanup()

## Cleanup pipeline resources
func _cleanup() -> void:
	for step in current_steps:
		if step:
			step.cleanup()
			if step.is_inside_tree():
				remove_child(step)
			step.queue_free()
	current_steps.clear()
	context = null

## Stop the pipeline (for manual interruption)
func stop() -> void:
	if is_running:
		print("[ExperiencePipeline] Pipeline stopped manually")
		_cleanup()
		is_running = false
