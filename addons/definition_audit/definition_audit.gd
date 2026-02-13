@tool
extends EditorPlugin

var dock: VBoxContainer
var defs_vbox: VBoxContainer
var archived_vbox: VBoxContainer

func _enter_tree():
	# Build UI
	dock = VBoxContainer.new()
	dock.name = "DefinitionAuditDock"
	var header = Label.new()
	header.text = "Flow Step Definitions Audit"
	header.add_theme_color_override("font_color", Color(1,1,1))
	dock.add_child(header)

	var controls = HBoxContainer.new()
	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(Callable(self, "_refresh"))
	controls.add_child(refresh_btn)

	var run_cli_btn = Button.new()
	run_cli_btn.text = "Run CLI Report"
	run_cli_btn.pressed.connect(Callable(self, "_run_cli_report"))
	controls.add_child(run_cli_btn)

	dock.add_child(controls)

	# Scroll area for active definitions
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 200)
	defs_vbox = VBoxContainer.new()
	sc.add_child(defs_vbox)
	dock.add_child(Label.new())
	var active_lbl = Label.new()
	active_lbl.text = "Active definitions:"
	dock.add_child(active_lbl)
	dock.add_child(sc)

	# Archived section
	var archived_lbl = Label.new()
	archived_lbl.text = "Archived definitions:"
	dock.add_child(archived_lbl)
	var sc2 = ScrollContainer.new()
	sc2.custom_minimum_size = Vector2(0, 100)
	archived_vbox = VBoxContainer.new()
	sc2.add_child(archived_vbox)
	dock.add_child(sc2)

	add_control_to_bottom_panel(dock, "DefAudit")
	_refresh()

func _exit_tree():
	remove_control_from_bottom_panel(dock)

# UI actions
func _run_cli_report():
	var program = "python3"
	var args = ["tools/report_definition_usage.py"]
	var exit_code = OS.execute(program, args)
	print("Ran report, exit: %d" % exit_code)

func _refresh():
	# Clear
	_clear_container(defs_vbox)
	_clear_container(archived_vbox)

	# Gather data
	var defs = _gather_definitions()
	var usage = _gather_usage()
	var archived = _gather_archived_definitions()

	# Populate active definitions
	var def_keys = defs.keys()
	def_keys.sort()
	for def_id in def_keys:
		var h = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = def_id
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_lbl)

		var count = usage.get(def_id, 0)
		var usage_lbl = Label.new()
		usage_lbl.text = str(count)
		h.add_child(usage_lbl)

		var archive_btn = Button.new()
		archive_btn.text = "Archive"
		archive_btn.disabled = (count > 0)
		archive_btn.pressed.connect(Callable(self, "_on_archive_pressed").bind(def_id))
		h.add_child(archive_btn)

		defs_vbox.add_child(h)

	# Populate archived definitions with Restore button
	var arch_keys = archived.keys()
	arch_keys.sort()
	for def_id in arch_keys:
		var h2 = HBoxContainer.new()
		var n = Label.new()
		n.text = def_id
		h2.add_child(n)
		var restore_btn = Button.new()
		restore_btn.text = "Restore"
		restore_btn.pressed.connect(Callable(self, "_on_restore_pressed").bind(def_id))
		h2.add_child(restore_btn)
		archived_vbox.add_child(h2)

func _gather_definitions() -> Dictionary:
	var out := {}
	var dir = DirAccess.open("res://data/flow_step_definitions")
	if not dir:
		return out
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		# skip directories and archived folder
		if fname == "." or fname == "..":
			fname = dir.get_next()
			continue
		if fname == "archived":
			fname = dir.get_next()
			continue
		if fname.ends_with('.json'):
			var id = fname.substr(0, fname.length() - 5)
			out[id] = "res://data/flow_step_definitions/" + fname
		fname = dir.get_next()
	dir.list_dir_end()
	return out

func _gather_archived_definitions() -> Dictionary:
	var out := {}
	var arch_path = "res://data/flow_step_definitions/archived"
	var dir = DirAccess.open(arch_path)
	if not dir:
		return out
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname == "." or fname == "..":
			fname = dir.get_next()
			continue
		if fname.ends_with('.json'):
			var id = fname.substr(0, fname.length() - 5)
			out[id] = arch_path + "/" + fname
		fname = dir.get_next()
	dir.list_dir_end()
	return out

func _gather_usage() -> Dictionary:
	var usage := {}
	var flows_dir = DirAccess.open("res://data/experience_flows")
	if not flows_dir:
		return usage
	flows_dir.list_dir_begin()
	var fname = flows_dir.get_next()
	while fname != "":
		if fname.ends_with('.json'):
			var path = "res://data/experience_flows/" + fname
			var f = FileAccess.open(path, FileAccess.READ)
			if f:
				var txt = f.get_as_text()
				f.close()
				var j = JSON.new()
				if j.parse(txt) == OK and typeof(j.data) == TYPE_DICTIONARY:
					var flow = j.data.get("flow", [])
					for node in flow:
						var def_id = node.get("definition_id", "")
						if def_id != "":
							usage[def_id] = usage.get(def_id, 0) + 1
		fname = flows_dir.get_next()
	flows_dir.list_dir_end()
	return usage

# Archive action: copy file content to archived folder and remove original
func _on_archive_pressed(def_id: String) -> void:
	var src = "res://data/flow_step_definitions/" + def_id + ".json"
	var arch_dir = "res://data/flow_step_definitions/archived"
	var dir = DirAccess.open(arch_dir)
	if not dir:
		# Create archived folder using platform mkdir -p on the project path
		var abs = ProjectSettings.globalize_path(arch_dir)
		OS.execute("mkdir", ["-p", abs])
	# read source
	var f = FileAccess.open(src, FileAccess.READ)
	if not f:
		printerr("Failed to open source: %s" % src)
		return
	var content = f.get_as_text()
	f.close()
	# write dest
	var dest = arch_dir + "/" + def_id + ".json"
	var wf = FileAccess.open(dest, FileAccess.WRITE)
	if not wf:
		printerr("Failed to write archive: %s" % dest)
		return
	wf.store_string(content)
	wf.close()
	# remove original
	var parent_dir = DirAccess.open("res://data/flow_step_definitions")
	if parent_dir:
		parent_dir.remove("%s.json" % def_id)
	print("Archived definition: %s" % def_id)
	_refresh()

func _on_restore_pressed(def_id: String) -> void:
	var src = "res://data/flow_step_definitions/archived/" + def_id + ".json"
	var f = FileAccess.open(src, FileAccess.READ)
	if not f:
		printerr("Failed to open archived: %s" % src)
		return
	var content = f.get_as_text()
	f.close()
	var dest = "res://data/flow_step_definitions/" + def_id + ".json"
	var wf = FileAccess.open(dest, FileAccess.WRITE)
	if not wf:
		printerr("Failed to write restored: %s" % dest)
		return
	wf.store_string(content)
	wf.close()
	# remove archived
	var ad = DirAccess.open("res://data/flow_step_definitions/archived")
	if ad:
		ad.remove("%s.json" % def_id)
	print("Restored definition: %s" % def_id)
	_refresh()

# Utility
func _clear_container(ct: Control) -> void:
	while ct.get_child_count() > 0:
		var c = ct.get_child(0)
		ct.remove_child(c)
		c.queue_free()
