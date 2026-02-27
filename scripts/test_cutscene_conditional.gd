extends Node

var NodeResolvers = null

func _ensure_resolvers():
    if NodeResolvers == null:
        var s = load("res://scripts/helpers/node_resolvers_api.gd")
        if s != null and typeof(s) != TYPE_NIL:
            NodeResolvers = s
        else:
            NodeResolvers = load("res://scripts/helpers/node_resolvers_shim.gd")

## Test script for cutscene and conditional branching
## Run this from the console or attach to a test scene

func _ready():
    _ensure_resolvers()
	print("\n" + "=".repeat(80))
	print("CUTSCENE & CONDITIONAL BRANCHING TEST")
	print("=".repeat(80))

	# Wait a frame for autoloads to be ready
	await get_tree().process_frame

	print("\n[TEST] Step 1: Loading test_flow_simple...")
	var xd = NodeResolvers._get_xd()
	var success = xd.load_flow("test_flow_simple") if xd and xd.has_method("load_flow") else false
	if not success:
		print("[TEST] ❌ FAILED to load test flow!")
		return

	print("[TEST] ✅ Flow loaded successfully")
	if xd and xd.parser:
		print("[TEST] Flow has %d nodes" % xd.parser.get_flow_length(xd.current_flow))
	else:
		print("[TEST] Flow parser unavailable")

	print("\n[TEST] Step 2: Starting flow...")
	print("[TEST] This should process level_01 node")
	if xd and xd.has_method("start_flow"):
		xd.start_flow()

	print("\n[TEST] Step 3: Simulating level completion...")
	await get_tree().create_timer(1.0).timeout

	# Simulate level complete event
	print("[TEST] Emitting level_complete for level_01")
	var eb = NodeResolvers._get_evbus()
	if eb and eb.has_method("level_complete"):
		eb.level_complete.emit("level_01", {"score": 1000, "stars": 3})

	print("\n[TEST] Step 4: Waiting for flow to process...")
	await get_tree().create_timer(1.0).timeout

	print("\n[TEST] Step 5: Checking current state...")
	if xd and xd.has_method("debug_info"):
		xd.debug_info()

	print("\n[TEST] What should have happened:")
	print("[TEST]   1. Level_01 node processed")
	print("[TEST]   2. Reward node granted 100 coins and unlocked test_reward_1")
	print("[TEST]   3. Conditional evaluated: reward_unlocked('test_reward_1') = TRUE")
	print("[TEST]   4. Cutscene node inserted and executed (waited 2 seconds)")
	print("[TEST]   5. Flow should now be at level_02 node")

	print("\n[TEST] Expected console messages:")
	print("[TEST]   - '[ExperienceDirector] Evaluating conditional node'")
	print("[TEST]   - '[ExperienceDirector] Condition result: true'")
	print("[TEST]   - '[ExperienceDirector] Inserted 1 branch node(s) at index X'")
	print("[TEST]   - '[CutsceneExecutor] Waiting for duration: 2.0'")
	print("[TEST]   - '[CutsceneExecutor] Duration wait complete'")

	print("\n" + "=".repeat(80))
	print("TEST COMPLETE - Check console output above")
	print("=".repeat(80) + "\n")

	# Don't auto-quit - let user inspect
	# get_tree().quit()
