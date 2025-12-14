class_name AdMob extends Object

## GDScript interface for the DroidAdMob Android plugin
##
## This class provides a convenient way to access AdMob functionality in Godot.
## It supports banner ads, interstitial ads, and rewarded video ads.

var _plugin_name = "DroidAdMob"
var _plugin_singleton

# Signals - connect to these in your game
signal ad_loaded
signal ad_failed_to_load(error_message: String)
signal ad_opened
signal ad_closed
signal ad_impression
signal ad_clicked
signal rewarded(type: String, amount: int)
signal interstitial_loaded
signal interstitial_failed_to_load(error_message: String)
signal rewarded_ad_loaded
signal rewarded_ad_failed_to_load(error_message: String)
signal consent_info_updated
signal consent_info_update_failed(error_message: String)
signal consent_form_dismissed
signal consent_form_failed(error_message: String)
signal consent_status_changed(status: int)

func _init():
	if Engine.has_singleton(_plugin_name):
		_plugin_singleton = Engine.get_singleton(_plugin_name)
		_connect_signals()
	else:
		printerr("AdMob plugin not found. Make sure the plugin is enabled and you're running on Android.")

## Connect plugin signals to this class's signals
func _connect_signals():
	if _plugin_singleton:
		_plugin_singleton.connect("ad_loaded", _on_ad_loaded)
		_plugin_singleton.connect("ad_failed_to_load", _on_ad_failed_to_load)
		_plugin_singleton.connect("ad_opened", _on_ad_opened)
		_plugin_singleton.connect("ad_closed", _on_ad_closed)
		_plugin_singleton.connect("ad_impression", _on_ad_impression)
		_plugin_singleton.connect("ad_clicked", _on_ad_clicked)
		_plugin_singleton.connect("rewarded", _on_rewarded)
		_plugin_singleton.connect("interstitial_loaded", _on_interstitial_loaded)
		_plugin_singleton.connect("interstitial_failed_to_load", _on_interstitial_failed_to_load)
		_plugin_singleton.connect("rewarded_ad_loaded", _on_rewarded_ad_loaded)
		_plugin_singleton.connect("rewarded_ad_failed_to_load", _on_rewarded_ad_failed_to_load)
		_plugin_singleton.connect("consent_info_updated", _on_consent_info_updated)
		_plugin_singleton.connect("consent_info_update_failed", _on_consent_info_update_failed)
		_plugin_singleton.connect("consent_form_dismissed", _on_consent_form_dismissed)
		_plugin_singleton.connect("consent_form_failed", _on_consent_form_failed)
		_plugin_singleton.connect("consent_status_changed", _on_consent_status_changed)

# Signal handlers that forward to local signals
func _on_ad_loaded():
	ad_loaded.emit()

func _on_ad_failed_to_load(error_message: String):
	ad_failed_to_load.emit(error_message)

func _on_ad_opened():
	ad_opened.emit()

func _on_ad_closed():
	ad_closed.emit()

func _on_ad_impression():
	ad_impression.emit()

func _on_ad_clicked():
	ad_clicked.emit()

func _on_rewarded(type: String, amount: int):
	rewarded.emit(type, amount)

func _on_interstitial_loaded():
	interstitial_loaded.emit()

func _on_interstitial_failed_to_load(error_message: String):
	interstitial_failed_to_load.emit(error_message)

func _on_rewarded_ad_loaded():
	rewarded_ad_loaded.emit()

func _on_rewarded_ad_failed_to_load(error_message: String):
	rewarded_ad_failed_to_load.emit(error_message)

func _on_consent_info_updated():
	consent_info_updated.emit()

func _on_consent_info_update_failed(error_message: String):
	consent_info_update_failed.emit(error_message)

func _on_consent_form_dismissed():
	consent_form_dismissed.emit()

func _on_consent_form_failed(error_message: String):
	consent_form_failed.emit(error_message)

func _on_consent_status_changed(status: int):
	consent_status_changed.emit(status)

## Initialize the AdMob SDK
## @param is_test_mode: If true, uses test ads. Always use true during development!
func initialize(is_test_mode: bool = true) -> void:
	if _plugin_singleton:
		_plugin_singleton.initialize(is_test_mode)
	else:
		printerr("AdMob plugin not available")

## Get the test banner ad unit ID (for testing purposes)
func get_test_banner_ad_unit() -> String:
	if _plugin_singleton:
		return _plugin_singleton.getTestBannerAdUnit()
	return ""

## Get the test interstitial ad unit ID (for testing purposes)
func get_test_interstitial_ad_unit() -> String:
	if _plugin_singleton:
		return _plugin_singleton.getTestInterstitialAdUnit()
	return ""

## Get the test rewarded ad unit ID (for testing purposes)
func get_test_rewarded_ad_unit() -> String:
	if _plugin_singleton:
		return _plugin_singleton.getTestRewardedAdUnit()
	return ""

## Load and display a banner ad
## @param ad_unit_id: Your AdMob ad unit ID
## @param position: "top" or "bottom" (default: "bottom")
## @param size: "banner", "large_banner", "medium_rectangle", "full_banner", or "leaderboard" (default: "banner")
func load_banner(ad_unit_id: String, position: String = "bottom", size: String = "banner") -> void:
	if _plugin_singleton:
		_plugin_singleton.loadBanner(ad_unit_id, position, size)
	else:
		printerr("AdMob plugin not available")

## Remove the currently displayed banner ad
func remove_banner() -> void:
	if _plugin_singleton:
		_plugin_singleton.removeBanner()
	else:
		printerr("AdMob plugin not available")

## Hide the banner ad (without removing it)
func hide_banner() -> void:
	if _plugin_singleton:
		_plugin_singleton.hideBanner()
	else:
		printerr("AdMob plugin not available")

## Show the banner ad (if previously hidden)
func show_banner() -> void:
	if _plugin_singleton:
		_plugin_singleton.showBanner()
	else:
		printerr("AdMob plugin not available")

## Load an interstitial ad
## @param ad_unit_id: Your AdMob ad unit ID
func load_interstitial(ad_unit_id: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.loadInterstitial(ad_unit_id)
	else:
		printerr("AdMob plugin not available")

## Show the loaded interstitial ad
func show_interstitial() -> void:
	if _plugin_singleton:
		_plugin_singleton.showInterstitial()
	else:
		printerr("AdMob plugin not available")

## Check if an interstitial ad is loaded and ready to show
func is_interstitial_loaded() -> bool:
	if _plugin_singleton:
		return _plugin_singleton.isInterstitialLoaded()
	return false

## Load a rewarded video ad
## @param ad_unit_id: Your AdMob ad unit ID
func load_rewarded(ad_unit_id: String) -> void:
	if _plugin_singleton:
		_plugin_singleton.loadRewarded(ad_unit_id)
	else:
		printerr("AdMob plugin not available")

## Show the loaded rewarded video ad
func show_rewarded() -> void:
	if _plugin_singleton:
		_plugin_singleton.showRewarded()
	else:
		printerr("AdMob plugin not available")

## Check if a rewarded ad is loaded and ready to show
func is_rewarded_loaded() -> bool:
	if _plugin_singleton:
		return _plugin_singleton.isRewardedLoaded()
	return false

# Consent Management (GDPR/Privacy)

## Request consent information update
## Call this before initializing ads, especially in EU/UK regions
## @param is_test_mode: Enable test mode for consent (simulates EEA region)
## @param test_device_id: Your test device ID (empty string for production)
func request_consent_info_update(is_test_mode: bool = false, test_device_id: String = "") -> void:
	if _plugin_singleton:
		_plugin_singleton.requestConsentInfoUpdate(is_test_mode, test_device_id)
	else:
		printerr("AdMob plugin not available")

## Load and show consent form if required
## Call after consent_info_updated signal is received
func load_consent_form() -> void:
	if _plugin_singleton:
		_plugin_singleton.loadConsentForm()
	else:
		printerr("AdMob plugin not available")

## Get current consent status
## Returns: 0=UNKNOWN, 1=NOT_REQUIRED, 2=REQUIRED, 3=OBTAINED
func get_consent_status() -> int:
	if _plugin_singleton:
		return _plugin_singleton.getConsentStatus()
	return 0

## Check if privacy options are required
## Returns true if user should be able to change consent preferences
func is_privacy_options_required() -> bool:
	if _plugin_singleton:
		return _plugin_singleton.isPrivacyOptionsRequired()
	return false

## Show privacy options form
## Allows user to update their consent preferences
func show_privacy_options_form() -> void:
	if _plugin_singleton:
		_plugin_singleton.showPrivacyOptionsForm()
	else:
		printerr("AdMob plugin not available")

## Reset consent information (for testing)
func reset_consent_information() -> void:
	if _plugin_singleton:
		_plugin_singleton.resetConsentInformation()
	else:
		printerr("AdMob plugin not available")

