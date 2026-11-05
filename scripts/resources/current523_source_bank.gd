extends RefCounted
## Production card selector for a private current523 source-action bank.
## The source ZIP supplies typed identities; display sprites and names never join actors.
const BASE = preload("res://scripts/lineagem_base508.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const TABLES_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const SETTINGS = "user://current523_source_bank.json"
const TABLES = ["BuffCard", "BuffClass", "BuffBonus", "Bonus", "BonusType", "Unit", "PolymorphSet", "PolymorphEntityForSet", "PolymorphEntity", "BuffCardSpriteCustomizingOption", "ListSprAction", "NpcClass", "BonusApplicationType"]
const DECKS = {"transform":1, "doll":2, "relic":3}
# Existing TWILIGHT primary-family choice. This is explicit host presentation
# policy; it does not infer native alternate, shield, special or type74 intent.
const PRIMARY_ACTIONS = {
	0:{"idle":3,"walk":0,"attack":1}, 1:{"idle":7,"walk":4,"attack":5},
	2:{"idle":14,"walk":11,"attack":12}, 3:{"idle":23,"walk":20,"attack":21},
	4:{"idle":27,"walk":24,"attack":25}, 5:{"idle":43,"walk":40,"attack":41},
	6:{"idle":49,"walk":46,"attack":47}, 7:{"idle":53,"walk":50,"attack":51},
	8:{"idle":57,"walk":54,"attack":55}, 9:{"idle":61,"walk":58,"attack":59},
	10:{"idle":65,"walk":62,"attack":63}, 11:{"idle":86,"walk":83,"attack":84},
	34:{"idle":122,"walk":119,"attack":120}, 54:{"idle":127,"walk":124,"attack":125},
	84:{"idle":151,"walk":147,"attack":148}, 102:{"idle":156,"walk":152,"attack":153}
}
static var _table_path: String = ""
static var _rows: Dictionary = {}
static var _by_id: Dictionary = {}

static func fail(reason: String, enabled: bool = true) -> Dictionary:
	return {"ok":false,"enabled":enabled,"status":"selection_pending","reason":reason,"source_snapshot":"patch523"}

static func options(context: Dictionary = {}) -> Dictionary:
	var value: Variant = context.get("current523_source_bank", {})
	var explicit: bool = context.has("current523_source_bank")
	if not value is Dictionary: return fail("current523_bank_options_invalid")
	if value.is_empty() and not explicit:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--current523-source-bank-config="):
				explicit = true
				var path: String = argument.trim_prefix("--current523-source-bank-config=")
				if not FileAccess.file_exists(path): return fail("current523_bank_config_missing")
				value = JSON.parse_string(FileAccess.get_file_as_string(path))
				break
	if not explicit and FileAccess.file_exists(SETTINGS):
		value = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	if not value is Dictionary: return fail("current523_bank_config_invalid")
	if value.is_empty() or value.get("enabled",false) == false: return fail("current523_bank_disabled",false)
	if value.get("enabled") != true or value.get("schema") != 1 or value.get("source_snapshot") != "patch523": return fail("current523_bank_config_snapshot_invalid")
	for field: String in ["tables_zip","manifest_path"]:
		if not value.get(field) is String or str(value[field]).is_empty(): return fail("current523_bank_path_missing")
	if not BANK.valid_sha(value.get("manifest_sha256")): return fail("current523_bank_manifest_pin_required")
	return {"ok":true,"enabled":true,"options":value.duplicate(true)}

static func _load_tables(path: String) -> Dictionary:
	# Normal production integrity guard, independent of the optional old identity pack.
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != TABLES_SHA: return fail("current523_exact_source_tables_missing_or_changed")
	if path == _table_path and not _rows.is_empty(): return {"ok":true}
	var archive := ZIPReader.new()
	if archive.open(path) != OK: return fail("current523_source_tables_unreadable")
	var rows: Dictionary = {}
	var by_id: Dictionary = {}
	for table: String in TABLES:
		var member: String = "content/" + table + ".json"
		if not archive.file_exists(member):
			archive.close()
			return fail("current523_source_table_missing:" + table)
		var parsed: Variant = JSON.parse_string(archive.read_file(member).get_string_from_utf8())
		if not parsed is Dictionary or not parsed.get("rows") is Array:
			archive.close()
			return fail("current523_source_table_invalid:" + table)
		rows[table] = parsed.rows
		by_id[table] = {}
		for row: Variant in parsed.rows:
			if not row is Dictionary:
				archive.close()
				return fail("current523_source_row_invalid:" + table)
			if row.has("ID"):
				if not BANK.integer(row.ID) or by_id[table].has(int(row.ID)):
					archive.close()
					return fail("current523_source_row_identity_invalid:" + table)
				by_id[table][int(row.ID)] = row
	archive.close()
	_rows = rows
	_by_id = by_id
	_table_path = path
	return {"ok":true}

static func source_tables(context: Dictionary = {}) -> Dictionary:
	# Shared, read-only source tables for existing admitted NPC consumers.
	var configured: Dictionary = options(context)
	if not configured.ok: return configured
	var loaded: Dictionary = _load_tables(str(configured.options.tables_zip))
	if not loaded.ok: return loaded
	return {"ok":true,"rows":_rows,"by_id":_by_id,"options":configured.options,"source_tables_sha256":TABLES_SHA}

static func _add_set(set_id: int, path: Array, output: Array) -> bool:
	var source_set: Dictionary = _by_id.PolymorphSet.get(set_id,{})
	if source_set.is_empty(): return false
	for join: Dictionary in _rows.PolymorphEntityForSet:
		if int(join.get("PolymorphSetID",-1)) != set_id: continue
		var entity: Dictionary = _by_id.PolymorphEntity.get(int(join.get("PolymorphEntityID",-1)),{})
		if entity.is_empty() or not BANK.integer(entity.get("SpriteID"),1): return false
		output.append({"sprite_id":int(entity.SpriteID),"entity":entity.duplicate(true),"path":path + [{"table":"PolymorphSet","row":source_set.duplicate(true)},{"table":"PolymorphEntityForSet","row":join.duplicate(true)},{"table":"PolymorphEntity","row":entity.duplicate(true)}]})
	return true

static func _preserved_summon_matches(path: Array, npc: Dictionary, application: Dictionary, condition: Dictionary, rule: Dictionary) -> bool:
	if path.is_empty() or path[0].get("table","") != "BuffCard" or int(rule.get("card_id",-1)) != int(path[0].row.get("ID",-2)): return false
	if rule.get("selection_kind","") != "indirect_subslot_buff_summon" or rule.get("native_application_condition",{}) != condition or int(rule.get("summon_npc_class_id",-1)) != int(npc.ID) or int(rule.get("inworld_sprite_id",-1)) != int(npc.Sprite): return false
	var steps: Array = []
	var step: Dictionary = {}
	for item: Dictionary in path:
		var table: String = str(item.get("table",""))
		var row: Dictionary = item.get("row",{})
		if table == "BuffClass":
			if not step.is_empty(): steps.append(step)
			step = {"buff_class_id":int(row.ID)}
		elif table == "BuffBonus": step["buff_bonus"] = row
		elif table == "Bonus": step["bonus"] = row
		elif table == "BonusType": step["bonus_type"] = row
	if not step.is_empty(): steps.append(step)
	var declared: Variant = rule.get("declared_chain")
	if not declared is Array or declared.size() != steps.size() or steps.is_empty(): return false
	for index: int in range(steps.size()):
		if not declared[index] is Dictionary: return false
		for field: String in ["buff_class_id","buff_bonus","bonus","bonus_type"]:
			if not declared[index].has(field) or declared[index][field] != steps[index].get(field): return false
		if declared[index].has("bonus_application_type") and (index != steps.size()-1 or declared[index].bonus_application_type != application): return false
	return true

static func _add_npc_summon(bonus: Dictionary, kind: Dictionary, path: Array, output: Array, preserved_rule: Dictionary) -> bool:
	var unit: Dictionary = _by_id.Unit.get(int(kind.get("UnitID",-1)),{})
	if unit.get("Name","") != "NPCClassID": return false
	var npc: Dictionary = _by_id.NpcClass.get(int(bonus.get("Value",-1)),{})
	if npc.is_empty() or not BANK.integer(npc.get("Sprite"),1) or bool(npc.get("TestNPC",false)): return false
	var application: Dictionary = _by_id.BonusApplicationType.get(int(bonus.get("BonusApplicationTypeID",-1)),{})
	if application.is_empty(): return false
	var condition: Dictionary = {"BonusApplicationTypeID":int(bonus.BonusApplicationTypeID),"BonusApplicationTypeName":str(application.get("Name","")),"BonusApplicationTargetID":int(bonus.get("BonusApplicationTargetID",0))}
	var preserved: bool = _preserved_summon_matches(path,npc,application,condition,preserved_rule)
	# Existing selected/equipped-card presentation can reuse an exactly preserved
	# conditional identity. This never interprets the slot enum or applies a buff.
	if (int(condition.BonusApplicationTypeID) != 0 or int(condition.BonusApplicationTargetID) != 0) and not preserved: return false
	output.append({"sprite_id":int(npc.Sprite),"entity":npc.duplicate(true),"identity_kind":"typed_buff_card_npc_summon","native_application_condition":condition,"preserved_conditional_identity":preserved,"gameplay_condition":"preserved_uninterpreted; presentation_only","path":path + [{"table":"Unit","row":unit.duplicate(true)},{"table":"BonusApplicationType","row":application.duplicate(true)},{"table":"NpcClass","row":npc.duplicate(true)}]})
	return true

static func _walk_buff(buff_id: int, path: Array, seen: Array, output: Array, preserved_rule: Dictionary = {}) -> bool:
	if buff_id in seen or seen.size() >= 16: return false
	var buff: Dictionary = _by_id.BuffClass.get(buff_id,{})
	if buff.is_empty(): return false
	var base: Array = path + [{"table":"BuffClass","row":buff.duplicate(true)}]
	for link: Dictionary in _rows.BuffBonus:
		if int(link.get("BuffClassID",-1)) != buff_id: continue
		var bonus: Dictionary = _by_id.Bonus.get(int(link.get("BonusID",-1)),{})
		var kind: Dictionary = _by_id.BonusType.get(int(bonus.get("BonusTypeID",-1)),{})
		if bonus.is_empty() or kind.is_empty(): return false
		if kind.get("Name","") == "BuffCardSummonNPCClassID" and (int(link.get("CharacterLevel",0)) != 0 or int(link.get("CharacterClass",0)) != 0 or int(link.get("MinSpellLevel",0)) != 0): return false
		if kind.get("Name","") in ["PolymorphSetID","SpecialPolymorphSetID","SubSlotBuffClassID"]:
			# A source conditional cannot become unconditional appearance admission.
			if int(link.get("CharacterLevel",0)) != 0 or int(link.get("CharacterClass",0)) != 0 or int(link.get("MinSpellLevel",0)) != 0 or int(bonus.get("BonusApplicationTypeID",0)) != 0 or int(bonus.get("BonusApplicationTargetID",0)) != 0: return false
		var extended: Array = base + [{"table":"BuffBonus","row":link.duplicate(true)},{"table":"Bonus","row":bonus.duplicate(true)},{"table":"BonusType","row":kind.duplicate(true)}]
		if kind.get("Name","") in ["PolymorphSetID","SpecialPolymorphSetID"]:
			if not _add_set(int(bonus.get("Value",-1)),extended,output): return false
		elif kind.get("Name","") == "SubSlotBuffClassID":
			if not _walk_buff(int(bonus.get("Value",-1)),extended,seen + [buff_id],output,preserved_rule): return false
		elif kind.get("Name","") == "BuffCardSummonNPCClassID":
			if not _add_npc_summon(bonus,kind,extended,output,preserved_rule): return false
	return true

static func select_card(key: String, context: Dictionary = {}) -> Dictionary:
	var configured: Dictionary = options(context)
	if not configured.ok: return configured
	var consumer: String = key.get_slice(":",0)
	if not DECKS.has(consumer): return fail("current523_existing_card_consumer_required")
	var source_id: String = key.substr(key.find(":") + 1)
	if not source_id.begins_with("m508:") and not source_id.begins_with("m523:"): return fail("current523_namespaced_card_required")
	var record: Dictionary = BASE.canonical({"source":"lineagem_base508","sourceId":source_id})
	if record.get("sourceId","") != source_id or not record.get("source_original_card") is Dictionary: return fail("current523_canonical_card_required")
	var loaded: Dictionary = _load_tables(str(configured.options.tables_zip))
	if not loaded.ok: return loaded
	var native: Dictionary = _by_id.BuffCard.get(int(record.get("source_card_id",-1)),{})
	if native.is_empty() or native != record.source_original_card or int(native.get("BuffCardDeckID",-1)) != DECKS[consumer] or source_id != "%s:%d:%d" % [source_id.get_slice(":",0),int(native.BuffCardDeckID),int(native.ID)]: return fail("current523_complete_typed_card_definition_differs")
	if bool(native.get("IsTest",false)): return fail("current523_test_card_not_admitted")
	var preserved_rule: Dictionary = BASE.identity_rules().get(int(native.ID),{}) if source_id.begins_with("m508:") else {}
	var card_conditions: Dictionary = {"ServerLimitSetID":int(native.get("ServerLimitSetID",0)),"StartDateTimeID":int(native.get("StartDateTimeID",0)),"EndDateTimeID":int(native.get("EndDateTimeID",0))}
	var conditional_card: bool = card_conditions.ServerLimitSetID != 0 or card_conditions.StartDateTimeID != 0 or card_conditions.EndDateTimeID != 0
	# A known stable conditional summon must still match its complete source chain
	# below. New conditional identities do not acquire a local admission meaning.
	if conditional_card and preserved_rule.get("selection_kind","") != "indirect_subslot_buff_summon": return fail("current523_conditional_card_admission_unresolved")
	var path: Array = [{"table":"BuffCard","row":native.duplicate(true)}]
	var chains: Array = []
	var active: Dictionary = context.get("active_card_options",{})
	var option_id: int = int(active.get(source_id,record.get("source_active_custom_option_id",0)))
	if option_id > 0:
		var option: Dictionary = _by_id.BuffCardSpriteCustomizingOption.get(option_id,{})
		var unit: Dictionary = _by_id.Unit.get(int(option.get("UnitID",-1)),{})
		if int(option.get("BuffCardID",-1)) != int(native.ID) or unit.get("Name","") != "PolymorphSetID": return fail("current523_active_option_not_declared_for_card")
		if not _add_set(int(option.get("Value",-1)),path + [{"table":"BuffCardSpriteCustomizingOption","row":option.duplicate(true)},{"table":"Unit","row":unit.duplicate(true)}],chains): return fail("current523_active_option_entity_missing")
	elif not _walk_buff(int(native.get("BuffClassID",-1)),path,[],chains,preserved_rule): return fail("current523_typed_buff_entity_chain_incomplete")
	var matches: Dictionary = {}
	var selected_chains: Array = []
	for chain: Dictionary in chains:
		var entity: Dictionary = chain.entity
		var class_id: int = int(entity.get("ClassID",0))
		var gender_id: int = int(entity.get("GenderID",0))
		if class_id > 0 and class_id != int(context.get("class_id",0)): continue
		if gender_id > 0 and gender_id != int(context.get("gender_id",0)): continue
		if conditional_card and not bool(chain.get("preserved_conditional_identity",false)): return fail("current523_conditional_summon_identity_not_preserved")
		matches[int(chain.sprite_id)] = true
		selected_chains.append(chain)
	if matches.size() != 1: return fail("current523_source_entity_context_missing_or_not_unique")
	var application_conditions: Array = []
	for chain: Dictionary in selected_chains:
		if chain.has("native_application_condition") and not chain.native_application_condition in application_conditions: application_conditions.append(chain.native_application_condition.duplicate(true))
	var weapon: int = int(context.get("source_weapon_type",0)) if consumer == "transform" else 0
	if not PRIMARY_ACTIONS.has(weapon): return fail("current523_explicit_weapon_policy_unavailable")
	var actions: Dictionary = PRIMARY_ACTIONS[weapon].duplicate()
	if consumer != "transform": actions.erase("attack")
	for role: String in actions:
		var action: Dictionary = _by_id.ListSprAction.get(int(actions[role]),{})
		if action.is_empty() or int(action.get("WeaponType",-1)) != weapon or int(action.get("MotionType",-1)) != {"idle":4,"walk":1,"attack":2}[role]: return fail("current523_primary_action_source_row_differs")
		if int(action.get("WeaponAlterType",-1)) != (1 if weapon in [3,10] and role == "attack" else 0): return fail("current523_primary_action_alter_policy_differs")
	return {"ok":true,"enabled":true,"status":"selected","sprite_id":int(matches.keys()[0]),"source_snapshot":"patch523","origin":"current523_exact_typed_card_entity_chain","request_key":key,"consumer":consumer,"typed_chains":selected_chains,"native_card_conditions":card_conditions,"native_application_conditions":application_conditions,"native_application_condition":application_conditions[0] if application_conditions.size() == 1 else {},"gameplay_condition":"preserved_uninterpreted; presentation_only","source_tables_sha256":TABLES_SHA,"manifest_path":configured.options.manifest_path,"manifest_sha256":configured.options.manifest_sha256,"role_actions":actions,"loop_policy":{"idle":true,"walk":true,"attack":false} if consumer == "transform" else {"idle":true,"walk":true},"source_weapon_type":weapon,"overlay_whitelist_path":configured.options.get("overlay_whitelist_path",""),"overlay_whitelist_sha256":configured.options.get("overlay_whitelist_sha256",""),"host_policy":"TWILIGHT_existing_primary_roles_loop_and_facing_plus3; native_dispatch_unverified"}
