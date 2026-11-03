extends Node
## Real-money purchases (autoload "Store"): the Supporter Packs and Pearl packs (VFData.PACKS /
## PEARL_PACKS) through Google Play Billing (addons/GodotGooglePlayBilling, Android only).
##
## mode "play": the Google Play build (export feature "play", which has the billing plugin). Prices are Play's own local prices. A finished purchase is given to the
##   game with VF.grant_purchase(product, token) (the token makes sure it's never given twice), then
##   Pearl packs are consumed (they can be bought again) and Supporter Packs acknowledged (kept forever).
##   At start we also ask Play for anything bought but not finished (the game closed mid-purchase, a
##   slow payment, a reinstall).
## mode "test": debug builds and --test-store: every purchase succeeds at once (for testing the flow).
## mode "none": PC / web / GitHub APK release builds: purchases are in the Google Play version; what
##   you bought there comes with your account's cloud save.

signal changed

var mode := "none"                 # play | test | none
var online := false                # connected to Google Play (or the test store)
var prices := {}                   # product id -> Google Play's local price ("€1,99")
var busy := ""                     # the product being bought right now
var message := ""                  # the last thing worth telling the player
var _client = null                 # the plugin's BillingClient
var _billing = null                # its script (for the enums)


func _ready() -> void:
	var cfg := _config()
	_billing = class_by_name("BillingClient")
	if OS.has_feature("play") and _billing != null:
		mode = "play"
		_connect_play()
	elif "--test-store" in OS.get_cmdline_user_args() or (OS.is_debug_build() and bool(cfg.get("test_store_in_debug", true))):
		mode = "test"
		online = true
	else:
		mode = "none"


static func _config() -> Dictionary:
	var path := "res://data/monetization.json"
	if not FileAccess.file_exists(path): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## A global class (class_name) from an addon, or null when the addon isn't in this build.
static func class_by_name(cls: String):
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls: return load(c["path"])
	return null


func available() -> bool:
	return mode != "none" and online


static func all_ids() -> Array:
	return VFData.PACK_ORDER + VFData.PEARL_PACK_ORDER


func price(id: String) -> String:
	if prices.has(id): return prices[id]
	if VFData.PACKS.has(id): return VFData.PACKS[id].price
	if VFData.PEARL_PACKS.has(id): return VFData.PEARL_PACKS[id].price
	return ""


func owns(id: String) -> bool:
	return id in VF.packs


## Start buying a product. The result arrives later (changed + VF.grant_purchase).
func buy(id: String) -> void:
	if busy != "" or owns(id): return
	message = ""
	match mode:
		"test":
			VF.grant_purchase(id, "test-%d" % Time.get_ticks_usec())
			message = "Test purchase: nothing was charged."
		"play":
			if not online:
				message = "Connecting to Google Play... try again in a moment."
				_client.start_connection()
			else:
				if Backend.user_id != "":
					_client.set_obfuscated_account_id(Backend.user_id.sha256_text().substr(0, 32))   # helps Play spot fraud
				busy = id
				var r: Dictionary = _client.purchase(id)
				if int(r.get("response_code", 0)) != 0:
					busy = ""
					message = _friendly(int(r.get("response_code", 6)))
		_:
			message = "Purchases are in the Google Play version of fosh&fish. What you buy there shows up here when you sign in to the same account."
	changed.emit()


# ------------------------------------------------------------- Google Play
func _connect_play() -> void:
	_client = _billing.new()
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(func(): online = false; changed.emit())
	_client.connect_error.connect(func(code: int, msg: String):
		online = false
		message = _friendly(code)
		print("Store: can't connect to Google Play (%d) %s" % [code, msg])
		changed.emit())
	_client.query_product_details_response.connect(_on_details)
	_client.query_purchases_response.connect(func(r: Dictionary): _handle(r.get("purchases", [])))
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.consume_purchase_response.connect(func(r: Dictionary):
		if int(r.get("response_code", 0)) != 0: print("Store: consume failed ", r))
	_client.acknowledge_purchase_response.connect(func(r: Dictionary):
		if int(r.get("response_code", 0)) != 0: print("Store: acknowledge failed ", r))
	_client.start_connection()


func _on_connected() -> void:
	online = true
	_client.query_product_details(PackedStringArray(all_ids()), _billing.ProductType.INAPP)
	_client.query_purchases(_billing.ProductType.INAPP)       # bought earlier but not finished
	changed.emit()


func _on_details(r: Dictionary) -> void:
	for d in r.get("product_details", []):
		var offers = d.get("one_time_purchase_offer_details_list")
		if offers is Array and not offers.is_empty():
			prices[String(d.get("product_id", ""))] = String(offers[0].get("formatted_price", ""))
	changed.emit()


func _on_purchase_updated(r: Dictionary) -> void:
	busy = ""
	var code := int(r.get("response_code", 6))
	if code == 0:
		_handle(r.get("purchases", []))
	elif code == 7:                                            # ITEM_ALREADY_OWNED: finish it
		_client.query_purchases(_billing.ProductType.INAPP)
	elif code != 1:                                            # 1 = the player cancelled
		message = _friendly(code)
	changed.emit()


func _handle(purchases: Array) -> void:
	for p in purchases:
		if not p is Dictionary: continue
		var token := String(p.get("purchase_token", ""))
		if int(p.get("purchase_state", 0)) != int(_billing.PurchaseState.PURCHASED):
			message = "Your purchase is waiting for the payment to go through."
			continue
		for raw_id in p.get("product_ids", []):
			var id := String(raw_id)
			VF.grant_purchase(id, token)                       # (never twice for one token)
			if id in VFData.PEARL_PACK_ORDER:
				_client.consume_purchase(token)
			elif not bool(p.get("is_acknowledged", false)):
				_client.acknowledge_purchase(token)
	changed.emit()


static func _friendly(code: int) -> String:
	match code:
		2, 12, -1, -3: return "Can't reach Google Play. Check your internet and try again."
		3: return "Google Play purchases aren't available on this device."
		4: return "That item isn't available right now."
		7: return "You already own that."
	return "The purchase didn't go through. Please try again."
