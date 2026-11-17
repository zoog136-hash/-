extends RefCounted
## Presentation selection for an effect already requested by an existing caller.
## Does not admit spells, apply bonuses, create combat events or infer Sprite IDs.
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const STAGES = {"cast":"CasterEffectSpriteID", "effect":"EffectSpriteID", "impact":"EffectExplosionSpriteID", "success":"SuccessEffectSpriteID", "fail":"FailEffectSpriteID", "critical":"CriticalEffectSpriteID"}
const GLOBALS = {"polymorph":"PolymorphEffectSpriteID"}
static var _manifest_path: String = ""
static var _manifest_sha: String = ""
static var _manifest: Dictionary = {}
## Size and modified time of the verified manifest: an unchanged file is not
## hashed again on every effect request (a full SHA256 of the bank manifest).
static var _manifest_stamp: String = ""
## The first effect of a session read, SHA-256 hashed and JSON-parsed the
## whole bank manifest (~40 MB for the complete 523 bank) on the main thread,
## inside the hit/cast that showed it (phone: player.impact 1,274 ms for one
## hit). prewarm() does that read/hash/parse on a worker thread
## (sp2_background_loader.gd) when a 523 field starts; the result is adopted
## with exactly the checks below, and an effect requested before the worker
## finished waits for its remaining time instead of starting over.
const LOADER = preload("res://scripts/resources/sp2_background_loader.gd")
const SELF_PATH := "res://scripts/resources/current523_source_effect_selection.gd"

static func fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"ok":false,"enabled":true,"status":"selection_pending","reason":reason,"source_snapshot":"patch523","source_reference":detail}

static var _rejected_key: String = ""
static var _rejected: Dictionary = {}

static func _reject(key: String, result: Dictionary) -> Dictionary:
	_rejected_key = key
	_rejected = result.duplicate()
	return result

static func _bank(options: Dictionary) -> Dictionary:
	var path: String = str(options.get("manifest_path",""))
	var expected: String = str(options.get("manifest_sha256",""))
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > BANK.MAX_MANIFEST_JSON or not BANK.valid_sha(expected): return fail("current523_effect_bank_missing_or_oversized")
	var stamp: String = "%d:%d" % [file.get_length(), FileAccess.get_modified_time(path)]
	file.close()
	if path == _manifest_path and expected == _manifest_sha and stamp == _manifest_stamp and not _manifest.is_empty(): return {"ok":true,"manifest":_manifest}
	# A pinned manifest that was read and rejected stays rejected while the
	# file is unchanged. Without this every effect request re-read, hashed and
	# parsed the whole ~45 MB manifest again on the main thread (2026-11-16:
	# the installed pack's bank has no source_action_domains, so every hit or
	# cast paid this; phone player.impact 1,274 ms).
	var rejected_key: String = path + "|" + expected + "|" + stamp
	if rejected_key == _rejected_key: return _rejected.duplicate()
	var prepared: Dictionary = {}
	if LOADER.enabled and not LOADER.idle():
		var key: String = LOADER.json_key(path, expected)
		var adopting: bool = LOADER.in_flight(key)
		prepared = LOADER.take(key)
		# Finishing the task may have adopted it already (_prewarmed).
		if adopting and path == _manifest_path and expected == _manifest_sha and stamp == _manifest_stamp and not _manifest.is_empty(): return {"ok":true,"manifest":_manifest}
	var value: Variant
	if not prepared.is_empty() and "%d:%d" % prepared.stamp == stamp:
		# Read and SHA-256 checked by the worker for this exact file stamp.
		if not prepared.value.ok:
			if str(prepared.value.error).begins_with("Bank JSON SHA256 mismatch"): return fail("current523_effect_bank_pin_changed")
			if str(prepared.value.error).begins_with("Missing or oversized"): return fail("current523_effect_bank_missing_or_oversized")
			value = null
		else:
			value = prepared.value.value
	else:
		# Ordinary production pin admission; no separate resource audit is launched.
		if FileAccess.get_sha256(path) != expected: return fail("current523_effect_bank_pin_changed")
		if path == _manifest_path and expected == _manifest_sha and not _manifest.is_empty():
			_manifest_stamp = stamp
			return {"ok":true,"manifest":_manifest}
		value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("kind") != "current523_reference_sp2_action_bank" or value.get("source_snapshot") != "patch523" or not value.get("actors") is Dictionary or not value.get("source_action_domains") is Dictionary: return _reject(rejected_key, fail("current523_effect_original_action_domain_required"))
	if value.get("source_dummy_exclusion_policy") != BANK.SOURCE_DUMMY_EXCLUSION_POLICY or not value.get("excluded_source_actors") is Dictionary: return _reject(rejected_key, fail("current523_effect_source_dummy_policy_required"))
	_manifest_path = path
	_manifest_sha = expected
	_manifest = value
	_manifest_stamp = stamp
	return {"ok":true,"manifest":value}

## Starts reading/hashing/parsing the configured bank manifest on a worker,
## unless it is already loaded for the file as it is now. true = started or
## already warm.
static func prewarm(context: Dictionary = {}) -> bool:
	if not LOADER.enabled: return false
	var configured: Dictionary = SOURCE.options(context)
	if not configured.get("ok", false): return false
	var path: String = str(configured.options.get("manifest_path", ""))
	var expected: String = str(configured.options.get("manifest_sha256", ""))
	if path.is_empty() or not BANK.valid_sha(expected) or not FileAccess.file_exists(path): return false
	var stamp: String = "%d:%d" % [FileAccess.get_size(path), FileAccess.get_modified_time(path)]
	if path == _manifest_path and expected == _manifest_sha and stamp == _manifest_stamp and not _manifest.is_empty(): return true
	return LOADER.request_json(path, expected, BANK.MAX_MANIFEST_JSON, Callable(load(SELF_PATH), "_prewarmed").bind(path, expected))

## Main thread, when the prewarm task finished: adopts it through _bank()
## (the same stamp, pin and structure checks as an effect request).
static func _prewarmed(_result: Dictionary, path: String, expected: String) -> void:
	_bank({"manifest_path":path,"manifest_sha256":expected})

static func _source_integer(value: Variant) -> int:
	if BANK.integer(value,0): return int(value)
	if value is String and value.is_valid_int() and int(value) >= 0: return int(value)
	return -1

const COOKED_STORE = preload("res://scripts/resources/cooked_actor_store.gd")
## The cook tool sets the index it derived (same shape as the cooked pack's).
static var cooked_domain_index: Dictionary = {}

## Action selection from the cooked pack's cook-time action domains (same
## rules as below: dummy exclusion, sole or declared action in the domain,
## compiled inputs present), without reading the bank manifest.
static func _cooked_action(index: Dictionary, sprite: int, explicit_action: int) -> Dictionary:
	var key: String = "sprite:" + str(sprite)
	if index.excluded.has(key): return fail("current523_effect_source_declared_dummy",index.excluded[key])
	var domain: Variant = index.domains.get(key)
	if not domain is PackedInt32Array: return fail("current523_effect_complete_original_action_domain_missing")
	var action: int = explicit_action
	if action < 0:
		if domain.size() != 1: return fail("current523_effect_original_action_selection_not_unique")
		action = int(domain[0])
	if not domain.has(action): return fail("current523_effect_requested_action_not_declared")
	var compiled: Variant = index.compiled.get(key)
	if not compiled is PackedInt32Array or not compiled.has(action): return fail("current523_effect_original_action_inputs_unavailable")
	return {"ok":true,"action_id":action,"source_action_domain":{"source_snapshot":"patch523","source_actor_id":sprite,"action_ids":Array(domain),"action_domain_basis":str(index.get("domain_basis",""))}}

static func _action(options: Dictionary, sprite: int, explicit_action: int = -1) -> Dictionary:
	var sha: String = str(options.get("manifest_sha256","")).to_lower()
	var cooked: Dictionary = cooked_domain_index if not cooked_domain_index.is_empty() and str(cooked_domain_index.get("manifest_sha256","")) == sha else COOKED_STORE.effect_index(sha)
	if not cooked.is_empty(): return _cooked_action(cooked,sprite,explicit_action)
	var loaded: Dictionary = _bank(options)
	if not loaded.ok: return loaded
	var index: Dictionary = loaded.manifest
	var key: String = "sprite:" + str(sprite)
	if index.excluded_source_actors.has(key): return fail("current523_effect_source_declared_dummy",index.excluded_source_actors[key])
	var domain: Variant = index.source_action_domains.get(key)
	if not domain is Dictionary or domain.get("source_snapshot") != "patch523" or domain.get("source_actor_id") != sprite or domain.get("action_domain_basis") != "all_effective_original_SPR_actions_not_only_compiled_entries" or not domain.get("action_ids") is Array: return fail("current523_effect_complete_original_action_domain_missing")
	var ids: Array[int] = []
	for id: Variant in domain.action_ids:
		if not BANK.integer(id): return fail("current523_effect_original_action_domain_invalid")
		ids.append(int(id))
	var action: int = explicit_action
	if action < 0:
		# Existing source-overlay consumer contract requires a sole original
		# action; a partial compiled bank must never turn many actions into one.
		if ids.size() != 1: return fail("current523_effect_original_action_selection_not_unique")
		action = int(ids[0])
	if not ids.has(action): return fail("current523_effect_requested_action_not_declared")
	var entries: Variant = index.actors.get(key)
	if not entries is Dictionary or not entries.has(str(action)): return fail("current523_effect_original_action_inputs_unavailable")
	return {"ok":true,"action_id":action,"source_action_domain":domain.duplicate(true)}

static func _selected(supplied: Dictionary, sprite: int, action: Dictionary, consumer: String, request_key: String, reference: Dictionary, request_snapshot: String) -> Dictionary:
	return {"ok":true,"enabled":true,"status":"selected","source_snapshot":"patch523","request_source_snapshot":request_snapshot,
		"consumer":consumer,"request_key":request_key,"sprite_id":sprite,"action_id":int(action.action_id),
		"role_actions":{"idle":int(action.action_id)},"loop_policy":{"idle":false},
		"manifest_path":supplied.options.manifest_path,"manifest_sha256":supplied.options.manifest_sha256,
		"source_tables_sha256":supplied.source_tables_sha256,"source_reference":reference,
		"source_action_domain":action.source_action_domain,
		"source_bank_context":{"current523_source_bank":supplied.options.duplicate(true)},
		"host_policy":"existing_source_event_anchor_and_facing_plus3_one_shot; native_trigger_and_composition_unverified"}

static func select_spell_row(spell: Dictionary, stage: String, source_snapshot: String, context: Dictionary = {}) -> Dictionary:
	if source_snapshot not in ["base508","patch523"] or not STAGES.has(stage) or not BANK.integer(spell.get("ID"),1): return fail("current523_effect_explicit_spell_and_stage_required")
	var supplied: Dictionary = SOURCE.source_tables(context)
	if not supplied.ok: return supplied
	var native: Dictionary = SOURCE.table_row("SpellClass",int(spell.ID))
	# Full source-row agreement protects legacy callers from numeric snapshot
	# substitution. Current-row callers supply their actual admitted Spell row.
	if native.is_empty() or native != spell: return fail("current523_effect_complete_spell_definition_differs")
	if native.get("TestSpell") != false: return fail("current523_test_spell_effect_not_admitted")
	var field: String = STAGES[stage]
	var sprite: int = _source_integer(native.get(field))
	if sprite <= 0: return fail("current523_effect_sprite_field_absent")
	var explicit_action: int = -1
	if field == "EffectSpriteID":
		explicit_action = _source_integer(native.get("EffectSpriteActionNo"))
		if explicit_action < 0: return fail("current523_effect_explicit_source_action_required")
	var action: Dictionary = _action(supplied.options,sprite,explicit_action)
	if not action.ok: return action
	var reference: Dictionary = {"table":"SpellClass","row":native.duplicate(true),"field":field,"stage":stage,
		"action_field":"EffectSpriteActionNo" if field == "EffectSpriteID" else "sole_original_SPR_action_host_policy",
		"gameplay_admission":"existing_caller_only; no_spell_or_bonus_activation_by_visual_loader"}
	return _selected(supplied,sprite,action,"spell_effect","lineagem_%s:spell:%d:%s" % [source_snapshot,int(native.ID),stage],reference,source_snapshot)

static func select_invoke_effect(original_option: Dictionary, field: String, context: Dictionary = {}) -> Dictionary:
	# The invoke owner has already admitted the event. This selects only its
	# declared visual and never evaluates chance, damage or invoke conditions.
	if field not in ["TargetEffectSpriteID","AttackerEffectSpriteID"] or not BANK.integer(original_option.get("ID"),1): return fail("current523_invoke_effect_complete_source_option_and_field_required")
	var supplied: Dictionary = SOURCE.source_tables(context,["InvokeOption"])
	if not supplied.ok: return supplied
	var native: Dictionary = SOURCE.table_row("InvokeOption",int(original_option.ID))
	if native.is_empty() or native != original_option: return fail("current523_invoke_effect_complete_option_definition_differs")
	var reference: Dictionary = {"table":"InvokeOption","row":native.duplicate(true),"field":field,
		"action_field":"sole_original_SPR_action_host_policy",
		"gameplay_admission":"existing_invoke_owner_only; no_callback_chance_damage_ownership_or_save_changes_by_visual_loader"}
	var invoke_type: int = _source_integer(native.get("InvokeOptionTypeID"))
	if invoke_type < 0: return fail("current523_invoke_effect_source_option_type_missing",reference)
	# ElementalArrow remains archived-unused or consumer-unconfirmed. This is
	# an InvokeOption path hold, not a ban on a Sprite shared by other callers.
	if invoke_type == 34: return fail("current523_invoke_effect_elemental_arrow_consumer_unconfirmed",reference)
	var sprite: int = _source_integer(native.get(field))
	if sprite <= 0: return fail("current523_invoke_effect_source_sprite_missing",reference)
	var action: Dictionary = _action(supplied.options,sprite)
	if not action.ok: return action
	return _selected(supplied,sprite,action,"invoke_effect","current523:invoke:%d:%s" % [int(native.ID),field],reference,"patch523")

## Original SkipDamageMotionSprite: a body sprite the original declares as
## skipping its damage motion shows DamageEffectSpriteID when it takes damage
## (at the attacker when DamageEffectNearAttacker). Only that declared sprite
## is selected; a body without a row has no hit effect (none is invented).
## ExceptOverDamage (when the damage motion still plays) is not used here.
static func select_damage_effect(body_sprite: int, context: Dictionary = {}) -> Dictionary:
	if not BANK.integer(body_sprite,1): return fail("current523_damage_effect_body_sprite_required")
	var supplied: Dictionary = SOURCE.source_tables(context,["SkipDamageMotionSprite"])
	if not supplied.ok: return supplied
	var matches: Array[Dictionary] = SOURCE.table_where("SkipDamageMotionSprite","SpriteID",body_sprite)
	if matches.is_empty(): return fail("current523_damage_effect_not_declared")
	if matches.size() != 1: return fail("current523_damage_effect_declaration_not_unique")
	var row: Dictionary = matches[0]
	var sprite: int = _source_integer(row.get("DamageEffectSpriteID"))
	if sprite <= 0: return fail("current523_damage_effect_sprite_absent")
	var action: Dictionary = _action(supplied.options,sprite)
	if not action.ok: return action
	var selected: Dictionary = _selected(supplied,sprite,action,"damage_effect","current523:damage_effect:%d" % body_sprite,
		{"table":"SkipDamageMotionSprite","row":row.duplicate(true),"field":"DamageEffectSpriteID",
		"action_field":"sole_original_SPR_action_host_policy",
		"gameplay_admission":"existing_successful_hit_feedback_only; no_damage_motion_or_combat_change_by_visual_loader"},"patch523")
	selected["near_attacker"] = row.get("DamageEffectNearAttacker") == true
	return selected

static func select_player_death(request_key: String, context: Dictionary = {}) -> Dictionary:
	# The existing death owner has already requested the visual. A separate
	# source one-shot must not set ActorMotion.dead or change revival/save state.
	if request_key != "class:current523" and not request_key.begins_with("transform:m508:") and not request_key.begins_with("transform:m523:"):
		return fail("current523_death_existing_player_source_identity_required")
	var identity: Dictionary = SOURCE.select_class(context) if request_key == "class:current523" else SOURCE.select_card(request_key,context)
	if not identity.get("ok",false): return identity
	var supplied: Dictionary = SOURCE.source_tables(context)
	if not supplied.get("ok",false): return supplied
	var matches: Array[Dictionary] = []
	for row: Dictionary in SOURCE.table_rows("ListSprAction"):
		# Death is a distinct source motion, not an inferred weapon attack or
		# a fabricated corpse frame. Require its unique canonical declaration.
		if row.get("MotionType") == 5 and row.get("WeaponType") == 0 and row.get("WeaponAlterType") == 0:
			matches.append(row)
	if matches.size() != 1: return fail("current523_death_source_action_not_unique")
	var action: Dictionary = _action(supplied.options,int(identity.sprite_id),int(matches[0].ID))
	if not action.get("ok",false): return action
	return _selected(supplied,int(identity.sprite_id),action,"death_pose",request_key + ":death",
		{"table":"ListSprAction","row":matches[0].duplicate(true),"player_identity":identity.duplicate(true),
		"gameplay_admission":"existing_death_visual_event_only; no_motion_dead_revive_save_or_loss_changes"},"patch523")

static func select_item_consume(original_item: Dictionary, requested_sprite: int, context: Dictionary = {}) -> Dictionary:
	# The item owner has already admitted and completed its use. This selects
	# only that existing caller's requested display; it applies no item bonus.
	if not BANK.integer(original_item.get("ID"),1) or requested_sprite <= 0: return fail("current523_item_consume_complete_source_item_required")
	var supplied: Dictionary = SOURCE.source_tables(context,["ItemClass","ItemBonus"])
	if not supplied.ok: return supplied
	var native: Dictionary = SOURCE.table_row("ItemClass",int(original_item.ID))
	if native.is_empty() or native != original_item: return fail("current523_item_consume_complete_item_definition_differs")
	if not native.get("TestItem") is bool or native.TestItem != false: return fail("current523_test_item_consume_effect_not_admitted")
	var matches: Dictionary = {}
	var chains: Array = []
	for link: Dictionary in SOURCE.table_where("ItemBonus","ItemClassID",int(native.ID)):
		if not BANK.integer(link.get("BonusID"),1): return fail("current523_item_consume_typed_bonus_link_missing")
		var bonus: Dictionary = SOURCE.table_row("Bonus",int(link.BonusID))
		if bonus.is_empty() or not BANK.integer(bonus.get("BonusTypeID")): return fail("current523_item_consume_typed_bonus_chain_incomplete")
		var kind: Dictionary = SOURCE.table_row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if bonus.is_empty() or kind.is_empty(): return fail("current523_item_consume_typed_bonus_chain_incomplete")
		if kind.get("Name") != "ItemConsumeEffectSpriteID": continue
		var chain: Dictionary = {"ItemClass":native.duplicate(true),"ItemBonus":link.duplicate(true),
			"Bonus":bonus.duplicate(true),"BonusType":kind.duplicate(true)}
		if not link.get("IsPossession") is bool or link.IsPossession != false: return fail("current523_item_consume_possession_condition_unresolved",chain)
		if not BANK.integer(bonus.get("BonusApplicationTypeID")) or int(bonus.BonusApplicationTypeID) != 0 or not BANK.integer(bonus.get("BonusApplicationTargetID")) or int(bonus.BonusApplicationTargetID) != 0: return fail("current523_item_consume_bonus_condition_unresolved",chain)
		if not BANK.integer(kind.get("UnitID"),1): return fail("current523_item_consume_typed_sprite_unit_missing",chain)
		var unit: Dictionary = SOURCE.table_row("Unit",int(kind.UnitID))
		if unit.get("Name") != "SpriteID": return fail("current523_item_consume_bonus_unit_not_sprite_id",chain)
		chain["Unit"] = unit.duplicate(true)
		var sprite: int = _source_integer(bonus.get("Value"))
		if sprite <= 0: return fail("current523_item_consume_source_sprite_missing",chain)
		matches[sprite] = true
		chains.append(chain)
	if matches.size() != 1: return fail("current523_item_consume_source_sprite_not_unique",{"ItemClass":native.duplicate(true),"typed_chains":chains})
	var selected_sprite: int = int(matches.keys()[0])
	if selected_sprite != requested_sprite: return fail("current523_item_consume_requested_sprite_differs",{"ItemClass":native.duplicate(true),"typed_chains":chains,"requested_sprite":requested_sprite})
	var action: Dictionary = _action(supplied.options,selected_sprite)
	if not action.ok: return action
	var reference: Dictionary = {"table":"Bonus","field":"Value","bonus_type_name":"ItemConsumeEffectSpriteID",
		"owner":{"table":"ItemClass","row":native.duplicate(true)},
		"typed_chains":chains,"unit_semantic":"SpriteID","requested_sprite":requested_sprite,
		"action_field":"sole_original_SPR_action_host_policy",
		"gameplay_admission":"existing_successful_item_use_only; no_item_admission_cost_effect_or_bonus_activation_by_visual_loader"}
	return _selected(supplied,selected_sprite,action,"item_effect","current523:item:%d:consume" % int(native.ID),reference,"patch523")

static func select_global(event_name: String, legacy_definition: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if not GLOBALS.has(event_name): return fail("current523_existing_global_event_required")
	var supplied: Dictionary = SOURCE.source_tables(context)
	if not supplied.ok: return supplied
	var matches: Array[Dictionary] = []
	for row: Dictionary in SOURCE.table_rows("ConstantData"):
		if row.get("Name") == GLOBALS[event_name]: matches.append(row)
	if matches.size() != 1: return fail("current523_global_source_constant_not_unique")
	var row: Dictionary = matches[0]
	var card: Variant = context.get("current523_card_context",{})
	var current_card: bool = card is Dictionary and card.get("ok") == true and card.get("source_snapshot") == "patch523" and card.get("source_tables_sha256") == supplied.source_tables_sha256 and card.get("consumer") in ["transform","doll","relic"]
	if not current_card:
		if legacy_definition.get("source_table") != "ConstantData" or legacy_definition.get("source_original") != row: return fail("current523_global_existing_source_definition_required")
	var sprite: int = _source_integer(row.get("Value"))
	if sprite <= 0 or (not current_card and _source_integer(legacy_definition.get("sprite_id")) != sprite): return fail("current523_global_source_sprite_differs")
	var action: Dictionary = _action(supplied.options,sprite)
	if not action.ok: return action
	return _selected(supplied,sprite,action,"global_effect","current523:global:" + event_name,
		{"table":"ConstantData","row":row.duplicate(true),"field":"Value","event":event_name,
		"gameplay_admission":"existing_apply_event_only; no_new_game_event"},"patch523" if current_card else "base508")

## One direct (IsPossession false, Character/0) ItemBonus row of `bonus_name`
## with unit SpriteID on the complete ItemClass row: {sprite, chain}; sprite 0
## when the item has no such row, -1 when the row is conditional/ambiguous.
static func _item_sprite(native: Dictionary, bonus_name: String) -> Dictionary:
	var found: Array[Dictionary] = []
	for link: Dictionary in SOURCE.table_where("ItemBonus","ItemClassID",int(native.ID)):
		var bonus: Dictionary = SOURCE.table_row("Bonus",int(link.get("BonusID",-1)))
		var kind: Dictionary = SOURCE.table_row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if kind.get("Name") != bonus_name: continue
		var unit: Dictionary = SOURCE.table_row("Unit",int(kind.get("UnitID",-1)))
		if link.get("IsPossession") != false or not BANK.integer(bonus.get("BonusApplicationTypeID")) or int(bonus.BonusApplicationTypeID) != 0 or not BANK.integer(bonus.get("BonusApplicationTargetID")) or int(bonus.BonusApplicationTargetID) != 0 or unit.get("Name") != "SpriteID": return {"sprite":-1}
		found.append({"ItemBonus":link.duplicate(true),"Bonus":bonus.duplicate(true),"BonusType":kind.duplicate(true)})
	if found.is_empty(): return {"sprite":0}
	var sprites: Dictionary = {}
	for chain: Dictionary in found: sprites[_source_integer(chain.Bonus.get("Value"))] = true
	if sprites.size() != 1 or int(sprites.keys()[0]) <= 0: return {"sprite":-1}
	return {"sprite":int(sprites.keys()[0]),"chains":found}

const AMMO_STAGES = {"flight":["AmmoEffectSpriteIDByWeapon","AmmoEffectSpriteID","DefaultAmmoEffectSpriteID"],"explosion":["","AmmoExplosionSpriteID","DefaultAmmoExplosionSpriteID"]}
## Original sprite of a normal ranged attack's projectile, from tables only:
## flight = weapon AmmoEffectSpriteIDByWeapon, else the ammo's
## AmmoEffectSpriteID, else the weapon's WeaponType.DefaultAmmoEffectSpriteID;
## explosion = ammo AmmoExplosionSpriteID, else WeaponType
## .DefaultAmmoExplosionSpriteID. `ammo_items` are complete ItemClass rows in
## the existing owner's order (worn quiver item, then the fired stack). The
## bank lookup of that sprite is the caller's (current523_ammo_flight).
static func ammo_sprite(weapon_item: Dictionary, ammo_items: Array, stage: String, context: Dictionary = {}) -> Dictionary:
	if not AMMO_STAGES.has(stage) or not BANK.integer(weapon_item.get("ID"),1): return fail("current523_ammo_effect_complete_weapon_and_stage_required")
	var supplied: Dictionary = SOURCE.source_tables(context,["ItemClass","ItemBonus","WeaponType"])
	if not supplied.ok: return supplied
	var weapon: Dictionary = SOURCE.table_row("ItemClass",int(weapon_item.ID))
	if weapon.is_empty() or weapon != weapon_item or weapon.get("TestItem") != false: return fail("current523_ammo_effect_complete_weapon_definition_differs")
	var fields: Array = AMMO_STAGES[stage]
	var reference: Dictionary = {"stage":stage,"weapon_item_class_id":int(weapon.ID),"gameplay_admission":"existing_normal_ranged_attack_flight_only; no_damage_ammo_or_bonus_change_by_visual_loader"}
	var sprite: int = 0
	if not str(fields[0]).is_empty():
		var own: Dictionary = _item_sprite(weapon,str(fields[0]))
		if int(own.sprite) < 0: return fail("current523_ammo_effect_weapon_row_unresolved",reference)
		if int(own.sprite) > 0: sprite = int(own.sprite); reference["field"] = fields[0]
	if sprite == 0:
		for value: Variant in ammo_items:
			if not value is Dictionary or not BANK.integer(value.get("ID"),1): continue
			var native: Dictionary = SOURCE.table_row("ItemClass",int(value.ID))
			if native.is_empty() or native != value or native.get("TestItem") != false: return fail("current523_ammo_effect_complete_ammo_definition_differs",reference)
			var row: Dictionary = _item_sprite(native,str(fields[1]))
			if int(row.sprite) < 0: return fail("current523_ammo_effect_ammo_row_unresolved",reference)
			if int(row.sprite) > 0:
				sprite = int(row.sprite); reference["field"] = fields[1]; reference["ammo_item_class_id"] = int(native.ID)
				break
	if sprite == 0:
		var weapon_type: Dictionary = _item_sprite_type(weapon)
		if weapon_type.is_empty(): return fail("current523_ammo_effect_weapon_type_unresolved",reference)
		sprite = _source_integer(weapon_type.get(fields[2]))
		reference["field"] = "WeaponType."+str(fields[2]); reference["weapon_type_id"] = int(weapon_type.ID)
	if sprite <= 0: return fail("current523_ammo_effect_source_sprite_absent",reference)
	return {"ok":true,"sprite_id":sprite,"stage":stage,"source_reference":reference,"options":supplied.options}

## The weapon's sole direct WeaponType row (unit WeaponTypeID) -> WeaponType row.
static func _item_sprite_type(native: Dictionary) -> Dictionary:
	var types: Dictionary = {}
	for link: Dictionary in SOURCE.table_where("ItemBonus","ItemClassID",int(native.ID)):
		var bonus: Dictionary = SOURCE.table_row("Bonus",int(link.get("BonusID",-1)))
		var kind: Dictionary = SOURCE.table_row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if kind.get("Name") != "WeaponType": continue
		if link.get("IsPossession") != false or not BANK.integer(bonus.get("BonusApplicationTypeID")) or int(bonus.BonusApplicationTypeID) != 0 or not BANK.integer(bonus.get("BonusApplicationTargetID")) or int(bonus.BonusApplicationTargetID) != 0: return {}
		types[_source_integer(bonus.get("Value"))] = true
	if types.size() != 1 or int(types.keys()[0]) <= 0: return {}
	return SOURCE.table_row("WeaponType",int(types.keys()[0]))
