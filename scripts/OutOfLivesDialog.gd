extends Control

var NodeResolvers = null

# Out of Lives dialog - shown when player has no lives

signal refill_requested(method: String)
signal dialog_closed

@onready var lives_label = $Panel/VBoxContainer/LivesLabel
@onready var gem_refill_button = $Panel/VBoxContainer/ButtonContainer/GemRefillButton
@onready var watch_ad_button = $Panel/VBoxContainer/ButtonContainer/WatchAdButton
@onready var wait_button = $Panel/VBoxContainer/ButtonContainer/WaitButton
@onready var timer_label = $Panel/VBoxContainer/TimerLabel

const GEM_REFILL_COST = 50

func _init_resolvers():
    if NodeResolvers == null:
        var s = load("res://scripts/helpers/node_resolvers_api.gd")
        if s != null and typeof(s) != TYPE_NIL and s.has_method("_get_rm"):
            NodeResolvers = s
        else:
            NodeResolvers = load("res://scripts/helpers/node_resolvers_shim.gd")

func _ready():
    _init_resolvers()
    visible = false

    if gem_refill_button:
        gem_refill_button.pressed.connect(_on_gem_refill_pressed)
    if watch_ad_button:
        watch_ad_button.pressed.connect(_on_watch_ad_pressed)
    if wait_button:
        wait_button.pressed.connect(_on_wait_pressed)

    # Connect to AdMob signals via resolver
    var ad_manager = NodeResolvers._get_adm()
    if ad_manager == null and has_method("get_tree"):
        var _root = get_tree().root
        if _root:
            ad_manager = _root.get_node_or_null("AdMobManager")
    if ad_manager:
        if ad_manager.has_method("rewarded_ad_loaded") and ad_manager.rewarded_ad_loaded:
            ad_manager.rewarded_ad_loaded.connect(_on_ad_loaded)
        if ad_manager.has_method("user_earned_reward") and ad_manager.user_earned_reward:
            ad_manager.user_earned_reward.connect(_on_ad_reward_earned)
        print("[OutOfLivesDialog] Connected to AdMobManager signals")
        if ad_manager.has_method("is_initialized"):
            print("[OutOfLivesDialog] AdMobManager initialized:", ad_manager.is_initialized)
        if ad_manager.has_method("is_rewarded_ad_ready"):
            print("[OutOfLivesDialog] Ad ready:", ad_manager.is_rewarded_ad_ready())
    else:
        print("[OutOfLivesDialog] WARNING: AdMobManager not found!")

func _process(_delta):
    if visible:
        var rm = NodeResolvers._get_rm()
        if rm == null and has_method("get_tree"):
            var _r = get_tree().root
            if _r:
                rm = _r.get_node_or_null("RewardManager")
        if rm and rm.get_lives() < rm.MAX_LIVES:
            var time_remaining = rm.get_time_until_next_life()
            var minutes = int(time_remaining / 60)
            var seconds = int(time_remaining) % 60
            timer_label.text = tr("UI_NEXT_LIFE_IN") % [minutes, seconds]

            # If a life regenerated, close dialog
            if rm and rm.get_lives() > 0:
                _close_dialog()

func show_dialog():
    """Show the out of lives dialog"""
    visible = true
    modulate = Color.TRANSPARENT

    # Update button states
    _update_button_states()

    var tween = create_tween()
    tween.tween_property(self, "modulate", Color.WHITE, 0.3)

    var rm_show = NodeResolvers._get_rm()
    print("[OutOfLivesDialog] Showing dialog - Lives: %d/%d" % [rm_show.get_lives() if rm_show and rm_show.has_method("get_lives") else 0, rm_show.MAX_LIVES if rm_show else 0])

func _update_button_states():
    """Update button enabled states based on available resources"""
    var rm_gems = NodeResolvers._get_rm()
    if rm_gems == null and has_method("get_tree"):
        var _r2 = get_tree().root
        if _r2:
            rm_gems = _r2.get_node_or_null("RewardManager")
    var gems = 0
    if rm_gems and rm_gems.has_method("get_gems"):
        gems = rm_gems.get_gems()
    else:
        # If RewardManager autoload/class isn't available, default to 0 gems (UI will disable refill)
        gems = 0

    if gem_refill_button:
        gem_refill_button.disabled = (gems < GEM_REFILL_COST)
        gem_refill_button.text = tr("UI_REFILL_GEMS") % GEM_REFILL_COST

    # Update watch ad button based on ad availability
    if watch_ad_button:
        var ad_manager = NodeResolvers._get_adm()
        if ad_manager == null and has_method("get_tree"):
            var _r3 = get_tree().root
            if _r3:
                ad_manager = _r3.get_node_or_null("AdMobManager")
        if ad_manager and ad_manager.is_rewarded_ad_ready():
            watch_ad_button.disabled = false
            watch_ad_button.text = tr("UI_WATCH_AD_LIFE")
        else:
            watch_ad_button.disabled = true
            watch_ad_button.text = tr("UI_LOADING_AD")

func _on_gem_refill_pressed():
    """Player chose to spend gems to refill lives"""
    var rm_spend = NodeResolvers._get_rm()
    if rm_spend == null and has_method("get_tree"):
        var _r4 = get_tree().root
        if _r4:
            rm_spend = _r4.get_node_or_null("RewardManager")
    if rm_spend and rm_spend.has_method("spend_gems") and rm_spend.spend_gems(GEM_REFILL_COST):
        if rm_spend.has_method("refill_lives"):
            rm_spend.refill_lives()
        print("[OutOfLivesDialog] Lives refilled with gems")
        refill_requested.emit("gems")
        _close_dialog()
    else:
        print("[OutOfLivesDialog] Not enough gems!")

func _on_watch_ad_pressed():
    """Player chose to watch an ad for a life"""
    print("[OutOfLivesDialog] Player requesting to watch ad...")

    var ad_manager = NodeResolvers._get_adm()
    if ad_manager == null and has_method("get_tree"):
        var _r5 = get_tree().root
        if _r5:
            ad_manager = _r5.get_node_or_null("AdMobManager")

    if not ad_manager:
        print("[OutOfLivesDialog] AdMobManager not available")
        return

    # Disable button while ad is loading/showing
    if watch_ad_button:
        watch_ad_button.disabled = true
        watch_ad_button.text = tr("UI_LOADING")

    # Show rewarded ad - Don't await here, let the signal handle it
    ad_manager.show_rewarded_ad()
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

    # Grant the life (resolve RewardManager first)
    var rm_add = NodeResolvers._get_rm()
    if rm_add == null and has_method("get_tree"):
        var _r6 = get_tree().root
        if _r6:
            rm_add = _r6.get_node_or_null("RewardManager")
    print("[OutOfLivesDialog] Lives BEFORE adding: %d/%d" % [rm_add.get_lives() if rm_add and rm_add.has_method("get_lives") else 0, rm_add.MAX_LIVES if rm_add else 0])
    if rm_add and rm_add.has_method("add_life"):
        rm_add.add_life(reward_amount)

    print("[OutOfLivesDialog] Lives AFTER adding: %d/%d" % [rm_add.get_lives() if rm_add and rm_add.has_method("get_lives") else 0, rm_add.MAX_LIVES if rm_add else 0])
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
