extends RefCounted
## Boxes bought from converted cash-store offers. Their contents are read from
## the installed original 523 definitions (LuckyBagClass / SelectReward), never
## from notices: notices only supplied the KRW price. Rewards are delivered to
## the existing game owners: cards -> card collection, known items -> inventory
## (physical instances for equipment), and nested boxes -> openable boxes.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const CashMarket = preload("res://scripts/shop/source523_cash_market.gd")
const TAG: String = "twilight-cash-package"
const ITEM_TAG: String = "twilight-cash-package-item"
const CARD_CATEGORIES: Dictionary = {1:"변신", 2:"마법인형", 98:"성물"}
const ALL_CLASSES: int = 10000
const SELECT_REWARD_TYPE: int = 111
const ITEM_REWARD_TYPE: int = 2
const MAX_DEPTH: int = 8
const GOTCHA_UNIT: int = 35
const BUFF_CARD_UNIT: int = 33
const LIMIT: int = 9007199254740991
static var _definitions: Dictionary = {}
static var _names: Dictionary = {}
static var rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var busy: bool = false

static func reset() -> void:
	_definitions.clear()
	_names.clear()

static func available() -> bool:
	return not SOURCE.identity().is_empty() and not CashMarket.data().is_empty()

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value))

static func label(item_id: int) -> String:
	var item: Dictionary = SOURCE.row("ItemClass", item_id)
	if item.is_empty(): return ""
	var text: String = str(SOURCE.row("DescData_Korean", int(item.get("DescID", 0))).get("Description", "")).strip_edges()
	return text

static func bonus_values(item_id: int) -> Dictionary:
	var out: Dictionary = {}
	for link: Dictionary in SOURCE.related("ItemBonus", "ItemClassID", item_id):
		var bonus: Dictionary = SOURCE.row("Bonus", int(link.get("BonusID", 0)))
		if bonus.is_empty(): continue
		var type: Dictionary = SOURCE.row("BonusType", int(bonus.get("BonusTypeID", 0)))
		var key: String = str(type.get("Name", ""))
		if key.is_empty(): continue
		if not out.has(key): out[key] = []
		out[key].append(bonus.get("Value"))
	return out

## Original box rule for one ItemClass, or {} when the item is not a box.
static func definition(item_id: int) -> Dictionary:
	if _definitions.has(item_id): return _definitions[item_id]
	var result: Dictionary = {}
	if item_id > 0 and not SOURCE.identity().is_empty():
		var values: Dictionary = bonus_values(item_id)
		var bags: Array = values.get("LuckyBagClassID", [])
		var selects: Array = values.get("SelectRewardClassID", [])
		if bags.size() == 1 and selects.is_empty() and integer(bags[0]):
			result = _bag(item_id, int(bags[0]))
		elif selects.size() == 1 and bags.is_empty() and integer(selects[0]):
			result = _select(item_id, int(selects[0]))
		elif bags.is_empty() and selects.is_empty() and values.get("MarketPurchaseID", []).size() == 1 and integer(values.MarketPurchaseID[0]):
			result = _gotcha(item_id, int(values.MarketPurchaseID[0]))
	_definitions[item_id] = result
	return result

static func _bag(item_id: int, bag_id: int) -> Dictionary:
	var bag: Dictionary = SOURCE.row("LuckyBagClass", bag_id)
	if bag.is_empty(): return {}
	var entries: Array = []
	for row: Dictionary in SOURCE.related("LuckyBagEntityView", "LuckyBagClassID", bag_id):
		var kind: int = int(row.get("LuckyBagEntityTypeID", -1))
		if kind not in [0, 1] or not integer(row.get("ItemAmount")) or int(row.ItemAmount) < 1: return {}
		entries.append({"entity_id":int(row.ID), "item_class_id":int(row.ItemClassID), "amount":int(row.ItemAmount),
			"given":kind == 1, "probability":int(row.get("Probability", 0)), "limit_class":int(row.get("LimitClass", ALL_CLASSES)),
			"bless":int(row.get("ItemBlessCodeID", 1)), "enchant":int(row.get("ItemEnchant", 0))})
	if entries.is_empty(): return {}
	return {"kind":"bag", "item_class_id":item_id, "lucky_bag_class_id":bag_id, "entries":entries}

static func _select(item_id: int, reward_id: int) -> Dictionary:
	var root: Dictionary = SOURCE.row("Reward", reward_id)
	if int(root.get("RewardTypeID", -1)) != SELECT_REWARD_TYPE: return {}
	var group: Dictionary = SOURCE.row("SelectReward", int(root.get("RewardClassID", 0)))
	if group.is_empty(): return {}
	var entries: Array = []
	for link: Dictionary in SOURCE.related("SelectRewardEntity", "SelectRewardID", int(group.ID)):
		var reward: Dictionary = SOURCE.row("Reward", int(link.get("RewardID", 0)))
		if int(reward.get("RewardTypeID", -1)) != ITEM_REWARD_TYPE or not integer(reward.get("Amount")) or int(reward.Amount) < 1: continue
		entries.append({"entity_id":int(link.ID), "reward_id":int(reward.ID), "item_class_id":int(reward.RewardClassID),
			"amount":int(reward.Amount), "class_id":int(reward.get("CharacterClassID", 0)), "bless":int(reward.get("ItemBlessCodeID", 1))})
	if entries.is_empty(): return {}
	return {"kind":"select", "item_class_id":item_id, "reward_id":reward_id, "select_reward_id":int(group.ID),
		"root_class_id":int(root.get("CharacterClassID", 0)), "max":int(group.get("SelectMaxCount", 1)), "entries":entries}

## Original card draw pack: the item runs a market purchase whose products are
## GotChaClass draws (Unit 35). Only polymorph/doll/relic card pools qualify.
static func _gotcha(item_id: int, purchase_id: int) -> Dictionary:
	var draws: Array = []
	for link: Dictionary in SOURCE.related("MarketPurchaseProduct", "MarketPurchaseID", purchase_id):
		var product: Dictionary = SOURCE.row("MarketProduct", int(link.get("MarketProductID", 0)))
		if int(product.get("UnitID", 0)) != GOTCHA_UNIT or not integer(product.get("Amount")) or int(product.Amount) < 1: return {}
		var entries: Array = []
		var total: int = 0
		for row: Dictionary in SOURCE.related("GotChaEntityView", "GotChaClassID", int(product.ClassID)):
			if int(row.get("UnitID", 0)) != BUFF_CARD_UNIT or int(row.get("Probability", 0)) <= 0: return {}
			var card: Dictionary = SOURCE.row("BuffCard", int(row.ClassID))
			if not CARD_CATEGORIES.has(int(card.get("BuffCardDeckID", 0))): return {}
			entries.append({"entity_id":int(row.ID), "card_id":int(row.ClassID), "probability":int(row.Probability), "amount":1, "item_class_id":0})
			total += int(row.Probability)
		if entries.is_empty() or total <= 0: return {}
		draws.append({"gotcha_class_id":int(product.ClassID), "count":int(product.Amount), "total":total, "entries":entries})
	if draws.is_empty(): return {}
	var flat: Array = []
	for draw: Dictionary in draws: flat.append_array(draw.entries)
	return {"kind":"gotcha", "item_class_id":item_id, "market_purchase_id":purchase_id, "draws":draws, "entries":flat}

static func roll_gotcha(spec: Dictionary, random: RandomNumberGenerator) -> Array:
	var rewards: Array = []
	for draw: Dictionary in spec.draws:
		for unused: int in range(int(draw.count)):
			var pick: int = random.randi_range(1, int(draw.total))
			for entry: Dictionary in draw.entries:
				pick -= int(entry.probability)
				if pick <= 0:
					rewards.append(entry)
					break
	return rewards

static func _card_target(world, card_id: int) -> Dictionary:
	var card: Dictionary = SOURCE.row("BuffCard", card_id)
	var category: String = str(CARD_CATEGORIES.get(int(card.get("BuffCardDeckID", 0)), ""))
	if category.is_empty(): return {}
	var candidates: Array = []
	for row: Dictionary in world.catalog_db.get(category, []):
		if int(row.get("source_card_id", -1)) == card_id and row.get("source") in ["lineagem_base508", "lineagem_patch523"]: candidates.append(row)
	if candidates.size() != 1: return {}
	return {"kind":"card", "category":category, "card_id":card_id, "record":candidates[0]}

static func is_package(item_id: int) -> bool:
	return not definition(item_id).is_empty()

static func card_reference(item_id: int) -> Dictionary:
	var cards: Array = bonus_values(item_id).get("BuffCardID", [])
	if cards.size() != 1 or not integer(cards[0]): return {}
	var card: Dictionary = SOURCE.row("BuffCard", int(cards[0]))
	var category: String = str(CARD_CATEGORIES.get(int(card.get("BuffCardDeckID", 0)), ""))
	if category.is_empty(): return {}
	return {"card_id":int(cards[0]), "category":category}

## Same TWILIGHT estimate as native 523 records (item_weight_rules.json
## current523_source_weight: ceil(raw * numerator / denominator)).
static func _weight(item_id: int) -> int:
	var raw: Variant = SOURCE.row("ItemClass", item_id).get("Weight", 0)
	if not integer(raw) or int(raw) <= 0: return 0
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_weight_rules.json"))
	var policy: Dictionary = rules.get("current523_source_weight", {}) if rules is Dictionary else {}
	var numerator: int = int(policy.get("points_numerator", 3))
	var denominator: int = maxi(1, int(policy.get("source_units_denominator", 351)))
	return int((int(raw) * numerator + denominator - 1) / denominator)

static func _grade(item_id: int) -> String:
	var grade: int = int(SOURCE.row("ItemClass", item_id).get("GradeID", 1))
	return str({1:"일반", 2:"고급", 3:"희귀", 4:"영웅", 5:"전설", 6:"신화", 7:"유일"}.get(grade, "일반"))

static func _summary(item_id: int) -> String:
	var spec: Dictionary = definition(item_id)
	var lines: Array[String] = []
	if spec.kind == "gotcha":
		var count: int = 0
		for draw: Dictionary in spec.draws: count += int(draw.count)
		return "원본 카드 뽑기 %d회 · 카드 %d종 중 원본 확률로 획득\n원본523 GotCha 정의 · 원작 현금 상점 경로" % [count, spec.entries.size()]
	if spec.kind == "select": lines.append("구성품 중 1종 선택하여 획득")
	else:
		var weighted: bool = false
		for entry: Dictionary in spec.entries:
			if not entry.given: weighted = true
		lines.append("구성품 모두 획득" if not weighted else "정해진 확률에 따라 구성품 획득")
	var seen: Dictionary = {}
	for entry: Dictionary in spec.entries:
		var text: String = "- %s %d개" % [label(int(entry.item_class_id)), int(entry.amount)]
		if seen.has(text): continue
		seen[text] = true
		if seen.size() > 12:
			lines.append("- 외 %d종" % (spec.entries.size() - 12))
			break
		lines.append(text)
	return "\n".join(lines) + "\n원본523 상자 정의 · 원작 현금 상품을 TWILIGHT 다이아로 구매"

## Inventory name for an original item. Keeps an existing different item intact.
static func _box_name(world, item_id: int) -> String:
	if _names.has(item_id): return _names[item_id]
	var name: String = label(item_id)
	var existing: Dictionary = world._find_catalog_item_record(name)
	if not existing.is_empty() and not (existing.get("source") in [TAG, ITEM_TAG] and int(existing.get("source_item_class_id", 0)) == item_id):
		name = "%s · 상점#%d" % [name, item_id]
	_names[item_id] = name
	return name

static func _register(world, record: Dictionary) -> Dictionary:
	var existing: Dictionary = world._find_catalog_item_record(str(record.name))
	if not existing.is_empty(): return existing
	world.item_db.append(record.duplicate(true))
	world.catalog_db["아이템"].append(record)
	return record

static func box_record(world, item_id: int) -> Dictionary:
	var name: String = _box_name(world, item_id)
	return _register(world, {"name":name, "grade":_grade(item_id), "type":"상자", "slot":"consumable", "stackable":true,
		"weight":_weight(item_id), "source_weight_origin":"current523_original_estimate", "droppable":false, "sellable":false, "source":TAG, "source_item_class_id":item_id,
		"sourceId":"cash523:%d" % item_id, "cash_package":true, "desc":_summary(item_id)})

## Where one original reward item goes in TWILIGHT.
static func resolve(world, item_id: int) -> Dictionary:
	if is_package(item_id): return {"kind":"box", "name":box_record(world, item_id).name, "record":world._find_catalog_item_record(_box_name(world, item_id))}
	var card: Dictionary = card_reference(item_id)
	if not card.is_empty():
		var found: Dictionary = _card_target(world, int(card.card_id))
		if not found.is_empty(): return found
	# Existing TWILIGHT owner: exact original ID first, then the original Korean
	# name. Native 523 records need physical receipts and are not used here.
	var exact: Dictionary = {}
	for row: Dictionary in world.catalog_db.get("아이템", []):
		if row.get("source") in [TAG, ITEM_TAG] or bool(row.get("source_m_native_item", false)): continue
		var sid: String = str(row.get("sourceId", ""))
		if int(row.get("source_item_class_id", -1)) == item_id or int(row.get("source523_shop_item_id", -1)) == item_id or (row.get("source") == "inven" and sid == str(item_id)):
			exact = row
			break
	if exact.is_empty():
		var named: Dictionary = world._find_catalog_item_record(label(item_id))
		if not named.is_empty() and not named.get("source") in [TAG, ITEM_TAG] and not bool(named.get("source_m_native_item", false)): exact = named
	if not exact.is_empty():
		return {"kind":"item", "name":str(exact.name), "record":exact}
	# Original item without a TWILIGHT owner yet: kept as a plain inventory item.
	var name: String = _box_name(world, item_id)
	var record: Dictionary = _register(world, {"name":name, "grade":_grade(item_id), "type":"재료", "slot":"material", "stackable":true,
		"weight":_weight(item_id), "source_weight_origin":"current523_original_estimate", "droppable":false, "sellable":false, "source":ITEM_TAG, "source_item_class_id":item_id,
		"sourceId":"cash523:%d" % item_id, "desc":"원본523 아이템 · 현금 상점 상자 구성품 · TWILIGHT 사용 기능 연결 대기"})
	return {"kind":"item", "name":name, "record":record}

static func _walk(world, item_id: int, seen: Dictionary, depth: int) -> void:
	if depth > MAX_DEPTH or seen.has(item_id): return
	seen[item_id] = true
	resolve(world, item_id)
	var spec: Dictionary = definition(item_id)
	if spec.get("kind") == "gotcha": return
	for entry: Dictionary in spec.get("entries", []): _walk(world, int(entry.item_class_id), seen, depth + 1)

## Registers every box/reward item reachable from listed offers (also needed
## after a reload so saved stacks keep their record) and returns shop bindings.
static func install(world, catalog) -> Dictionary:
	var bindings: Dictionary = {}
	if not available() or catalog == null: return bindings
	var seen: Dictionary = {}
	for key: String in CashMarket.data().entries:
		var offer: Dictionary = catalog.market_offer(int(key))
		for link: Dictionary in offer.get("products", []):
			var product: Dictionary = link.product.definition
			if int(product.get("UnitID", 0)) != 4: continue
			var item_id: int = int(product.ClassID)
			_walk(world, item_id, seen, 0)
			var target: Dictionary = resolve(world, item_id)
			if target.kind in ["box", "item"]: bindings["4:%d" % item_id] = {"name":str(target.name), "record":target.record.duplicate(true)}
	world._index_item_weights()
	return bindings

static func current_class(world) -> int:
	return int(preload("res://scripts/loot/current523_native_stack.gd").current_class(world))

static func _eligible(entry: Dictionary, class_id: int, select: bool) -> bool:
	if select: return int(entry.class_id) == 0 or int(entry.class_id) == class_id
	return int(entry.limit_class) == ALL_CLASSES or int(entry.limit_class) == class_id

## The rewards one opening of a bag yields for the player's class.
static func roll_bag(spec: Dictionary, class_id: int, random: RandomNumberGenerator) -> Dictionary:
	var rewards: Array = []
	var weighted: Array = []
	var total: int = 0
	for entry: Dictionary in spec.entries:
		if not _eligible(entry, class_id, false): continue
		if entry.given: rewards.append(entry)
		elif int(entry.probability) > 0:
			weighted.append(entry)
			total += int(entry.probability)
	if not weighted.is_empty():
		var pick: int = random.randi_range(1, total)
		for entry: Dictionary in weighted:
			pick -= int(entry.probability)
			if pick <= 0:
				rewards.append(entry)
				break
	if rewards.is_empty(): return {"ok":false, "reason":"현재 직업이 받을 수 있는 원본 구성품이 없습니다"}
	return {"ok":true, "rewards":rewards}

static func options(spec: Dictionary, class_id: int) -> Array:
	var result: Array = []
	if int(spec.root_class_id) != 0 and int(spec.root_class_id) != class_id: return result
	for entry: Dictionary in spec.entries:
		if _eligible(entry, class_id, true): result.append(entry)
	return result

static func try_use(world, item_name: String) -> bool:
	var record: Dictionary = world._find_catalog_item_record(item_name)
	if record.get("source") != TAG: return false
	var item_id: int = int(record.get("source_item_class_id", 0))
	var spec: Dictionary = definition(item_id)
	if spec.is_empty():
		world.hud.show_message("원본523 상자 정의를 확인할 수 없습니다 · 아이템 보존")
		return true
	if int(world.inventory.get(item_name, 0)) < 1:
		world.hud.show_message("상자가 없습니다")
		return true
	var class_id: int = current_class(world)
	if spec.kind == "select":
		var choices: Array = options(spec, class_id)
		if choices.is_empty():
			world.hud.show_message("현재 직업이 고를 수 있는 원본 구성품이 없습니다 · 아이템 보존")
			return true
		_choose(world, item_name, choices)
		return true
	if spec.kind == "gotcha":
		var drawn: Dictionary = open(world, item_name, roll_gotcha(spec, rng))
		world.hud.show_message(str(drawn.get("message", drawn.get("reason", ""))))
		return true
	var rolled: Dictionary = roll_bag(spec, class_id, rng)
	if not rolled.ok:
		world.hud.show_message(str(rolled.reason) + " · 아이템 보존")
		return true
	var result: Dictionary = open(world, item_name, rolled.rewards)
	world.hud.show_message(str(result.get("message", result.get("reason", ""))))
	return true

static func _choose(world, item_name: String, choices: Array) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "%s 선택" % item_name
	dialog.dialog_text = "받을 구성품을 고른 다음 확인하세요. 확인 전에는 상자가 소모되지 않습니다."
	var selector: OptionButton = OptionButton.new()
	selector.custom_minimum_size = Vector2(360, 44)
	for entry: Dictionary in choices:
		selector.add_item("%s ×%d" % [label(int(entry.item_class_id)), int(entry.amount)])
	dialog.add_child(selector)
	world.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if selector.selected >= 0 and selector.selected < choices.size():
			var result: Dictionary = open(world, item_name, [choices[selector.selected]])
			world.hud.show_message(str(result.get("message", result.get("reason", ""))))
		dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.popup_centered()

## Debits one box and delivers the given original rewards in one save.
static func open(world, item_name: String, rewards: Array) -> Dictionary:
	if busy: return {"ok":false, "reason":"상자 개봉 처리 중"}
	var inventory: Dictionary = world.inventory.duplicate(true)
	var have: int = int(inventory.get(item_name, 0))
	if have < 1: return {"ok":false, "reason":"상자가 없습니다"}
	if have == 1: inventory.erase(item_name)
	else: inventory[item_name] = have - 1
	var instances: Dictionary = world.item_instances.duplicate(true)
	var next_id: int = int(world.next_item_instance_id)
	var cards_before: Dictionary = world.card_draw_fusion.export_state()
	var card_results: Array = []
	var received: Array[String] = []
	var failure: String = ""
	for entry: Dictionary in rewards:
		var item_id: int = int(entry.item_class_id)
		var amount: int = int(entry.amount)
		var target: Dictionary = _card_target(world, int(entry.card_id)) if int(entry.get("card_id", 0)) > 0 else resolve(world, item_id)
		if target.is_empty():
			failure = "원본 카드 정의 연결 실패"
			break
		if target.kind == "card":
			for unused: int in range(amount):
				var outcome: Dictionary = world.card_draw_fusion.receive_source_card(target.category, target.record, {"card_id":int(target.card_id),
					"item_class_id":item_id, "source_snapshot":"patch523", "origin":"twilight_cash_package", "box_item_class_id":int(definition_id_of(world, item_name))})
				if not outcome.get("ok", false):
					failure = str(outcome.get("error", "카드 지급 실패"))
					break
				card_results.append_array(outcome.get("results", []))
			received.append("%s (%s)" % [str(target.record.name), target.category])
		else:
			var name: String = str(target.name)
			if int(inventory.get(name, 0)) > LIMIT - amount:
				failure = "아이템 보유 범위 초과"
			else:
				inventory[name] = int(inventory.get(name, 0)) + amount
				var record: Dictionary = target.record
				if not str(world._enhancement_kind_for_record(record)).is_empty():
					if amount > 1000: failure = "한 번에 받을 장비가 너무 많습니다"
					for unused: int in range(mini(amount, 1000)):
						while instances.has(str(next_id)): next_id += 1
						instances[str(next_id)] = {"name":name, "level":maxi(0, int(entry.get("enchant", 0))), "element":"", "element_level":0, "record":record.duplicate(true), "sourceId":str(record.get("sourceId", ""))}
						next_id += 1
				received.append("%s ×%d" % [name, amount])
		if not failure.is_empty(): break
	var cards_after: Dictionary = world.card_draw_fusion.export_state()
	world.card_draw_fusion.import_state(cards_before)
	if not failure.is_empty(): return {"ok":false, "reason":failure + " · 상자 보존"}
	world._index_item_weights()
	if _weight_of(world, inventory) > int(world._carrying_capacity()): return {"ok":false, "reason":"무게 한도 초과 · 상자 보존"}
	busy = true
	var saved: Error = world._save_game(true, {"inventory":inventory, "item_instances":instances, "next_item_instance_id":next_id, "card_draw_fusion":cards_after})
	busy = false
	if saved != OK: return {"ok":false, "reason":"상자 개봉 저장 실패 · 상자와 기존 보유 상태 보존"}
	world.inventory = inventory
	world.item_instances = instances
	world.next_item_instance_id = next_id
	world.card_draw_fusion.import_state(cards_after)
	if world.has_method("_invalidate_equipment_static"): world._invalidate_equipment_static()
	world.hud.refresh_inventory(world.inventory)
	if world.has_method("_update_hud"): world._update_hud()
	var message: String = "%s 개봉 · %s" % [item_name, ", ".join(received)]
	if world.hud.has_method("append_log"): world.hud.append_log(message)
	if not card_results.is_empty() and world.hud.has_method("present_card_reveal"):
		var first: Dictionary = _card_target(world, int(rewards[0].card_id)) if int(rewards[0].get("card_id", 0)) > 0 else resolve(world, int(rewards[0].item_class_id))
		world.hud.present_card_reveal(str(first.get("category", "변신")), {"ok":true, "results":card_results}, false)
	return {"ok":true, "message":message, "received":received}

static func definition_id_of(world, item_name: String) -> int:
	return int(world._find_catalog_item_record(item_name).get("source_item_class_id", 0))

static func _weight_of(world, inventory: Dictionary) -> int:
	var total: int = 0
	for name: String in inventory:
		total += int(inventory[name]) * maxi(0, int(world.item_weight_index.get(name, 3)))
	return total
