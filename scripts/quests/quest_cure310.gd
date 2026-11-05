extends RefCounted
## Original310/Buff27 is an instant cure, not a duration-zero timed buff.
## Reuse the existing Player.clear_poison after one confirmed ownership save.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const C=preload("res://scripts/quests/quest_reward_consumption.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const KIND="twilight.quest523.instant-poison-cure.v1"
static func fail(reason: String)->Dictionary:return {"ok":false,"saved":false,"handled":true,"consumed":0,"reason":reason}
static func profile(saved: Dictionary)->Dictionary:
	if int(saved.get("source_item_class_id",0))!=310 or D.pack_identity().get("sha256")!=PIN:return {}
	var definition: Dictionary=D.definition_id("310");var record: Dictionary=D.expected_variant(definition.get("native_record",{}),saved)
	if record.is_empty() or not D.matches(record,saved) or record.get("source_test_item",true):return {}
	var spec: Dictionary=record.get("source_use_spec",{})
	if spec.get("kind")!="source_timed_buff" or spec.get("duration_seconds")!=0 or spec.get("consume_delay_ms")!=500 or spec.get("buff_class_id")!=27 or not spec.get("typed_effects",{}).is_empty() or not spec.get("source_buff_bonus",[]).is_empty():return {}
	if not C.same(spec.get("blocked_reasons"),["missing_or_ambiguous_positive_duration","no_supported_buff_effects","unsupported_buff_priority_or_spell_level_rule"]):return {}
	var source: Dictionary=spec.get("source_buff_class",{});var group: Dictionary=spec.get("source_buff_group",{})
	if source.get("ID")!=27 or source.get("BuffGroupID")!=3 or source.get("BuffGroupPriority")!=11 or source.get("IsAuto")!=false or group.get("ID")!=3 or group.get("IsAllowOverlap")!=false or group.get("IsAllowPriority")!=false or group.get("IsEraseBySpellLevel")!=false:return {}
	var expected: Dictionary={"ItemConsumeDelay":[500,"MilliSeconds"],"BuffClassID":[27,"BuffClassID"],"ItemConsumeEffectSpriteID":[192,"SpriteID"]};var seen: Dictionary={}
	for row: Dictionary in definition.get("item_bonus",[]):
		var name: String=str(row.bonus_type.Name)
		if not expected.has(name) or seen.has(name) or row.get("IsPossession")!=false or row.bonus.get("BonusApplicationTypeID")!=0 or row.bonus.get("BonusApplicationTargetID")!=0 or row.bonus.Value!=expected[name][0] or row.unit.Name!=expected[name][1]:return {}
		seen[name]=true
	if seen.size()!=3:return {}
	record=record.duplicate(true);spec=spec.duplicate(true);spec["activation_status"]="unrestricted";spec["kind"]="source_instant_poison_cure";spec["owner_scope"]="existing_Player.clear_poison_only; other status namespaces unchanged";record["source_use_spec"]=spec
	return record
static func poison(world: Node)->Dictionary:
	if not is_instance_valid(world.player) or not world.player.has_method("clear_poison") or not world.player.has_method("is_poisoned"):return {}
	var result: Dictionary={}
	for key: String in ["poison_remaining","poison_tick_interval","poison_tick_clock","poison_tick_damage"]:
		var value: Variant=world.player.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value<0:return {}
		result[key]=value
	return result
static func stamp(world: Node)->String:
	return JSON.stringify([OWN.stamp(world),poison(world),world.hp,world.mp,world.job_class,world.level,world.item_use_cooldowns,world.consumable_service.export_state(),world.ui_preferences.get("item_locks",{}),world.quest_service.save_blocked,world.rng.state]).sha256_text()
static func prepare(world: Node,saved: Dictionary,physical_id: String="")->Dictionary:
	var record: Dictionary=profile(saved)
	var use: GDScript=load("res://scripts/loot/patch523_item_use.gd")
	if record.is_empty() or world.quest_service.save_blocked or world.hp<=0 or not world._patch523_item_allowed() or world._option_awakening_busy():return fail("원본 해독제 정체·생존·행동·저장 확인 필요")
	if world.hud.has_method("is_card_reveal_busy") and world.hud.is_card_reveal_busy():return fail("현재 동작 종료 후 해독제 사용 가능")
	var problem: String=use.eligibility(world,record)
	if not problem.is_empty():return fail(problem)
	var requirements: Dictionary=record.source_use_spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or requirements.get("service_region_code")!="" or (not requirements.get("can_use_when_invisible",false) and world.is_player_concealed()):return fail("원본 사용 대상·서비스·은신 조건 확인 필요")
	var observed: Dictionary=poison(world)
	if observed.is_empty() or not world.player.is_poisoned():return fail("해제할 기존 플레이어 독 없음 · 해독제 보존 (TWILIGHT 보존 정책)")
	if float(world.item_use_cooldowns.get("m523:item:310",0))>0:return fail("원본 해독제 재사용 대기")
	if world._item_locked(str(record.name),"") or (not physical_id.is_empty() and world._item_locked(str(record.name),physical_id)):return fail("잠긴 해독제 보존")
	var step: Dictionary={};var payload: Dictionary={};var proof: Dictionary={}
	if physical_id.is_empty():
		var actual: Dictionary=world._find_catalog_item_record(str(record.name));var quantity: int=OWN.positive(world.inventory.get(str(record.name)))
		if quantity<1 or not D.matches(actual,record) or actual.get("source_m_native_item")!=true or actual.get("source_snapshot")!="patch523" or actual.get("source_item_class_id")!=310 or int(actual.get("source_bless_raw",0))!=int(record.source_bless_raw):return fail("정확한 원본 소유 해독제 없음")
		payload={"inventory":use.debit(world,str(record.name)),"item_instances":world.item_instances.duplicate(true)}
		proof={"kind":"native_catalog","key":"native:"+str(record.sourceId),"source_id":str(record.sourceId),"item_class_id":310,"bless":int(record.source_bless_raw)}
	else:
		var owned: Dictionary=OWN.proof(world,physical_id)
		if not owned.get("ok",false) or owned.source_use_immediately or owned.item_class_id!=310 or int(owned.bless_code_id)!=int(record.source_bless_raw) or owned.source_item!=D.definition_id("310").original_item:return fail("선택한 원본 해독제 영수증 불일치")
		step=C.stage(world,[{"physical_id":physical_id,"quantity":1,"expected_quantity":int(owned.quantity),"expected_remaining":int(owned.quantity)-1,"quest_reward_receipt":world.item_instances[physical_id].quest_reward_receipt.duplicate(true)}],PIN)
		if not step.get("ok",false):return step
		payload=step.overrides.duplicate(true);proof={"kind":"quest_owned","key":"quest:"+physical_id,"physical_id":physical_id,"item_class_id":310,"bless":int(owned.bless_code_id),"quest_reward_receipt":world.item_instances[physical_id].quest_reward_receipt.duplicate(true)}
	var state: Dictionary=world.consumable_service.export_state();var log: Variant=state.get("source_instant_cure_uses",{})
	if not log is Dictionary:return fail("기존 해독 사용 기록 형식 보존 · 확인 필요")
	log=log.duplicate(true);var previous: Variant=log.get(proof.key,{})
	if not previous is Dictionary:return fail("기존 해독 소유 증명 보존 · 확인 필요")
	var count: int=0
	if not previous.is_empty():
		if previous.get("schema")!=1 or previous.get("item_pack_sha256")!=PIN or not C.same(previous.get("proof"),proof):return fail("기존 해독 사용 증명 불일치")
		count=OWN.positive(previous.get("units_consumed"))
		if count<1 or count>=9007199254740991:return fail("기존 해독 사용 수량 확인 필요")
	var next: Dictionary=previous.duplicate(true);next.merge({"schema":1,"proof":proof,"item_pack_sha256":PIN,"units_consumed":count+1,"source_buff_class_id":27,"effect_owner":"Player.clear_poison","transient_status_policy":"existing_load_clears_player_statuses"},true);log[proof.key]=next;state["source_instant_cure_uses"]=log
	payload["consumable_state"]=state;payload["item_use_cooldowns"]=world.item_use_cooldowns.duplicate(true);payload.item_use_cooldowns["m523:item:310"]=0.5;payload.item_use_cooldowns[str(record.name)]=0.5
	return {"ok":true,"kind":KIND,"base_stamp":stamp(world),"physical_id":physical_id,"record":record,"poison_before":observed,"source_step":step,"payload":payload,"use_authorized":false}
static func commit(world: Node,quote: Dictionary)->Dictionary:
	if quote.get("kind")!=KIND or quote.get("base_stamp")!=stamp(world):return fail("해독 대상·소유 선택 변경 · 보존")
	var fresh: Dictionary=prepare(world,quote.get("record",{}),str(quote.get("physical_id","")))
	if not fresh.get("ok",false) or not C.same(fresh,quote):return fail("현재 해독 사용 후보 불일치")
	if not quote.source_step.is_empty() and not C.matches_payload(world,quote.source_step,quote.payload):return fail("선택 해독제의 최종 소유 후보 불일치")
	var payload: Dictionary=quote.payload;var path: String=world.save_path();var prior: String=FileAccess.get_sha256(path);var error: Error=world._save_game(true,payload)
	if error!=OK:
		if world.get("patch523_owner_state_problem") is String and not world.patch523_owner_state_problem.is_empty():
			world.quest_service.save_blocked=true
			var blocked: Dictionary=fail("공동 저장 결과 미확정 · 해독 재사용 중지");blocked["uncertain"]=true;return blocked
		var parser:=JSON.new();var parse_error: Error=parser.parse(FileAccess.get_file_as_string(path));var durable: Variant=parser.data if parse_error==OK else null
		var expected: Dictionary=JSON.parse_string(JSON.stringify(payload,"",true,true));var confirmed: bool=durable is Dictionary
		if confirmed:
			for key: String in expected:
				if durable.get(key)!=expected[key]:confirmed=false;break
		if not confirmed:
			var uncertain: bool=FileAccess.get_sha256(path)!=prior
			if uncertain:world.quest_service.save_blocked=true
			var failure: Dictionary=fail("해독 저장 결과 미확정 · 재사용 중지" if uncertain else "해독 저장 실패 · 독·소유 수량 보존");failure["uncertain"]=uncertain;return failure
		if not world.equipment_collections.accept_load(durable):
			world.quest_service.save_blocked=true
			var failure: Dictionary=fail("해독 저장 복구 확인 필요");failure["uncertain"]=true;return failure
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.consumable_service.import_state(payload.consumable_state);world.item_use_cooldowns=payload.item_use_cooldowns
	if payload.has("quest_state"):world.quest_service.import_state(payload.quest_state)
	# Existing valid-load behavior clears these transient player statuses too.
	# No persisted source DOT/curse namespace is inferred or erased by name.
	world.player.clear_poison();world.deferred_save.cancel();world.quest_auto.refresh_context(world);world.hud.refresh_inventory(world.inventory);world._update_hud()
	return {"ok":true,"saved":true,"handled":true,"consumed":1,"physical_id":str(quote.physical_id),"source_item_class_id":310,"source_buff_class_id":27,"cleared_owner":"Player.clear_poison","message":"원본 해독제 · 기존 플레이어 독 해제"}
static func perform(world: Node,record: Dictionary,physical_id: String="")->Dictionary:
	var quote: Dictionary=prepare(world,record,physical_id);var result: Dictionary=commit(world,quote) if quote.get("ok",false) else quote
	world.hud.show_message(str(result.get("message",result.get("reason","해독 결과 확인 필요"))))
	if result.get("saved",false) and is_instance_valid(world.option_awakening):world.option_awakening.combat.emit_sprite(192,world.player)
	return result
