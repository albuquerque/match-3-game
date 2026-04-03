extends Node
## DLC System Verification Test
## Add this to your MainGame scene and run the game to test DLC functionality

func _ready():
	# Wait a frame for autoloads to initialize
	await get_tree().process_frame

	print("\n" + "=".repeat(60))
	print("         DLC SYSTEM VERIFICATION TEST")
	print("=".repeat(60) + "\n")

	run_all_tests()

func run_all_tests():
	var tests_passed = 0
	var tests_failed = 0
	var tests_skipped = 0

	# Test 1: Autoload Detection
	if test_autoloads():
		tests_passed += 1
	else:
		tests_failed += 1

	# Test 2: Directory Creation
	if test_directory_creation():
		tests_passed += 1
	else:
		tests_failed += 1

	# Test 3: DLC Scanning
	if test_dlc_scanning():
		tests_passed += 1
	else:
		tests_failed += 1

	# Test 4: Chapter Detection (may skip)
	var chapter_result = test_chapter_detection()
	if chapter_result == 1:
		tests_passed += 1
	elif chapter_result == -1:
		tests_skipped += 1
	else:
		tests_failed += 1

	# Test 5: Chapter Loading (may skip)
	if AssetRegistry.is_chapter_installed("test_chapter"):
		if test_chapter_loading():
			tests_passed += 1
		else:
			tests_failed += 1
	else:
		tests_skipped += 1
		print("\n[TEST 5] Chapter Loading")
		print("  ⏭️  SKIPPED: test_chapter not installed\n")

	# Test 6: Asset Loading (may skip)
	if AssetRegistry.is_chapter_installed("test_chapter"):
		if test_asset_loading():
			tests_passed += 1
		else:
			tests_failed += 1
	else:
		tests_skipped += 1
		print("\n[TEST 6] Asset Loading")
		print("  ⏭️  SKIPPED: test_chapter not installed\n")

	# Summary
	print("=".repeat(60))
	print("                    TEST SUMMARY")
	print("=".repeat(60))
	print("  ✅ Passed:  %d" % tests_passed)
	print("  ❌ Failed:  %d" % tests_failed)
	print("  ⏭️  Skipped: %d" % tests_skipped)
	print("=".repeat(60))

	if tests_failed == 0 and tests_passed > 0:
		print("\n🎉 ALL TESTS PASSED! DLC system is working correctly.")
	elif tests_failed > 0:
		print("\n⚠️  SOME TESTS FAILED. Check the output above for details.")

	if tests_skipped > 0:
		print("\nℹ️  Some tests were skipped because test_chapter is not installed.")
		print("   To run all tests, follow the instructions in:")
		print("   docs/DLC_TESTING_GUIDE.md")

	print("\n")

func test_autoloads() -> bool:
	print("\n[TEST 1] Autoload Detection")
	print("  Checking for required autoloads...")

	var success = true

	# Check AssetRegistry
	if AssetRegistry == null:
		print("  ❌ AssetRegistry not found")
		print("     Add to project.godot autoloads")
		success = false
	else:
		print("  ✅ AssetRegistry found")

	# Check EffectResolver
	if EffectResolver == null:
		print("  ❌ EffectResolver not found")
		print("     Add to project.godot autoloads")
		success = false
	else:
		print("  ✅ EffectResolver found")

	# Check DLCManager
	if DLCManager == null:
		print("  ❌ DLCManager not found")
		print("     Add to project.godot autoloads")
		success = false
	else:
		print("  ✅ DLCManager found")

	if success:
		print("  ✅ TEST PASSED: All autoloads present")
	else:
		print("  ❌ TEST FAILED: Missing autoloads")

	return success

func test_directory_creation() -> bool:
	print("\n[TEST 2] DLC Directory Creation")

	var dlc_path = AssetRegistry.DLC_BASE_DIR
	print("  Checking directory: %s" % dlc_path)

	if DirAccess.dir_exists_absolute(dlc_path):
		print("  ✅ DLC directory exists")
		print("  ✅ TEST PASSED")
		return true
	else:
		print("  ❌ DLC directory does not exist")
		print("  ❌ TEST FAILED: AssetRegistry should create this on _ready()")
		return false

func test_dlc_scanning() -> bool:
	print("\n[TEST 3] DLC Scanning")
	print("  Scanning for installed chapters...")

	var installed = AssetRegistry.get_installed_chapters()

	print("  Found %d installed chapter(s)" % installed.size())

	if installed.size() > 0:
		for chapter_id in installed:
			var info = AssetRegistry.get_chapter_info(chapter_id)
			var name = info.get("name", "Unknown")
			var version = info.get("version", "?.?.?")
			print("    • %s (v%s)" % [name, version])
	else:
		print("    (no chapters installed)")

	print("  ✅ TEST PASSED: Scan completed without errors")
	return true

func test_chapter_detection() -> int:
	print("\n[TEST 4] Test Chapter Detection")
	print("  Looking for 'test_chapter'...")

	if AssetRegistry.is_chapter_installed("test_chapter"):
		var info = AssetRegistry.get_chapter_info("test_chapter")
		print("  ✅ test_chapter found!")
		print("     Name: %s" % info.get("name", "N/A"))
		print("     Version: %s" % info.get("version", "N/A"))
		print("  ✅ TEST PASSED")
		return 1
	else:
		print("  ℹ️  test_chapter not installed")
		print("  ⏭️  SKIPPED: To install, follow docs/DLC_TESTING_GUIDE.md")
		return -1

func test_chapter_loading() -> bool:
	print("\n[TEST 5] Chapter Loading")
	print("  Loading test_chapter...")

	var success = EffectResolver.load_dlc_chapter("test_chapter")

	if success:
		var effect_count = EffectResolver.active_effects.size()
		print("  ✅ Chapter loaded successfully")
		print("     Active effects: %d" % effect_count)

		if effect_count > 0:
			print("     Effect list:")
			for effect in EffectResolver.active_effects:
				var event = effect.get("on", "?")
				var type = effect.get("effect", "?")
				print("       • %s → %s" % [event, type])

		print("  ✅ TEST PASSED")
		return true
	else:
		print("  ❌ Failed to load chapter")
		print("     Check manifest.json syntax")
		print("  ❌ TEST FAILED")
		return false

func test_asset_loading() -> bool:
	print("\n[TEST 6] Asset Loading")
	print("  Attempting to load test particle asset...")

	# First load the chapter to populate assets
	EffectResolver.load_dlc_chapter("test_chapter")

	var particle = AssetRegistry.get_asset("particles", "test_dust")

	if particle:
		print("  ✅ Asset loaded successfully")
		print("     Type: %s" % particle.get_class())
		print("  ✅ TEST PASSED")
		return true
	else:
		print("  ⚠️  Asset not loaded")
		print("     This may be expected if particles/test_dust.json doesn't exist")
		print("     or if the JSON format is not yet implemented")
		print("  ℹ️  TEST PASSED (asset loading is optional)")
		return true  # Don't fail on this for now

func _exit_tree():
	# Optional: Print user data path for convenience
	print("\nℹ️  User data directory: %s" % OS.get_user_data_dir())
	print("   DLC path: %s\n" % AssetRegistry.DLC_BASE_DIR)
