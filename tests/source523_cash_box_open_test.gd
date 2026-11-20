extends SceneTree
## Opening an original 523 cash box (source523_cash_packages.open) without the
## original files, on a small host world:
## - the opening is checked by the full save validation (validate-only) and
##   the file is written by the general save of the next frame; until then
##   nothing is written, and the box and its rewards change together;
## - a refused validation keeps the box and changes nothing;
## - only the records a first-seen reward appends are weighed (no full weight
##   index) and the bag publish is the items-only one.
const CashPackages = preload("res://scripts/shop/source523_cash_packages.gd")
const Fusion = preload("res://scripts/card_draw_fusion.gd")
var checks: int = 0
var failures: Array[String] = []

class Hud extends Node:
	var messages: Array = []
	var refreshes: int = 0
	func show_message(text: String) -> void: messages.append(text)
	func refresh_inventory(_inventory: Dictionary) -> void: refreshes += 1
	func append_log(_text: String) -> void: pass

class Host extends Node:
	var inventory: Dictionary = {"시험 상자":2}
	var item_instances: Dictionary = {}
	var next_item_instance_id: int = 1
	var item_db: Array = []
	var catalog_db: Dictionary = {"아이템":[{"name":"시험 상자","source":CashPackages.TAG,"source_item_class_id":900100,"weight":0},
		{"name":"시험 물약","source_item_class_id":900001,"weight":2,"slot":"consumable"}], "변신":[], "마법인형":[], "성물":[]}
	var item_weight_index: Dictionary = {"시험 상자":0,"시험 물약":2}
	var card_draw_fusion = Fusion.new()
	var hud: Hud = Hud.new()
	var saves: Array = []
	var refuse: bool = false
	var general_requests: int = 0
	var appended_calls: Array = []
	var full_weight_builds: int = 0
	var bag_refreshes: int = 0
	var full_publishes: int = 0
	func _ready() -> void:
		add_child(hud)
		card_draw_fusion.configure(catalog_db)
	func _find_catalog_item_record(name: String, _source_id: String = "") -> Dictionary:
		for row: Dictionary in catalog_db["아이템"] + item_db:
			if row.name == name: return row
		return {}
	func _catalog_item_from_source_id(_id: String) -> Dictionary: return {}
	func _index_item_weights() -> void: full_weight_builds += 1
	func _index_item_weights_appended(catalog_size: int, item_db_size: int) -> void: appended_calls.append([catalog_size, item_db_size])
	func _enhancement_kind_for_record(_record: Dictionary) -> String: return ""
	func _carrying_capacity() -> int: return 100000
	func _save_game(quiet: bool, override: Dictionary = {}, movement: Dictionary = {}, validate_only: bool = false, background: bool = false) -> Error:
		saves.append({"quiet":quiet, "override":override.duplicate(true), "validate_only":validate_only, "background":background, "movement":movement})
		return ERR_INVALID_DATA if refuse else OK
	func _request_general_save() -> void: general_requests += 1
	func _queue_inventory_hud_refresh() -> void: bag_refreshes += 1
	func _update_hud() -> void: full_publishes += 1

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var host: Host = Host.new()
	root.add_child(host)
	await process_frame
	var reward: Array = [{"item_class_id":900001, "amount":3}]
	var opened: Dictionary = CashPackages.open(host, "시험 상자", reward)
	check(opened.get("ok", false), "the box opens: %s" % str(opened))
	check(host.saves.size() == 1 and host.saves[0].validate_only, "the opening is checked by the full save validation only: %s" % str(host.saves))
	var staged: Dictionary = host.saves[0].override if not host.saves.is_empty() else {}
	check(int(staged.get("inventory", {}).get("시험 상자", 0)) == 1 and int(staged.get("inventory", {}).get("시험 물약", 0)) == 3, "the checked payload holds the debit and the reward together")
	check(int(host.inventory.get("시험 상자", 0)) == 1 and int(host.inventory.get("시험 물약", 0)) == 3, "the checked state is adopted")
	check(host.general_requests == 0, "nothing is written in the opening frame")
	await process_frame
	await process_frame
	check(host.general_requests == 1, "the general save of the next frame writes it: %d" % host.general_requests)
	check(host.appended_calls == [[2, 0]] and host.full_weight_builds == 0, "only appended records are weighed: %s / %d" % [str(host.appended_calls), host.full_weight_builds])
	check(host.bag_refreshes == 1 and host.full_publishes == 0, "items only: the bag publish, not the full character sheet")
	# A refused validation keeps the box and everything else.
	host.refuse = true
	var before: Dictionary = host.inventory.duplicate(true)
	var refused: Dictionary = CashPackages.open(host, "시험 상자", reward)
	check(not refused.get("ok", true) and host.inventory == before, "a refused validation keeps the box and the bag")
	await process_frame
	await process_frame
	check(host.general_requests == 1, "a refused opening requests no save")
	host.refuse = false
	host.queue_free()
	print("SOURCE523_CASH_BOX_OPEN_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
