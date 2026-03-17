extends "res://scripts/ui/ScreenBase.gd"

# Legacy GalleryScreen — kept for reference. The active screen is
# res://scenes/ui/gallery/GalleryScreen.tscn + GalleryScreen.gd.
# This file no longer uses preload so it won't crash if opened by mistake.

@export var items_per_tab: int = 9

var item_scene: PackedScene = null
# No preload — load at runtime to avoid import errors
var _placeholder_texture: Texture2D = null

func _populate_grid_from_scene(grid: GridContainer) -> void:
	# Clear existing children
	for c in grid.get_children():
		c.queue_free()

	for i in range(items_per_tab):
		var inst = item_scene.instantiate()
		inst.name = "Item_%d" % i
		# Create a fixed-size cell to contain the instanced item so GridContainer measures cells correctly
		var cell = Control.new()
		cell.name = "%s_cell" % inst.name
		cell.anchor_left = 0
		cell.anchor_top = 0
		cell.anchor_right = 0
		cell.anchor_bottom = 0
		# Set a custom minimum size for the cell so GridContainer measures cells correctly
		# Use the public property `custom_minimum_size` (safer across Godot versions)
		cell.custom_minimum_size = Vector2(210, 240)
		# Let the cell expand horizontally so GridContainer can size columns properly
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Configure the instanced item to fill the cell
		inst.anchor_left = 0
		inst.anchor_top = 0
		inst.anchor_right = 1
		inst.anchor_bottom = 1
		inst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inst.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var cell_min = "<n/a>"
		if cell.has_method("get_minimum_size"):
			cell_min = str(cell.get_minimum_size())
		print("[GalleryScreen] instanced %s inside %s with cell_min=%s" % [inst.name, cell.name, cell_min])
		if inst.has_node("Progress"):
			inst.get_node("Progress").text = "0 / 9"
		cell.add_child(inst)
		# Before adding to grid, size and center the Silhouette to avoid large texture native sizes overflowing cells
		var sil = null
		# try common paths
		if inst.has_node("Silhouette"):
			sil = inst.get_node("Silhouette")
		else:
			# search recursively (covers SilhouetteContainer/Silhouette)
			sil = _find_descendant(inst, "Silhouette")
		if sil and sil is TextureRect:
			# Force the designer-provided frame image into every Silhouette for now
			if _placeholder_texture != null:
				sil.texture = _placeholder_texture
			var target_size = Vector2(160, 120)
			# If the texture is large, create a scaled-down ImageTexture to prevent native size inflation
			var orig_tex = sil.texture
			if orig_tex and orig_tex is Texture2D:
				var ok = false
				# Attempt to get image from texture and resize
				if orig_tex.has_method("get_image"):
					var img = orig_tex.get_image()
					if img:
						var resized = img.duplicate()
						resized.lock()
						resized.resize(int(target_size.x), int(target_size.y), Image.INTERPOLATE_BILINEAR)
						resized.unlock()
						var small_tex = ImageTexture.create_from_image(resized)
						if small_tex:
							sil.texture = small_tex
							ok = true
				# Fallback: if we couldn't create a scaled texture, at least constrain the min size
#				if not ok:
					# continue with size guards below
			# make anchors absolute so rect_position/rect_size take effect
			sil.anchor_left = 0
			sil.anchor_top = 0
			sil.anchor_right = 0
			sil.anchor_bottom = 0
			sil.size_flags_horizontal = 0
			sil.size_flags_vertical = 0
			# Set container and silhouette minimum sizes to constrain layout and prevent large native texture sizes
			var cell_min_size = Vector2(210, 240)
			if cell.has_method("get_minimum_size"):
				cell_min_size = cell.get_minimum_size()
			var padding = 12
			var top_area_size = Vector2(max(0, cell_min_size.x - padding), max(0, int(cell_min_size.y * 0.72) - padding))
			var sil_parent = sil.get_parent()
			if sil_parent and sil_parent is Control:
				sil_parent.custom_minimum_size = top_area_size
			# ensure the silhouette itself has a constrained minimum size
			sil.custom_minimum_size = target_size
			sil.expand = false
			sil.stretch_mode = 2
			# center silhouette inside its parent
			var cx = max(0, (top_area_size.x - target_size.x) * 0.5)
			var cy = max(0, (top_area_size.y - target_size.y) * 0.5)
			sil.rect_position = Vector2(cx, cy)
		grid.add_child(cell)

		# Diagnostic: print silhouette placement info to help trace offset issues
		if inst.has_node("Silhouette"):
			sil = inst.get_node("Silhouette")
			var sil_parent = sil.get_parent()
			var sil_parent_path = "<no-parent>"
			if sil_parent:
				sil_parent_path = sil_parent.get_path()
			var anchors = "%s,%s,%s,%s" % [str(sil.anchor_left), str(sil.anchor_top), str(sil.anchor_right), str(sil.anchor_bottom)]
			var rect_pos = str(sil.rect_position)
			var rect_size = str(sil.rect_size)
			print("[GalleryScreen DEBUG] %s Silhouette parent=%s anchors=[%s] pos=%s size=%s" % [inst.get_path(), sil_parent_path, anchors, rect_pos, rect_size])

	grid.queue_sort()
	# Defer a final layout pass to compute and set each cell's rect_size to the grid's cell size.
	call_deferred("_finalize_grid_layout", grid)

func _ready():
	ensure_fullscreen()
	# Load placeholder texture at runtime to avoid import-time errors.
	var placeholder_path = "res://assets/gallery/locked_placeholder.svg"
	if ResourceLoader.exists(placeholder_path):
		var tex = load(placeholder_path)
		if tex and tex is Texture2D:
			_placeholder_texture = tex
			print("[GalleryScreen] Placeholder texture loaded: %s" % placeholder_path)
		else:
			print("[GalleryScreen] WARNING: resource at %s is not a Texture2D" % placeholder_path)
	else:
		print("[GalleryScreen] WARNING: Placeholder texture not found at: %s" % placeholder_path)

	print("[GalleryScreen] _ready - deferring bind/populate to idle frame")
	call_deferred("_deferred_bind_and_populate")

func _deferred_bind_and_populate() -> void:
	# Direct lookup for CategoryTabs inside this instance
	var tabs = get_node_or_null("CategoryTabs")
	# If not found, search the scene tree for any node named CategoryTabs
	if tabs == null and has_method("get_tree"):
		var root = get_tree().root
		if root:
			var found = _find_descendant(root, "CategoryTabs")
			if found and found is TabContainer:
				tabs = found

	if tabs and tabs is TabContainer:
		# Populate only the currently active tab to keep iteration minimal and predictable.
		var current_index = 0
		# TabContainer provides get_current_tab(); fallback to property access if needed
		if tabs.has_method("get_current_tab"):
			current_index = tabs.get_current_tab()
		elif "current_tab" in tabs:
			current_index = int(tabs.current_tab)
		# Clamp index and populate that single tab's Grid
		if current_index >= 0 and current_index < tabs.get_child_count():
			var tab = tabs.get_child(current_index)
			if tab:
				var g = tab.get_node_or_null("Grid")
				if g and g is GridContainer:
					_populate_grid_from_scene(g)
					# Ensure the tab has a sensible title
					tabs.set_tab_title(current_index, "Category %d" % (current_index + 1))
	else:
		# Fallback: create CategoryTabs programmatically under this node so UI is visible
		print("[GalleryScreen] CategoryTabs not found or empty; creating fallback tabs at runtime")
		tabs = TabContainer.new()
		tabs.name = "CategoryTabs"
		tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(tabs)
		for i in range(4):
			var tab = VBoxContainer.new()
			tab.name = "Tab_%d" % i
			var g = GridContainer.new()
			g.name = "Grid"
			g.columns = 3
			g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.size_flags_vertical = Control.SIZE_EXPAND_FILL
			g.set("custom_constants/separation", 12)
			tab.add_child(g)
			tabs.add_child(tab)
			tabs.set_tab_title(i, "Category %d" % (i + 1))
			_populate_grid_from_scene(g)

	# Update debug count
	var dbg = get_node_or_null("../ContentRoot/DebugCount")
	if dbg == null:
		dbg = get_node_or_null("DebugCount")
	if dbg:
		dbg.text = "tabs=%d items_per_tab=%d" % [tabs.get_child_count() if tabs else 0, items_per_tab]

	print("[GalleryScreen] bound and populated %d tabs" % (tabs.get_child_count() if tabs else 0))

	# Diagnostic: defer detailed tree print to the idle frame so layout and min sizes are calculated
	call_deferred("_debug_print_tree", self)


func _debug_print_tree(node: Node, indent: String = "") -> void:
	if node == null:
		return
	# Basic info
	var info = "%s- %s (%s)" % [indent, str(node.name), str(node.get_class())]
	# If Control, include anchors / min size / size flags
	if node is Control:
		var c = node as Control
		info += " anchors=[%s,%s,%s,%s]" % [str(c.anchor_left), str(c.anchor_top), str(c.anchor_right), str(c.anchor_bottom)]
		# Safely get the effective minimum size; use get_minimum_size() when available
		var rect_min = "<n/a>"
		if c.has_method("get_minimum_size"):
			rect_min = str(c.get_minimum_size())
		info += " rect_min=%s" % rect_min
		info += " size_flags_h=%d v=%d" % [int(c.size_flags_horizontal), int(c.size_flags_vertical)]
	# If GridContainer, include columns and child_count
	if node is GridContainer:
		var g = node as GridContainer
		info += " Grid(columns=%d, children=%d)" % [int(g.columns), g.get_child_count()]
	# If TextureRect, include texture presence and stretch
	if node is TextureRect:
		var t = node as TextureRect
		var tex = t.texture
		var tex_path = "<none>"
		if tex and typeof(tex) != TYPE_NIL:
			if tex is Resource and tex.resource_path != "":
				tex_path = tex.resource_path
			else:
				tex_path = str(tex)
		info += " Texture=%s stretch=%s" % [tex_path, str(t.stretch_mode)]
	print("[GalleryScreen TREE] %s" % info)
	# Recurse children
	for ch in node.get_children():
		_debug_print_tree(ch, indent + "  ")

	# If this node is a GridContainer, also print its direct children names to help detect ordering issues
	if node is GridContainer:
		var names = []
		for ch in node.get_children():
			names.append(str(ch.name))
		print("[GalleryScreen DEBUG] Grid %s children_order=%s" % [str(node.get_path()), str(names)])

func _finalize_grid_layout(grid: GridContainer) -> void:
	if grid == null:
		return
	# Ensure the grid has a valid rect_size; if not, defer again briefly
	# Try to retrieve a runtime size safely. Prefer actual rect if available via get_minimum_size();
	# fall back to zero to trigger deferred retry.
	var grid_size = Vector2(0, 0)
	if grid.has_method("get_minimum_size"):
		grid_size = grid.get_minimum_size()
	# If size is not yet valid, defer and try again later
	if grid_size.x <= 0 or grid_size.y <= 0:
		call_deferred("_finalize_grid_layout", grid)
		return
	var cols = int(grid.columns)
	var total_w = grid_size.x
	var sep = 0
	# attempt to read separation safely
	if grid.has_method("get"):
		var s = grid.get("custom_constants/separation")
		if typeof(s) == TYPE_FLOAT or typeof(s) == TYPE_INT:
			sep = int(s)
	var cell_w = 0.0
	if cols > 0:
		cell_w = max(0.0, (total_w - float(max(0, cols - 1)) * sep) / cols)
	# compute rows based on child count
	var child_count = grid.get_child_count()
	var rows = int(ceil(float(child_count) / max(1, cols)))
	var cell_h = 0.0
	if rows > 0:
		cell_h = max(0.0, grid_size.y / rows)

	for ch in grid.get_children():
		if ch is Control:
			# enforce custom minimum size so GridContainer uses this as baseline
			if ch.has_method("set"):
				ch.custom_minimum_size = Vector2(cell_w, cell_h)
			# Recursively apply sizes to children so nested containers (CenterContainer/Silhouette) get constrained
			_apply_sizes_to_children(ch, cell_w, cell_h)

	# After forcing sizes, request a sort/layout update
	grid.queue_sort()

func _apply_sizes_to_children(node: Node, cell_w: float, cell_h: float) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Control:
			var c = child as Control
			# Default: make child fill the cell area
			c.anchor_left = 0
			c.anchor_top = 0
			c.anchor_right = 0
			c.anchor_bottom = 0
			# If this is a CenterContainer (SilhouetteContainer), size it to the top area
			if c is CenterContainer:
				var top_h = max(0.0, cell_h * 0.72)
				# constrain the center container's minimum size to the top area
				c.custom_minimum_size = Vector2(cell_w, top_h)
			elif c is TextureRect:
				# Constrain the silhouette to a reasonable target within the top area
				var padding = 12
				var max_w = max(0.0, cell_w - padding)
				var max_h = max(0.0, int(cell_h * 0.72) - padding)
				var target_w = min(max_w, 160)
				var target_h = min(max_h, 120)
				# set a constrained minimum size; CenterContainer will center the TextureRect
				c.custom_minimum_size = Vector2(target_w, target_h)
			else:
				c.custom_minimum_size = Vector2(cell_w, cell_h)
		# Recurse regardless
		_apply_sizes_to_children(child, cell_w, cell_h)

func _find_descendant(node: Node, name: String) -> Node:
	# Simple recursive search for a descendant node by name
	if node == null:
		return null
	for ch in node.get_children():
		if str(ch.name) == name:
			return ch
		var res = _find_descendant(ch, name)
		if res != null:
			return res
	return null
