extends SceneTree

const SHOP = preload("res://scripts/shop/shop_catalog.gd")
var failed: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed.append(label)
		printerr("SHOP_AUTHORITY_FAIL: " + label)

func _run() -> void:
	_check(SHOP.GOODS.size() == 20, "legacy shop stock and prices must remain")
	_check(SHOP.price_for("HP 물약") == 50, "existing HP price")
	_check(SHOP.price_for("드래곤의 용옥") == 1000000, "orb price")
	_check(SHOP.price_for("진명황의 집행검") == -1, "unlisted premium item cannot be purchased")
	_check(not bool(SHOP.quote("진명황의 집행검",1,1000000,0,9999,1).get("ok")), "forged product rejected")
	var valid: Dictionary = SHOP.quote("HP 물약",3,200,20,100,5)
	_check(bool(valid.get("ok")), "valid three-potion purchase")
	_check(int(valid.get("total",0)) == 150, "authoritative total derives from server catalog")
	var poorer: Dictionary = SHOP.quote("HP 물약",3,149,20,100,5)
	_check(not bool(poorer.get("ok")), "insufficient funds rejected")
	_check(not bool(SHOP.quote("HP 물약",3,9999,90,100,5).get("ok")), "overweight rejected")
	_check(bool(SHOP.quote("HP 물약",2,9999,90,100,5).get("ok")), "capacity boundary accepted")
	for bad_count: int in [-1,0,100,1000000]:
		_check(not bool(SHOP.quote("HP 물약",bad_count,999999999,0,999999,1).get("ok")), "invalid quantity rejected: " + str(bad_count))
	_check(not bool(SHOP.quote("드래곤의 용옥",2,3000000,0,9999,1).get("ok")), "orb bulk bypass rejected")
	_check(bool(SHOP.quote("드래곤의 용옥",1,1000000,0,9999,1).get("ok")), "one orb remains purchasable")
	_check(not bool(SHOP.quote("HP 물약",1,-1,0,9999,1).get("ok")), "negative wallet rejected")
	_check(not bool(SHOP.quote("HP 물약",1,100,0,-1,1).get("ok")), "negative capacity rejected")
	_check(not bool(SHOP.quote("HP 물약",1,100,0,9999,-1).get("ok")), "negative item weight rejected")
	var seen: Dictionary = {}
	for entry: Array in SHOP.GOODS:
		var name: String = str(entry[0])
		_check(not seen.has(name), "duplicate goods: " + name)
		seen[name] = true
		_check(SHOP.price_for(name) == int(entry[1]) and int(entry[1]) > 0, "price registry roundtrip: " + name)
	if failed.is_empty():
		print("SHOP_AUTHORITY_OK: whitelist, quantity, wallet, encumbrance, orb and price integrity")
		quit(0)
	else:
		print("SHOP_AUTHORITY_FAILED: %d" % failed.size())
		quit(1)
