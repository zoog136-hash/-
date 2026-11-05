extends RefCounted
## UNVERIFIED: original definitions only, with the existing relic consumer ABI.
## This module supplies data; it grants no card, item, unlock or visual asset.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const IDENTITIES = preload("res://scripts/cards/current523_card_identity.gd")
const OPTIONS = preload("res://scripts/cards/option_slot_definitions.gd")
const CARD_ACQUISITION = preload("res://scripts/cards/current523_card_acquisition_input.gd")
const RELIC_ACQUISITION = preload("res://scripts/cards/current523_relic_acquisition_input.gd")
const SCHEMA: String = "twilight.card-slots523.v1"
const ITEM: int = 365748
const BUFF: int = 95648
const BONUS: int = 2357388
const INVOKE: int = 16572
var problem: String = ""
var _issue: String = ""
var _exclusions: Array = []

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

func _row(table: String, id: Variant) -> Dictionary:
	if not _integer(id) or int(id) < 0:
		_issue = "invalid_source_reference:"+table
		return {}
	var raw: Dictionary = SOURCE.row(table,int(id))
	if raw.is_empty():
		_issue = "missing_or_ambiguous_source_reference:"+table+":"+str(int(id))+":"+SOURCE.problem()
		return {}
	var declaration: Dictionary = SOURCE.declared_exclusion(table,raw)
	if not declaration.is_empty():
		_exclusions.append({"table":table,"row":raw,"evidence":declaration})
		_issue = "source_declared_dummy:"+table+":"+str(int(id))
		return {}
	return raw

func _effect(table: String, link: Dictionary) -> Dictionary:
	var declaration: Dictionary = SOURCE.declared_exclusion(table,link)
	if not declaration.is_empty():
		_exclusions.append({"table":table,"row":link,"evidence":declaration})
		_issue = "source_declared_dummy:"+table+":"+str(link.get("ID",""))
		return {}
	var bonus: Dictionary = _row("Bonus",link.get("BonusID"))
	if bonus.is_empty(): return {}
	var type: Dictionary = _row("BonusType",bonus.get("BonusTypeID"))
	if type.is_empty(): return {}
	var unit: Dictionary = _row("Unit",type.get("UnitID"))
	var application: Dictionary = _row("BonusApplicationType",bonus.get("BonusApplicationTypeID"))
	if unit.is_empty() or application.is_empty(): return {}
	if not type.get("Name") is String or not unit.get("Name") is String or not _integer(bonus.get("BonusApplicationTargetID")) or typeof(bonus.get("Value")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(bonus.Value)):
		_issue = "invalid_typed_source_bonus:"+str(bonus.ID)
		return {}
	var ui_rows: Array[Dictionary] = SOURCE.related("UIUnit","UnitID",int(unit.ID))
	if ui_rows.size() > 1:
		_issue = "ambiguous_source_display_unit:"+str(unit.ID)
		return {}
	var ui: Dictionary = ui_rows[0] if ui_rows.size() == 1 else {}
	# The consumer still owns all application conditions and numeric mapping.
	return {"link":link,"bonus":bonus,"type":type,"unit":unit,"ui_unit":ui,"application_type":application}

func _effects(table: String, foreign_key: String, id: int) -> Array:
	var result: Array = []
	for link: Dictionary in SOURCE.related(table,foreign_key,id):
		var effect: Dictionary = _effect(table,link)
		if effect.is_empty(): return []
		result.append(effect)
	return result

func _summon(card: Dictionary, effects: Array) -> Dictionary:
	var out: Dictionary = {"npc_class_id":0,"sprite_id":0,"display_sprite_id":card.get("DisplaySpriteID",0),
		"display_sprite_verified":false,"same_source_sprite_verified":false,
		"visual_status":"current_original_pixels_or_official_pin_missing","reference_only":true,"can_execute":false}
	var selected: Array = []
	for effect: Dictionary in effects:
		if effect.type.Name == "BuffCardSummonNPCClassID" and effect.unit.Name == "NPCClassID" and effect.bonus.BonusApplicationTypeID == 461 and effect.bonus.BonusApplicationTargetID == 11:
			selected.append(effect)
	if selected.is_empty(): return out
	if selected.size() != 1 or not _integer(selected[0].bonus.Value):
		_issue = "ambiguous_or_invalid_relic_summon_reference:"+str(card.ID)
		return {}
	var npc: Dictionary = _row("NpcClass",selected[0].bonus.Value)
	if npc.is_empty(): return {}
	if bool(npc.get("TestNPC",false)) or not _integer(npc.get("Sprite")):
		_issue = "excluded_or_invalid_relic_npc_reference:"+str(npc.ID)
		return {}
	out.npc_class_id = int(npc.ID)
	out.sprite_id = int(npc.Sprite)
	out["source_npc"] = npc
	out["source_effect"] = selected[0]
	# A declaration of numeric Sprite equality is not installed pixel evidence.
	out["declared_display_sprite_match"] = npc.Sprite == card.get("DisplaySpriteID")
	return out

func _card(raw: Dictionary) -> Dictionary:
	var buff: Dictionary = _row("BuffClass",raw.get("BuffClassID"))
	if buff.is_empty(): return {}
	var primary: Array = _effects("BuffBonus","BuffClassID",int(buff.ID))
	if not _issue.is_empty(): return {}
	var links: Array = []
	for effect: Dictionary in primary:
		if effect.type.Name == "SubSlotBuffClassID" and effect.unit.Name == "BuffClassID": links.append(effect)
	if links.is_empty():
		# Retain an exact main-card row without inventing a secondary definition.
		return {"card":raw,"source_buff":buff,"source_primary_effects":primary,"effects":[],"summon_binding":_summon(raw,[]),"source_problem":"missing_typed_SubSlotBuffClassID"}
	if links.size() != 1 or not _integer(links[0].bonus.Value):
		_issue = "ambiguous_or_invalid_SubSlotBuffClassID:"+str(raw.ID)
		return {}
	var secondary: Dictionary = _row("BuffClass",links[0].bonus.Value)
	if secondary.is_empty(): return {}
	var effects: Array = _effects("BuffBonus","BuffClassID",int(secondary.ID))
	if not _issue.is_empty(): return {}
	if effects.is_empty():
		_issue = "missing_relic_secondary_BuffBonus:"+str(secondary.ID)
		return {}
	var summon: Dictionary = _summon(raw,effects)
	if summon.is_empty(): return {}
	return {"card":raw,"source_buff":buff,"source_primary_effects":primary,"subslot_link":links[0],"subslot_buff":secondary,"effects":effects,"summon_binding":summon}

func _unlock() -> Dictionary:
	var item: Dictionary = _row("ItemClass",ITEM)
	if item.is_empty(): return {}
	if bool(item.get("TestItem",false)):
		_issue = "source_TestItem_excluded:"+str(ITEM)
		return {}
	var category: Dictionary = _row("ItemCategory",item.get("CategoryID"))
	var grade: Dictionary = _row("Grade",item.get("GradeID"))
	var buff: Dictionary = _row("BuffClass",BUFF)
	if category.is_empty() or grade.is_empty() or buff.is_empty(): return {}
	var effects: Array = _effects("ItemBonus","ItemClassID",ITEM)
	if not _issue.is_empty(): return {}
	var exact_link: bool = false
	for effect: Dictionary in effects:
		if effect.bonus.ID == BONUS and effect.type.Name == "BuffClassID" and effect.type.UnitID == 16 and effect.bonus.Value == BUFF:
			exact_link = true
	if not exact_link:
		_issue = "missing_exact_relic_unlock_ItemBonus:"+str(ITEM)+":"+str(BONUS)+":"+str(BUFF)
		return {}
	var buff_effects: Array = _effects("BuffBonus","BuffClassID",BUFF)
	if not _issue.is_empty(): return {}
	var name_value: String = str(item.get("Name",""))
	if _integer(item.get("DescID")):
		var text: Dictionary = SOURCE.row("DescData_Korean",int(item.DescID))
		if text.get("Description") is String and not str(text.Description).is_empty(): name_value = text.Description
	if name_value.is_empty():
		_issue = "missing_relic_unlock_source_name:"+str(ITEM)
		return {}
	# source_rules_valid() remains the sole existing use-rule guard. Raw flags,
	# application IDs, duration and saved-unlock effects are not rewritten here.
	return {"item":item,"category":category,"grade":grade,"name":name_value,"buff":buff,"effects":effects,"buff_effects":buff_effects}

func _combat(cards: Dictionary, groups: Dictionary) -> Dictionary:
	var secondary: Dictionary = {}; var invokes: Array = []; var spells: Dictionary = {}; var references: Array = []
	for key: String in cards:
		var row: Dictionary = cards[key]
		if not row.has("subslot_buff"): continue
		secondary[key] = {"card":row.card,"effects":row.effects}
		var effects: Array = row.effects.duplicate()
		var group: Dictionary = groups.get(key+":11",{})
		if not group.is_empty(): effects.append_array(group.effects)
		for effect: Dictionary in effects:
			if effect.type.Name == "InvokeOption" and effect.bonus.BonusApplicationTypeID == 10 and effect.bonus.BonusApplicationTargetID == INVOKE:
				references.append(effect)
	if references.is_empty(): return {"relic_subslot_buffs":secondary,"invoke_options":invokes,"invoke_spells":spells}
	var option: Dictionary = _row("InvokeOption",INVOKE)
	if option.is_empty(): return {}
	var type: Dictionary = _row("InvokeOptionType",option.get("InvokeOptionTypeID"))
	if type.is_empty(): return {}
	var unit: Dictionary = _row("Unit",type.get("Param1Unit"))
	if unit.is_empty(): return {}
	if unit.get("Name") != "SpellClassID":
		_issue = "relic_invoke_Param1_not_declared_SpellClassID:"+str(INVOKE)
		return {}
	var spell: Dictionary = _row("SpellClass",option.get("Param1"))
	if spell.is_empty(): return {}
	if bool(spell.get("TestSpell",false)):
		_issue = "source_TestSpell_excluded:"+str(spell.ID)
		return {}
	var effects: Array = _effects("SpellBonus","SpellClassID",int(spell.ID))
	if not _issue.is_empty(): return {}
	invokes.append(option)
	spells[str(int(spell.ID))] = {"source_spell":spell,"effects":effects,"source_invoke_type":type,"source_param1_unit":unit}
	return {"relic_subslot_buffs":secondary,"invoke_options":invokes,"invoke_spells":spells}

func _acquisition_input(input, component: String, identity: Dictionary, unavailable: Array, status: Dictionary) -> Dictionary:
	# Only original definitions enter the existing acquisition readers. Each
	# owner still checks its recipe/box, actual ownership, time and final save.
	var value: Dictionary = input.build()
	_exclusions.append_array(input.exclusions)
	var issue: String = input.problem
	if input.source_identity != identity:
		value = {}
		issue = "source_acquisition_archive_identity_mismatch"
	status[component] = {"state":"available" if not value.is_empty() else "unavailable",
		"problem":issue,"source_identity":input.source_identity.duplicate(true),"data_only":true}
	if value.is_empty():
		if issue.is_empty(): issue = "original_acquisition_definition_unavailable"
		unavailable.append({"component":component,"problem":issue,"source_exclusion_evidence":input.exclusions.duplicate(true)})
	return value

func build() -> Dictionary:
	problem = ""; _issue = ""; _exclusions.clear()
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty():
		problem = "current523_original_unavailable:"+SOURCE.problem()
		return {}
	var originals: Array[Dictionary] = SOURCE.rows("BuffCard")
	if originals.is_empty():
		problem = "current523_BuffCard_unavailable:"+SOURCE.problem()
		return {}
	var cards: Dictionary = {}; var groups: Dictionary = {}; var unavailable: Array = []
	for raw: Dictionary in originals:
		if raw.get("BuffCardDeckID") != 98: continue
		if not _integer(raw.get("ID")):
			problem = "invalid_relic_BuffCard_ID"
			return {}
		_issue = ""
		var card: Dictionary = _row("BuffCard",raw.ID)
		if card.is_empty(): unavailable.append({"card":raw,"problem":_issue}); continue
		var stable: String = IDENTITIES.source_id(98,int(raw.ID))
		if stable.is_empty(): unavailable.append({"card":raw,"problem":"saved_namespace_not_declared"}); continue
		var row: Dictionary = _card(card)
		if row.is_empty(): unavailable.append({"card":raw,"problem":_issue}); continue
		var key: String = "98:"+str(int(raw.ID))
		cards[key] = row
		# The saved identity is a declared ABI mapping, not a name or old pack join.
		var group: Dictionary = OPTIONS.group_for("source:"+stable,11)
		if not group.is_empty() and group.get("card") == raw and group.get("source_input_identity",{}).get("source_sha256") == identity.get("source_sha256"):
			groups[key+":11"] = group
		elif not group.is_empty():
			unavailable.append({"card":raw,"slot_index":11,"problem":"source_option_group_identity_mismatch"})
		else:
			unavailable.append({"card":raw,"slot_index":11,"problem":OPTIONS.problem,"declared_exclusion":OPTIONS.declared_exclusion.duplicate(true)})
	if cards.is_empty():
		problem = "current523_relic_definitions_unavailable"
		return {}
	_issue = ""
	var unlock: Dictionary = _unlock()
	if unlock.is_empty(): unavailable.append({"item_class_id":ITEM,"problem":_issue})
	_issue = ""
	var combat: Dictionary = _combat(cards,groups)
	if combat.is_empty():
		unavailable.append({"invoke_option_id":INVOKE,"problem":_issue})
		# Preserve unrelated raw secondary effects; unknown invoke references stay
		# empty instead of creating an option or guessing its Param1 namespace.
		combat = {"relic_subslot_buffs":{},"invoke_options":[],"invoke_spells":{}}
		for key: String in cards:
			if cards[key].has("subslot_buff"): combat.relic_subslot_buffs[key] = {"card":cards[key].card,"effects":cards[key].effects}
	var acquisition_status: Dictionary = {}
	var card_acquisition: Dictionary = _acquisition_input(CARD_ACQUISITION.new(),"card_acquisition",identity,unavailable,acquisition_status)
	var relic_acquisition: Dictionary = _acquisition_input(RELIC_ACQUISITION.new(),"relic_acquisition",identity,unavailable,acquisition_status)
	var payload: Dictionary = {"schema":SCHEMA,"source_snapshot":"patch523",
		"new_cards":{"catalog":{},"option_definitions":[],"skill_cards":{},"source_server_limits":[],"primary_doll_buffs":{},"subslot_buffs":{},"subslot_npc_bindings":{}},
		"options":{"groups":{},"reviewed_primary_keys":[],"changed_primary_keys":[],"bonuses":{},"types":{},"units":{},"ui_units":{},"type_labels":{}},
		"relic":{"cards":cards,"option_groups":groups,"source_server_limits":SOURCE.rows("ServerLimit"),"unlock_item":unlock},
		"relic_combat":combat,"card_acquisition":card_acquisition,"relic_acquisition":relic_acquisition,
		"source_acquisition_input_status":acquisition_status,"unavailable_source_definitions":unavailable,"source_exclusion_evidence":_exclusions}
	var bytes: PackedByteArray = JSON.stringify(payload).to_utf8_buffer()
	var digest = HashingContext.new()
	digest.start(HashingContext.HASH_SHA256); digest.update(bytes)
	payload["input_identity"] = {"input_kind":"current523_original_memory","archive":identity.duplicate(true),
		"archive_sha256":identity.get("source_sha256",""),"payload_sha256":digest.finish().hex_encode(),
		"payload_sha256_scope":"JSON.stringify(model_without_input_identity).to_utf8_buffer()","source_model_available":true,
		"new_pack_installation_observed":false}
	return payload
