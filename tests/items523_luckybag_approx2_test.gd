extends SceneTree
## TWILIGHT 근사 (2) for the remaining blocked LuckyBags
## (docs/items523_remaining_missing_rules.md 18.2): ignored client rows,
## UsageInterval/ClassUsageInterval as a reuse wait, InfiniteAmount = not
## consumed, LuckyBagLimitedItemPossession, test rewards replaced (same
## functional row / the card itself), a class with no row drawing from every
## row, and the held possession title (ItemPossessionAppellationID).
## With the original ZIP every LuckyBag is counted by its actual bag-use
## profile, and in actual Main the new paths run and the save reloads.
const USE = preload("res://scripts/loot/patch523_item_use.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const JAR := 200743 # 아덴 영웅의 성장 항아리: InfiniteAmount + UsageInterval 86400
const CARD_BOX := 121713 # 희귀 변신 카드 상자: every reward is a test card item
const LIMITED := 96154 # 봉인된 지룡의 마안: LuckyBagLimitedItemPossession -> #75304 x1
const LIMIT_TARGET := 75304
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("LUCKYBAG_APPROX2_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func unit() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var spec: Dictionary = {"kind":"source_weighted_bag","approx_renormalized":true,"approx_class_pool":[3],"rewards":[{"entity_type_id":0,"probability_raw":5000000,"class_ids":[1],"item_class_id":1},{"entity_type_id":0,"probability_raw":5000000,"class_ids":[2],"item_class_id":2}]}
	check(not USE.select_rewards(spec,4,rng).get("ok",true), "a class outside the pool with no row of its own gets nothing")
	var hits: Dictionary = {}
	for _i: int in 300:
		var picked: Dictionary = USE.select_rewards(spec,3,rng)
		if picked.get("ok",false): hits[int(picked.rewards[0].item_class_id)] = int(hits.get(int(picked.rewards[0].item_class_id),0)) + 1
	check(hits.size()==2, "approx_class_pool class 3 draws from every row: "+str(hits))

func spec_of(id: int) -> Dictionary:
	var record: Dictionary = D.variant_item(D.definition_id(str(id)).get("native_record",{}),1)
	return NATIVE_FIELDS.full(record).get("source_use_spec",{}) if not record.is_empty() else {}

func table() -> void:
	var categories: Dictionary = {}
	for row: Dictionary in SOURCE.rows("ItemCategory"):
		if str(row.get("Name",""))=="LuckyBag": categories[int(row.ID)] = true
	var counts: Dictionary = {"bags":0,"usable":0,"blocked":0,"substituted":0,"card_rewards":0,"reusable":0,"reuse_wait":0,"possession_limit":0,"class_pool":0,"ignored_rows":0}
	var reasons: Dictionary = {}
	for row: Dictionary in SOURCE.rows_matching("ItemClass","CategoryID",categories):
		if row.get("TestItem")!=false: continue
		var record: Dictionary = D.variant_item(D.definition_id(str(int(row.ID))).get("native_record",{}),1)
		if record.is_empty(): continue
		var spec: Dictionary = NATIVE_FIELDS.full(record).get("source_use_spec",{})
		if spec.get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"]: continue
		counts.bags += 1
		if not STACK.profile(record).is_empty(): counts.usable += 1
		else:
			counts.blocked += 1
			for why: Variant in spec.get("blocked_reasons",["(profile)"]):
				var key: String = str(why)
				if not reasons.has(key): reasons[key] = {"n":0,"ex":[]}
				reasons[key].n += 1
				if reasons[key].ex.size() < 4: reasons[key].ex.append(int(row.ID))
		for reward: Dictionary in spec.get("rewards",[]):
			if reward.has("approx_substituted_from"): counts.substituted += 1; break
		for reward: Dictionary in spec.get("rewards",[]):
			if reward.has("approx_card"): counts.card_rewards += 1; break
		if spec.get("approx_reusable",false): counts.reusable += 1
		if spec.has("approx_reuse_seconds"): counts.reuse_wait += 1
		if spec.has("approx_possession_limits"): counts.possession_limit += 1
		if spec.has("approx_class_pool"): counts.class_pool += 1
		if spec.has("approx_ignored_rows"): counts.ignored_rows += 1
	evidence["counts"] = counts
	evidence["blocked_reasons"] = reasons
	check(int(counts.substituted)+int(counts.card_rewards)>100 and int(counts.reusable)>=12 and int(counts.possession_limit)>0, "approximations reach the bags: "+str(counts))
	var jar: Dictionary = spec_of(JAR)
	check(jar.get("activation_status")=="unrestricted" and jar.get("approx_reusable",false) and int(jar.get("approx_reuse_seconds",0))==86400 and int(jar.get("consume_delay_ms",0))==86400000, "성장 항아리: 소모 안 함 + 24시간 재사용 대기 (원본 설명 '재사용 시간 24시간')")

func grant(world: Node, id: int, amount: int = 1) -> String:
	var staged: Dictionary = SUPPLY.stage(world,[{"item_class_id":id,"amount":amount,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok",false), "grant #%d: %s" % [id,str(staged.get("error",""))]): return ""
	world._save_game(true,staged.overrides)
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	for uid: String in world.item_instances:
		if int(world.item_instances[uid].get("record",{}).get("source_item_class_id",0))==id: return str(world.item_instances[uid].name)
	return ""

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
	# InfiniteAmount jar: opened, kept, then refused by the 24h wait.
	var jar: String = grant(world, JAR)
	if not jar.is_empty():
		var first: Dictionary = STACK.try_use(world, jar)
		evidence["jar"] = {"ok":first.get("ok"),"reason":first.get("reason",first.get("message","")),"consumed":first.get("consumed"),"left":int(world.inventory.get(jar,0)),"wait":world.item_use_cooldowns.get("m523:item:"+str(JAR),0.0)}
		check(first.get("ok",false) and int(first.get("consumed",-1))==0 and int(world.inventory.get(jar,0))==1 and float(evidence.jar.wait)>=86399.0, "성장 항아리 개봉: 물약 지급, 항아리 보존, 24시간 대기 "+str(evidence.jar))
		var again: Dictionary = STACK.try_use(world, jar)
		check(not again.get("ok",true) and int(world.inventory.get(jar,0))==1, "대기 중 다시 열기는 거부: "+str(again.get("reason",again.get("message",""))))
		world._load_game(true)
		check(int(world.inventory.get(jar,0))==1 and float(world.item_use_cooldowns.get("m523:item:"+str(JAR),0.0))>0.0, "reload keeps the jar and the wait")
	# Test card rewards: the card itself is given.
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
	var box: String = grant(world, CARD_BOX)
	if not box.is_empty():
		var owned_before: int = (world.card_draw_fusion.export_state().get("owned",{}).get("변신",{}) as Dictionary).size()
		var opened: Dictionary = STACK.try_use(world, box)
		var owned_after: Dictionary = world.card_draw_fusion.export_state().get("owned",{}).get("변신",{})
		evidence["card_box"] = {"ok":opened.get("ok"),"reason":opened.get("reason",opened.get("message","")),"cards":opened.get("cards",[]),"owned":[owned_before,owned_after.size()],"left":int(world.inventory.get(box,0))}
		check(opened.get("ok",false) and not world.inventory.has(box) and not (opened.get("cards",[]) as Array).is_empty(), "테스트 변신 카드 보상 상자: 카드 지급 "+str(evidence.card_box))
		world._load_game(true)
		var reloaded: Dictionary = world.card_draw_fusion.export_state().get("owned",{}).get("변신",{})
		check(reloaded.size()==owned_after.size(), "reload keeps the given card")
	# LuckyBagLimitedItemPossession: refused while the target item is owned.
	world.inventory = {}; world.item_instances = {}; world.item_use_cooldowns = {}
	var limited: String = grant(world, LIMITED)
	if not limited.is_empty():
		var target: String = grant(world, LIMIT_TARGET)
		var refused: Dictionary = STACK.try_use(world, limited)
		check(not refused.get("ok",true) and int(world.inventory.get(limited,0))==1, "보유 제한: 지룡의 마안 보유 중이면 거부·상자 보존 "+str(refused.get("reason",refused.get("message",""))))
		if not target.is_empty():
			world.inventory.erase(target)
			for uid: String in world.item_instances.keys():
				if str(world.item_instances[uid].get("name",""))==target: world.item_instances.erase(uid)
		var allowed: Dictionary = STACK.try_use(world, limited)
		evidence["limited"] = {"refused":refused.get("reason",refused.get("message","")),"ok":allowed.get("ok"),"reason":allowed.get("reason",allowed.get("message",""))}
		check(allowed.get("ok",false) and not world.inventory.has(limited), "보유 제한: 없으면 열림 "+str(evidence.limited))
	# Possession title: an emblem with ItemPossessionAppellationID.
	world.inventory = {}; world.item_instances = {}
	var emblem: int = 0
	for row: Dictionary in SOURCE.rows("ItemBonus"):
		var bonus: Dictionary = SOURCE.row("Bonus", int(row.get("BonusID",0)))
		if str(SOURCE.row("BonusType", int(bonus.get("BonusTypeID",0))).get("Name",""))!="ItemPossessionAppellationID": continue
		var item: Dictionary = SOURCE.row("ItemClass", int(row.ItemClassID))
		if item.get("TestItem")!=false: continue
		var title: Dictionary = world.item_appellation523.title(int(bonus.Value))
		if not title.is_empty() and int(title.values.get("xp",0)) > 0: emblem = int(row.ItemClassID); break
	if check(emblem > 0, "an item with a possession title giving 경험치"):
		var before: int = world._active_item_buff_total("xp")
		var name_value: String = grant(world, emblem)
		world.item_appellation523._checked_ms = -100000
		var held: Dictionary = world.item_appellation523.active()
		evidence["appellation"] = {"item":emblem,"name":name_value,"title":held.get("name",""),"values":held.get("values",{}),"unmapped":held.get("unmapped",[]),"xp":[before,world._active_item_buff_total("xp")]}
		check(not str(held.get("name","")).is_empty() and world._active_item_buff_total("xp") > before, "보유 칭호: 칭호 이름과 경험치 효과 "+str(evidence.appellation))
		world.inventory.erase(name_value)
		world.item_appellation523._checked_ms = -100000
		check(world.item_appellation523.active().is_empty(), "칭호 아이템이 없으면 효과 없음")
	world.queue_free()
	await process_frame

func run() -> void:
	unit()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("LUCKYBAG_APPROX2_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
