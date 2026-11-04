extends RefCounted
## Private 523 rules. Existing TWILIGHT recipes and economic tables stay separate.
const BLESS = preload("res://scripts/equipment_blessing.gd")
const OPTIONS = preload("res://scripts/inven_option_adapter.gd")
const ITEM_USE = preload("res://scripts/crafting/patch523_item_use.gd")
const SCHEMA: String = "twilight-patch523-equipment-v1"
const MAX_BYTES: int = 64000000
const MAX_BATCH: int = 20
var data: Dictionary = {}
var recipes: Dictionary = {}
var problem: String = ""
var digest: String = ""

static func valid_material(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: String in ["item", "source_id"]:
		if not value.get(key) is String or str(value[key]).is_empty(): return false
	for key: String in ["quantity", "level", "bless_code"]:
		if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or float(value[key]) != float(int(value[key])): return false
	return int(value.quantity)>0 and int(value.quantity)<=(1000000000 if str(value.source_id)=="26" and bool(value.get("wallet",false)) else 100000000) and int(value.level)>=0 and int(value.level)<=21 and int(value.bless_code) in [1,2] and typeof(value.get("physical"))==TYPE_BOOL

func load_file(path: String, expected_sha256: String) -> bool:
	problem = ""
	if expected_sha256.length() != 64 or not FileAccess.file_exists(path):
		problem = "원본523 제작 규칙 파일·해시가 필요합니다"
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		problem = "원본523 제작 규칙 파일 크기를 확인하세요"
		return false
	file.close()
	if FileAccess.get_sha256(path) != expected_sha256:
		problem = "원본523 제작 규칙 SHA 불일치"
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		problem = "원본523 규칙 JSON 형식 오류"
		return false
	var parsed: Variant = parser.data
	if not parsed is Dictionary or parsed.get("schema", "") != SCHEMA or parsed.get("snapshot", "") != "patch523" or parsed.get("catalog_sha256", "") != FileAccess.get_sha256("res://data/catalog_v19.json"):
		problem = "원본523 제작 규칙·현재 아이템 DB 불일치"
		return false
	for key: String in ["recipes", "raw_recipes", "items", "bonuses", "bonus_types", "enchantment", "source_files"]:
		if not parsed.get(key) is Dictionary:
			problem = "원본523 제작 규칙 구조 오류"
			return false
	for id: Variant in parsed.recipes:
		var value: Variant = parsed.recipes[id]
		if not value is Dictionary or not str(id).begins_with("patch523:") or value.get("id", "") != id or value.get("source_snapshot", "") != "patch523" or not value.get("result") is Dictionary or not value.get("materials") is Array or int(value.get("adena", -1)) < 0:
			problem = "원본523 제작식 구조 오류"
			return false
		for material: Variant in value.materials:
			if not valid_material(material):
				problem = "원본523 재료 상태 구조 오류"
				return false
		if value.has("outcomes"):
			if not value.outcomes is Array or value.outcomes.size()<2:
				problem="원본 제작 결과 분기 구조 오류"; return false
			var total: int=0
			for outcome: Variant in value.outcomes:
				if not valid_material(outcome) or typeof(outcome.get("probability")) not in [TYPE_INT,TYPE_FLOAT] or float(outcome.probability)!=float(int(outcome.probability)) or int(outcome.probability)<1:
					problem="원본 제작 확률 구조 오류"; return false
				total+=int(outcome.probability)
			if total!=1000000:
				problem="원본 제작 확률 합계 오류"; return false
		if value.has("material_slots"):
			if not value.material_slots is Array:
				problem = "원본523 후보 슬롯 구조 오류"
				return false
			for slot: Variant in value.material_slots:
				if not slot is Dictionary or typeof(slot.get("slot_index")) not in [TYPE_INT,TYPE_FLOAT] or not slot.get("candidates") is Array or slot.candidates.is_empty():
					problem = "원본523 후보 슬롯 구조 오류"
					return false
				for material: Variant in slot.candidates:
					if not valid_material(material) or typeof(material.get("row_id")) not in [TYPE_INT,TYPE_FLOAT] or int(material.row_id)<1:
						problem = "원본523 후보 재료 구조 오류"
						return false
	# Rejected replacements never erase the last valid registry.
	data = parsed
	recipes = data.recipes.duplicate(true)
	digest = expected_sha256
	return true

static func denied(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func record(source_id: String) -> Dictionary:
	var item: Dictionary = data.get("items",{}).get(source_id,{})
	var result: Dictionary = item.get("catalog_record",{}).duplicate(true)
	var use: Dictionary = item.get("use_conditions",{})
	if not use.is_empty(): result["patch523_item_use"]=use.duplicate(true)
	return result

func craftsman_weapon_rule(pinned: Dictionary) -> Dictionary:
	# Public table is grade scoped. Only exact current523/catalog identities
	# enter this override; local and unidentified host items keep their rules.
	if pinned.get("source","")!="inven" or pinned.get("slot","")!="weapon": return {}
	var id: String = str(pinned.get("sourceId",""))
	var entry: Dictionary = data.get("items",{}).get(id,{})
	var canonical: Dictionary = entry.get("catalog_record",{})
	if canonical.get("source","")!="inven" or canonical.get("name")!=pinned.get("name") or canonical.get("grade")!=pinned.get("grade"): return {}
	var grade: int = int(entry.get("item_class",{}).get("GradeID",-1))
	var names: Dictionary = {1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",32:"신화",52:"유일"}
	if not names.has(grade) or canonical.get("grade")!=names[grade]: return {}
	return {"levels":[] if grade==52 else ([9,10,11] if grade==32 else ([9,10] if grade==5 else [9])),
		"success":5.0,"no_change":95.0,"destroy":0.0,"decrease":0.0}

static func identity(physical: Dictionary) -> String:
	var pinned: Variant = physical.get("record", {})
	if not pinned is Dictionary or pinned.get("source", "") != "inven":
		return ""
	var source_id: String = str(pinned.get("sourceId", ""))
	if physical.has("sourceId") and str(physical.sourceId) != source_id:
		return ""
	return source_id

static func bless_code(physical: Dictionary) -> int:
	var pinned: Dictionary = physical.get("record", {})
	var result: int = 2 if BLESS.is_blessed(physical, pinned) else 1
	return result if int(physical.get("source_bless_code", result)) == result else -1

static func _worn(equipped: Dictionary, id: String) -> bool:
	for value: Variant in equipped.values():
		if value is Dictionary and str(value.get("instance_id", "")) == id:
			return true
	return false

func _state_matches(physical: Dictionary, material: Dictionary, allow_smelt_loss: bool) -> bool:
	if identity(physical) != str(material.source_id) or int(physical.get("level", -1)) != int(material.level) or bless_code(physical) != int(material.bless_code):
		return false
	if str(physical.get("element", "")) != "" or int(physical.get("element_level", 0)) != 0:
		return false
	var canonical: Dictionary = record(str(material.source_id))
	if canonical.is_empty():
		return false
	var annotated: Dictionary = OPTIONS.annotate(canonical)
	var pinned: Dictionary = physical.get("record", {})
	for key: Variant in pinned:
		if key == "originalSourceOptions":
			if pinned[key] != canonical.get("sourceOptions", []):
				return false
		elif key == "enhancement_options":
			if pinned[key] != canonical.get(key, {}) and pinned[key] != supported_seal_options(str(material.source_id), int(material.bless_code)):
				return false
		elif key == "patch523_item_use":
			if pinned[key]!=canonical.get(key,{}): return false
		elif key in ["bless_state", "blessed", "grade_original", "grade_evidence", "patch523_effect_basis", "weaponTypeKey", "attackKind", "attackRangeCells", "ammo", "weaponAttackSpeed"]:
			continue
		elif key == "weight" and not canonical.has(key):
			if int(pinned[key]) != 3:
				return false
		elif not canonical.has(key) and not annotated.has(key):
			return false
		elif key in ["name", "source", "sourceId", "slot", "type", "atk", "def", "hit", "hpFlat", "hpPct", "speed", "attackSpeed", "stat"]:
			if pinned[key] != canonical.get(key) and pinned[key] != annotated.get(key):
				return false
	# Unknown instance options stay protected. A known smelt state can be lost
	# only by a recipe whose original popup explicitly warns about that loss.
	for key: Variant in physical:
		if key not in ["name", "level", "element", "element_level", "record", "sourceId", "source_snapshot", "source_bless_code", "bless_state", "blessed"]:
			if key != "source_smelt" or not allow_smelt_loss:
				return false
	return true

func available_material(material: Dictionary, inventory: Dictionary, items: Dictionary, physical: Dictionary, equipped: Dictionary, locks: Dictionary, allow_smelt_loss: bool, gold: int = -1) -> int:
	var item_name: String = str(material.item)
	if bool(material.get("wallet",false)) and str(material.source_id)=="26": return maxi(0,gold)
	if bool(locks.get(item_name, false)):
		return 0
	var owned: int = maxi(0, int(inventory.get(item_name, 0)))
	if not bool(material.physical):
		var item: Dictionary = items.get(item_name, {})
		return owned if _stack_identity_matches(item,material) else 0
	var eligible: int = 0
	for id: Variant in physical:
		var instance: Variant = physical[id]
		if instance is Dictionary and instance.get("name", "") == item_name and not _worn(equipped, str(id)) and not bool(locks.get(item_name + "@@@" + str(id), false)) and _state_matches(instance, material, allow_smelt_loss):
			eligible += 1
	return mini(owned, eligible)

func _stack_identity_matches(item: Dictionary, material: Dictionary) -> bool:
	if str(item.get("sourceId",""))!=str(material.source_id): return false
	if item.get("source","")=="inven": return true
	var canonical: Dictionary=record(str(material.source_id))
	return item.get("source","")=="twilight_host_binding" and canonical.get("source","")=="twilight_host_binding" and item.get("name")==canonical.get("name") and item.get("host_kind")==canonical.get("host_kind") and item.get("host_amount")==canonical.get("host_amount")

static func recipe_cost(recipe: Dictionary, count: int) -> int:
	var cost: int=int(recipe.adena)*count
	for material: Dictionary in recipe.materials:
		if bool(material.get("wallet",false)) and str(material.source_id)=="26": cost+=int(material.quantity)*count
	return cost

func material_selection(recipe_id: String, choices: Dictionary = {}) -> Dictionary:
	if not recipes.has(recipe_id): return denied("원본 제작법이 없습니다")
	var recipe: Dictionary = recipes[recipe_id].duplicate(true)
	if not recipe.has("material_slots"): return {"ok":true,"recipe":recipe}
	var selected: Array = []
	var missing: bool = false
	for slot: Dictionary in recipe.material_slots:
		var candidates: Array = slot.candidates
		var chosen: Dictionary = {}
		if candidates.size() == 1:
			chosen = candidates[0]
		else:
			var wanted: int = int(choices.get(str(int(slot.slot_index)), -1))
			for candidate: Dictionary in candidates:
				if int(candidate.row_id) == wanted: chosen = candidate
		if chosen.is_empty():
			missing = true
			continue
		selected.append(chosen)
	recipe["materials"] = selected
	return {"ok":not missing,"recipe":recipe,"reason":"각 재료 슬롯의 후보를 직접 선택하세요" if missing else ""}

func quote(recipe_id: String, count: int, inventory: Dictionary, gold: int, items: Dictionary, physical: Dictionary, equipped: Dictionary, current_weight: int, capacity: int, locks: Dictionary = {}, choices: Dictionary = {}) -> Dictionary:
	if not recipes.has(recipe_id) or count < 1 or count > MAX_BATCH or gold < 0 or current_weight < 0 or capacity < 0:
		return denied("원본 제작법·횟수·보관 상태가 유효하지 않습니다")
	var selection: Dictionary = material_selection(recipe_id, choices)
	if not bool(selection.get("ok", false)): return selection
	var recipe: Dictionary = selection.recipe
	if recipe.has("outcomes") and count!=1: return denied("확률 제작은 결과를 확인하며 1회씩 진행합니다")
	var output: Dictionary = recipe.result
	var result_record: Dictionary = record(str(output.source_id))
	if result_record.is_empty() or str(result_record.get("name", "")) != str(output.item):
		return denied("원본 결과 아이템의 정확한 ID 연결이 필요합니다")
	var wallet_output: bool = bool(output.get("wallet_currency",false)) and str(output.source_id)=="26" and str(result_record.get("source",""))=="lineagem_patch523" and str(output.item)=="아데나" and not bool(output.physical)
	var current_output: Dictionary = result_record if wallet_output else items.get(str(output.item), {})
	if not wallet_output and (current_output.get("source", "") != "inven" or str(current_output.get("sourceId", "")) != str(output.source_id)):
		return denied("현재 게임에서 원본 결과 아이템을 사용할 수 없습니다")
	var costs: Dictionary = {}
	var selections: Array[String] = []
	var net_weight: int = current_weight
	var cost: int = recipe_cost(recipe,count)
	if gold < cost:
		return denied("아데나가 부족합니다")
	for material: Dictionary in recipe.materials:
		if bool(material.get("wallet",false)) and str(material.source_id)=="26": continue
		var item_name: String = str(material.item)
		var required: int = int(material.quantity) * count
		var item: Dictionary = items.get(item_name, {})
		if required < 1 or bool(locks.get(item_name, false)):
			return denied("잠긴 재료 또는 중복 재료는 사용할 수 없습니다")
		if int(inventory.get(item_name, 0)) < required + int(costs.get(item_name, 0)):
			return denied(item_name + " 재료가 부족합니다")
		if bool(material.physical):
			var candidates: Array = physical.keys()
			candidates.sort()
			var selected: int = 0
			for raw_id: Variant in candidates:
				var id: String = str(raw_id)
				var instance: Variant = physical[raw_id]
				if not instance is Dictionary or str(instance.get("name", "")) != item_name or id in selections or _worn(equipped, id) or bool(locks.get(item_name + "@@@" + id, false)):
					continue
				if _state_matches(instance, material, int(recipe.get("popup_text_id", 0)) != 0):
					selections.append(id)
					selected += 1
					if selected == required:
						break
			if selected != required:
				return denied("재료의 원본 ID·강화·축복·잠금·장착 상태를 확인하세요: " + item_name)
		elif not _stack_identity_matches(item,material):
			return denied("이름만 같은 재료는 사용할 수 없습니다: " + item_name)
		costs[item_name] = int(costs.get(item_name, 0)) + required
		net_weight -= maxi(0, int(item.get("weight", 3))) * required
	var produced: int = int(output.quantity) * count
	var output_weight: int=maxi(0,int(current_output.get("weight",3)))*produced
	for outcome: Dictionary in recipe.get("outcomes",[]):
		var candidate: Dictionary=items.get(str(outcome.item),{})
		if candidate.get("source","")!="inven" or str(candidate.get("sourceId",""))!=str(outcome.source_id) or record(str(outcome.source_id)).get("name","")!=outcome.item:
			return denied("모든 확률 결과의 정확한 아이템 ID 연결이 필요합니다")
		output_weight=maxi(output_weight,maxi(0,int(candidate.get("weight",3)))*int(outcome.quantity))
	net_weight += output_weight
	if net_weight < 0 or net_weight > capacity:
		return denied("제작 결과를 보관할 무게가 부족합니다")
	return {"ok": true, "result_name": str(output.item), "result_quantity": produced, "cost": cost,
		"materials": costs, "consumed_ids": selections, "new_weight": net_weight}

func execute(recipe_id: String, count: int, inventory: Dictionary, gold: int, items: Dictionary, physical: Dictionary, equipped: Dictionary, current_weight: int, capacity: int, next_id: int, locks: Dictionary = {}, choices: Dictionary = {}, roll: int = -1) -> Dictionary:
	var approval: Dictionary = quote(recipe_id, count, inventory, gold, items, physical, equipped, current_weight, capacity, locks, choices)
	if not bool(approval.get("ok", false)):
		return approval
	var output: Dictionary = recipes[recipe_id].result
	if recipes[recipe_id].has("outcomes"):
		if roll<0 or roll>=1000000: return denied("확률 제작의 유효한 추첨이 필요합니다")
		var threshold: int=0
		for outcome: Dictionary in recipes[recipe_id].outcomes:
			threshold+=int(outcome.probability)
			if roll<threshold:
				output=outcome
				break
		approval.result_name=output.item
		approval.result_quantity=int(output.quantity)
		approval["outcome_label"]=str(output.label)
	var staged_inventory: Dictionary = inventory.duplicate(true)
	var staged_physical: Dictionary = physical.duplicate(true)
	for item_name: String in approval.materials:
		staged_inventory[item_name] = int(staged_inventory.get(item_name, 0)) - int(approval.materials[item_name])
		if int(staged_inventory[item_name]) == 0:
			staged_inventory.erase(item_name)
	for id: String in approval.consumed_ids:
		staged_physical.erase(id)
	var output_record: Dictionary = record(str(output.source_id))
	var output_name: String = str(output.item)
	var wallet_reward: int = int(approval.result_quantity) if bool(output.get("wallet_currency",false)) and str(output.source_id)=="26" else 0
	if wallet_reward==0: staged_inventory[output_name] = int(staged_inventory.get(output_name, 0)) + int(approval.result_quantity)
	var counter: int = maxi(1, next_id)
	if bool(output.physical):
		for _i: int in range(int(approval.result_quantity)):
			var refund_id: String=""
			if str(output.get("label",""))=="실패" and bool(recipes[recipe_id].get("preserve_refund_instance",false)):
				for id: String in approval.consumed_ids:
					if not staged_physical.has(id) and identity(physical[id])==str(output.source_id) and int(physical[id].level)==int(output.level) and bless_code(physical[id])==int(output.bless_code):
						refund_id=id
						break
			if not refund_id.is_empty():
				staged_physical[refund_id]=physical[refund_id].duplicate(true)
				continue
			while staged_physical.has(str(counter)):
				counter += 1
			var pinned: Dictionary = output_record.duplicate(true)
			pinned["bless_state"] = "blessed" if int(output.bless_code) == 2 else "normal"
			var seal_options: Dictionary = supported_seal_options(str(output.source_id), int(output.bless_code))
			if not seal_options.is_empty():
				pinned["enhancement_options"] = seal_options
				pinned["patch523_effect_basis"] = {"sha256":digest, "bless_code":2, "selection":"exact_level_only"}
			staged_physical[str(counter)] = {"name": output_name, "level": int(output.level),
				"element": "", "element_level": 0, "sourceId": str(output.source_id),
				"source_snapshot": "patch523", "source_bless_code": int(output.bless_code),
				"bless_state": pinned.bless_state, "record": pinned}
			counter += 1
	# Return a staged transaction. The actual Main persists this snapshot first.
	approval.merge({"inventory": staged_inventory, "item_instances": staged_physical,
		"gold_after": gold - int(approval.cost) + wallet_reward, "next_instance_id": counter})
	return approval

func supported_seal_options(source_id: String, source_bless: int) -> Dictionary:
	# Exact Blessed2 rows only. Raw0 is never remapped to Normal1 here.
	# Existing host consumers keep their stacking, rounding and caps; source
	# values are selected by exact level and blessing, never cumulatively.
	if source_id not in ["30671", "130551"] or source_bless != 2:
		return {}
	var fields: Dictionary = {
		"MeleeHit":["melee_accuracy","hit",1], "RangeHit":["ranged_accuracy","hit",1],
		"MeleeDamage":["melee_damage","meleeDamage",1], "RangeDamage":["ranged_damage","rangedDamage",1],
		"DamageReduction":["reduction","damage_reduction",1],
		"HPPotionIncreaseStatic":["potion_heal_flat","potionHealFlat",1],
		"HPPotionIncreasePercent":["potion_heal_pct","potionHealPct",10000],
		"ExperienceAdditionPercent":["xp_pct","_unused",10000],
		"EinasadSavingPercent":["ain_saving_pct","blessing_consumption_reduction_pct",10000],
		"PotionConsumeDelayDecreasePercent":["potion_cooldown_pct","potionCooldownPct",10000],
		"SpecialResistance":["stun_resistance","stun_resistance",10000]}
	var base: Dictionary = OPTIONS.annotate(record(source_id))
	var result: Dictionary = {}
	for level_value: int in range(9):
		var exact: Array = effect_evidence(int(source_id), level_value, 2)
		if exact.is_empty():
			continue
		var totals: Dictionary = {}
		for effect: Dictionary in exact:
			var bonus: Dictionary = effect.bonus
			var type_name: String = str(effect.bonus_type.get("Name", ""))
			if not fields.has(type_name): continue
			if type_name == "SpecialResistance":
				if int(bonus.get("BonusApplicationTypeID", -1)) != 2 or int(bonus.get("BonusApplicationTargetID", -1)) != 6: continue
			elif int(bonus.get("BonusApplicationTypeID", -1)) != 0 or int(bonus.get("BonusApplicationTargetID", -1)) != 0: continue
			var definition: Array = fields[type_name]
			if int(bonus.Value) % int(definition[2]) != 0:
				continue
			var key: String = str(definition[0])
			totals[key] = int(totals.get(key, 0)) + int(float(bonus.Value) / float(definition[2]))
		for definition: Array in fields.values():
			var key: String = str(definition[0])
			if totals.has(key):
				# The existing engine adds enchant increments to its catalog +0
				# base, so subtract that actual base once, never lower ranks.
				totals[key] = int(totals[key]) - int(base.get(str(definition[1]), 0))
		if totals.has("xp_pct"): totals.xp_pct = int(totals.xp_pct) - int(round(float(base.get("xp",0.0))*100.0))
		result[str(level_value)] = totals
	return result

func refresh_derived_options(physical: Dictionary) -> bool:
	var source_id: String = identity(physical)
	if source_id.is_empty() or bless_code(physical) != 2: return false
	var pinned: Dictionary = physical.get("record", {})
	if pinned.get("patch523_effect_basis", {}).get("selection", "") != "exact_level_only": return false
	var current: Variant = pinned.get("enhancement_options", {})
	var complete: Dictionary = supported_seal_options(source_id, 2)
	if not current is Dictionary or current.is_empty() or complete.is_empty(): return false
	# Add newly connected consumers only when every old derived value agrees.
	# Unknown/custom options are never replaced by a catalog refresh.
	for level_key: Variant in current:
		if not current[level_key] is Dictionary or not complete.has(level_key): return false
		for key: Variant in current[level_key]:
			if current[level_key][key] != complete[level_key].get(key): return false
	pinned["enhancement_options"] = complete.duplicate(true)
	pinned["patch523_effect_basis"] = {"sha256":digest,"bless_code":2,"selection":"exact_level_only"}
	return true

func recipe_evidence(craft_id: int) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["inputs", "outputs", "views", "restrictions"]:
		result[key] = data.get("raw_recipes", {}).get(key, {}).get(str(craft_id), []).duplicate(true)
	return result

func effect_evidence(item_id: int, level: int, raw_bless_code: int) -> Array:
	var result: Array = []
	for row: Dictionary in data.get("items", {}).get(str(item_id), {}).get("enchant_effects", []):
		if int(row.EnchantLevel) == level and int(row.BlessCode) == raw_bless_code:
			var bonus: Dictionary = data.bonuses.get(str(int(row.BonusID)), {})
			result.append({"row": row.duplicate(true), "bonus": bonus.duplicate(true),
				"bonus_type": data.bonus_types.get(str(int(bonus.get("BonusTypeID", -1))), {}).duplicate(true)})
	return result

func enhancement_evidence(item_id: int, scroll_id: int, level: int, target_bless: int, scroll_bless: int) -> Dictionary:
	var equip_groups: Array = []
	var scroll_groups: Array = []
	for link: Dictionary in data.get("items", {}).get(str(item_id), {}).get("item_bonuses", []):
		var bonus: Dictionary = data.bonuses.get(str(int(link.BonusID)), {})
		if int(bonus.get("BonusTypeID", -1)) == 2032:
			equip_groups.append(int(bonus.Value))
	for link: Dictionary in data.get("items", {}).get(str(scroll_id), {}).get("item_bonuses", []):
		var bonus: Dictionary = data.bonuses.get(str(int(link.BonusID)), {})
		var kind: int = int(bonus.get("BonusTypeID", -1))
		if kind == 2022 or (kind == 8352 and int(bonus.get("BonusApplicationTypeID", 0)) == 202 and int(bonus.get("BonusApplicationTargetID", -1)) == scroll_bless):
			scroll_groups.append(int(bonus.Value))
	var equip_probabilities: Array = []
	var matched: Array = []
	for row: Dictionary in data.get("enchantment", {}).get("ItemEnchantEquipGroupMapping", []):
		if int(row.ItemEnchantEquipGroupID) in equip_groups:
			equip_probabilities.append(int(row.ItemEnchantProbabilityGroupID))
	for row: Dictionary in data.get("enchantment", {}).get("ItemEnchantScrollGroupMapping", []):
		var group: int = int(row.ItemEnchantProbabilityGroupID)
		if int(row.ItemEnchantScrollGroupID) in scroll_groups and group in equip_probabilities and group not in matched:
			matched.append(group)
	var result: Dictionary = {"groups": matched, "probabilities": [], "costs": [], "unresolved": ["current_or_result_level_contract", "target_bless_zero_matching", "cost_currency", "zero_consume_amount", "side_effect_amount", "blessed_leap_activation"]}
	for table: String in ["BmItemEnchantProView", "ItemEnchantCostView"]:
		for row: Dictionary in data.get("enchantment", {}).get(table, []):
			# Preserve 0 rows separately; never silently equate 0 with Normal1.
			if int(row.ItemEnchantProbabilityGroupID) in matched and int(row.EnchantLevel) == level and int(row.TargetItemBlessCode) in [0, target_bless]:
				(result["probabilities" if table == "BmItemEnchantProView" else "costs"] as Array).append(row.duplicate(true))
	return result
