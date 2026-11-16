extends RefCounted
## Original 523 비법서 제작 (GachaCraft) — executable, quote → confirm → execute.
##
## Original data (current523_definition_rows):
##   calling item  ItemClass (ItemCategory ScrollGachaCraft) with ItemBonus →
##                 Bonus types GachaCraftID (2302), MaterialClassID (2312),
##                 MaterialAmount (2322), GachaCraftCost (2332)
##   GachaCraft                  ID, ChangeCost (목록 변경 비용)
##   GachaCraftGroupProbability  GachaCraftID → GachaCraftGroupID, GroupSelectProbability
##   GachaCraftOutput            GachaCraftGroupID, ClassID, ItemClassID, Probability,
##                               ItemAmount, ItemBlessCodeID, ItemEnchant, BoundItemProbability
##   GachaCraftBoundItem         ItemClassID → BoundItemClassID
## Every rule the tables do not state is a "TWILIGHT 근사" below and in
## docs/PATCH523_CRAFTING_EQUIPMENT.md ("비법서 제작").
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const DUMMY = preload("res://scripts/quests/source_dummy523.gd")

## Original weights: GroupSelectProbability and each group's Probability per
## ClassID sum to 10,000,000 in every 523 row set (checked by the test).
const SCALE: int = 10000000

## ── TWILIGHT 근사 (sources: https://dailyfun.kr/85 , https://dailyfun.kr/27 ,
## https://dailyfun.kr/206 , https://www.inven.co.kr/board/lineagem/5056/10935) ──
## Live client: double-click the 비법서, load the 구슬/재료, a list of candidates
## is drawn (목록 변경 = ChangeCost 아데나), then 제작 (GachaCraftCost 아데나)
## gives one random item of the list.
## TWILIGHT: one 제작 = 1 calling 비법서 + MaterialAmount × MaterialClassID +
## GachaCraftCost 아데나, and one direct draw over the original weights
## (group by GroupSelectProbability, then item by Probability). The candidate
## list and its ChangeCost reroll are not modelled (a reroll does not change the
## final weights of a single draw). (근거 약함: consumption timing of the book.)
const APPROX_CONSUME_BOOK: int = 1
## TWILIGHT 근사 (근거 약함): BoundItemProbability is the chance (per SCALE)
## that the drawn item is given as its GachaCraftBoundItem.BoundItemClassID.
## TWILIGHT 근사: ClassID 0 rows are for every class. When a group has no row
## for the player's class, the knight (ClassID 1) rows are used (근거 약함).
const APPROX_FALLBACK_CLASS: int = 1
## TWILIGHT 근사: an output row whose item is TestItem / declared dummy is left
## out and the rest of its group is renormalized (they cannot exist offline).
## TWILIGHT 근사: ItemBlessCodeID 0 (one row) is given as normal (1).
const ORIGIN := "TWILIGHT 근사 2026-11-16 · 비법서 제작 (docs/PATCH523_CRAFTING_EQUIPMENT.md)"

const BONUS_TYPES := {2302:"gacha",2312:"material",2322:"material_amount",2332:"cost"}
static var _specs: Dictionary = {}
static var _spec_identity: Dictionary = {}

static func _fail(reason: String, code: String = "refused") -> Dictionary:
	return {"ok":false,"reason":reason,"code":code}

static func _int(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value))

static func _name(item_class_id: int) -> String:
	var raw: Dictionary = SOURCE.row("ItemClass",item_class_id)
	if raw.is_empty(): return ""
	for field: String in ["IdentifiedDescID","DescID"]:
		var rows: Array = SOURCE.related("DescData_Korean","ID",int(raw.get(field,0)))
		if not rows.is_empty() and not str(rows[-1].get("Description","")).strip_edges().is_empty(): return str(rows[-1].Description).strip_edges()
	return str(raw.get("Name",""))

## {gacha_id, material_id, material_amount, cost, change_cost} of a calling
## item (empty when it is not a usable original 비법서).
static func spec(item_class_id: int) -> Dictionary:
	if SOURCE.identity() != _spec_identity: _specs.clear(); _spec_identity = SOURCE.identity()
	if _specs.has(item_class_id): return _specs[item_class_id]
	var result: Dictionary = {}
	var raw: Dictionary = SOURCE.row("ItemClass",item_class_id)
	if not raw.is_empty() and raw.get("TestItem") == false and DUMMY.item_evidence(raw).is_empty():
		var found: Dictionary = {}
		for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",item_class_id):
			var bonus: Array = SOURCE.related("Bonus","ID",int(link.get("BonusID",0)))
			if bonus.is_empty(): continue
			var kind: Variant = BONUS_TYPES.get(int(bonus[-1].get("BonusTypeID",0)))
			if kind != null and _int(bonus[-1].get("Value")): found[kind] = int(bonus[-1].Value)
		var craft: Array = SOURCE.related("GachaCraft","ID",int(found.get("gacha",0)))
		if found.size() == 4 and craft.size() == 1 and int(found.material_amount) > 0 and int(found.cost) >= 0:
			result = {"item_class_id":item_class_id,"name":_name(item_class_id),"gacha_id":int(found.gacha),"material_id":int(found.material),
				"material_name":_name(int(found.material)),"material_amount":int(found.material_amount),"cost":int(found.cost),"change_cost":int(craft[0].get("ChangeCost",0))}
	_specs[item_class_id] = result
	return result

## Every usable calling 비법서 of the original (non-test, complete bonuses).
static func callers() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	# Column reads only: Bonus has ~218,000 rows.
	var types: Variant = SOURCE.column("Bonus","BonusTypeID")
	var ids: Variant = SOURCE.column("Bonus","ID")
	var bonus_ids: Array = []
	if types.size() == SOURCE.row_count("Bonus") and ids.size() == types.size():
		for index: int in types.size():
			if int(types[index]) == 2302: bonus_ids.append(int(ids[index]))
	else:
		for index: int in SOURCE.row_count("Bonus"):
			var row: Dictionary = SOURCE.row_at("Bonus",index)
			if int(row.get("BonusTypeID",0)) == 2302: bonus_ids.append(int(row.ID))
	for bonus_id: int in bonus_ids:
		for link: Dictionary in SOURCE.related("ItemBonus","BonusID",bonus_id):
			var id: int = int(link.get("ItemClassID",0))
			if seen.has(id): continue
			seen[id] = true
			if not spec(id).is_empty(): result.append(id)
	result.sort()
	return result

static func _drawable(item_class_id: int) -> bool:
	var raw: Dictionary = SOURCE.row("ItemClass",item_class_id)
	return not raw.is_empty() and raw.get("TestItem") == false and DUMMY.item_evidence(raw).is_empty() and SOURCE.declared_exclusion("ItemClass",raw).is_empty()

## The draw table for one class: [{group_id, group_weight, row, weight}], where
## weight = group_weight × row weight / group total (integers, SCALE² basis).
static func table(gacha_id: int, class_id: int) -> Dictionary:
	var groups: Array = SOURCE.related("GachaCraftGroupProbability","GachaCraftID",gacha_id)
	if groups.is_empty(): return _fail("원본 비법서 그룹 확률이 없습니다","no_groups")
	var entries: Array = []; var group_total: int = 0; var notes: Dictionary = {}
	for group: Dictionary in groups: group_total += int(group.get("GroupSelectProbability",0))
	if group_total <= 0: return _fail("원본 그룹 확률 합이 0입니다","group_total")
	if group_total != SCALE: notes["group_normalized"] = group_total
	var total: int = 0
	for group: Dictionary in groups:
		var group_id: int = int(group.GachaCraftGroupID)
		var group_weight: int = int(group.GroupSelectProbability)
		if group_weight <= 0: continue
		var rows: Array = SOURCE.related("GachaCraftOutput","GachaCraftGroupID",group_id)
		var chosen: Array = []
		for wanted: int in [class_id,0,APPROX_FALLBACK_CLASS]:
			for row: Dictionary in rows:
				if int(row.get("ClassID",-1)) == wanted: chosen.append(row)
			if not chosen.is_empty():
				if wanted == APPROX_FALLBACK_CLASS and class_id != APPROX_FALLBACK_CLASS: notes["class_fallback"] = true
				break
		var kept: Array = []; var row_total: int = 0
		for row: Dictionary in chosen:
			if int(row.get("Probability",0)) <= 0 or int(row.get("ItemAmount",0)) < 1: continue
			if not _drawable(int(row.get("ItemClassID",0))): notes["test_rows_removed"] = int(notes.get("test_rows_removed",0))+1; continue
			kept.append(row); row_total += int(row.Probability)
		if kept.is_empty(): continue
		for row: Dictionary in kept:
			# group_weight/group_total × row/row_total on a SCALE² integer basis.
			var weight: int = int(round(float(group_weight) / float(group_total) * float(row.Probability) / float(row_total) * float(SCALE) * float(SCALE)))
			if weight <= 0: weight = 1
			entries.append({"group_id":group_id,"group_weight":group_weight,"row":row,"weight":weight})
			total += weight
	if entries.is_empty(): return _fail("이 직업이 받을 수 있는 원본 결과가 없습니다","empty")
	return {"ok":true,"entries":entries,"total":total,"notes":notes}

## Pure draw: `roll` in [0,total) picks the entry; `bound_roll` in [0,SCALE)
## turns it into its bound item when below BoundItemProbability.
static func pick(drawn: Dictionary, roll: int, bound_roll: int) -> Dictionary:
	var threshold: int = 0
	for entry: Dictionary in drawn.entries:
		threshold += int(entry.weight)
		if roll < threshold:
			var row: Dictionary = entry.row
			var item_id: int = int(row.ItemClassID)
			var bound: bool = false
			if int(row.get("BoundItemProbability",0)) > 0 and bound_roll < int(row.BoundItemProbability):
				var mapping: Array = SOURCE.related("GachaCraftBoundItem","ItemClassID",item_id)
				if not mapping.is_empty() and _drawable(int(mapping[0].get("BoundItemClassID",0))): item_id = int(mapping[0].BoundItemClassID); bound = true
			var bless: int = int(row.get("ItemBlessCodeID",1))
			if bless not in [1,2,3]: bless = 1
			return {"row_id":int(row.get("ID",0)),"group_id":int(entry.group_id),"item_class_id":item_id,"amount":int(row.ItemAmount),"enchant":int(row.get("ItemEnchant",0)),"bless_raw":bless,"bound":bound,"name":_name(item_id)}
	return {}

static func class_of(world: Node) -> int:
	return int(preload("res://scripts/lineagem_base508.gd").source_class_id(str(world.job_class)))

## Proven physical stacks (receipted) of one original item, unlocked, ID order.
static func stacks_of(world: Node, item_class_id: int) -> Dictionary:
	var ids: Array = world.item_instances.keys(); ids.sort()
	var stacks: Array = []; var total: int = 0
	for uid: Variant in ids:
		var owned: Dictionary = STACK.proof(world,str(uid))
		if owned.is_empty() or int(owned.record.get("source_item_class_id",0)) != item_class_id or int(owned.record.get("source_bless_raw",1)) != 1: continue
		var name_value: String = str(owned.record.name)
		if world._item_locked(name_value,str(uid)) or world._item_locked(name_value): continue
		stacks.append({"uid":str(uid),"owned":owned}); total += int(owned.remaining)
	return {"stacks":stacks,"total":total}

static func _requests(stacks: Array, need: int) -> Array:
	var requests: Array = []; var remaining: int = need
	for stack: Dictionary in stacks:
		if remaining == 0: break
		var owned: Dictionary = stack.owned
		var amount: int = mini(remaining,int(owned.remaining))
		requests.append({"physical_id":stack.uid,"quantity":amount,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-amount,STACK.RECEIPT:owned.receipt.duplicate(true)})
		remaining -= amount
	return requests

## Calling 비법서 the bag holds, with counts: [{item_class_id, name, owned, spec}].
static func owned_callers(world: Node) -> Array:
	var counts: Dictionary = {}
	for uid: Variant in world.item_instances:
		var owned: Dictionary = STACK.proof(world,str(uid))
		if owned.is_empty(): continue
		var id: int = int(owned.record.get("source_item_class_id",0))
		if spec(id).is_empty(): continue
		counts[id] = int(counts.get(id,0)) + int(owned.remaining)
	var result: Array = []
	for id: int in counts: result.append({"item_class_id":id,"name":spec(id).name,"owned":counts[id],"spec":spec(id)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.item_class_id) < int(b.item_class_id))
	return result

## Material payment plan: wallet (아데나 / coin) or proven stacks.
static func _material(world: Node, item: Dictionary, extra_gold: int) -> Dictionary:
	var id: int = int(item.material_id); var need: int = int(item.material_amount)
	if id == 26:
		return {"ok":int(world.gold) >= need + extra_gold,"kind":"adena","owned":maxi(0,int(world.gold)-extra_gold),"need":need}
	var coin: String = SUPPLY.coin_wallet(id)
	if not coin.is_empty():
		return {"ok":int(world.inventory.get(coin,0)) >= need,"kind":"wallet","wallet":coin,"owned":int(world.inventory.get(coin,0)),"need":need}
	var owned: Dictionary = stacks_of(world,id)
	return {"ok":int(owned.total) >= need,"kind":"stack","owned":int(owned.total),"need":need,"requests":_requests(owned.stacks,need) if int(owned.total) >= need else []}

## Quote of one 비법서 제작: costs, ownership and the class's draw table.
static func quote(world: Node, item_class_id: int) -> Dictionary:
	if SOURCE.not_installed() or SOURCE.identity().is_empty(): return _fail("보유 원본523 정의 ZIP이 필요합니다","source")
	var item: Dictionary = spec(item_class_id)
	if item.is_empty(): return _fail("원본 비법서 제작 아이템이 아닙니다","not_caller")
	var drawn: Dictionary = table(int(item.gacha_id),class_of(world))
	if not drawn.get("ok",false): return drawn
	var books: Dictionary = stacks_of(world,item_class_id)
	var material: Dictionary = _material(world,item,int(item.cost))
	var gold_need: int = int(item.cost) + (int(item.material_amount) if material.kind == "adena" else 0)
	var outcomes: Array = []
	for entry: Dictionary in drawn.entries:
		outcomes.append({"item_class_id":int(entry.row.ItemClassID),"name":_name(int(entry.row.ItemClassID)),"amount":int(entry.row.ItemAmount),"enchant":int(entry.row.get("ItemEnchant",0)),"bless_raw":int(entry.row.get("ItemBlessCodeID",1)),"percent":100.0*float(entry.weight)/float(drawn.total),"bound_percent":100.0*float(entry.row.get("BoundItemProbability",0))/float(SCALE)})
	var reason: String = ""
	if int(books.total) < APPROX_CONSUME_BOOK: reason = "%s이(가) 없습니다" % str(item.name)
	elif not material.ok: reason = "%s이(가) 부족합니다 (%d/%d)" % [str(item.material_name),int(material.owned),int(material.need)]
	elif int(world.gold) < gold_need: reason = "아데나가 부족합니다 (%d/%d)" % [int(world.gold),gold_need]
	return {"ok":reason.is_empty(),"reason":reason,"code":"short" if not reason.is_empty() else "","item":item,"books_owned":int(books.total),"material":material,
		"gold_cost":gold_need,"outcomes":outcomes,"total_weight":int(drawn.total),"notes":drawn.notes,"origin":ORIGIN,
		"book_requests":_requests(books.stacks,APPROX_CONSUME_BOOK) if int(books.total) >= APPROX_CONSUME_BOOK else []}

## Executes one 비법서 제작 (one atomic save: book + material + 아데나 + the
## granted item + RNG). `roll`/`bound_roll` < 0 draw from the game RNG.
static func execute(world: Node, item_class_id: int, roll: int = -1, bound_roll: int = -1) -> Dictionary:
	var approval: Dictionary = quote(world,item_class_id)
	if not approval.get("ok",false): return approval
	var rng := RandomNumberGenerator.new()
	rng.state = world.rng.state
	var drawn: Dictionary = table(int(approval.item.gacha_id),class_of(world))
	# 62-bit draw (two 32-bit values); the modulo bias over ~10^14 is < 10^-4.
	if roll < 0: roll = (((rng.randi() & 0x3FFFFFFF) << 32) | rng.randi()) % int(drawn.total)
	if bound_roll < 0: bound_roll = rng.randi_range(0,SCALE-1)
	if roll >= int(drawn.total) or bound_roll >= SCALE: return _fail("비법서 추첨 값이 범위 밖입니다","roll")
	var picked: Dictionary = pick(drawn,roll,bound_roll)
	if picked.is_empty(): return _fail("비법서 추첨 결과가 없습니다","roll")
	var requests: Array = approval.book_requests.duplicate(true)
	if approval.material.kind == "stack": requests.append_array(approval.material.requests)
	var debit: Dictionary = STACK.stage_debit(world,requests)
	if not debit.get("ok",false): return _fail(str(debit.get("reason",debit.get("error","비법서·재료 차감 준비 실패"))),"debit")
	var inventory: Dictionary = debit.overrides.inventory
	if approval.material.kind == "wallet":
		var left: int = int(inventory.get(approval.material.wallet,0)) - int(approval.material.need)
		if left < 0: return _fail("재화가 부족합니다","wallet")
		inventory[approval.material.wallet] = left
	var gold: int = int(world.gold) - int(approval.gold_cost)
	if gold < 0: return _fail("아데나가 부족합니다","adena")
	var view := STACK.SupplierView.new()
	view.host = world; view.inventory = inventory; view.item_instances = debit.overrides.item_instances; view.gold = gold
	var origin: Dictionary = {"kind":"source523_gacha_craft","approximation":ORIGIN,"caller_item_class_id":item_class_id,"gacha_craft_id":int(approval.item.gacha_id),
		"group_id":int(picked.group_id),"output_row_id":int(picked.row_id),"roll":roll,"bound_roll":bound_roll,"bound":picked.bound}
	var staged: Dictionary = SUPPLY.stage(view,[{"item_class_id":int(picked.item_class_id),"amount":int(picked.amount),"bless_raw":int(picked.bless_raw),"enchant":int(picked.enchant)}],origin)
	view.free()
	if not staged.get("ok",false): return _fail(str(staged.get("error","비법서 결과 지급 준비 실패")) + " · 비법서·재료·아데나 보존","grant")
	var overrides: Dictionary = staged.overrides
	overrides["consumable_state"] = debit.overrides.consumable_state
	var before: int = world.rng.state
	world.rng.state = rng.state
	if world._save_game(true,overrides) != OK:
		world.rng.state = before
		return _fail("비법서 제작 저장 실패 · 비법서·재료·아데나 보존","save")
	world.inventory = overrides.inventory
	world.item_instances = overrides.item_instances
	world.gold = int(overrides.gold)
	world.consumable_service.import_state(overrides.consumable_state)
	if world.get("hud") != null and world.hud != null:
		world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	var detail: String = "비법서 제작 · %s%s ×%d%s" % ["+%d " % int(picked.enchant) if int(picked.enchant) > 0 else "",str(picked.name),int(picked.amount)," (귀속)" if picked.bound else ""]
	return {"ok":true,"output":picked,"roll":roll,"bound_roll":bound_roll,"gold_cost":int(approval.gold_cost),"material":{"item_class_id":int(approval.item.material_id),"amount":int(approval.item.material_amount)},"detail":detail,"origin":ORIGIN}
