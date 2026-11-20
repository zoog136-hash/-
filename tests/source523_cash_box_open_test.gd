extends SceneTree
## Opening an original 523 cash box (source523_cash_packages.open) without the
## original files, on a small host world:
## - the opening is checked by the full save validation (validate-only) and
##   the file is written by the general save of the next frame; until then
##   nothing is written, and the box and its rewards change together;
## - a refused validation keeps the box and changes nothing;
## - only the records a first-seen reward appends are weighed (no full weight
##   index) and the bag publish is the items-only one;
## - the select box owner (source523_cash_select) lists the original rows,
##   claims one row through open(), and its plain fallback uses 확인 / 취소
##   with the guide text above the choices;
## - Godot dialogs get the Korean button texts (dialog_korean_texts) unless
##   the caller named them.
const CashPackages = preload("res://scripts/shop/source523_cash_packages.gd")
const CashSelect = preload("res://scripts/shop/source523_cash_select.gd")
const DialogTexts = preload("res://scripts/ui/dialog_korean_texts.gd")
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
	# The select box owner over the same rows.
	var owner: Node = CashSelect.new()
	owner.configure(host, "시험 상자", [{"entity_id":71, "item_class_id":900001, "amount":5, "bless":2}, {"entity_id":72, "item_class_id":900001, "amount":1, "bless":1}])
	host.add_child(owner)
	var rows: Array = owner.original_rows()
	check(rows.size() == 2 and rows[0].entity_id == 71 and int(rows[0].amount) == 5 and int(rows[0].blessing) == 2 and rows[1].entity_id == 72, "the owner lists the original rows in order")
	check(int(owner.box_info().item_class_id) == 900100, "the box slot names the box's ItemClass")
	check(not owner.claim_entity(99), "an unknown row claims nothing")
	var presented: Dictionary = owner.present()
	check(presented.get("fallback", false) and owner.shown == "fallback", "without the UI pack the plain chooser is shown")
	var dialog: ConfirmationDialog = owner.get_node_or_null("Source523CashSelectFallback") as ConfirmationDialog
	check(dialog != null and dialog.ok_button_text == "확인" and dialog.cancel_button_text == "취소", "the chooser's buttons are 확인 / 취소")
	var column: Node = dialog.get_node_or_null("DialogContent") if dialog != null else null
	check(column != null and column.get_child(0) is Label and column.get_child(1) is OptionButton and dialog.dialog_text.is_empty(), "the guide text sits above the choices (not over them)")
	var boxes: int = int(host.inventory.get("시험 상자", 0))
	check(owner.claim_entity(71), "a row is claimed through open()")
	check(int(host.inventory.get("시험 상자", 0)) == boxes - 1 and int(host.inventory.get("시험 물약", 0)) == 8, "one box gives the chosen row")
	await process_frame
	check(not is_instance_valid(owner), "a claimed owner closes")
	# Godot dialogs: the engine's English defaults become Korean.
	DialogTexts.install(self)
	var plain := ConfirmationDialog.new()
	var named := ConfirmationDialog.new()
	named.ok_button_text = "비용 지불 후 전환"
	var alert := AcceptDialog.new()
	root.add_child(plain); root.add_child(named); root.add_child(alert)
	await process_frame
	check(plain.ok_button_text == "확인" and plain.cancel_button_text == "취소" and plain.title == "확인", "a plain dialog reads 확인 / 취소: %s %s %s" % [plain.ok_button_text, plain.cancel_button_text, plain.title])
	check(named.ok_button_text == "비용 지불 후 전환" and named.cancel_button_text == "취소", "a caller's own text stays")
	check(alert.ok_button_text == "확인" and alert.title == "알림", "an alert reads 확인 / 알림")
	host.queue_free()
	print("SOURCE523_CASH_BOX_OPEN_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
