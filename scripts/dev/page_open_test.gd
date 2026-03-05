extends Node

# Headless test: open and close a set of pages via PageManager to validate parsing and close behavior.

func _ready():
	print("[PAGE_OPEN_TEST] starting")
	# Wait longer for autoloads to initialize
	await get_tree().create_timer(1.0).timeout
	var NodeResolvers = null
	# Lazy-load resolver script after wait
	var s = load("res://scripts/helpers/node_resolvers_api.gd")
	if s != null and typeof(s) != TYPE_NIL:
		NodeResolvers = s
	else:
		NodeResolvers = load("res://scripts/helpers/node_resolvers_shim.gd")

	var pm = null
	# Wait up to 5s for PageManager to appear
	var attempts = 0
	while attempts < 50:
		if typeof(NodeResolvers) != TYPE_NIL:
			pm = NodeResolvers._get_pm()
		if pm == null:
			var rt = get_tree().root
			if rt:
				pm = rt.get_node_or_null("PageManager")
		if pm:
			break
		await get_tree().create_timer(0.1).timeout
		attempts += 1
		print("[PAGE_OPEN_TEST] waiting for PageManager... attempt=", attempts)

	if pm == null:
		print("[PAGE_OPEN_TEST] PageManager not found after wait - aborting")
		get_tree().quit()
		return

	print("[PAGE_OPEN_TEST] Found PageManager: ", pm)

	var pages = ["SettingsDialog", "WorldMap", "AchievementsPage", "ShopUI"]
	for p in pages:
		print("[PAGE_OPEN_TEST] Opening page:", p)
		var eb = null
		if typeof(NodeResolvers) != TYPE_NIL:
			eb = NodeResolvers._get_evbus()
		if eb and eb.has_method("emit_open_page"):
			print("[PAGE_OPEN_TEST] Emitting EventBus.open_page for:", p)
			eb.emit_open_page(p, {})
		else:
			print("[PAGE_OPEN_TEST] Calling PageManager.open for:", p)
			pm.open(p, {})

		# Wait up to 3s for page to open
		var waited = 0
		while waited < 60:
			await get_tree().create_timer(0.05).timeout
			waited += 1
			if pm.is_open(p):
				print("[PAGE_OPEN_TEST] Page open confirmed:", p)
				break
			# else keep waiting

		# Wait a bit to allow page to run _ready()
		await get_tree().create_timer(0.25).timeout

		# Attempt to close via PageManager
		print("[PAGE_OPEN_TEST] Closing page:", p)
		var closed = pm.close(p)
		if closed:
			print("[PAGE_OPEN_TEST] Closed page:", p)
		else:
			print("[PAGE_OPEN_TEST] Failed to close page (will force free if instance found):", p)
			# Try to free top instance matching name
			var top = pm.top_page()
			if top and top.name == p and top.node:
				top.node.queue_free()

		await get_tree().create_timer(0.05).timeout

	print("[PAGE_OPEN_TEST] Completed all pages")
	get_tree().quit()
