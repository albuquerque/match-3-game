extends Node

# AdMob Manager - Using custom compiled DroidAdMob plugin with GDPR consent

signal rewarded_ad_loaded
signal rewarded_ad_failed_to_load(error_message: String)
signal rewarded_ad_opened
signal rewarded_ad_closed
signal rewarded_ad_failed_to_show(error_message: String)
signal user_earned_reward(reward_type: String, reward_amount: int)

# Consent signals
signal consent_ready

var admob = null  # AdMob instance (created at runtime)
var is_initialized = false
var is_rewarded_ad_loaded = false
var pending_reward_callback: Callable
var consent_completed = false

var test_ad_timer: Timer

func _ready():
	print("[AdMobManager] Initializing AdMob with GDPR consent flow...")
	_initialize_admob()

func _initialize_admob():
	var is_real_device = OS.get_name() == "Android" or OS.get_name() == "iOS"

	if not is_real_device:
		print("[AdMobManager] Running on desktop - test mode enabled")
		is_initialized = false
		consent_completed = true
		consent_ready.emit()
		return

	admob = AdMob.new()

	admob.consent_info_updated.connect(_on_consent_info_updated)
	admob.consent_info_update_failed.connect(_on_consent_info_failed)
	admob.consent_form_dismissed.connect(_on_consent_form_dismissed)
	admob.consent_form_failed.connect(_on_consent_form_failed)

	admob.rewarded_ad_loaded.connect(_on_ad_loaded)
	admob.rewarded_ad_failed_to_load.connect(_on_ad_failed_to_load)
	admob.ad_opened.connect(_on_ad_opened)
	admob.ad_closed.connect(_on_ad_closed)
	admob.rewarded.connect(_on_user_earned_reward)

	print("[AdMobManager] AdMob wrapper initialized, signals connected")
	print("[AdMobManager] Starting GDPR consent flow...")

	admob.request_consent_info_update(false, "")

func _on_consent_info_updated():
	var status = admob.get_consent_status()
	print("[AdMobManager] Consent info updated, status: ", status)
	print("[AdMobManager] Status meanings: 0=UNKNOWN, 1=NOT_REQUIRED, 2=REQUIRED, 3=OBTAINED")

	admob.load_consent_form()

func _on_consent_info_failed(error: String):
	print("[AdMobManager] Consent info update failed: ", error)
	print("[AdMobManager] Proceeding with limited ads...")
	_complete_consent_flow()

func _on_consent_form_dismissed():
	var status = admob.get_consent_status()
	print("[AdMobManager] Consent form dismissed, final status: ", status)
	_complete_consent_flow()

func _on_consent_form_failed(error: String):
	print("[AdMobManager] Consent form failed: ", error)
	print("[AdMobManager] Proceeding with limited ads...")
	_complete_consent_flow()

func _complete_consent_flow():
	if consent_completed:
		return

	consent_completed = true
	var status = admob.get_consent_status()
	print("[AdMobManager] Consent flow complete, final status: ", status)
	print("[AdMobManager] Initializing AdMob SDK...")

	admob.initialize(true)
	is_initialized = true
	print("[AdMobManager] AdMob SDK initialized")

	consent_ready.emit()

	await get_tree().create_timer(1.0).timeout
	load_rewarded_ad()

func load_rewarded_ad():
	if not is_initialized or not admob:
		print("[AdMobManager] Not initialized, test mode")
		is_rewarded_ad_loaded = true
		rewarded_ad_loaded.emit()
		return

	var ad_unit_id = admob.get_test_rewarded_ad_unit()
	print("[AdMobManager] Loading rewarded ad with unit ID: ", ad_unit_id)
	admob.load_rewarded(ad_unit_id)
	is_rewarded_ad_loaded = false

func show_rewarded_ad(reward_callback: Callable = Callable()):
	pending_reward_callback = reward_callback

	if not is_initialized or not admob:
		print("[AdMobManager] Test mode - simulating ad watch")
		_start_test_ad_simulation()
		return

	if is_rewarded_ad_loaded:
		print("[AdMobManager] Showing rewarded ad...")
		admob.show_rewarded()
	else:
		print("[AdMobManager] Rewarded ad not loaded yet")
		rewarded_ad_failed_to_show.emit("Ad not loaded")

func is_rewarded_ad_ready() -> bool:
	if not is_initialized or not admob:
		return is_rewarded_ad_loaded
	return admob.is_rewarded_loaded()

func _on_ad_loaded():
	print("[AdMobManager] Rewarded ad loaded successfully!")
	is_rewarded_ad_loaded = true
	rewarded_ad_loaded.emit()

func _on_ad_failed_to_load(error_message: String):
	print("[AdMobManager] Rewarded ad failed to load: ", error_message)
	is_rewarded_ad_loaded = false
	rewarded_ad_failed_to_load.emit(error_message)

func _on_ad_opened():
	print("[AdMobManager] Ad opened")
	rewarded_ad_opened.emit()

func _on_ad_closed():
	print("[AdMobManager] Ad closed")
	rewarded_ad_closed.emit()
	is_rewarded_ad_loaded = false
	load_rewarded_ad()

func _on_ad_failed_to_show(error_message: String):
	print("[AdMobManager] Ad failed to show: ", error_message)
	rewarded_ad_failed_to_show.emit(error_message)
	is_rewarded_ad_loaded = false

func _on_user_earned_reward(reward_type: String, reward_amount: int):
	print("[AdMobManager] User earned reward: ", reward_type, " x", reward_amount)
	user_earned_reward.emit(reward_type, reward_amount)

	if pending_reward_callback and pending_reward_callback.is_valid():
		pending_reward_callback.call()
		pending_reward_callback = Callable()

func get_consent_status() -> int:
	if admob:
		return admob.get_consent_status()
	return 0

func is_privacy_options_required() -> bool:
	if admob:
		return admob.is_privacy_options_required()
	return false

func show_privacy_options_form():
	if admob:
		print("[AdMobManager] Showing privacy options form...")
		admob.show_privacy_options_form()
	else:
		print("[AdMobManager] AdMob not available, cannot show privacy options")

func reset_consent():
	if admob:
		print("[AdMobManager] Resetting consent information...")
		admob.reset_consent_information()
		print("[AdMobManager] Restart the app to see consent flow again")
	else:
		print("[AdMobManager] AdMob not available, cannot reset consent")

func _start_test_ad_simulation():
	print("[AdMobManager] Test ad simulation started (2 seconds)...")
	rewarded_ad_opened.emit()

	if not test_ad_timer:
		test_ad_timer = Timer.new()
		add_child(test_ad_timer)
		test_ad_timer.timeout.connect(_on_test_ad_complete)

	test_ad_timer.wait_time = 2.0
	test_ad_timer.one_shot = true
	test_ad_timer.start()

func _on_test_ad_complete():
	print("[AdMobManager] Test mode - Ad watched successfully!")
	user_earned_reward.emit("life", 1)
	rewarded_ad_closed.emit()

	if pending_reward_callback.is_valid():
		pending_reward_callback.call()
		pending_reward_callback = Callable()

