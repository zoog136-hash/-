extends SceneTree
## Original coin wallets (명예 코인, 변신/마법인형/성물 제작 코인) are
## name-keyed bag stacks with no physical record; their bag/quickslot slot
## showed only the count (2026-11-19 recording). The wallet's own original
## ItemClass row supplies its original icon; other plain names are untouched.
##   godot --headless --path <repo> --script res://tests/bag_wallet_icon_test.gd
const BAG = preload("res://scripts/ui/lineage_inventory_ui.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("BAG_WALLET_ICON_FAIL: " + label)

func _initialize() -> void:
	var bag: Control = BAG.new() # not added to the tree: no UI is built
	bag.catalog_data = {"아이템":[]}
	var installed: bool = not SOURCE.not_installed()
	evidence["definitions_installed"] = installed
	evidence["image_pack"] = IMAGES.selection_status()
	check(IMAGES._wallet_item_class_id({"name":"옛 물약"}, "") == -1, "a plain non-wallet name gets no wallet identity")
	check(IMAGES._wallet_item_class_id({"name":"명예 코인 · 축복"}, "") == -1, "only the exact wallet name is a wallet")
	var linked: Dictionary = {}
	for id: int in INVENTORY.COIN_WALLETS:
		var name: String = str(INVENTORY.COIN_WALLETS[id])
		var record: Dictionary = bag._find_item_record(name) # bare fallback: no catalog row
		var expected: int = id if installed and not INVENTORY.coin_wallet(id).is_empty() else -1
		check(IMAGES._wallet_item_class_id(record, "") == expected, "%s -> original ItemClass #%d" % [name, expected])
		check(IMAGES.handles_item(record) == (expected > 0), "%s is presented by the original image owner" % name)
		if expected <= 0 or not IMAGES.selected(): continue
		var info: Dictionary = IMAGES.describe_item(record, name)
		linked[name] = {"id":int(info.get("item_class_id",-1)),"path":str(info.get("path","")),"status":str(info.get("status","")),"reason":str(info.get("reason",""))}
		check(int(info.get("item_class_id",-1)) == id and info.get("route") == "source523_images" and info.get("status") == "original_linked" and info.get("texture") is Texture2D and info.get("original_bytes_unchanged") == true,
			"%s draws its original icon (%s)" % [name, JSON.stringify(linked[name])])
		check(bag._item_visual_record(name, record) == record, "%s: the bag keeps its row for the picture" % name)
	evidence["linked"] = linked
	bag.free()
	print("BAG_WALLET_ICON_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
