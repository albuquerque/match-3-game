extends Node

# Test runner that loads a flow and attempts to create pipeline steps from nodes
# Demonstrates `definition_id` merging and `NodeTypeStepFactory` usage at runtime

func _ready():
	print("[TestDefinitionRunner] Starting test runner")

	# Instantiate parser like the game does
	var parser = Node.new()
	parser.set_script(preload("res://scripts/ExperienceFlowParser.gd"))
	add_child(parser)

	var flow_path = "res://data/experience_flows/test_definition_flow.json"
	var flow = parser.parse_flow_file(flow_path)
	if flow.empty():
		print("[TestDefinitionRunner] Failed to load flow: %s" % flow_path)
		parser.queue_free()
		return

	print("[TestDefinitionRunner] Flow loaded: %s (nodes: %d)" % [flow.get("experience_id","?"), flow.get("flow",[]).size()])

	# Iterate nodes and create steps using the factory — factory will merge definitions
	for i in range(flow.get("flow",[]).size()):
		var node = flow.get("flow")[i]
		print("[TestDefinitionRunner] Node %d raw: %s" % [i, node])
		var step = null
		# NodeTypeStepFactory is class_name registered — call static create
		if Engine.has_singleton("NodeTypeStepFactory"):
			# unlikely path — but handle gracefully
			step = Engine.get_singleton("NodeTypeStepFactory").create_step_from_node(node)
		else:
			# Call directly by referencing the script resource
			step = NodeTypeStepFactory.create_step_from_node(node)

		if step:
			print("[TestDefinitionRunner] Created step: %s" % step.step_name)
			# Clean up the created step immediately
			if step.is_inside_tree():
				step.queue_free()
			else:
				# If it's not inside tree, still free it (safe)
				step.queue_free()
		else:
			print("[TestDefinitionRunner] No step created for node: %s" % str(node))

	# Done
	parser.queue_free()
	print("[TestDefinitionRunner] Test run complete")
	# Quit if running in headless test environment
	if OS.has_feature("standalone"):
		get_tree().quit()
