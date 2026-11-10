extends RefCounted
## UNVERIFIED: current original rows in the existing option-consumer shape.
## Saved identities are ABI only. Former card packs are never input/fallback.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const IDENTITIES = preload("res://scripts/cards/current523_card_identity.gd")
const SLOTS = preload("res://scripts/cards/option_slot_definitions.gd")
const UNLOCK_ITEM: int = 346901
const UNLOCK_BUFF: int = 91531
const UNLOCK_BONUS: int = 2171301
static var problem: String = ""
static var _data: Dictionary = {}
static var _issue: String = ""
static var _exclusions: Array = []

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func _empty(identity: Dictionary = {}) -> Dictionary:
	return {"schema":1,"source_snapshot":"patch523","ready":false,"source_input_identity":identity,
		"primary_doll_buffs":{},"subslot_buffs":{},"subslot_npc_bindings":{},"option_groups":[],
		"invoke_options":[],"invoke_spells":{},"invoke_buffs":{},"spell_material_types":[],"economy":{},
		"subslot_unlock_item":{},"invoke_references":[],"unavailable_source_definitions":[],"source_exclusion_evidence":[],"problem":""}

static func _row(table: String, id: Variant) -> Dictionary:
	if not _integer(id) or int(id) < 0:
		_issue = "invalid_source_reference:"+table
		return {}
	var raw: Dictionary = SOURCE.row(table,int(id))
	if raw.is_empty():
		_issue = "missing_or_ambiguous_source_reference:"+table+":"+str(int(id))+":"+SOURCE.problem()
		return {}
	var exclusion: Dictionary = SOURCE.declared_exclusion(table,raw)
	if not exclusion.is_empty():
		_exclusions.append({"table":table,"row":raw,"evidence":exclusion})
		_issue = "source_declared_dummy:"+table+":"+str(int(id))
		return {}
	return raw

static func _effect(table: String, link: Dictionary) -> Dictionary:
	var exclusion: Dictionary = SOURCE.declared_exclusion(table,link)
	if not exclusion.is_empty():
		_exclusions.append({"table":table,"row":link,"evidence":exclusion})
		_issue = "source_declared_dummy:"+table+":"+str(link.get("ID",""))
		return {}
	var bonus: Dictionary = _row("Bonus",link.get("BonusID"))
	if bonus.is_empty(): return {}
	var type: Dictionary = _row("BonusType",bonus.get("BonusTypeID"))
	if type.is_empty(): return {}
	var unit: Dictionary = _row("Unit",type.get("UnitID"))
	if unit.is_empty(): return {}
	if not type.get("Name") is String or not unit.get("Name") is String or not _integer(bonus.get("BonusApplicationTypeID")) or not _integer(bonus.get("BonusApplicationTargetID")) or typeof(bonus.get("Value")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(bonus.Value)):
		_issue = "invalid_typed_source_bonus:"+str(bonus.ID)
		return {}
	var conditions: Array = []
	if table == "SpellBonus": conditions = ["MinSpellLevel"]
	elif table == "BuffBonus": conditions = ["CharacterLevel","CharacterClass","MinSpellLevel"]
	for field: String in conditions:
		if not _integer(link.get(field)):
			_issue = "invalid_source_link_condition:"+table+":"+field
			return {}
	var ui_rows: Array[Dictionary] = SOURCE.related("UIUnit","UnitID",int(unit.ID))
	if ui_rows.size() > 1:
		_issue = "ambiguous_source_display_unit:"+str(unit.ID)
		return {}
	var ui: Dictionary = ui_rows[0] if ui_rows.size() == 1 else {}
	if not ui.is_empty() and not _integer(ui.get("Denominator")):
		_issue = "invalid_source_display_denominator:"+str(unit.ID)
		return {}
	return {"link":link,"bonus":bonus,"type":type,"unit":unit,"ui_unit":ui}

static func _effects(table: String, foreign_key: String, id: int) -> Array:
	var result: Array = []
	for link: Dictionary in SOURCE.related(table,foreign_key,id):
		var effect: Dictionary = _effect(table,link)
		if effect.is_empty(): return []
		result.append(effect)
	return result

static func _buff(id: Variant) -> Dictionary:
	var raw: Dictionary = _row("BuffClass",id)
	if raw.is_empty(): return {}
	# Absence of TestBuff is retained as absence, never fabricated as false.
	if raw.has("TestBuff") and (typeof(raw.TestBuff) != TYPE_BOOL or raw.TestBuff):
		_issue = "source_TestBuff_excluded_or_invalid:"+str(raw.ID)
		return {}
	return raw

static func _collect_invokes(effects: Array, targets: Dictionary) -> void:
	for effect: Dictionary in effects:
		if effect.type.Name != "InvokeOption" or effect.bonus.BonusApplicationTypeID != 10: continue
		var target: Variant = effect.bonus.BonusApplicationTargetID
		if _integer(target) and int(target) >= 0: targets[int(target)] = true

static func _summon(card: Dictionary, primary: Array, secondary: Array) -> Dictionary:
	var selected: Array = []
	for effect: Dictionary in secondary:
		if effect.type.Name == "BuffCardSummonNPCClassID" and effect.unit.Name == "NPCClassID" and effect.bonus.BonusApplicationTypeID == 461 and effect.bonus.BonusApplicationTargetID == 11:
			selected.append(effect)
	if selected.is_empty(): return {}
	if selected.size() != 1 or not _integer(selected[0].bonus.Value):
		_issue = "ambiguous_or_invalid_doll_summon_reference:"+str(card.ID)
		return {}
	var npc: Dictionary = _row("NpcClass",selected[0].bonus.Value)
	if npc.is_empty(): return {}
	if not _integer(npc.get("Sprite")) or bool(npc.get("TestNPC",false)):
		_issue = "excluded_or_invalid_doll_npc_reference:"+str(npc.ID)
		return {}
	var primary_sprites: Array = []
	for effect: Dictionary in primary:
		if effect.type.Name != "BuffCardSummonNPCClassID" or effect.unit.Name != "NPCClassID": continue
		var actor: Dictionary = _row("NpcClass",effect.bonus.Value)
		if actor.is_empty() or not _integer(actor.get("Sprite")): continue
		if int(actor.Sprite) not in primary_sprites: primary_sprites.append(int(actor.Sprite))
	primary_sprites.sort()
	# Source Sprite equality supplies metadata, never physical pixel evidence.
	return {"npc_class_id":int(npc.ID),"sprite_id":int(npc.Sprite),"display_sprite_id":card.get("DisplaySpriteID"),
		"primary_sprite_ids":primary_sprites,"display_sprite_verified":false,"same_source_sprite_verified":false,
		"declared_display_sprite_match":npc.Sprite == card.get("DisplaySpriteID"),
		"declared_primary_sprite_match":int(npc.Sprite) in primary_sprites,
		"visual_status":"current_original_pixels_or_official_pin_missing","source_npc":npc,"source_effect":selected[0],
		"source_input_identity":SOURCE.identity(),"reference_only":true,"can_execute":false}

static func _note(result: Dictionary, context: Dictionary, issue: String) -> void:
	var record: Dictionary = context.duplicate(true)
	record["problem"] = issue
	result.unavailable_source_definitions.append(record)

static func _economy(result: Dictionary) -> void:
	var invalid: Dictionary = {}
	var originals: Array[Dictionary] = SOURCE.rows("BuffCardOptionAwakenValue")
	if originals.is_empty(): _note(result,{"table":"BuffCardOptionAwakenValue"},"source_option_economy_unavailable:"+SOURCE.problem())
	for row: Dictionary in originals:
		_issue = ""
		# This compiler table is keyed by deck/grade/value type, not an
		# invented ID. The original whole row is the consumed rule.
		var exclusion: Dictionary = SOURCE.declared_exclusion("BuffCardOptionAwakenValue",row)
		if not exclusion.is_empty():
			_exclusions.append({"table":"BuffCardOptionAwakenValue","row":row,"evidence":exclusion})
			_note(result,{"table":"BuffCardOptionAwakenValue","row":row},"source_declared_dummy:BuffCardOptionAwakenValue")
			continue
		var type: Dictionary = _row("BuffCardOptionAwakenValueType",row.get("BuffCardOptionAwakenValueTypeID"))
		if type.is_empty() or not type.get("Name") is String or str(type.Name).is_empty() or not _integer(row.get("BuffCardDeckID")) or not _integer(row.get("GradeID")) or not _integer(row.get("Value")):
			_note(result,{"table":"BuffCardOptionAwakenValue","row":row},_issue if not _issue.is_empty() else "invalid_typed_option_economy_row")
			continue
		var key: String = str(int(row.BuffCardDeckID))+":"+str(int(row.GradeID))
		var name_value: String = type.Name
		var typed_key: String = key+":"+name_value
		if invalid.has(typed_key): continue
		if not result.economy.has(key): result.economy[key] = {}
		if result.economy[key].has(name_value):
			result.economy[key].erase(name_value)
			invalid[typed_key] = true
			_note(result,{"table":"BuffCardOptionAwakenValue","key":key,"type":name_value},"duplicate_typed_option_economy_rule")
			continue
		result.economy[key][name_value] = row

static func _unlock(result: Dictionary) -> Dictionary:
	_issue = ""
	var item: Dictionary = _row("ItemClass",UNLOCK_ITEM)
	var buff: Dictionary = _buff(UNLOCK_BUFF)
	if item.is_empty() or buff.is_empty():
		_note(result,{"item_class_id":UNLOCK_ITEM,"buff_class_id":UNLOCK_BUFF},_issue)
		return {}
	if typeof(item.get("TestItem")) != TYPE_BOOL or item.TestItem:
		_note(result,{"item_class_id":UNLOCK_ITEM,"row":item},"source_TestItem_excluded_or_invalid")
		return {}
	var category: Dictionary = _row("ItemCategory",item.get("CategoryID"))
	var grade: Dictionary = _row("Grade",item.get("GradeID"))
	if category.is_empty() or grade.is_empty():
		_note(result,{"item_class_id":UNLOCK_ITEM},_issue)
		return {}
	if typeof(category.get("IsConsumable")) != TYPE_BOOL or not _integer(item.get("MaxStackAmount")) or not grade.get("Name") is String:
		_note(result,{"item_class_id":UNLOCK_ITEM},"invalid_source_unlock_item_shape")
		return {}
	var effects: Array = _effects("ItemBonus","ItemClassID",UNLOCK_ITEM)
	if not _issue.is_empty():
		_note(result,{"item_class_id":UNLOCK_ITEM},_issue)
		return {}
	var exact_link: bool = false
	for effect: Dictionary in effects:
		if typeof(effect.link.get("IsPossession")) != TYPE_BOOL:
			_note(result,{"item_class_id":UNLOCK_ITEM,"reference":effect},"invalid_source_unlock_IsPossession")
			return {}
		if effect.bonus.ID == UNLOCK_BONUS and effect.type.Name == "BuffClassID" and effect.unit.Name == "BuffClassID" and effect.bonus.Value == UNLOCK_BUFF: exact_link = true
	if not exact_link:
		_note(result,{"item_class_id":UNLOCK_ITEM,"buff_class_id":UNLOCK_BUFF,"bonus_id":UNLOCK_BONUS},"missing_exact_doll_unlock_ItemBonus")
		return {}
	var buff_effects: Array = _effects("BuffBonus","BuffClassID",UNLOCK_BUFF)
	if not _issue.is_empty():
		_note(result,{"buff_class_id":UNLOCK_BUFF},_issue)
		return {}
	var name_value: String = str(item.get("Name",""))
	if _integer(item.get("DescID")):
		var text: Dictionary = _row("DescData_Korean",item.DescID)
		if text.get("Description") is String and not str(text.Description).is_empty(): name_value = text.Description
	if name_value.is_empty():
		_note(result,{"item_class_id":UNLOCK_ITEM},"source_unlock_item_name_unavailable")
		return {}
	return {"item":item,"category":category,"grade":grade,"name":name_value,"buff":buff,
		"effects":effects,"buff_effects":buff_effects,"source_input_identity":result.source_input_identity}

static func _doll(result: Dictionary, card: Dictionary, identity: String, targets: Dictionary) -> void:
	_issue = ""
	var buff: Dictionary = _buff(card.get("BuffClassID"))
	if buff.is_empty():
		_note(result,{"identity":identity},_issue)
		return
	var primary: Array = _effects("BuffBonus","BuffClassID",int(buff.ID))
	if not _issue.is_empty():
		_note(result,{"identity":identity},_issue)
		return
	result.primary_doll_buffs[identity] = {"card":card,"source_buff":buff,"effects":primary,"source_input_identity":result.source_input_identity}
	_collect_invokes(primary,targets)
	var refs: Array = []
	for effect: Dictionary in primary:
		if effect.type.Name == "SubSlotBuffClassID" and effect.unit.Name == "BuffClassID": refs.append(effect)
	if refs.is_empty(): return
	if refs.size() != 1:
		_note(result,{"identity":identity},"ambiguous_SubSlotBuffClassID")
		return
	var secondary: Dictionary = _buff(refs[0].bonus.Value)
	if secondary.is_empty():
		_note(result,{"identity":identity,"reference":refs[0]},_issue)
		return
	var effects: Array = _effects("BuffBonus","BuffClassID",int(secondary.ID))
	if not _issue.is_empty():
		_note(result,{"identity":identity},_issue)
		return
	result.subslot_buffs[identity] = {"card":card,"link":refs[0],"source_buff":secondary,"effects":effects,"source_input_identity":result.source_input_identity}
	_collect_invokes(effects,targets)
	var binding: Dictionary = _summon(card,primary,effects)
	if not binding.is_empty(): result.subslot_npc_bindings[identity] = binding
	if not _issue.is_empty(): _note(result,{"identity":identity},_issue)

static func _invoke(result: Dictionary, id: int) -> void:
	_issue = ""
	var option: Dictionary = _row("InvokeOption",id)
	if option.is_empty():
		_note(result,{"table":"InvokeOption","row_id":id},_issue)
		return
	var type: Dictionary = _row("InvokeOptionType",option.get("InvokeOptionTypeID"))
	if type.is_empty():
		_note(result,{"table":"InvokeOption","row_id":id,"row":option},_issue)
		return
	# Only the existing two spell-using option types follow Param1. Other
	# parameters remain numeric source fields for the existing consumers.
	if int(type.ID) not in [1,2]:
		result.invoke_options.append(option)
		result.invoke_references.append({"row":option,"type":type})
		return
	var unit: Dictionary = _row("Unit",type.get("Param1Unit"))
	if unit.is_empty() or unit.get("Name") != "SpellClassID":
		_note(result,{"table":"InvokeOption","row_id":id,"row":option,"type":type,"param1_unit":unit},_issue if not _issue.is_empty() else "invoke_Param1_not_declared_SpellClassID")
		return
	var spell: Dictionary = _row("SpellClass",option.get("Param1"))
	if spell.is_empty():
		_note(result,{"table":"InvokeOption","row_id":id,"row":option,"type":type,"param1_unit":unit},_issue)
		return
	if typeof(spell.get("TestSpell")) != TYPE_BOOL or spell.TestSpell:
		_note(result,{"table":"SpellClass","row_id":spell.ID,"row":spell},"source_TestSpell_excluded_or_invalid")
		return
	var effects: Array = _effects("SpellBonus","SpellClassID",int(spell.ID))
	if not _issue.is_empty():
		_note(result,{"table":"SpellClass","row_id":spell.ID,"row":spell},_issue)
		return
	result.invoke_options.append(option)
	result.invoke_references.append({"row":option,"type":type,"param1_unit":unit})
	result.invoke_spells[str(int(spell.ID))] = {"source_spell":spell,"effects":effects,"source_invoke_type":type,"source_param1_unit":unit,"source_input_identity":result.source_input_identity}
	for effect: Dictionary in effects:
		if effect.type.Name != "BuffClassID": continue
		if effect.unit.Name != "BuffClassID":
			_note(result,{"table":"SpellClass","row_id":spell.ID,"reference":effect},"spell_BuffClassID_unit_unresolved")
			continue
		_issue = ""
		var buff: Dictionary = _buff(effect.bonus.Value)
		if buff.is_empty():
			_note(result,{"table":"SpellClass","row_id":spell.ID,"reference":effect},_issue)
			continue
		var buffs: Array = _effects("BuffBonus","BuffClassID",int(buff.ID))
		if not _issue.is_empty():
			_note(result,{"table":"BuffClass","row_id":buff.ID,"row":buff},_issue)
			continue
		result.invoke_buffs[str(int(buff.ID))] = buffs

## The session model is a pure function of the verified original and the
## scripts that build it. Lineage M style it is compiled once on this device:
## only a small head (economy, spell material types, invoke options, the doll
## unlock item, identity and problem) stays resident; the per-identity doll
## rows, invoke spells/buffs and the build-only diagnostics stay in a record
## bake read on demand through a small LRU (accessors below). Every value a
## reader gets is the value the former resident dictionary held.
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const RECORDS = preload("res://scripts/resources/current523_keyed_records.gd")
const RECORDS_NAME := "option_combat523_records"
const RECORDS_PRODUCER := "option_combat523"
const RECORDS_SCHEMA := "option_combat_input.v1|records.v1"
## Per-key sections kept on storage.
const KEYED: Array[String] = ["primary_doll_buffs","subslot_buffs","subslot_npc_bindings","invoke_spells","invoke_buffs"]
## Parts only the build uses (no reader); kept on storage as one diagnostics record.
const DIAGNOSTIC: Array[String] = ["option_groups","invoke_references","unavailable_source_definitions","source_exclusion_evidence"]
const DIAGNOSTICS := "diagnostics"
static var bake_enabled: bool = true
static var _store: RefCounted = null
## Last storage failure of this producer ({} when none): stage and message.
static var store_failure: Dictionary = {}

## Tests only (never set in production): the source identity a synthetic
## session stands for, in place of the installed original's.
static var _identity_for_test: Dictionary = {}

static func session() -> Dictionary:
	var identity: Dictionary = _identity_for_test if not _identity_for_test.is_empty() else SOURCE.identity()
	if identity.is_empty():
		_store = null
		_data = _empty()
		problem = "current523_original_unavailable:"+SOURCE.problem()
		_data.problem = problem
		return _data
	if not _data.is_empty() and _data.get("ready",false) and _data.get("source_input_identity") == identity: return _data
	_store = null; store_failure = {}
	var verified: String = SOURCE.verified_key() if bake_enabled else ""
	var key: String = BAKE.producer_key(RECORDS_NAME,RECORDS_PRODUCER,RECORDS_SCHEMA,verified) if not verified.is_empty() else ""
	var opened: RECORDS.Store = RECORDS.open(RECORDS_NAME,key) if not key.is_empty() else null
	if opened != null and opened.head is Dictionary and opened.head.get("ready") == true and opened.head.get("source_input_identity") == identity and opened.head.get("problem") is String:
		_store = opened
		_data = opened.head
		problem = _data.problem
		return _data
	_data = _build(identity)
	if _data.ready and not key.is_empty(): _data = _adopt(_data,key,identity)
	return _data

## Stores a built session as records and returns its resident head. Storage
## failure: disk-required (Android/iOS) is an explicit failure (an empty,
## ready session with the cause; nothing activated; the next start retries);
## elsewhere the whole session stays resident as before.
static func _adopt(result: Dictionary, key: String, identity: Dictionary) -> Dictionary:
	var split: Dictionary = split_session(result)
	# A definition table that failed to reach storage this run may have
	# degraded the build: such a result is used now but never persisted.
	var degraded: bool = not SOURCE._store_failures.is_empty()
	var stored: RECORDS.Store = null if degraded else RECORDS.write(RECORDS_NAME,key,split.head,split.sections)
	if stored != null:
		_store = stored
		return split.head
	if BAKE.disk_required():
		store_failure = {"stage":"degraded_source" if degraded else "records","message":"원본523 카드 옵션 기록 파일을 저장하지 못했습니다"}
		problem = str(store_failure.message)+" · 기기 저장 공간을 확인한 뒤 다시 시작하면 다시 시도합니다"
		var failed: Dictionary = _empty(identity)
		failed.ready = true
		failed.problem = problem
		return failed
	return result

## {head, sections}: the session without its keyed and build-only parts, and
## those parts as sections. Pure (the session is not modified).
static func split_session(result: Dictionary) -> Dictionary:
	var head: Dictionary = result.duplicate(false)
	var sections: Dictionary = {}
	for field: String in KEYED:
		sections[field] = result.get(field,{})
		head.erase(field)
	var diagnostics: Dictionary = {}
	for field: String in DIAGNOSTIC:
		if result.has(field): diagnostics[field] = result[field]
		head.erase(field)
	sections[DIAGNOSTICS] = {"value":diagnostics}
	return {"head":head,"sections":sections}

static func store_result() -> Dictionary:
	if store_failure.is_empty(): return {}
	return {"ok":false,"reason":"option_combat_store_failed","stage":str(store_failure.get("stage","")),"message":problem}

## --- Accessors: the same values the former resident session held. ---
static func _keyed(section: String, key: String, fallback: Variant) -> Variant:
	session()
	if _store != null: return _store.value(section,key,fallback)
	return (_data.get(section,{}) as Dictionary).get(key,fallback)

static func primary_doll_buff(identity: String) -> Dictionary: return _keyed("primary_doll_buffs",identity,{})
static func subslot_buff(identity: String) -> Dictionary: return _keyed("subslot_buffs",identity,{})
static func subslot_npc_binding(identity: String) -> Dictionary: return _keyed("subslot_npc_bindings",identity,{})
## The invoke spell of an InvokeOption Param1, or null when this input has none.
static func invoke_spell(id: String) -> Variant: return _keyed("invoke_spells",id,null)
static func invoke_buff(id: String) -> Array: return _keyed("invoke_buffs",id,[])

static func section_keys(section: String) -> PackedStringArray:
	session()
	if _store != null: return _store.section_keys(section)
	return PackedStringArray((_data.get(section,{}) as Dictionary).keys())

## Build-only parts (option groups, invoke references, unavailable source
## definitions, exclusion evidence), read from storage when asked.
static func diagnostics() -> Dictionary:
	session()
	if _store != null: return _store.value(DIAGNOSTICS,"value",{})
	var out: Dictionary = {}
	for field: String in DIAGNOSTIC:
		if _data.has(field): out[field] = _data[field]
	return out

## Test seams: adopt a synthetic built session exactly as session() does
## after a build (key "" = no device bake); reset() forgets it.
static func adopt_for_test(result: Dictionary, key: String) -> void:
	_store = null; store_failure = {}
	_identity_for_test = result.get("source_input_identity",{})
	problem = str(result.get("problem",""))
	_data = result if key.is_empty() or not result.get("ready",false) else _adopt(result,key,_identity_for_test)

static func reopen_for_test(key: String) -> bool:
	_store = null
	var opened: RECORDS.Store = RECORDS.open(RECORDS_NAME,key)
	if opened == null or not opened.head is Dictionary: return false
	_store = opened; _data = opened.head; problem = str(_data.get("problem",""))
	return true

static func reset_for_test() -> void:
	_data = {}; _store = null; store_failure = {}; problem = ""; _identity_for_test = {}

static func _build(identity: Dictionary) -> Dictionary:
	_exclusions = []; _issue = ""; problem = ""
	var result: Dictionary = _empty(identity)
	var originals: Array[Dictionary] = SOURCE.rows("BuffCard")
	if originals.is_empty():
		problem = "current523_BuffCard_unavailable:"+SOURCE.problem()
		result.problem = problem
		return result
	_economy(result)
	var material_types: Array = []
	for raw: Dictionary in SOURCE.rows("SpellMaterialType"):
		_issue = ""
		var row: Dictionary = _row("SpellMaterialType",raw.get("ID"))
		if row.is_empty() or not row.get("Name") is String:
			_note(result,{"table":"SpellMaterialType","row_id":raw.get("ID")},_issue if not _issue.is_empty() else "invalid_source_spell_material_type")
			continue
		material_types.append(row)
	result.spell_material_types = material_types
	if material_types.is_empty(): _note(result,{"table":"SpellMaterialType"},"source_spell_material_types_unavailable:"+SOURCE.problem())
	result.subslot_unlock_item = _unlock(result)
	var targets: Dictionary = {}
	for raw: Dictionary in originals:
		if not _integer(raw.get("BuffCardDeckID")) or int(raw.BuffCardDeckID) not in [1,2]: continue
		_issue = ""
		var card: Dictionary = _row("BuffCard",raw.get("ID"))
		if card.is_empty():
			_note(result,{"table":"BuffCard","row_id":raw.get("ID")},_issue)
			continue
		var stable: String = IDENTITIES.source_id(int(card.BuffCardDeckID),int(card.ID))
		if stable.is_empty():
			_note(result,{"table":"BuffCard","row_id":card.ID},"saved_namespace_not_declared")
			continue
		var identity_key: String = "source:"+stable
		for slot: int in [1,11]:
			var present: bool = false
			for raw_group: Dictionary in SOURCE.related("BuffCardOptionAwakenGroup","BuffCardID",int(card.ID)):
				if raw_group.get("SlotIndex") == slot: present = true
			if not present: continue
			var group: Dictionary = SLOTS.group_for(identity_key,slot)
			if group.is_empty() or group.get("card") != card or group.get("source_input_identity") != identity:
				_note(result,{"identity":identity_key,"slot_index":slot},SLOTS.problem if group.is_empty() else "source_option_group_identity_mismatch")
				continue
			result.option_groups.append(group)
			_collect_invokes(group.effects,targets)
		if int(card.BuffCardDeckID) == 2: _doll(result,card,identity_key,targets)
	for id: int in targets: _invoke(result,id)
	result.source_exclusion_evidence = _exclusions.duplicate(true)
	# Build scratch only: the evidence now lives in the result.
	_exclusions = []
	result.ready = true
	if not result.unavailable_source_definitions.is_empty(): problem = "current523_option_input_partial:see_unavailable_source_definitions"
	result.problem = problem
	return result

static func union_options(candidates: Array) -> Array:
	# Input union only: one pinned row per exact ID, preserving first position.
	# Conflicting rows are withheld; no probability or trigger is evaluated here.
	if SOURCE.identity().is_empty():
		problem = "current523_original_unavailable:"+SOURCE.problem()
		return []
	var result: Array = []
	var positions: Dictionary = {}; var conflicts: Dictionary = {}
	for candidate: Variant in candidates:
		if not candidate is Dictionary or not _integer(candidate.get("ID")):
			problem = "invalid_source_invoke_candidate"
			continue
		var id: int = int(candidate.ID)
		if conflicts.has(id): continue
		if positions.has(id):
			if result[int(positions[id])] != candidate:
				conflicts[id] = true
				problem = "conflicting_source_invoke_candidate:"+str(id)
			continue
		positions[id] = result.size()
		result.append(candidate)
	var unique: Array = []
	for candidate: Dictionary in result:
		if not conflicts.has(int(candidate.ID)): unique.append(candidate)
	return unique

