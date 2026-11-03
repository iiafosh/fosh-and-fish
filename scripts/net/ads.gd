extends Node
## Rewarded ads (autoload "Ads"): watch an ad to the end, get its reward (VFData.AD_REWARDS, given by
## VF.grant_ad, AD_DAILY_MAX a day). AdMob through addons/admob (poingstudios, Android only).
##
## mode "admob": the Google Play build (export feature "play", which has the AdMob plugin). At start: Google's consent form where the law needs one (UMP; EEA/UK), then
##   MobileAds.initialize() and one rewarded ad loaded ahead, so "Watch" plays at once.
##   The ad unit is data/monetization.json "admob_rewarded_android" (Google's test unit until you put
##   yours there); the AdMob App ID is a project setting (see docs/PLAY_STORE.md).
## mode "test": debug builds and --test-ads: a fake 2.5 s "ad", then the reward (for testing).
## mode "none": PC / web / GitHub APK release builds: no ads.

signal changed

const TEST_UNIT := "ca-app-pub-3940256099942544/5224354917"   # Google's always-filled test rewarded unit

var mode := "none"                 # admob | test | none
var watching := ""                 # the reward whose ad is playing
var loaded := false                # an AdMob ad is ready to show
var message := ""
var unit_id := TEST_UNIT
var _ad = null
var _listener = null
var _full = null
var _loading := false
var _earned := false


func _ready() -> void:
	var cfg := Store._config()
	unit_id = String(cfg.get("admob_rewarded_android", TEST_UNIT))
	if OS.has_feature("play") and Store.class_by_name("RewardedAdLoader") != null:
		mode = "admob"
		_consent_then_start()
	elif "--test-ads" in OS.get_cmdline_user_args() or (OS.is_debug_build() and bool(cfg.get("test_store_in_debug", true))):
		mode = "test"


func available() -> bool:
	return mode != "none"


## can this reward be watched right now?
func can_watch(id: String) -> bool:
	return available() and watching == "" and VF.ad_left(id) > 0 and (mode == "test" or loaded)


func watch(id: String) -> void:
	if not can_watch(id):
		if mode == "admob" and not loaded:
			message = "The ad is still loading. Try again in a moment."
			_load()
			changed.emit()
		return
	message = ""
	watching = id
	changed.emit()
	if mode == "test":
		await get_tree().create_timer(2.5).timeout
		_reward(id)
		watching = ""
		changed.emit()
		return
	_earned = false
	loaded = false
	_ad.show(_listener)


func _reward(id: String) -> void:
	var got: Dictionary = VF.grant_ad(id)
	if got.has("error"): message = got.error


# ------------------------------------------------------------------ AdMob
func _cls(n: String):
	return Store.class_by_name(n)


func _ump():
	return get_node_or_null("/root/UserMessagingPlatform") if has_node("/root/UserMessagingPlatform") else _cls("UserMessagingPlatform")


## Google's consent form first (UMP: only where the law needs one), then ads either way
func _consent_then_start() -> void:
	var ump = _ump()
	var params_cls = _cls("ConsentRequestParameters")
	if ump == null or params_cls == null:
		_start()
		return
	var request = params_cls.new()
	request.tag_for_under_age_of_consent = false
	ump.consent_information.update(request, _on_consent_info, _on_consent_error)


func _on_consent_info() -> void:
	var ump = _ump()
	if ump.consent_information.get_is_consent_form_available():
		ump.load_consent_form(_on_consent_form, _on_consent_error)
	else:
		_start()


func _on_consent_form(form) -> void:
	var ump = _ump()
	if ump.consent_information.get_consent_status() == ump.consent_information.ConsentStatus.REQUIRED:
		form.show(_on_consent_error)                 # closed (with or without an error): start either way
	else:
		_start()


func _on_consent_error(_err = null) -> void:
	_start()


var _started := false

func _start() -> void:
	if _started: return
	_started = true
	var mob = get_node_or_null("/root/MobileAds") if has_node("/root/MobileAds") else _cls("MobileAds")
	if mob != null: mob.initialize()
	_listener = _cls("OnUserEarnedRewardListener").new()
	_listener.on_user_earned_reward = func(_item): _earned = true
	_full = _cls("FullScreenContentCallback").new()
	_full.on_ad_dismissed_full_screen_content = _closed
	_full.on_ad_failed_to_show_full_screen_content = func(_err):
		message = "The ad couldn't play. Try again later."
		_closed()
	_load()


func _load() -> void:
	if _loading or loaded or mode != "admob": return
	_loading = true
	if _ad != null:
		_ad.destroy()
		_ad = null
	var cb = _cls("RewardedAdLoadCallback").new()
	cb.on_ad_loaded = func(ad):
		_loading = false
		_ad = ad
		_ad.full_screen_content_callback = _full
		loaded = true
		changed.emit()
	cb.on_ad_failed_to_load = func(err):
		_loading = false
		loaded = false
		print("Ads: no ad (%s)" % str(err.message if err != null else "?"))
		get_tree().create_timer(30.0).timeout.connect(_load)        # try again later
		changed.emit()
	_cls("RewardedAdLoader").new().load(unit_id, _cls("AdRequest").new(), cb)


func _closed() -> void:
	var id := watching
	watching = ""
	if _earned and id != "":
		_reward(id)
	elif id != "" and message == "":
		message = "Watch the whole ad to get the reward."
	_earned = false
	changed.emit()
	_load()                                                        # the next one, ready ahead
