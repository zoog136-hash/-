extends RefCounted
## Production card selector for a private current523 source-action bank.
## The source ZIP supplies typed identities; display sprites and names never join actors.
const BASE = preload("res://scripts/lineagem_base508.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const TABLES_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const SETTINGS = "user://current523_source_bank.json"
const TABLES = ["BuffCard", "BuffCardDeck", "BuffClass", "BuffBonus", "Bonus", "BonusType", "Unit", "PolymorphSet", "PolymorphEntityForSet", "PolymorphEntity", "BuffCardSpriteCustomizingOption", "ListSprAction", "NpcClass", "BonusApplicationType", "SpriteRun", "SpriteSeparatedWalk", "SpellClass", "ConstantData", "BuffCardAwakenEffect", "StatusEffectAttr"]
const OPTIONAL_TABLES = ["ItemClass", "ItemBonus", "InvokeOption", "Class", "Gender", "WeaponType"]
# Exact current BuffCardDeck rows. Relics use native deck98 (HolyStuffCardDeck).
const DECKS = {"transform":1, "doll":2, "relic":98}
const DECK_NAMES = {"transform":"PolymorphCardDeck", "doll":"MagicDollCardDeck", "relic":"HolyStuffCardDeck"}
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
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
static var _table_path: String = ""
static var _table_sha: String = ""
static var _table_stamp: String = ""
static var _rows: Dictionary = {}
static var _by_id: Dictionary = {}
# True when the shared original-definition reader has opened an archive with
# this same pinned SHA. Its tables are column-packed and large ones stay on
# storage, so this module keeps no second whole-table copy (Bonus, SpellClass,
# NpcClass, ItemClass... cost about 1.4 GB as row dictionaries on a device).
static var _shared: bool = false
static var _shared_tables: Dictionary = {}
## Tests turn this off to compare against the row-dictionary path.
static var shared_tables_enabled: bool = true

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

static func _load_tables(path: String, additional_tables: Array[String] = []) -> Dictionary:
	var required: Array = TABLES.duplicate()
	for table: String in additional_tables:
		if not OPTIONAL_TABLES.has(table): return fail("current523_additional_source_table_not_supported:" + table)
		if not required.has(table): required.append(table)
	# Normal production integrity guard, independent of the optional old identity pack.
	# The SHA is measured again only when the file's size or time changes; every
	# NPC, effect and card selection calls this, and hashing 25 MB each time
	# cost tens of milliseconds per call on a phone.
	var stamp: String = ""
	if FileAccess.file_exists(path): stamp = "%d:%d" % [FileAccess.get_modified_time(path), FileAccess.get_size(path)]
	var current_sha: String = _table_sha if path == _table_path and not stamp.is_empty() and stamp == _table_stamp else (FileAccess.get_sha256(path) if not stamp.is_empty() else "")
	if path != _table_path or current_sha != _table_sha or stamp != _table_stamp:
		_rows.clear()
		_by_id.clear()
		_shared = false
		_shared_tables.clear()
		_table_path = path
		_table_sha = current_sha
		_table_stamp = stamp
	if current_sha != TABLES_SHA: return fail("current523_exact_source_tables_missing_or_changed")
	if shared_tables_enabled and (_shared or (DEF.SOURCE_SHA == TABLES_SHA and DEF.verified_key() == TABLES_SHA + ":" + str(DEF.SOURCE_BYTES))):
		for table: String in required:
			if _shared_tables.has(table): continue
			if DEF.table_metadata(table).is_empty(): return fail("current523_source_table_missing:" + table)
			_shared_tables[table] = true
		_shared = true
		return {"ok":true}
	var missing: Array[String] = []
	for table: String in required:
		if not _rows.has(table): missing.append(table)
	if missing.is_empty(): return {"ok":true}
	var archive := ZIPReader.new()
	if archive.open(path) != OK: return fail("current523_source_tables_unreadable")
	var rows: Dictionary = _rows.duplicate()
	var by_id: Dictionary = _by_id.duplicate()
	for table: String in missing:
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

static func source_tables(context: Dictionary = {}, additional_tables: Array[String] = []) -> Dictionary:
	# Shared, read-only source tables for existing admitted NPC consumers.
	var configured: Dictionary = options(context)
	if not configured.ok: return configured
	var loaded: Dictionary = _load_tables(str(configured.options.tables_zip), additional_tables)
	if not loaded.ok: return loaded
	return {"ok":true,"options":configured.options,"source_tables_sha256":TABLES_SHA}

## One original row by ID (a fresh copy), or {} when absent or not unique.
## Callers must have loaded the table through source_tables() first.
static func table_row(table: String, id: int) -> Dictionary:
	if not _shared:
		var row: Dictionary = _by_id.get(table,{}).get(id,{})
		return row
	var matches: Array[Dictionary] = table_where(table,"ID",id)
	return matches[0] if matches.size() == 1 else {}

## Rows whose `field` equals the integer `value`, in original table order.
static func table_where(table: String, field: String, value: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _shared:
		for row: Dictionary in _rows.get(table,[]):
			if row.has(field) and BANK.integer(row[field]) and int(row[field]) == value: result.append(row)
		return result
	if DEF.integer_field(table,field): return DEF.related(table,field,value)
	var column: Variant = DEF.column(table,field)
	if column is Array or column is PackedFloat64Array:
		for index: int in column.size():
			if BANK.integer(column[index]) and int(column[index]) == value: result.append(DEF.row_at(table,index))
		return result
	# A field missing from some rows: test each row as the dictionaries did.
	for index: int in DEF.row_count(table):
		var row: Dictionary = DEF.row_at(table,index)
		if row.has(field) and BANK.integer(row[field]) and int(row[field]) == value: result.append(row)
	return result

## Every row of a small table, in original table order.
static func table_rows(table: String) -> Array:
	if not _shared: return _rows.get(table,[])
	return DEF.rows(table)

static func _add_set(set_id: int, path: Array, output: Array) -> bool:
	var source_set: Dictionary = table_row("PolymorphSet",set_id)
	if source_set.is_empty(): return false
	for join: Dictionary in table_where("PolymorphEntityForSet","PolymorphSetID",set_id):
		var entity: Dictionary = table_row("PolymorphEntity",int(join.get("PolymorphEntityID",-1)))
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
	var unit: Dictionary = table_row("Unit",int(kind.get("UnitID",-1)))
	if unit.get("Name","") != "NPCClassID": return false
	var npc: Dictionary = table_row("NpcClass",int(bonus.get("Value",-1)))
	if npc.is_empty() or not BANK.integer(npc.get("Sprite"),1) or bool(npc.get("TestNPC",false)): return false
	var application: Dictionary = table_row("BonusApplicationType",int(bonus.get("BonusApplicationTypeID",-1)))
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
	var buff: Dictionary = table_row("BuffClass",buff_id)
	if buff.is_empty(): return false
	var base: Array = path + [{"table":"BuffClass","row":buff.duplicate(true)}]
	for link: Dictionary in table_where("BuffBonus","BuffClassID",buff_id):
		var bonus: Dictionary = table_row("Bonus",int(link.get("BonusID",-1)))
		var kind: Dictionary = table_row("BonusType",int(bonus.get("BonusTypeID",-1)))
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

static func source_run_binding(identity_actor: int, source_walk_action: int, source_weapon_type: int = 0) -> Dictionary:
	var run_rows: Array = []
	for row: Dictionary in table_where("SpriteRun","WalkSpriteID",identity_actor): run_rows.append(row.duplicate(true))
	var separate_rows: Array = []
	for row: Dictionary in table_where("SpriteSeparatedWalk","SpriteId",identity_actor): separate_rows.append(row.duplicate(true))
	var optional_actions: Dictionary = {}
	var optional_actors: Dictionary = {}
	var status: Dictionary = {"state":"no_unique_source_run_declared","source_SpriteRun_rows":run_rows,"source_SpriteSeparatedWalk_rows":separate_rows,"separate_walk_action_hint":"preserved_uninterpreted; no inferred action-ID conversion","fallback":"existing_native_walk_is_not_a_run_track"}
	var action: Dictionary = table_row("ListSprAction",source_walk_action)
	if action.get("MotionType") != 1 or action.get("WeaponType") != source_weapon_type or action.get("WeaponAlterType") != 0:
		status["state"] = "source_run_walk_action_family_unresolved"
	elif run_rows.size() == 1 and BANK.integer(run_rows[0].get("RunSpriteID"),1):
		# Existing accepted model: run uses the matching explicit WALK action in
		# the current table's RunSprite, with that actor's own source FPS/tokens.
		optional_actions["run"] = source_walk_action
		optional_actors["run"] = int(run_rows[0].RunSpriteID)
		status["state"] = "source_declared_optional_run_awaiting_bank"
		status["source_run_actor_id"] = int(run_rows[0].RunSpriteID)
		status["source_run_action_id"] = source_walk_action
		status["source_ListSprAction_row"] = action.duplicate(true)
		status["dispatch_policy"] = "existing_typed_SpriteRun_matching_primary_walk_action; native_dispatch_unverified"
	return {"optional_role_actions":optional_actions,"optional_role_actor_ids":optional_actors,"run_status":status}

static func select_class(context: Dictionary = {}) -> Dictionary:
	# The existing character owner supplies class/gender/weapon context. Never
	# convert the four legacy class-sheet indexes or a display name to a Sprite.
	var supplied: Dictionary = source_tables(context,["Class","Gender"])
	if not supplied.ok: return supplied
	if not BANK.integer(context.get("class_id"),1) or not BANK.integer(context.get("gender_id"),1) or not BANK.integer(context.get("source_weapon_type")):
		return fail("current523_explicit_character_class_gender_weapon_required")
	var gender_id: int = int(context.gender_id)
	if gender_id not in [1,2]: return fail("current523_explicit_character_gender_required")
	var native: Dictionary = table_row("Class",int(context.class_id))
	var gender: Dictionary = table_row("Gender",gender_id)
	if native.is_empty() or gender.get("Name") != ("Male" if gender_id == 1 else "Female"):
		return fail("current523_original_character_class_or_gender_missing")
	var field: String = "MaleSpriteID" if gender_id == 1 else "FemaleSpriteID"
	if not BANK.integer(native.get(field),1): return fail("current523_class_original_sprite_missing")
	var weapon: int = int(context.source_weapon_type)
	if not PRIMARY_ACTIONS.has(weapon): return fail("current523_explicit_weapon_policy_unavailable")
	var actions: Dictionary = PRIMARY_ACTIONS[weapon].duplicate()
	var action_rows: Dictionary = {}
	for role: String in actions:
		var action: Dictionary = table_row("ListSprAction",int(actions[role]))
		if action.is_empty() or action.get("WeaponType") != weapon or action.get("MotionType") != {"idle":4,"walk":1,"attack":2}[role] or action.get("WeaponAlterType") != (1 if weapon in [3,10] and role == "attack" else 0):
			return fail("current523_primary_action_source_row_differs")
		action_rows[role] = action.duplicate(true)
	var sprite: int = int(native[field])
	var run: Dictionary = source_run_binding(sprite,int(actions.walk),weapon)
	var hit: Dictionary = source_hit_binding(weapon)
	if hit.get("ok",false):
		run.optional_role_actions["hit"] = int(hit.action.ID)
		run.optional_role_actor_ids["hit"] = sprite
	return {"ok":true,"enabled":true,"status":"selected","source_snapshot":"patch523","consumer":"class",
		"request_key":"class:current523","sprite_id":sprite,"source_weapon_type":weapon,
		"source_reference":{"table":"Class","row":native.duplicate(true),"field":field,"gender":gender.duplicate(true),"ListSprAction":action_rows,
			"admission":"existing_character_class_and_gender_only; no_creation_stat_or_save_changes"},
		"source_tables_sha256":supplied.source_tables_sha256,"manifest_path":supplied.options.manifest_path,"manifest_sha256":supplied.options.manifest_sha256,
		"source_bank_context":{"current523_source_bank":supplied.options.duplicate(true)},
		"role_actions":actions,"loop_policy":{"idle":true,"walk":true,"attack":false},
		"optional_role_actions":run.optional_role_actions,"optional_role_actor_ids":run.optional_role_actor_ids,"optional_role_loop_policy":{"run":true,"hit":false},"run_status":run.run_status,"hit_status":hit,
		"host_policy":"existing_player_primary_roles_loop_and_facing_plus3; native_dispatch_unverified"}

static func source_hit_binding(weapon: int) -> Dictionary:
	# The existing player motion owner has already admitted the hit state.
	# Only its exact current primary weapon family supplies a reaction action.
	var matches: Array[Dictionary] = []
	for row: Dictionary in table_rows("ListSprAction"):
		if row.get("MotionType") == 3 and row.get("WeaponType") == weapon and row.get("WeaponAlterType") == 0:
			matches.append(row)
	if matches.size() != 1: return {"ok":false,"state":"source_primary_hit_action_not_unique","source_weapon_type":weapon}
	return {"ok":true,"state":"source_declared_optional_hit_awaiting_bank","table":"ListSprAction","action":matches[0].duplicate(true),"source_weapon_type":weapon,"dispatch_policy":"existing_admitted_player_hit_state_only; native_dispatch_unverified"}

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
	var native: Dictionary = table_row("BuffCard",int(record.get("source_card_id",-1)))
	# The data owner's canonical sourceId is the saved ABI. Do not reconstruct
	# that namespace from a current deck number or relabel the saved identity.
	if native.is_empty() or native != record.source_original_card or int(native.get("BuffCardDeckID",-1)) != DECKS[consumer] or int(record.get("source_deck_id",-1)) != int(native.BuffCardDeckID): return fail("current523_complete_typed_card_definition_differs")
	var deck: Dictionary = table_row("BuffCardDeck",int(native.BuffCardDeckID))
	if deck.get("Name") != DECK_NAMES[consumer]: return fail("current523_typed_card_deck_category_differs")
	if bool(native.get("IsTest",false)): return fail("current523_test_card_not_admitted")
	var preserved_rule: Dictionary = BASE.identity_rules().get(int(native.ID),{}) if source_id.begins_with("m508:") else {}
	var card_conditions: Dictionary = {"ServerLimitSetID":int(native.get("ServerLimitSetID",0)),"StartDateTimeID":int(native.get("StartDateTimeID",0)),"EndDateTimeID":int(native.get("EndDateTimeID",0))}
	var conditional_card: bool = card_conditions.ServerLimitSetID != 0 or card_conditions.StartDateTimeID != 0 or card_conditions.EndDateTimeID != 0
	# A known stable conditional summon must still match its complete source chain
	# below. New conditional identities do not acquire a local admission meaning.
	if conditional_card and preserved_rule.get("selection_kind","") != "indirect_subslot_buff_summon": return fail("current523_conditional_card_admission_unresolved")
	var path: Array = [{"table":"BuffCard","row":native.duplicate(true)},{"table":"BuffCardDeck","row":deck.duplicate(true)}]
	var chains: Array = []
	var active: Dictionary = context.get("active_card_options",{})
	var option_id: int = int(active.get(source_id,record.get("source_active_custom_option_id",0)))
	if option_id > 0:
		var option: Dictionary = table_row("BuffCardSpriteCustomizingOption",option_id)
		var unit: Dictionary = table_row("Unit",int(option.get("UnitID",-1)))
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
		var action: Dictionary = table_row("ListSprAction",int(actions[role]))
		if action.is_empty() or int(action.get("WeaponType",-1)) != weapon or int(action.get("MotionType",-1)) != {"idle":4,"walk":1,"attack":2}[role]: return fail("current523_primary_action_source_row_differs")
		if int(action.get("WeaponAlterType",-1)) != (1 if weapon in [3,10] and role == "attack" else 0): return fail("current523_primary_action_alter_policy_differs")
	var identity_actor: int = int(matches.keys()[0])
	var run_binding: Dictionary = source_run_binding(identity_actor,int(actions.walk),weapon)
	var optional_actions: Dictionary = run_binding.optional_role_actions
	var optional_actors: Dictionary = run_binding.optional_role_actor_ids
	var run_status: Dictionary = run_binding.run_status
	var hit: Dictionary = source_hit_binding(weapon) if consumer == "transform" else {}
	if hit.get("ok",false):
		optional_actions["hit"] = int(hit.action.ID)
		optional_actors["hit"] = identity_actor
	return {"ok":true,"enabled":true,"status":"selected","sprite_id":identity_actor,"source_snapshot":"patch523","origin":"current523_exact_typed_card_entity_chain","request_key":key,"consumer":consumer,"typed_chains":selected_chains,"native_card_conditions":card_conditions,"native_application_conditions":application_conditions,"native_application_condition":application_conditions[0] if application_conditions.size() == 1 else {},"gameplay_condition":"preserved_uninterpreted; presentation_only","source_tables_sha256":TABLES_SHA,"manifest_path":configured.options.manifest_path,"manifest_sha256":configured.options.manifest_sha256,"role_actions":actions,"optional_role_actions":optional_actions,"optional_role_actor_ids":optional_actors,"optional_role_loop_policy":{"run":true,"hit":false},"run_status":run_status,"hit_status":hit,"loop_policy":{"idle":true,"walk":true,"attack":false} if consumer == "transform" else {"idle":true,"walk":true},"source_weapon_type":weapon,"overlay_whitelist_path":configured.options.get("overlay_whitelist_path",""),"overlay_whitelist_sha256":configured.options.get("overlay_whitelist_sha256",""),"host_policy":"TWILIGHT_existing_primary_roles_loop_and_facing_plus3; native_dispatch_unverified"}
