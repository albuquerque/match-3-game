@tool
extends EditorScript

# Editor script to list flow step definitions, usages, and archive unused ones

func _run():
	var defs_dir = "res://data/flow_step_definitions"
	print("Definition audit path: %s" % defs_dir)
	# Simple listing of definitions present
	var dir = DirAccess.open(defs_dir)
	if not dir:
		print("Cannot access definitions dir: %s" % defs_dir)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with('.json'):
			print("  - %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("Run tools/report_definition_usage.py for a full CLI report")
