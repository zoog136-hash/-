extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Source InfiniteAmount is ownership-preserving use, never a zero-quantity
## call to the material debit ABI. Reuse the existing source buff/MP consumers.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const C=preload("res://scripts/quests/quest_reward_consumption.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const EXTRA=preload("res://scripts/quests/quest_source_buffs523.gd")
const IDS=[295544,302461,203422,295504,282793,295524]
const MP_IDS=[203422,295504]
const PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
static func profile(record: Dictionary)->Dictionary:
	var id: int=int(record.get("source_item_class_id",0))
	if id not in IDS or D.pack_identity().get("sha256")!=PIN:return {}
	var definition: Dictionary=D.definition_id(str(id))
	var expected: Dictionary=D.expected_variant(definition.get("native_record",{}),record)
	if expected.is_empty() or not D.matches(record,expected) or expected.get("source_test_item",true):return {}
	if id in EXTRA.FOOD:return EXTRA.profile(record)
	var spec: Dictionary=NATIVE_FIELDS.full(expected).get("source_use_spec",{})
	if id in MP_IDS:return mp_profile(definition,expected)
	if spec.get("kind")!="source_timed_buff" or spec.get("activation_status")!="blocked" or spec.get("blocked_reasons")!=["source_infinite_amount_not_supported"]:return {}
	var amounts: Dictionary={"ItemConsumeDelay":[500,"MilliSeconds"],"BuffClassID":[223 if id==295544 else 5,"BuffClassID"],"BuffDuration":[1800,"Seconds"],"ItemConsumeEffectSpriteID":[751 if id==295544 else 15889,"SpriteID"],"InfiniteAmount":[1,"Value"]}
	var seen: Dictionary={}
	for row: Dictionary in definition.get("item_bonus",[]):
		var name: String=str(row.bonus_type.Name)
		if not amounts.has(name) or seen.has(name) or row.get("IsPossession")!=false or row.bonus.get("BonusApplicationTypeID")!=0 or row.bonus.get("BonusApplicationTargetID")!=0 or row.bonus.Value!=amounts[name][0] or row.unit.Name!=amounts[name][1]:return {}
		seen[name]=true
	if seen.size()!=5 or spec.get("duration_seconds")!=1800 or spec.get("consume_delay_ms")!=500:return {}
	var source: Dictionary=spec.get("source_buff_class",{});var group: Dictionary=spec.get("source_buff_group",{})
	if source.get("ID")!=(223 if id==295544 else 5) or source.get("BuffGroupID")!=(502 if id==295544 else 5) or source.get("IsImmuneToCancellation")!=true or source.get("IsImmuneToDead")!=(id==295544) or group.get("ID")!=source.get("BuffGroupID") or group.get("IsAllowOverlap")!=(id==302461) or group.get("IsAllowPriority")!=false or group.get("IsEraseBySpellLevel")!=false:return {}
	var typed: Dictionary={"melee_damage":3,"melee_accuracy":3,"ranged_damage":3,"ranged_accuracy":3,"sp":3,"magic_accuracy":3} if id==295544 else {"def":3}
	if not C.same(spec.get("typed_effects"),typed):return {}
	for row: Dictionary in spec.get("source_buff_bonus",[]):
		if row.get("CharacterLevel")!=0 or row.get("CharacterClass")!=0 or row.get("MinSpellLevel")!=0 or row.bonus.get("BonusApplicationTypeID")!=0 or row.bonus.get("BonusApplicationTargetID")!=0 or row.unit.Name!="Value" or row.bonus.Value!=3:return {}
	var result: Dictionary=expected.duplicate(true)
	result.source_use_spec=NATIVE_FIELDS.full(result).source_use_spec.duplicate(true)
	NATIVE_FIELDS.full(result).source_use_spec["activation_status"]="unrestricted"
	return result
static func mp_profile(definition: Dictionary,expected: Dictionary)->Dictionary:
	var spec: Dictionary=NATIVE_FIELDS.full(expected).get("source_use_spec",{})
	if spec.get("kind")!="source_mp_dice" or spec.get("activation_status")!="blocked" or not C.same(spec.get("blocked_reasons"),["unsupported_item_bonus:ClassUsageInterval","source_infinite_amount_not_supported"]):return {}
	if spec.get("base")!=1000 or spec.get("MPRestoration")!=1000 or spec.get("dice_number")!=0 or spec.get("dice_spot_count")!=0 or spec.get("consume_delay_ms")!=1000:return {}
	var expected_bonuses: Dictionary={"MPRestoration":[1000,"Value"],"ItemConsumeEffectSpriteID":[190,"SpriteID"],"ItemConsumeDelay":[1000,"MilliSeconds"],"ClassUsageInterval":[1800,"Seconds"],"InfiniteAmount":[1,"Value"]}
	var seen: Dictionary={}
	for row: Dictionary in definition.get("item_bonus",[]):
		var name: String=str(row.bonus_type.Name)
		if not expected_bonuses.has(name) or seen.has(name) or row.get("IsPossession")!=false or row.bonus.get("BonusApplicationTypeID")!=0 or row.bonus.get("BonusApplicationTargetID")!=0 or row.bonus.Value!=expected_bonuses[name][0] or row.unit.Name!=expected_bonuses[name][1]:return {}
		seen[name]=true
	if seen.size()!=5:return {}
	var result: Dictionary=expected.duplicate(true)
	result.source_use_spec=NATIVE_FIELDS.full(result).source_use_spec.duplicate(true)
	NATIVE_FIELDS.full(result).source_use_spec["activation_status"]="unrestricted"
	NATIVE_FIELDS.full(result).source_use_spec["source_class_usage_interval_seconds"]=1800
	NATIVE_FIELDS.full(result).source_use_spec["host_interval_policy"]="per_ItemClass_active_play_seconds; native_shared_scope_offline_clock_unverified"
	return result
static func interval_key(record: Dictionary)->String:return "m523:class-interval:"+str(int(record.source_item_class_id))
static func stamp(world: Node)->String:
	return JSON.stringify([OWN.stamp(world),world.quest_service.save_blocked,world.active_item_buffs,world.item_use_cooldowns,world.consumable_service.export_state(),world.ui_preferences.get("item_locks",{}),world.job_class,world.level,world.hp,world.mp,world.rng.state,world.ui_preferences.get("quest523_source_class_usage_interval_policy","per_item_class_active_play_seconds"),world.ui_preferences.get("quest523_food_regen_interval_seconds",30.0)]).sha256_text()
static func ownership(world: Node,record: Dictionary,physical_id: String)->Dictionary:
	if world.quest_service.save_blocked or world.hp<=0 or profile(record).is_empty():return {}
	var key: String=str(record.name)
	if world._item_locked(key,"") or (not physical_id.is_empty() and world._item_locked(key,physical_id)):return {}
	if physical_id.is_empty():
		var registered: Dictionary=world._find_catalog_item_record(key)
		if not D.matches(registered,record) or registered.get("source_m_native_item")!=true or registered.get("source_snapshot")!="patch523" or int(registered.get("source_item_class_id",0))!=int(record.source_item_class_id) or int(registered.get("source_bless_raw",0))!=int(record.source_bless_raw) or OWN.positive(world.inventory.get(key))<1:return {}
		return {"kind":"native_catalog","key":"native:"+str(record.sourceId),"item_class_id":int(record.source_item_class_id),"bless":int(record.source_bless_raw),"source_id":str(record.sourceId)}
	var owned: Dictionary=OWN.proof(world,physical_id)
	if not owned.get("ok",false) or owned.source_use_immediately or owned.source_item.get("TestItem",true) or int(owned.item_class_id)!=int(record.source_item_class_id) or int(owned.bless_code_id)!=int(record.source_bless_raw) or owned.source_item!=D.definition_id(str(owned.item_class_id)).original_item or world._item_locked(str(owned.inventory_key),""):return {}
	# Verify previous consumed quantity without inventing a consumption for this
	# infinite use. Invalid historical owner records remain protected.
	var proof: Dictionary=C.stage(world,[{"physical_id":physical_id,"quantity":1,"expected_quantity":int(owned.quantity),"expected_remaining":int(owned.quantity)-1,"quest_reward_receipt":world.item_instances[physical_id].quest_reward_receipt.duplicate(true)}],PIN)
	if not proof.get("ok",false):return {}
	return {"kind":"quest_owned","key":"quest:"+physical_id,"physical_id":physical_id,"item_class_id":int(owned.item_class_id),"bless":int(owned.bless_code_id),"quest_reward_receipt":world.item_instances[physical_id].quest_reward_receipt.duplicate(true)}
class View extends Node:
	var host: Node
	var record: Dictionary
	var proof: Dictionary
	var base_stamp: String
	var inventory: Dictionary
	var active_item_buffs: Dictionary
	var item_use_cooldowns: Dictionary
	var hp: int
	var mp: int
	var committed: bool=false
	var uncertain: bool=false
	func _get(key: StringName)->Variant:return host.get(key)
	func _effective_max_hp()->int:return host._effective_max_hp()
	func _effective_max_mp()->int:return host._effective_max_mp()
	func _format_seconds_short(v: float)->String:return host._format_seconds_short(v)
	func _refresh_speed_modifiers()->void:host._refresh_speed_modifiers()
	func _update_hud()->void:host._update_hud()
	func _save_game(_quiet: bool,overrides: Dictionary)->Error:
		var owner_script: GDScript=load("res://scripts/quests/quest_reusable523.gd")
		if committed or base_stamp!=owner_script.stamp(host) or not C.same(owner_script.ownership(host,record,str(proof.get("physical_id",""))),proof):return ERR_INVALID_DATA
		var is_mp: bool=int(record.source_item_class_id) in MP_IDS
		if overrides.size()!=3 or not overrides.get("inventory") is Dictionary or not overrides.get("item_use_cooldowns") is Dictionary:return ERR_INVALID_DATA
		if is_mp:
			if not overrides.get("mp") is int or overrides.mp!=mini(host._effective_max_mp(),host.mp+1000):return ERR_INVALID_DATA
		else:
			if not overrides.get("active_item_buffs") is Dictionary:return ERR_INVALID_DATA
		var expected: Dictionary=inventory.duplicate(true);expected[str(record.name)]=int(expected[str(record.name)])-1
		if int(expected[str(record.name)])==0:expected.erase(str(record.name))
		if overrides.inventory!=expected:return ERR_INVALID_DATA
		var state: Dictionary=host.consumable_service.export_state()
		var ledger: Variant=state.get("source_reusable_item_uses",{})
		if not ledger is Dictionary:return ERR_INVALID_DATA
		ledger=ledger.duplicate(true)
		var old: Variant=ledger.get(proof.key,{})
		if not old is Dictionary:return ERR_INVALID_DATA
		var count: int=0
		if not old.is_empty():
			if old.get("schema")!=1 or old.get("quantity_consumed")!=0 or not C.same(old.get("proof"),proof) or old.get("item_pack_sha256")!=PIN:return ERR_INVALID_DATA
			count=OWN.positive(old.get("uses"))
			if count<1 or count>=9007199254740991:return ERR_INVALID_DATA
		var next_record: Dictionary=old.duplicate(true)
		next_record.merge({"schema":1,"proof":proof.duplicate(true),"item_pack_sha256":PIN,"uses":count+1,"quantity_consumed":0},true)
		ledger[proof.key]=next_record
		state["source_reusable_item_uses"]=ledger
		var payload: Dictionary={"inventory":host.inventory.duplicate(true),"item_instances":host.item_instances.duplicate(true),"quest_state":host.quest_service.export_state(),"consumable_state":state,"item_use_cooldowns":overrides.item_use_cooldowns.duplicate(true)}
		if is_mp:
			payload["mp"]=overrides.mp
			payload.item_use_cooldowns[owner_script.interval_key(record)]=1800.0
		else:payload["active_item_buffs"]=overrides.active_item_buffs.duplicate(true)
		var path: String=host.save_path();var prior: String=FileAccess.get_sha256(path)
		var error: Error=host._save_game(true,payload)
		if error!=OK:
			if host.get("patch523_owner_state_problem") is String and not host.patch523_owner_state_problem.is_empty():host.quest_service.save_blocked=true;uncertain=true;return error
			var parser:=JSON.new();var parse_error: Error=parser.parse(FileAccess.get_file_as_string(path))
			var durable: Variant=parser.data if parse_error==OK else null
			var normalized: Dictionary=JSON.parse_string(JSON.stringify(payload,"",true,true));var confirmed: bool=durable is Dictionary
			if confirmed:
				for key: String in normalized:
					if durable.get(key)!=normalized[key]:confirmed=false;break
			if not confirmed:
				if FileAccess.get_sha256(path)!=prior:host.quest_service.save_blocked=true;uncertain=true
				return error
			if not host.equipment_collections.accept_load(durable):host.quest_service.save_blocked=true;uncertain=true;return error
		if payload.has("active_item_buffs"):host.active_item_buffs=payload.active_item_buffs
		if payload.has("mp"):host.mp=int(payload.mp)
		host.item_use_cooldowns=payload.item_use_cooldowns;host.consumable_service.import_state(state)
		host.deferred_save.cancel();committed=true
		return OK
static func perform(world: Node,record: Dictionary,physical_id: String="")->Dictionary:
	var result: Dictionary={"handled":true,"saved":false,"consumed":0,"uncertain":false}
	var canonical: Dictionary=EXTRA.action(world,profile(record))
	var proof: Dictionary=ownership(world,canonical,physical_id)
	var use: GDScript=load("res://scripts/loot/patch523_item_use.gd")
	if canonical.is_empty() or NATIVE_FIELDS.full(canonical).get("source_use_spec",{}).get("activation_status")!="unrestricted" or proof.is_empty() or not use.eligibility(world,canonical).is_empty() or not world._patch523_item_allowed() or world._option_awakening_busy() or (world.hud.has_method("is_card_reveal_busy") and world.hud.is_card_reveal_busy()):world.hud.show_message("원본 무한 아이템 소유·조건 확인 필요 · 보존");return result
	var spec: Dictionary=NATIVE_FIELDS.full(canonical).source_use_spec;var requirements: Dictionary=spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or requirements.get("service_region_code")!="" or (not requirements.get("can_use_when_invisible",false) and world.is_player_concealed()):return result
	if float(world.item_use_cooldowns.get("m523:item:"+str(int(canonical.source_item_class_id)),0))>0:world.hud.show_message("원본 아이템 재사용 대기");return result
	if int(canonical.source_item_class_id) in MP_IDS:
		# The table provides1800 seconds. Per-ItemClass scope and the existing
		# active-play cooldown clock are labelled host policy, not server proof.
		if world.ui_preferences.get("quest523_source_class_usage_interval_policy","per_item_class_active_play_seconds")!="per_item_class_active_play_seconds":world.hud.show_message("원본 재사용 범위 정책 미확인 · 무한 회복제 보존");return result
		if float(world.item_use_cooldowns.get(interval_key(canonical),0.0))>0:world.hud.show_message("원본 ClassUsageInterval 재사용 대기");return result
	var view:=View.new();view.host=world;view.record=canonical;view.proof=proof;view.base_stamp=stamp(world)
	view.inventory=world.inventory.duplicate(true)
	# Private counterfactual debit for the unchanged buff consumer. It is never
	# adopted as ownership or written; the real held/native inventory is retained.
	view.inventory[str(canonical.name)]=maxi(1,int(view.inventory.get(str(canonical.name),0)))
	view.active_item_buffs=world.active_item_buffs.duplicate(true);view.item_use_cooldowns=world.item_use_cooldowns.duplicate(true);view.hp=world.hp;view.mp=world.mp
	if int(canonical.source_item_class_id) in MP_IDS:use._mp_potion(view,canonical,spec)
	else:use._flat_buff(view,canonical,spec)
	result.saved=view.committed;result.uncertain=view.uncertain
	if view.committed and int(canonical.source_item_class_id) in EXTRA.FOOD:world.hud.show_message("원본 요리 HP2·MP3 · TWILIGHT 회복 주기 %s초 · 원본 주기 미확인" % str(EXTRA.interval(world)))
	if view.committed and int(canonical.source_item_class_id) in MP_IDS:world.hud.show_message("원본 MP1000 · 재사용1800초 · TWILIGHT 아이템별 플레이시간 정책")
	view.free()
	return result
