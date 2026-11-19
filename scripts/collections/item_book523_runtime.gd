extends RefCounted
## World owner of the original 523 아이템 컬렉션 (item_book523_source.gd).
## A card is registered by consuming one ItemBookItem alternative from the bag
## exactly as the original row states it (ItemClassID, Enchant, BlessCode,
## Amount): a plain original equipment piece (not equipped, not locked) or
## a receipted original stack. The bag change and the registration are one
## atomic whole-save (world._save_game override); a failed save changes
## nothing. Saved under its own key (SAVE_KEY).
##
## Earlier TWILIGHT 장비 컬렉션 records (equipment_collection_runtime, the
## guide data's 447 collections) are never changed: a registered legacy slot
## whose item matches a card of the same-named original collection is linked
## to that card (legacy_links) so it counts as registered here; a record that
## matches nothing stays only in its own save key. Collection effects are
## listed but not applied by this owner yet (the legacy owner still applies
## the guide effects), so no effect counts twice.
const Source = preload("res://scripts/collections/item_book523_source.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const REFINE = preload("res://scripts/refine523/bless_refine523_service.gd")
const SAVE_KEY := "item_book523"
const SCHEMA := 1
const ROMAN: Dictionary = {"Ⅰ":"I","Ⅱ":"II","Ⅲ":"III","Ⅳ":"IV","Ⅴ":"V","Ⅵ":"VI","Ⅶ":"VII","Ⅷ":"VIII","Ⅸ":"IX","Ⅹ":"X"}

var world: Node
var source = Source.new()
var state: Dictionary = fresh()
## A saved value this build cannot read stays as it is and blocks registering.
var preserved_raw: Variant = null
var problem: String = ""
## Why the saved value is preserved unread (registering is blocked).
var save_problem: String = ""
var busy: bool = false
var _source_tried: bool = false
var _linked: bool = false
var _bag: Dictionary = {}
var _bag_valid: bool = false
## Test hook: a fixture reader instead of the original archive.
var test_reader: RefCounted

static func fresh() -> Dictionary:
	return {"schema":SCHEMA,"revision":0,"registered":{},"legacy_links":{}}

static func _int(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

static func _fail(message: String, code: String = "refused") -> Dictionary:
	return {"ok":false,"code":code,"message":message}

func configure(owner: Node) -> void:
	world = owner

## Loads the original tables on first use (not at boot) and links legacy
## records once per load.
func prepare() -> bool:
	if not _source_tried:
		_source_tried = true
		if not source.load_source(test_reader): problem = source.problem
	if not source.ready: return false
	if not _linked:
		_linked = true
		link_legacy()
	return true

func ready() -> bool:
	return prepare() and preserved_raw == null

## --- Save ------------------------------------------------------------------

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "아이템 컬렉션 저장 형식 오류"
	if int(value.get("schema", -1)) != SCHEMA or not _int(value.get("revision")): return "아이템 컬렉션 저장 버전 오류"
	for key: String in ["registered","legacy_links"]:
		if not value.get(key) is Dictionary: return "아이템 컬렉션 저장 구조 손상: " + key
		for cid: Variant in value[key]:
			if not str(cid).is_valid_int() or not value[key][cid] is Dictionary: return "아이템 컬렉션 ID 형식 오류"
			for card: Variant in value[key][cid]:
				if not str(card).is_valid_int() or not value[key][cid][card] is Dictionary: return "아이템 컬렉션 카드 형식 오류"
	return ""

func import_state(value: Variant) -> void:
	preserved_raw = null
	state = fresh()
	_bag_valid = false
	_linked = false
	save_problem = ""
	if value == null: return
	var error: String = validate(value)
	if not error.is_empty():
		preserved_raw = value.duplicate(true) if (value is Dictionary or value is Array) else value
		save_problem = error + " · 기존 저장 보존"
		return
	state = (value as Dictionary).duplicate(true)
	state.revision = int(state.revision)
	# A new load relinks legacy records against this load's legacy owner.
	_linked = false

func export_state() -> Variant:
	if preserved_raw != null: return preserved_raw.duplicate(true) if (preserved_raw is Dictionary or preserved_raw is Array) else preserved_raw
	return state.duplicate(true)

## --- Rows --------------------------------------------------------------------

func card_registered(cid: String, card: String) -> bool:
	return state.registered.get(cid, {}).has(card) or state.legacy_links.get(cid, {}).has(card)

func registered_count(cid: String) -> int:
	var count: int = 0
	for card: Dictionary in source.collection(cid).get("cards", []):
		if card_registered(cid, str(card.id)): count += 1
	return count

func complete(cid: String) -> bool:
	var row: Dictionary = source.collection(cid)
	return not row.is_empty() and registered_count(cid) == (row.cards as Array).size()

## The window's rows of one tab (same shape as growth96.snapshot()).
func rows(tab_button: String) -> Array:
	var result: Array = []
	if not ready(): return result
	_index_bag()
	for raw: Dictionary in source.tab_rows(tab_button):
		var cid: String = str(raw.id)
		var cards: Array = []
		var count: int = 0
		for card: Dictionary in raw.cards:
			var id: String = str(card.id)
			var done: bool = card_registered(cid, id)
			if done: count += 1
			var option: Dictionary = _shown_option(card, cid)
			cards.append({"id":id,"registered":done,"possible":not done and not _cheap_option(card).is_empty(),"legacy":state.legacy_links.get(cid, {}).has(id),
				"item_class_id":int(option.item_class_id),"enchant":int(option.enchant),"bless":int(option.bless),"amount":int(option.amount)})
		result.append({"id":cid,"owner":"item_book523","name":str(raw.name),"tab":str(raw.tab),"level":int(raw.level),"recommend":bool(raw.recommend),
			"registered":count,"required":cards.size(),"complete":count == cards.size(),"cards":cards,"effects":[],
			"approximations":raw.approximations.duplicate()})
	return result

## Adds the original names and effect lines to rows about to be shown (one
## page; the item and bonus lookups stay off the other rows).
func detail(row: Dictionary) -> Dictionary:
	var out: Dictionary = row.duplicate(true)
	out.effects = source.effects_of(str(row.id))
	for card: Dictionary in out.cards: card["label"] = source.option_label(card)
	return out

## The alternative shown on a slot: the registered one, else the first.
func _shown_option(card: Dictionary, cid: String) -> Dictionary:
	var saved: Dictionary = state.registered.get(cid, {}).get(str(card.id), {})
	if not saved.is_empty():
		for option: Dictionary in card.items:
			if int(option.item_class_id) == int(saved.get("item_class_id", -1)) and int(option.bless) == int(saved.get("bless", -1)): return option
	return card.items[0]

## --- Bag ---------------------------------------------------------------------

## One cheap pass over the bag: ItemClassID -> physical entries. Registration
## re-proves the chosen entries with the owners' full checks.
func _index_bag() -> void:
	_bag.clear()
	_bag_valid = true
	if world == null: return
	var equipped: Dictionary = {}
	for slot: Variant in world.equipped_items:
		var value: Variant = world.equipped_items[slot]
		if value is Dictionary: equipped[str(value.get("instance_id", ""))] = true
	for uid: Variant in world.item_instances:
		var entry: Variant = world.item_instances[uid]
		if not entry is Dictionary or not entry.get("record") is Dictionary: continue
		var record: Dictionary = entry.record
		if record.get("source_m_native_item") != true or not _int(record.get("source_item_class_id")): continue
		var id: int = int(record.source_item_class_id)
		var stack: bool = entry.has(STACK.RECEIPT)
		var bless: int = int(record.get("source_bless_raw", 1)) if _int(record.get("source_bless_raw", 1)) else 1
		var state_name: String = str(entry.get("bless_state", ""))
		if state_name in ["blessed","축복"]: bless = 2
		elif state_name in ["cursed","저주"]: bless = 3
		var amount: int = int(entry.get(STACK.QUANTITY, 0)) if stack and _int(entry.get(STACK.QUANTITY, 0)) else 1
		if not _bag.has(id): _bag[id] = []
		_bag[id].append({"uid":str(uid),"stack":stack,"enchant":int(entry.get("level", 0)) if _int(entry.get("level", 0)) else -1,"bless":bless,"amount":amount,"equipped":equipped.has(str(uid))})

func _cheap_option(card: Dictionary) -> Dictionary:
	if not _bag_valid: _index_bag()
	for option: Dictionary in card.items:
		var total: int = 0
		for entry: Dictionary in _bag.get(int(option.item_class_id), []):
			if bool(entry.equipped) or int(entry.bless) != int(option.bless): continue
			if not bool(entry.stack) and int(entry.enchant) != int(option.enchant): continue
			if bool(entry.stack) and int(option.enchant) != 0: continue
			total += int(entry.amount)
		if total >= int(option.amount): return option
	return {}

## The proven bag entries that satisfy one alternative, or why not.
func _prove(option: Dictionary) -> Dictionary:
	var need: int = int(option.amount)
	var id: int = int(option.item_class_id)
	var equipment: Array = []
	var reasons: Array[String] = []
	var ids: Array = world.item_instances.keys()
	ids.sort()
	for uid: Variant in ids:
		var entry: Variant = world.item_instances[uid]
		if not entry is Dictionary or entry.has(STACK.RECEIPT) or not entry.get("record") is Dictionary: continue
		if int(entry.record.get("source_item_class_id", -1)) != id: continue
		var info: Dictionary = REFINE.equipment(world, str(uid))
		if not info.get("ok", false):
			reasons.append(str(info.get("reason", "")))
			continue
		if int(info.enchant) != int(option.enchant):
			reasons.append("강화 수치가 다릅니다 (+%d)" % int(info.enchant))
			continue
		if int(info.bless) != int(option.bless):
			reasons.append("축복 상태가 다릅니다")
			continue
		equipment.append(info)
		if equipment.size() == need: return {"ok":true,"kind":"equipment","items":equipment,"option":option}
	if int(option.enchant) == 0:
		var stacks: Array = []
		var total: int = 0
		for stack: Dictionary in REFINE.stacks_of(world, id).stacks:
			if int(stack.owned.record.get("source_bless_raw", 1)) != int(option.bless): continue
			stacks.append(stack)
			total += int(stack.owned.remaining)
		if total >= need: return {"ok":true,"kind":"stack","requests":REFINE._debit_requests(stacks, need),"option":option}
		if total > 0: reasons.append("수량 부족 %d/%d" % [total, need])
	return {"ok":false,"reasons":reasons}

func quote(cid: String, card_id: String) -> Dictionary:
	if not save_problem.is_empty(): return _fail(save_problem, "save_preserved")
	if not ready(): return _fail(problem if not problem.is_empty() else "원본 아이템 컬렉션 표를 읽을 수 없습니다", "source")
	var row: Dictionary = source.collection(cid)
	var card: Dictionary = {}
	for value: Dictionary in row.get("cards", []):
		if str(value.id) == card_id: card = value
	if card.is_empty(): return _fail("알 수 없는 컬렉션 칸", "unknown")
	if card_registered(cid, card_id): return _fail("이미 등록한 칸입니다", "registered")
	var reasons: Array[String] = []
	for option: Dictionary in card.items:
		var proven: Dictionary = _prove(option)
		if proven.ok:
			proven["collection_id"] = cid
			proven["card_id"] = card_id
			proven["revision"] = int(state.revision)
			proven["label"] = source.option_label(option)
			proven["message"] = "%s\n%s 을(를) 등록합니다. 등록한 아이템은 사라집니다." % [str(row.name), proven.label]
			return proven
		reasons.append_array(proven.reasons)
	var wanted: PackedStringArray = []
	for option: Dictionary in card.items: wanted.append(source.option_label(option))
	var detail: String = " · ".join(wanted)
	if not reasons.is_empty(): detail += "\n(" + reasons[0] + ")"
	return _fail("등록할 아이템이 없습니다: " + detail, "missing")

func execute(cid: String, card_id: String, expected_revision: int) -> Dictionary:
	if busy: return _fail("이전 등록을 저장 중입니다", "busy")
	if int(state.revision) != expected_revision: return _fail("컬렉션이 변경되었습니다. 다시 선택하세요", "stale")
	var offer: Dictionary = quote(cid, card_id)
	if not offer.get("ok", false): return offer
	busy = true
	var overrides: Dictionary = {}
	var physical: Array = []
	if offer.kind == "stack":
		var debit: Dictionary = STACK.stage_debit(world, offer.requests)
		if not debit.get("ok", false):
			busy = false
			return _fail(str(debit.get("reason", debit.get("error", "재료 차감 준비 실패"))), "debit")
		overrides = debit.overrides
		for selection: Dictionary in debit.selections: physical.append(str(selection.physical_id))
	else:
		var inventory: Dictionary = world.inventory.duplicate(true)
		var instances: Dictionary = world.item_instances.duplicate(true)
		for info: Dictionary in offer.items:
			REFINE._remove(inventory, instances, info)
			physical.append(str(info.uid))
		overrides = {"inventory":inventory,"item_instances":instances}
	var next: Dictionary = state.duplicate(true)
	if not next.registered.has(cid): next.registered[cid] = {}
	var option: Dictionary = offer.option
	next.registered[cid][card_id] = {"item_class_id":int(option.item_class_id),"enchant":int(option.enchant),"bless":int(option.bless),"amount":int(option.amount),
		"book_item_id":int(option.get("book_item_id", 0)),"physical_ids":physical,"at":int(Time.get_unix_time_from_system())}
	next.revision = int(next.revision) + 1
	overrides[SAVE_KEY] = next
	if world._save_game(true, overrides) != OK:
		busy = false
		return _fail("저장 실패 · 아이템과 컬렉션은 그대로입니다", "save")
	world.inventory = overrides.inventory
	world.item_instances = overrides.item_instances
	if overrides.has("consumable_state"): world.consumable_service.import_state(overrides.consumable_state)
	state = next
	_bag_valid = false
	busy = false
	if world.get("hud") != null:
		if world.hud.has_method("refresh_inventory"): world.hud.refresh_inventory(world.inventory)
		if world.hud.has_method("append_log"): world.hud.append_log("아이템 컬렉션 등록 · %s · %s" % [str(source.collection(cid).name), str(offer.label)])
	if world.has_method("_update_hud"): world._update_hud()
	return {"ok":true,"completed":complete(cid),"message":("컬렉션 완성 · " if complete(cid) else "등록 완료 · ") + str(source.collection(cid).name)}

## --- Legacy records (TWILIGHT 장비 컬렉션, 447 guide collections) ---------------

static func match_key(text: String) -> String:
	var value: String = text
	var at: int = value.find(" · 원본#")
	if at >= 0: value = value.substr(0, at)
	for roman: String in ROMAN: value = value.replace(roman, str(ROMAN[roman]))
	for marker: String in ["(각인)","[각인]","（각인）"]: value = value.replace(marker, "")
	return value.replace(" ", "").strip_edges()

static func engraved(text: String) -> bool:
	return text.contains("각인")

## Links every registered legacy slot item to one free card of the same-named
## original collection with the same item and enchant. Never edits legacy
## records; an item that matches nothing stays only in the legacy save.
## Returns how many receipts were linked by this call.
func link_legacy() -> int:
	var legacy: Variant = world.get("equipment_collections") if world != null else null
	if legacy == null or not legacy.get("progress") is Dictionary or not source.ready or preserved_raw != null: return 0
	var progress: Dictionary = legacy.progress
	if not progress.get("progress") is Dictionary or not progress.get("receipts") is Dictionary: return 0
	var linked: Dictionary = {}
	for cid: String in state.legacy_links:
		for card: String in state.legacy_links[cid]:
			for receipt: Variant in state.legacy_links[cid][card].get("legacy_receipt_ids", []): linked[str(receipt)] = true
	var definitions: Dictionary = {}
	for row: Dictionary in legacy.definitions(): definitions[str(row.get("id", ""))] = row
	var names: Dictionary = {}
	for cid: String in source.order:
		var key: String = match_key(str(source.collections[cid].name))
		if not names.has(key): names[key] = []
		names[key].append(cid)
	var added: int = 0
	var lcids: Array = progress.progress.keys()
	lcids.sort()
	for lcid: Variant in lcids:
		var definition: Dictionary = definitions.get(str(lcid), {})
		if definition.is_empty(): continue
		var candidates: Array = []
		for name_value: Variant in [definition.get("name", "")] + Array(definition.get("source_names", [])):
			for cid: String in names.get(match_key(str(name_value)), []):
				if not candidates.has(cid): candidates.append(cid)
		if candidates.is_empty(): continue
		var slots: Dictionary = progress.progress[lcid]
		var slot_ids: Array = slots.keys()
		slot_ids.sort()
		for slot_id: Variant in slot_ids:
			var requirement: Dictionary = {}
			for value: Dictionary in definition.get("requirements", []):
				if str(value.get("slot_id", "")) == str(slot_id): requirement = value
			if requirement.is_empty() or not slots[slot_id] is Array: continue
			for receipt_id: Variant in slots[slot_id]:
				if linked.has(str(receipt_id)): continue
				var receipt: Dictionary = progress.receipts.get(str(receipt_id), {})
				if receipt.is_empty(): continue
				var target: Array = _legacy_target(candidates, requirement, receipt)
				if target.is_empty(): continue
				if not state.legacy_links.has(target[0]): state.legacy_links[target[0]] = {}
				state.legacy_links[target[0]][target[1]] = {"legacy_collection_id":str(lcid),"legacy_slot_id":str(slot_id),"legacy_receipt_ids":[str(receipt_id)],
					"legacy_item":str(receipt.get("original_name", "")),"enchant":receipt.get("enchant", 0)}
				linked[str(receipt_id)] = true
				added += 1
	if added > 0: state.revision = int(state.revision) + 1
	return added

## [collection id, card id] of the free card a legacy receipt fills, or [].
## The 각인 copy of a same-named collection is preferred for an engraved item.
func _legacy_target(candidates: Array, requirement: Dictionary, receipt: Dictionary) -> Array:
	var item_key: String = match_key(str(requirement.get("name", "")))
	var enchant: Variant = receipt.get("enchant", requirement.get("enchant"))
	if not _int(enchant): return []
	var wants_engraved: bool = engraved(str(receipt.get("original_name", "")))
	var ordered: Array = []
	for pass_engraved: bool in [wants_engraved, not wants_engraved]:
		for cid: String in candidates:
			if engraved(str(source.collections[cid].name)) == pass_engraved and not ordered.has(cid): ordered.append(cid)
	for cid: String in ordered:
		for card: Dictionary in source.collections[cid].cards:
			if card_registered(cid, str(card.id)): continue
			for option: Dictionary in card.items:
				if int(option.enchant) == int(enchant) and match_key(source.item_name(int(option.item_class_id))) == item_key: return [cid, str(card.id)]
	return []

func summary() -> Dictionary:
	var done: int = 0
	var links: int = 0
	if ready():
		for cid: String in source.order:
			if complete(cid): done += 1
	for cid: String in state.legacy_links: links += (state.legacy_links[cid] as Dictionary).size()
	return {"ready":source.ready,"collections":source.order.size(),"completed":done,"legacy_links":links,"problem":problem,"save_problem":save_problem}
