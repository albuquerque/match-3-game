extends Node

# PageManager: central navigation/page lifecycle manager
# Responsibilities: open/close pages, maintain modal stack, centralize z-index for overlays

signal page_opened(page_name: String, node: Node)
signal page_closed(page_name: String)

var _stack: Array = []
var _pages_parent: Node = null

# z-index base for pages so they stack above gameplay UI
const BASE_Z_INDEX := 1000

var NodeRes = null

func _init_resolvers():
	if NodeRes == null:
		var s = load("res://scripts/helpers/node_resolvers_api.gd")
		if s != null and typeof(s) != TYPE_NIL and s.has_method("_get_gm"):
			NodeRes = s
		else:
			NodeRes = load("res://scripts/helpers/node_resolvers_shim.gd")

func _ready() -> void:
	_init_resolvers()
	# Prefer VisualAnchorManager anchor if present
	var vam = null
	# Try scene root first (safe) to avoid calling unknown static APIs on script resources
	if has_method("get_tree"):
		var rt0 = get_tree().root
		if rt0:
			vam = rt0.get_node_or_null("VisualAnchorManager")
	# Fallback to NodeResolvers helper
	if vam == null and typeof(NodeRes) != TYPE_NIL:
		vam = NodeRes._get_vam()

	# If still not available, wait a few frames for initialization
	if vam == null:
		print("[PageManager] VisualAnchorManager not ready - waiting up to 10 frames for registration")
		for i in range(10):
			await get_tree().process_frame
			if typeof(NodeRes) != TYPE_NIL:
				vam = NodeRes._get_vam()
			if vam == null and has_method("get_tree"):
				var rt2 = get_tree().root
				if rt2:
					vam = rt2.get_node_or_null("VisualAnchorManager")
			if vam:
				break

	if vam and vam.has_method("get_anchor") and vam.has_anchor("overlay"):
		_pages_parent = vam.get_anchor("overlay")
	else:
		# fallback to tree root
		_pages_parent = get_tree().root

	# subscribe to EventBus open/close (wait briefly if EventBus not ready)
	var eb = null
	# Try scene root first (safe)
	if has_method("get_tree"):
		var rt_ev = get_tree().root
		if rt_ev:
			eb = rt_ev.get_node_or_null("EventBus")
	# Fallback to NodeResolvers helper if available
	if eb == null:
		# Try runtime load of resolver shim to avoid parse-time preloads
		var resolver_script = load("res://scripts/helpers/node_resolvers_api.gd")
		if resolver_script != null and typeof(resolver_script) != TYPE_NIL and resolver_script.has_method("_get_evbus"):
			eb = resolver_script._get_evbus()
		else:
			# Fallback to shim
			var shim = load("res://scripts/helpers/node_resolvers_shim.gd")
			if shim != null and shim is Script and shim.has_source_code():
				var shim_inst = shim.new()
				if shim_inst and shim_inst.has_method("_get_evbus"):
					eb = shim_inst._get_evbus()
	# Wait a few frames for EventBus if still missing
	if eb == null:
		print("[PageManager] EventBus not ready - waiting up to 10 frames to connect")
		for i in range(10):
			await get_tree().process_frame
			if typeof(NodeRes) != TYPE_NIL:
				eb = NodeRes._get_evbus()
			if eb == null and has_method("get_tree"):
				var rt3 = get_tree().root
				if rt3:
					eb = rt3.get_node_or_null("EventBus")
			if eb:
				break

	if eb:
		if eb.has_signal("open_page"):
			eb.connect("open_page", Callable(self, "_on_open_page"))
		if eb.has_signal("close_page"):
			eb.connect("close_page", Callable(self, "_on_close_page"))
		# Ensure StartPage is removed when a level loads (covers direct StartPage children not managed by PageManager)
		if eb.has_signal("level_loaded"):
			eb.connect("level_loaded", Callable(self, "_on_global_level_loaded"))
		print("[PageManager] Connected to EventBus signals")
	else:
		print("[PageManager] WARNING: EventBus not found; PageManager will not respond to EventBus.open_page until restarted")
	print("[PageManager] Ready - parent=%s" % str(_pages_parent))

func _z_for_index(idx: int) -> int:
	return BASE_Z_INDEX + idx

func open(page_name: String, params: Dictionary = {}) -> bool:
	# Prevent duplicate opens: if page is already open, don't instantiate another copy
	if is_open(page_name):
		print("[PageManager] Page already open: %s — ignoring duplicate open" % page_name)
		# Optionally, bring existing page to top (not implemented yet)
		return true

	# Hide current top page to avoid transparent overlays showing underlying page
	if _stack.size() > 0:
		var top_entry = _stack[_stack.size() - 1]
		if top_entry and top_entry.node and is_instance_valid(top_entry.node):
			# If the current top is StartPage, hide it immediately (no animation) so translucent overlays don't reveal it
			if top_entry["name"] == "StartPage":
				if top_entry.node is CanvasItem:
					# Immediate hide ensures no visual bleed-through
					top_entry.node.visible = false
					# Ensure fully transparent modulate so any lingering alpha doesn't show
					if top_entry.node.has_method("set"):
						top_entry.node.set("modulate", Color(1,1,1,0))
			else:
				# Prefer calling hide_screen so page can animate out when supported, otherwise fallback to hide()
				if top_entry.node.has_method("hide_screen"):
					top_entry.node.call_deferred("hide_screen")
				elif top_entry.node is CanvasItem:
					top_entry.node.hide()

	# Additionally, ensure StartPage (if present anywhere in stack) is hidden when opening other pages
	if page_name != "StartPage":
		for e in _stack:
			if e and e["name"] == "StartPage" and e.node and is_instance_valid(e.node):
				# mark that PageManager hid it so we can restore later
				e["__hidden_by_manager"] = true
				# Hide StartPage immediately to avoid any transparent overlay showing underlying UI
				if e.node is CanvasItem:
					e.node.visible = false
					if e.node.has_method("set"):
						e.node.set("modulate", Color(1,1,1,0))

	# Attempt to load scene from scenes/ui/pages/<page_name>.tscn (new refactor location)
	var tried_paths = []
	var scene_path = "res://scenes/ui/pages/%s.tscn" % page_name
	var inst = null
	if ResourceLoader.exists(scene_path):
		tried_paths.append(scene_path)
		print("[PageManager] load candidate: %s" % scene_path)
		var packed = load(scene_path)
		if packed:
			inst = packed.instantiate()
		else:
			print("[PageManager] Failed to load packed scene: %s" % scene_path)
			return false
	else:
		# Attempt to load scene from scenes/ui/<page_name>.tscn (legacy refactor location)
		scene_path = "res://scenes/ui/%s.tscn" % page_name
		if ResourceLoader.exists(scene_path):
			tried_paths.append(scene_path)
			var packed = load(scene_path)
			if packed:
				inst = packed.instantiate()
			else:
				print("[PageManager] Failed to load packed scene: %s" % scene_path)
				return false
		else:
			# Try legacy scene location: res://scenes/<page>.tscn
			scene_path = "res://scenes/%s.tscn" % page_name
			if ResourceLoader.exists(scene_path):
				tried_paths.append(scene_path)
				var packed2 = load(scene_path)
				if packed2:
					inst = packed2.instantiate()
				else:
					print("[PageManager] Failed to load packed scene: %s" % scene_path)
					return false
			else:
				# Fallback: try script variant at scripts/ui/<page_name>.gd
				var script_path = "res://scripts/ui/%s.gd" % page_name
				if ResourceLoader.exists(script_path):
					tried_paths.append(script_path)
					var script = load(script_path)
					if script:
						inst = Control.new()
						inst.set_script(script)
					else:
						print("[PageManager] Failed to load script: %s" % script_path)
						return false
				else:
					# Legacy script location: res://scripts/<page>.gd
					script_path = "res://scripts/%s.gd" % page_name
					if ResourceLoader.exists(script_path):
						tried_paths.append(script_path)
						var script2 = load(script_path)
						if script2:
							inst = Control.new()
							inst.set_script(script2)
						else:
							print("[PageManager] Failed to load script: %s" % script_path)
							return false
					else:
						print("[PageManager] Scene and script not found for page: %s. Tried: %s" % [page_name, str(tried_paths)])
						return false
	# Attach to parent and configure as fullscreen control when possible (deferred to avoid busy-parent errors)
	_pages_parent.call_deferred("add_child", inst)

	# z-index management (deferred to ensure node exists in scene tree)
	_stack.append({"name": page_name, "node": inst})
	var z = _z_for_index(_stack.size())
	# Defer configuration to helper to avoid passing Callables into call_deferred
	call_deferred("_configure_page_node", inst, z)

	# Pass params to page if it supports a setup function
	if params and inst:
		if inst.has_method("setup"):
			inst.call_deferred("setup", params)
		elif inst.has_method("set_params"):
			inst.call_deferred("set_params", params)

	# Show the new page using its 'show_screen' hook if available so animations run; otherwise just show
	if inst:
		if inst.has_method("show_screen"):
			inst.call_deferred("show_screen")
		elif inst is CanvasItem:
			inst.call_deferred("show")

	emit_signal("page_opened", page_name, inst)
	print("[PageManager] Opened page: %s (z=%d)" % [page_name, z])
	return true

func close(page_name: String, options: Dictionary = {}) -> bool:
	var _flow_starting: bool = options.get("flow_starting", false)
	# find top-most matching page and remove
	for i in range(_stack.size() - 1, -1, -1):
		var entry = _stack[i]
		var name = entry.get("name", "")
		if name == page_name or page_name == "":
			var node = entry.get("node", null)
			if node and is_instance_valid(node):
				# If page exposes a 'will_close' hook, call it
				if node.has_method("will_close"):
					node.call("will_close")
				node.queue_free()
			_stack.remove_at(i)
			emit_signal("page_closed", name)
			print("[PageManager] Closed page: %s" % name)

			# After removing, reveal the new top page (if any)
			if _stack.size() > 0:
				var new_top = _stack[_stack.size() - 1]
				var new_node = new_top.get("node", null)
				# If a flow is starting, do NOT reveal the page underneath (e.g. StartPage) —
				# the pipeline will show the board instead.
				if _flow_starting:
					print("[PageManager] %s closed with flow_starting=true — suppressing reveal of underlying %s" % [name, new_top.get("name", "?")])
				elif new_node and is_instance_valid(new_node) and new_node is CanvasItem:
					# Prefer animated show if the page supports ScreenBase.show_screen
					if new_node.has_method("show_screen"):
						new_node.call_deferred("show_screen")
					else:
						new_node.show()
					# Ensure visibility and modulate restored (force fallback if animation fails)
					new_node.call_deferred("set", "visible", true)
					new_node.call_deferred("set", "modulate", Color(1,1,1,1))
					# Ensure it's on top of z-order for its index
					if new_node is CanvasItem:
						var idx = _stack.size() - 1
						new_node.call_deferred("set", "z_index", _z_for_index(idx+1))
					# If this page was hidden by manager earlier, clear the flag on reveal and ensure it's visible
					if new_top.get("name", "") == "StartPage" and new_top.has("__hidden_by_manager"):
						new_top["__hidden_by_manager"] = false
						# If StartPage was hidden immediately, restore it now. Prefer animated show if available.
						if new_node.has_method("show_screen"):
							new_node.call_deferred("show_screen")
						elif new_node is CanvasItem:
							new_node.call_deferred("show")
							new_node.call_deferred("set", "modulate", Color(1,1,1,1))
			else:
				# No pages left on the stack: return to StartPage so player isn't left on a blank overlay
				# EXCEPTION: if StartPage itself was just closed, the pipeline/flow is starting — don't re-open it.
				if name == "StartPage":
					print("[PageManager] StartPage was closed and stack is empty — suppressing auto-reopen (flow starting)")
				elif _flow_starting:
					print("[PageManager] %s closed with flow_starting=true — suppressing StartPage auto-reopen" % name)
				elif not is_open("StartPage"):
					# Only auto-open StartPage if the game is not currently running.
					# If a level is active (GameManager.initialized == true), don't reopen StartPage now.
					# Also suppress if ExperienceDirector has an active flow running.
					var gm = null
					if typeof(NodeRes) != TYPE_NIL and NodeRes.has_method("_get_gm"):
						gm = NodeRes._get_gm()
					else:
						if has_method("get_tree"):
							var rt = get_tree().root
							if rt:
								gm = rt.get_node_or_null("GameManager")
					var should_open_start = true
					if gm != null and ("initialized" in gm) and gm.initialized:
						should_open_start = false
					if should_open_start and has_method("get_tree"):
						var ed = get_tree().root.get_node_or_null("ExperienceDirector")
						if ed and ed.has_method("is_flow_active") and ed.is_flow_active():
							should_open_start = false
					if should_open_start:
						call_deferred("open", "StartPage", {})
			return true
	return false

# Utility: close all open pages
func close_all() -> void:
	for i in range(_stack.size() - 1, -1, -1):
		var entry = _stack[i]
		if entry.node and is_instance_valid(entry.node):
			entry.node.queue_free()
	_stack.clear()
	emit_signal("page_closed", "_all_")
	print("[PageManager] Closed all pages")
	# After clearing pages, ensure StartPage is open so UI has a landing page
	# BUT do not auto-open StartPage if a game level is currently initialized,
	# or if ExperienceDirector has an active flow running.
	var should_open_start = true
	var gm = null
	if typeof(NodeRes) != TYPE_NIL and NodeRes.has_method("_get_gm"):
		gm = NodeRes._get_gm()
	else:
		if has_method("get_tree"):
			var rt = get_tree().root
			if rt:
				gm = rt.get_node_or_null("GameManager")
	if gm != null and ("initialized" in gm) and gm.initialized:
		should_open_start = false
	if should_open_start and has_method("get_tree"):
		var ed = get_tree().root.get_node_or_null("ExperienceDirector")
		if ed and ed.has_method("is_flow_active") and ed.is_flow_active():
			should_open_start = false
	if should_open_start and not is_open("StartPage"):
		call_deferred("open", "StartPage", {})

# Query helper: return top page info or null
func top_page():
	if _stack.size() == 0:
		return null
	return _stack[_stack.size() - 1]

# Return the scene node for an open page by name, or null
func get_open_page(page_name: String) -> Node:
	for entry in _stack:
		if entry.get("name", "") == page_name:
			return entry.get("node", null)
	return null

# Check if a page is open
func is_open(page_name: String) -> bool:
	for entry in _stack:
		if entry["name"] == page_name:
			return true
	return false

# EventBus handlers
func _on_open_page(page_name: String, params: Dictionary = {}) -> void:
	open(page_name, params)

func _on_close_page(page_name: String) -> void:
	close(page_name)

func _on_global_level_loaded(level_id: String, context: Dictionary = {}):
	# Close StartPage immediately when a level loads. This prevents StartPage visuals from
	# showing behind the GameBoard. We close by name and also sweep the scene tree for
	# stray StartPage instances and queue_free them.
	print("[PageManager] Global level_loaded received: ", level_id, " - ensuring StartPage removed from scene and stack")
	# Close via stack if present
	if is_open("StartPage"):
		close("StartPage")

	# Also remove any StartPage nodes in the scene tree that aren't in the stack
	var root = get_tree().root if has_method("get_tree") else null
	if root:
		_sweep_and_remove_named(root, "StartPage")

func _sweep_and_remove_named(start_node: Node, name: String) -> void:
	if start_node == null:
		return
	var to_remove = []
	for child in start_node.get_children():
		if child == null:
			continue
		var should_remove = false
		if child.name == name:
			should_remove = true
		else:
			if child and child.get_script() != null:
				var script_path = str(child.get_script())
				if script_path.find("StartPage.gd") != -1:
					should_remove = true
		if should_remove and is_instance_valid(child):
			to_remove.append(child)
		else:
			_sweep_and_remove_named(child, name)

	# Remove collected nodes immediately to avoid a visible frame where they still render
	for n in to_remove:
		if n and is_instance_valid(n):
			print("[PageManager] Removing stray StartPage at: ", n.get_path(), " (immediate removal)")
			var p = n.get_parent()
			if p:
				p.remove_child(n)
			if n is CanvasItem:
				n.visible = false
				if n.has_method("set"):
					n.set("modulate", Color(1,1,1,0))
			n.queue_free()


# Helper: configure node after it's been added to scene tree
func _configure_page_node(inst: Node, z: int) -> void:
	# Find the page name for this instance from the stack
	var page_name = ""
	for entry in _stack:
		if entry.get("node", null) == inst:
			page_name = entry.get("name", "")
			break

	# The "Game" page is a transparent gameplay placeholder — never block its input
	var is_gameplay_placeholder = (page_name == "Game")

	if inst is Control:
		inst.anchor_left   = 0
		inst.anchor_top    = 0
		inst.anchor_right  = 1
		inst.anchor_bottom = 1
		inst.offset_left   = 0
		inst.offset_top    = 0
		inst.offset_right  = 0
		inst.offset_bottom = 0
		# Do NOT set inst.size — when opposite anchors differ Godot owns the size.
		# Gameplay placeholder must pass all input through to board/boosters beneath it
		if is_gameplay_placeholder:
			inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			inst.mouse_filter = Control.MOUSE_FILTER_STOP
	if inst is CanvasItem:
		inst.z_index = z

	# Inject an opaque background ColorRect behind non-gameplay pages so the game
	# board never shows through (avoids transparent-page-over-board issue).
	if inst is Control and not is_gameplay_placeholder and not inst.get_node_or_null("__PageBackground"):
		var bg = ColorRect.new()
		bg.name = "__PageBackground"
		bg.color = Color(0.07, 0.05, 0.12, 1.0)  # Dark opaque background
		bg.anchor_left = 0
		bg.anchor_top = 0
		bg.anchor_right = 1
		bg.anchor_bottom = 1
		bg.position = Vector2.ZERO
		bg.size = get_viewport().get_visible_rect().size
		bg.z_index = -1  # Behind page content
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		inst.call_deferred("add_child", bg)
		inst.call_deferred("move_child", bg, 0)

## Refactor: add enum-based API per docs/refactor.md
enum Page {
	HOME,
	WORLD_MAP,
	GALLERY,
	ACHIEVEMENTS,
	SETTINGS,
	ABOUT,
	PROFILE,
	GAME
}

# Map enum values to scene names (string keys used by `open`)
var _page_lookup: Dictionary = {
	Page.HOME: "StartPage",
	Page.WORLD_MAP: "WorldMap",
	Page.GALLERY: "gallery/gallery_screen",
	Page.ACHIEVEMENTS: "AchievementsPage",
	Page.SETTINGS: "SettingsDialog",
	Page.ABOUT: "AboutPage",
	Page.PROFILE: "ProfilePage",
	Page.GAME: "Game"
}

func _page_name_for(page) -> String:
	# Accept either enum (int) or string page name
	if typeof(page) == TYPE_INT and _page_lookup.has(page):
		return _page_lookup[page]
	if typeof(page) == TYPE_STRING:
		return page
	return ""

func go_to_page(page, params: Dictionary = {}) -> void:
	"""Public API: navigate to a page (pushes current page onto stack). Accepts Page enum or string."""
	var name = _page_name_for(page)
	if name == "":
		push_error("[PageManager] go_to_page: unknown page: %s" % str(page))
		return
	open(name, params)

func go_back() -> void:
	"""Public API: pop the navigation stack and restore previous page."""
	# Close top-most page and reveal previous
	if _stack.size() == 0:
		# nothing to go back to
		return
	var top = _stack.pop_back()
	if top.node and is_instance_valid(top.node):
		top.node.queue_free()
	# Reveal previous if any
	if _stack.size() > 0:
		var prev = _stack[_stack.size() - 1]
		if prev.node and is_instance_valid(prev.node) and prev.node is CanvasItem:
			prev.node.show()

func get_current_page():
	if _stack.size() == 0:
		return null
	return _stack[_stack.size() - 1]["name"]

func replace_current_page(page, params: Dictionary = {}) -> void:
	"""Replace the top-most page with another (pop then push)."""
	if _stack.size() > 0:
		var top = _stack.pop_back()
		if top.node and is_instance_valid(top.node):
			top.node.queue_free()
	go_to_page(page, params)

func clear_stack_and_go_to(page, params: Dictionary = {}) -> void:
	"""Clear navigation stack and go to the given page."""
	close_all()
	go_to_page(page, params)
