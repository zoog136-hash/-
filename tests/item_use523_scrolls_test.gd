extends SceneTree
## 주문서 (강화·귀환) 사용 (user report 2026-11-21 "아직 아이템 구현 안 돼서
## 사용 안 되는 거 많아"). The item-use audit (tests/item_use_audit523.gd)
## found every original 523 enchant scroll (무기·갑옷·장신구 마법 주문서 …)
## and 귀환 주문서 obtained from a box, drop or craft refused in the bag:
## "원본 표에 이 아이템의 사용 규칙이 없거나 … 보관용". Those receipted
## stacks have no native rule, while the name-keyed owner that the 523 shop's
## plain stacks use (World._scroll_kind → enhancement window, regional_return
## → 귀환) does. The receipted stack is now handed to the plain stack
## (ledger: remaining units discarded with TWILIGHT_plain_stack_handoff) and
## that owner runs.
## Without the pinned 523 tables only the ledger rule runs. With them every
## scroll of the kind is checked for its owner; with --runtime each one is
## used from the bag (and an enchant scroll enhances a +0 target) in Main.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const RETURN = preload("res://scripts/quickslots/regional_return.gd")
## Original ItemCategory IDs of ScrollEnchant (52) / ScrollTeleport (5).
const CATEGORIES = [52, 5]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	var owned: Dictionary = {"receipt":{"granted_quantity":5},"used":1,"remaining":4}
	var row: Dictionary = STACK.ledger_row(owned, 1, 0, 4, "TWILIGHT_plain_stack_handoff")
	check(row == {"receipt":{"granted_quantity":5},"used_quantity":1,"remaining_quantity":0,"discarded_quantity":4,"discard_reason":"TWILIGHT_plain_stack_handoff"}, "a handoff keeps used units and discards the remaining ones")
	check(STACK.ledger_row(owned, 1, 0, 4).discard_reason == "TWILIGHT_existing_ground_lifetime", "the ground lifetime row is unchanged")
	check(STACK.DISCARD_REASONS.has("TWILIGHT_plain_stack_handoff") and STACK.DISCARD_REASONS.has("TWILIGHT_existing_ground_lifetime"), "both discard reasons are accepted by the ledger check")
	var text: String = FileAccess.get_file_as_string("res://scripts/loot/current523_native_stack.gd")
	check(text.contains("if effect.is_empty() and plain_owner(world,item_name,record):") and text.find("plain_owner(world,item_name,record)") < text.find('supply_profile(record).get("kind")=="storage":return _failure('), "the plain owner runs before the storage refusal")

func targets(world: Node) -> Dictionary:
	# +0 targets of each enhancement kind, from the original table.
	var found: Dictionary = {}
	for id: int in [27, 248, 249, 230, 349, 378, 287, 290, 374]:
		var record: Dictionary = D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1)
		if record.is_empty(): continue
		var kind: String = str(world._enhancement_kind_for_record(record))
		if not kind.is_empty() and not found.has(kind): found[kind] = id
	return found

func scroll_ids() -> Array:
	var ids: Array = []
	for row: Dictionary in SOURCE.rows("ItemClass"):
		if row.get("TestItem", true) != false or int(row.get("ID", 0)) <= 0: continue
		if int(row.get("CategoryID", 0)) not in CATEGORIES: continue
		ids.append(int(row.ID))
	return ids

var baseline: Dictionary = {}
func stage(world: Node, grants: Array) -> bool:
	var staged: Dictionary = INV.stage(world, grants, {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok", false) or world._save_game(true, staged.overrides) != OK: return false
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	return true

func key_for(world: Node, id: int) -> String:
	for key: Variant in world.inventory:
		if str(key).ends_with("#" + str(id)) or str(world._find_catalog_item_record(str(key)).get("source_item_class_id", 0)) == str(id): return str(key)
	return ""

func use_scroll(world: Node, id: int, target_ids: Dictionary) -> Dictionary:
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
	for slot: String in world.equipped_items.keys(): world.equipped_items.erase(slot)
	world.consumable_service.import_state(baseline.duplicate(true))
	world._save_game(true)
	world.hud.message_label.text = ""
	var record: Dictionary = D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1)
	if record.is_empty(): return {"ok":false,"reason":"no record"}
	var name: String = str(record.name)
	var kind: String = str(world._scroll_kind(name))
	var grants: Array = [{"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0}]
	var target_kind: String = kind
	if kind == "source":
		for candidate: String in ["weapon","armor","accessory"]:
			if target_ids.has(candidate): target_kind = candidate; break
	if not kind.is_empty() and target_ids.has(target_kind): grants.append({"item_class_id":int(target_ids[target_kind]),"amount":1,"bless_raw":1,"enchant":0})
	if not stage(world, grants): return {"ok":false,"reason":"stage"}
	var plain: bool = STACK.plain_owner(world, name, world._find_catalog_item_record(name))
	world._on_inventory_item_activated(name)
	var message: String = world.hud.message_label.text
	var outcome: Dictionary = {"name":name,"kind":kind,"plain_owner":plain,"message":message,"section":str(world.hud.active_section)}
	var handed: bool = true
	for entry: Variant in world.item_instances.values():
		if entry is Dictionary and entry.get("name") == name and entry.has(STACK.RECEIPT): handed = false
	outcome["handed"] = handed
	if kind.is_empty():
		# 귀환 주문서: one scroll is read (a return or its own map refusal).
		outcome["ok"] = handed and (int(world.inventory.get(name, 0)) == 1 or message.contains("귀환") or message.contains("지역"))
	else:
		outcome["window"] = world.hud.active_section in ["enhance","patch523_equipment"]
		var target: String = ""
		for uid: Variant in world.item_instances:
			var entry: Dictionary = world.item_instances[uid]
			if str(entry.get("name","")) != name and D.equipment(entry.get("record", {})): target = str(entry.name) + "@@@" + str(uid)
		if not target.is_empty():
			world._attempt_enhancement(name, target)
			outcome["after"] = world.hud.message_label.text
			outcome["left"] = int(world.inventory.get(name, 0))
			# A scroll for another stage or scroll group (장인의 주문서, 기운의 주문서 …)
			# is refused by its own original rule; the scroll is kept.
			var after: String = str(outcome.after)
			outcome["rule_refusal"] = outcome.left == 2 and (after.begins_with("원본 단계") or after.begins_with("원본 장비·주문서 그룹") or after.contains("사용할 수 없는") or after.contains("강화할 수 없는"))
			outcome["ok"] = handed and outcome.window and (outcome.left == 1 or outcome.rule_refusal)
		else: outcome["ok"] = handed and outcome.window
	# The result screen only presents the rolled result; close it for the next scroll.
	var reveal: Variant = world.hud.get("enhancement_reveal")
	if is_instance_valid(reveal):
		var layer: Node = (reveal as Node).get_parent() if (reveal as Node).get_parent() is CanvasLayer else reveal
		world.hud.set("enhancement_reveal", null)
		layer.get_parent().remove_child(layer); layer.queue_free()
	outcome["problem"] = str(world.patch523_owner_state_problem)
	world.patch523_owner_state_problem = ""
	if world.hud.workspace != null: world.hud.workspace.hide()
	world.hud.active_section = ""
	return outcome

func runtime(ids: Array) -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var save_path: String = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_path)
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.level = 85
	baseline = world.consumable_service.export_state()
	var target_ids: Dictionary = targets(world)
	evidence["targets"] = target_ids
	var used: Dictionary = {}; var refused: Dictionary = {}
	for id: Variant in ids:
		var name: String = str(D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1).get("name", ""))
		if not STACK.plain_owner(world, name, world._find_catalog_item_record(name)): continue
		var outcome: Dictionary = use_scroll(world, int(id), target_ids)
		if outcome.get("ok", false) and str(outcome.get("problem","")).is_empty(): used[str(id)] = "rule_refusal" if outcome.get("rule_refusal", false) else outcome.get("kind","return")
		else: refused[str(id)] = outcome
	check(refused.is_empty(), "every enchant/return scroll is used from the bag: " + JSON.stringify(refused).left(1500))
	check(used.size() >= 4, "the original enchant and return scrolls were used")
	var kept: int = 0
	for key: String in used:
		if used[key] == "rule_refusal": kept += 1
	evidence["runtime"] = {"used":used.size() - kept,"original_rule_refused":kept,"refused":refused.size()}
	world.queue_free()
	await process_frame
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null: file.store_buffer(original_save); file.close()
	elif FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		var ids: Array = scroll_ids()
		evidence["scrolls"] = ids.size()
		check(ids.size() > 0, "original enchant/teleport scrolls are listed")
		if "--runtime" in OS.get_cmdline_user_args(): await runtime(ids)
	print("ITEM_USE523_SCROLLS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
