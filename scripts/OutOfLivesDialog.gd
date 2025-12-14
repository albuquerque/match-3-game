extends Control

# Out of Lives dialog - shown when player has no lives

signal refill_requested(method: String)
signal dialog_closed

@onready var lives_label = $Panel/VBoxContainer/LivesLabel
@onready var gem_refill_button = $Panel/VBoxContainer/ButtonContainer/GemRefillButton
@onready var watch_ad_button = $Panel/VBoxContainer/ButtonContainer/WatchAdButton
@onready var wait_button = $Panel/VBoxContainer/ButtonContainer/WaitButton
@onready var timer_label = $Panel/VBoxContainer/TimerLabel

const GEM_REFILL_COST = 50

func _ready():
	visible = false

	if gem_refill_button:
		gem_refill_button.pressed.connect(_on_gem_refill_pressed)
	if watch_ad_button:
		watch_ad_button.pressed.connect(_on_watch_ad_pressed)
	if wait_button:
		wait_button.pressed.connect(_on_wait_pressed)

	# Connect to AdMob signals
	if AdMobManager:
		AdMobManager.rewarded_ad_loaded.connect(_on_ad_loaded)
		AdMobManager.user_earned_reward.connect(_on_ad_reward_earned)
		print("[OutOfLivesDialog] Connected to AdMobManager signals")
		print("[OutOfLivesDialog] AdMobManager initialized:", AdMobManager.is_initialized)
		print("[OutOfLivesDialog] Ad ready:", AdMobManager.is_rewarded_ad_ready())
	else:
		print("[OutOfLivesDialog] WARNING: AdMobManager not found!")

func _process(_delta):
	if visible and RewardManager.get_lives() < RewardManager.MAX_LIVES:
		var time_remaining = RewardManager.get_time_until_next_life()
		var minutes = int(time_remaining / 60)
		var seconds = int(time_remaining) % 60
		timer_label.text = "Next life in: %02d:%02d" % [minutes, seconds]

		# If a life regenerated, close dialog
		if RewardManager.get_lives() > 0:
			_close_dialog()

func show_dialog():
	"""Show the out of lives dialog"""
	visible = true
	modulate = Color.TRANSPARENT

	# Update button states
	_update_button_states()

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

	print("[OutOfLivesDialog] Showing dialog - Lives: %d/%d" % [RewardManager.get_lives(), RewardManager.MAX_LIVES])

func _update_button_states():
	"""Update button enabled states based on available resources"""
	var gems = RewardManager.get_gems()

	if gem_refill_button:
		gem_refill_button.disabled = (gems < GEM_REFILL_COST)
		gem_refill_button.text = "Refill (%d 💎)" % GEM_REFILL_COST

	# Update watch ad button based on ad availability
	if watch_ad_button:
		if AdMobManager and AdMobManager.is_rewarded_ad_ready():
			watch_ad_button.disabled = false
			watch_ad_button.text = "Watch Ad (+1 ❤️)"
		else:
			watch_ad_button.disabled = true
			watch_ad_button.text = "Loading Ad..."

func _on_gem_refill_pressed():
	"""Player chose to spend gems to refill lives"""
	if RewardManager.spend_gems(GEM_REFILL_COST):
		RewardManager.refill_lives()
		print("[OutOfLivesDialog] Lives refilled with gems")
		refill_requested.emit("gems")
		_close_dialog()
	else:
		print("[OutOfLivesDialog] Not enough gems!")
		# TODO: Show "not enough gems" message

func _on_watch_ad_pressed():
	"""Player chose to watch an ad for a life"""
	print("[OutOfLivesDialog] Player requesting to watch ad...")

	if not AdMobManager:
		print("[OutOfLivesDialog] AdMobManager not available")
		return

	# Disable button while ad is loading/showing
	if watch_ad_button:
		watch_ad_button.disabled = true
		watch_ad_button.text = "Loading..."

	# Show rewarded ad - Don't await here, let the signal handle it
	AdMobManager.show_rewarded_ad()
	print("[OutOfLivesDialog] Ad request sent to AdMobManager")


func _on_ad_watch_completed():
	"""Called when player successfully watches ad"""
	print("[OutOfLivesDialog] Ad watch completed!")
	# Reward is granted via AdMobManager signal

func _on_ad_loaded():
	"""Called when ad finishes loading"""
	print("[OutOfLivesDialog] Ad loaded and ready")
	_update_button_states()

func _on_ad_reward_earned(reward_type: String, reward_amount: int):
	"""Called when player earns reward from ad"""
	print("[OutOfLivesDialog] ========== AD REWARD RECEIVED ==========")
	print("[OutOfLivesDialog] Reward type: %s" % reward_type)
	print("[OutOfLivesDialog] Reward amount: %d" % reward_amount)
	print("[OutOfLivesDialog] Lives BEFORE adding: %d/%d" % [RewardManager.get_lives(), RewardManager.MAX_LIVES])

	# Grant the life
	RewardManager.add_life(reward_amount)

	print("[OutOfLivesDialog] Lives AFTER adding: %d/%d" % [RewardManager.get_lives(), RewardManager.MAX_LIVES])
	print("[OutOfLivesDialog] ====================================")

	# Emit signal and close dialog
	refill_requested.emit("ad")
	_close_dialog()

func _on_wait_pressed():
	"""Player chose to wait for life regeneration"""
	print("[OutOfLivesDialog] Player chose to wait")
	_close_dialog()

func _close_dialog():
	"""Close the dialog with animation"""
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(_on_dialog_close_complete)

func _on_dialog_close_complete():
	visible = false
	dialog_closed.emit()

