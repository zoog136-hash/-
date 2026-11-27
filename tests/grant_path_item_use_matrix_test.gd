extends SceneTree
## 지급 경로 × 대표 아이템 사용 매트릭스 (사용자 보고 2026-11-27 "성수, 퀘스트
## 카드 여전히 사용 안 되고"). The same original item reaches the bag in
## several save forms depending on how it was given:
## - receipted native stack: box/drop/shop supply (patch523_item_inventory),
## - the catalog "테스트 아이템 지급" by name or by variant: on the installed
##   phone pack (no full drop catalog) this used to store a plain balance,
## - a plain name balance of an older save (no physical receipt),
## - an old plain balance beside a new receipted grant,
## - a floor pickup without drop proof (plain), a monster drop with proof,
## - an old name-only 축복의 성수(대) shared by #117304 and dated #196513.
## Plain balances were refused ("이름만 같은 보유품 보존") or showed no 사용.
## Without the pinned 523 tables only the rules run. With them (--runtime)
## every form of each representative is used from the bag in Main, checked
## for its original effect (축복 포인트, card registration, box rewards) and
## again after a save and reload.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const LABELS = preload("res://scripts/ui/source523_item_identity.gd")
## 축복의 성수(소), 축복의 성수(대), 축복의 성수(대) (지배의 탑), 이벤트 성수,
## [변신 카드] 거대 미노타우르스, [미스터리 변신 카드] 영웅, 군왕&대법관 변신
## 카드 상자 (이벤트), 컬렉션 변신 카드 선택 상자, 상급 변신 뽑기권 (이벤트).
const ITEMS = [117284, 117304, 163744, 155593, 6521, 123461, 119312, 170734, 122784]
const FORMS = ["supply", "test_name", "test_variant", "plain", "mixed", "floor"]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var w: Node
var base: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("GRANT_PATH_ITEM_USE_FAIL ", label)

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	var stack: String = FileAccess.get_file_as_string("res://scripts/loot/current523_native_stack.gd")
	check(stack.contains("static func adopt_plain_balance(world: Node,item_name: String,named: Dictionary) -> Dictionary:"), "a plain native balance has an adoption owner")
	check(stack.contains('const LEGACY_PLAIN_ORIGIN := {"kind":"twilight_legacy_plain_balance","schema":1}'), "adopted balances carry their own origin")
	check(stack.contains("var rest: int=int(amount)-receipted") and stack.contains("if rest<1:return {}"), "only the unreceipted remainder is adopted")
	check(stack.contains("if not entry.has(RECEIPT):return {} # Another owner's physical form."), "another owner's physical entry is never adopted")
	check(stack.contains('var adopted: Dictionary=adopt_plain_balance(world,item_name,named)'), "the bag use adopts before refusing")
	check(stack.contains('not mystery_card_rule(named).is_empty():claims=true'), "a plain mystery card belongs to the native owner")
	var water: String = FileAccess.get_file_as_string("res://scripts/growth/symbol_source523.gd")
	check(water.contains("func shared_label_recharge(key: String, id: int) -> bool:") and water.contains("balances.unique_stock_name(key,id) or shared_label_recharge(key,id)"), "a shared holy-water label with one amount is usable")
	var world: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world.contains('or supply.stage(self,[grant],{"kind":"twilight_debug_catalog"}).get("ok",false):'), "the catalog test grant issues a receipted stack without the full drop catalog")
	check(stack.contains('if spec.kind=="source_bless_points":return use_bless_points(world,uid,selected_owned,record,spec)'), "a quest-held holy water uses the bless point owner")
	check(stack.contains('var paid: Dictionary=QUEST_CONSUME.stage(world,[request],str(SOURCE.identity().source_sha256)) if is_quest else stage_debit(world,[request])'), "a quest-held holy water is debited through the quest ledger")
	var provider: String = FileAccess.get_file_as_string("res://scripts/quests/quest_item_provider238.gd")
	check(provider.contains('"source_skill_book","source_bless_points"]'), "held event holy water routes to the native owner")
	var labels: String = FileAccess.get_file_as_string("res://scripts/ui/source523_item_identity.gd")
	check(labels.contains("static func ids_by_name(name: String) -> Array[int]:"), "original IDs by displayed name")
	# The shared-label rule on the repo's own holy-water table (no pack).
	var symbol = preload("res://scripts/growth/symbol_source523.gd").new()
	var amounts: Dictionary = {}
	for row: Dictionary in symbol.data.get("recharge",[]): amounts[int(row.ItemClassID)] = int(row.amount)
	check(amounts.get(117304) == 1000 and amounts.get(196513) == 1000, "#117304 and dated #196513 both charge 1,000 points")

func snapshot() -> Dictionary:
	return {"points":int(w.growth.state.points),"cards":JSON.stringify(w.card_draw_fusion.export_state()).sha256_text(),"inv":w.inventory.duplicate(true)}

## The player taps through the card result presentation.
func close_reveal() -> void:
	for attempt: int in 10:
		var stage: Variant = w.hud.get("card_reveal_stage")
		if not is_instance_valid(stage): return
		if stage.has_method("close_reveal"): stage.call("close_reveal")
		await process_frame
	w.hud.set("card_reveal_stage", null)

func reset() -> void:
	await close_reveal()
	if w.hud.workspace != null: w.hud.workspace.hide()
	w.hud.active_section = ""
	w.inventory = {}; w.item_instances = {}; w.item_use_cooldowns = {}
	w.card_draw_fusion.import_state(base.cards.duplicate(true))
	w.growth.state = base.growth.duplicate(true)
	w.consumable_service.import_state(base.consumable.duplicate(true))
	if base.has("quest"): w.quest_service.import_state(base.quest.duplicate(true))
	w.quest_service.save_blocked = false; w.patch523_owner_state_problem = ""
	w.hud.message_label.text = ""
	w._save_game(true)
	w.hud.refresh_inventory(w.inventory)

func native(id: int) -> Dictionary:
	return w._catalog_item_from_source_id("m523:item:"+str(id))

func give(id: int, form: String) -> bool:
	var record: Dictionary = native(id)
	var grant := [{"item_class_id":id,"amount":2,"bless_raw":1,"enchant":0}]
	match form:
		"supply": return INV.commit(w, grant, {"kind":"grant_path_matrix"})
		"test_name": w._grant_playtest_catalog_item(str(record.name), 2)
		"test_variant": w._grant_playtest_catalog_variant(str(record.sourceId), 2)
		"plain": w.inventory[str(record.name)] = 2
		"mixed":
			w.inventory[str(record.name)] = 1
			grant[0].amount = 1
			return INV.commit(w, grant, {"kind":"grant_path_matrix"})
		"floor":
			var view: Button = w.ground_loot.spawn(str(record.name), w.player.global_position, 2, "", {"item_record":record})
			if not is_instance_valid(view): return false
			while Time.get_ticks_msec()-view.visible_since < w.ground_loot.MIN_VISIBLE_MS: await process_frame
			return w._collect_ground_drop(view)
	w.hud.refresh_inventory(w.inventory)
	return int(w.inventory.get(str(record.name),0)) >= 2

func reference(id: int) -> String:
	var record: Dictionary = native(id)
	for entry: Dictionary in w.hud.lineage_inventory_ui._inventory_entries():
		if str(entry.reference).get_slice("@@@",0) == str(record.name): return str(entry.reference)
	return ""

## The bag gate of the second touch ("사용" shown), then the bag activation.
func use(id: int) -> Dictionary:
	w._update_hud(); w.hud.refresh_inventory(w.inventory)
	await process_frame
	var ref: String = reference(id)
	if ref.is_empty(): return {"ok":false,"why":"no bag entry"}
	var kind: String = w.hud.lineage_inventory_ui.item_action_kind(ref)
	var before: Dictionary = snapshot()
	w.hud.message_label.text = ""
	w._activate_inventory_input(ref)
	await process_frame
	var chooser: Variant = w.hud.get_meta("patch523_reward_choice") if w.hud.has_meta("patch523_reward_choice") else null
	var chosen: bool = false
	if is_instance_valid(chooser):
		# The original selection window: claim its first original reward.
		var rows: Array = chooser.pending.get("choices",[])
		if not rows.is_empty(): chosen = chooser.claim_entity(int(rows[0].get("source_entity_id",0)))
		if is_instance_valid(chooser): chooser.queue_free()
		w.hud.remove_meta("patch523_reward_choice")
		await process_frame
	var revealed: bool = w.hud.is_card_reveal_busy()
	await close_reveal()
	var after: Dictionary = snapshot()
	var name: String = ref.get_slice("@@@",0)
	var gained: int = 0
	for key: Variant in after.inv:
		if key != name and int(after.inv[key]) > int(before.inv.get(key,0)): gained += 1
	var out: Dictionary = {"kind":kind,"message":str(w.hud.message_label.text).left(60),"consumed":int(before.inv.get(name,0))-int(after.inv.get(name,0)),
		"points":after.points-before.points,"card":after.cards!=before.cards,"gained":gained,"chosen":chosen,"revealed":revealed}
	out["ok"] = kind == "사용" and out.consumed == 1 and (out.points > 0 or out.card or out.gained > 0)
	return out

func quest_held(id: int) -> Dictionary:
	var svc = w.quest_service
	var now: int = int(Time.get_unix_time_from_system())
	for qid: String in svc.index:
		var quest: Dictionary = svc.full(svc.index[qid])
		var rewards: bool = false
		for reward: Dictionary in quest.get("source_rewards",[]):
			if str(reward.get("type_name")) == "Item" and int(reward.get("RewardClassID",0)) == id: rewards = true
		if not rewards: continue
		for req: Dictionary in quest.get("prerequisites",[]):
			if req.get("type_name") == "Quest": svc.claimed["m523:quest:" + str(int(req.Value))] = true
		w.quest_auto.refresh_context(w)
		if not str(svc.source.gate(svc.index[qid], w.quest_auto.context, svc.claimed, now)).is_empty(): continue
		var before: Dictionary = w.item_instances.duplicate()
		var ids: Array[String] = [qid]
		if not w.quest_auto.complete(w, ids): continue
		for uid: Variant in w.item_instances:
			var entry: Dictionary = w.item_instances[uid]
			if not before.has(uid) and entry.has("quest_reward_receipt") and int(entry.get("record",{}).get("source_item_class_id",0)) == id:
				return {"ok":true,"quest":qid,"uid":str(uid),"name":str(entry.name),"quantity":int(entry.get("source_reward_quantity",1))}
		return {"ok":false,"quest":qid,"why":"no held unit"}
	return {"ok":false,"why":"no completable quest"}

func runtime() -> void:
	root.size = Vector2i(2048, 919)
	w = load("res://Main.tscn").instantiate()
	root.add_child(w)
	current_scene = w
	w.set_process(false)
	check(QA.enter_game(w, "기사"), "actual Main map entry")
	await process_frame
	w.player.set_physics_process(false); w.field_population.set_process(false); w.save_timer = -100000
	w._clear_monsters(); w._clear_drops()
	var save_path: String = w.save_path()
	var original_save: PackedByteArray = FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	w.level = 85; w.gold = 100000000
	base = {"cards":w.card_draw_fusion.export_state().duplicate(true),"growth":w.growth.state.duplicate(true),"consumable":w.consumable_service.export_state().duplicate(true),"quest":w.quest_service.export_state().duplicate(true)}
	var amounts: Dictionary = {}
	for row: Dictionary in w.growth.source523.data.recharge: amounts[int(row.ItemClassID)] = int(row.amount)
	var table: Dictionary = {}
	for id: int in ITEMS:
		for form: String in FORMS:
			await reset()
			var given: bool = await give(id, form)
			check(given, "#%d %s is issued" % [id, form])
			if not given: continue
			var first: Dictionary = await use(id)
			check(first.ok, "#%d %s is used from the bag: %s" % [id, form, JSON.stringify(first)])
			if amounts.has(id): check(first.points == amounts[id], "#%d %s charges its original %d points" % [id, form, amounts[id]])
			# The second unit after a save and reload.
			check(w._save_game(true) == OK, "#%d %s saves after the use" % [id, form])
			w._load_game(true)
			await process_frame
			var second: Dictionary = await use(id)
			check(second.ok, "#%d %s is used again after reload: %s" % [id, form, JSON.stringify(second)])
			table["%d:%s" % [id, form]] = "ok" if first.ok and second.ok else "fail"
	# Old name-only large holy water: #117304 and the dated #196513 share it.
	await reset()
	w.inventory[LABELS.original_name(117304)] = 2
	var shared: Dictionary = await use(117304)
	check(shared.ok and shared.points == 1000, "old name-only 축복의 성수(대) pays 1,000 points: " + JSON.stringify(shared))
	table["117304:old_label"] = "ok" if shared.ok else "fail"
	# Quest completion (common quest) issuing a held event holy water.
	await reset()
	var held: Dictionary = await quest_held(155593)
	check(held.get("ok",false), "a quest issues the held event holy water: " + JSON.stringify(held))
	if held.get("ok",false):
		var before_points: int = int(w.growth.state.points)
		w.hud.message_label.text = ""
		w._activate_inventory_input(str(held.name) + "@@@" + str(held.uid))
		await process_frame
		check(not w.item_instances.has(str(held.uid)) or int(w.item_instances[str(held.uid)].get("source_reward_quantity",0)) < int(held.quantity), "the held holy water is consumed once")
		check(int(w.growth.state.points) == before_points + int(amounts[155593]), "the held holy water charges its original points: " + w.hud.message_label.text)
		table["155593:quest_held"] = "ok" if int(w.growth.state.points) == before_points + int(amounts[155593]) else "fail"
	evidence["runtime"] = table
	await reset()
	w.queue_free()
	await process_frame
	if not original_save.is_empty():
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null: file.store_buffer(original_save); file.close()
	elif FileAccess.file_exists(save_path): DirAccess.remove_absolute(save_path)

func run() -> void:
	rules()
	if not SOURCE.not_installed() and "--runtime" in OS.get_cmdline_user_args(): await runtime()
	print("GRANT_PATH_ITEM_USE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
