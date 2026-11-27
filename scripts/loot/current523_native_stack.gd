extends RefCounted
const CATALOG_STACK = preload("res://scripts/loot/current523_catalog_stack.gd")
const RETIRED_ITEMS = preload("res://scripts/loot/retired_enhancement_items523.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const CATALYST=preload("res://scripts/loot/native_growth_catalyst523.gd")
const MANUAL_SCROLLS=preload("res://scripts/loot/native_manual_scrolls523.gd")
const FUSION_POINTS=preload("res://scripts/cards/source_fusion_points523.gd")
## Existing HP/MP effects with exact current-source physical quantity ownership.
## No name-only conversion, reference effect activation, or live trial grant.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const SERVER=preload("res://scripts/loot/current523_server_profile.gd")
const RESTORATION=preload("res://scripts/shop/source523_restoration.gd")
const QUEST_OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const QUEST_CONSUME=preload("res://scripts/quests/quest_reward_consumption.gd")
const QUANTITY="source_native_stack_quantity"
const RECEIPT="source_native_stack_receipt"
const USES="source_native_stack_uses"
const PARTITIONS="source_native_stack_partitions"
const BAG_USES="source_native_bag_uses" ## retired journal (dropped on load)
const AMMO_EQUIPPED="source_native_ammo_equipped"
const AMMO_USES="source_native_ammo_uses" ## retired journal
const AMMO_RNG="source_native_ammo_rng"
const SKILL_MATERIAL_USES="source_native_skill_material_uses" ## retired journal
const TRANSFERRED="source_native_stack_transferred_quantity"
## Bag stacking journal (native_stack_merge.gd): absorbed stacks' receipts.
const MERGES="source_native_stack_merges"
const MERGE=preload("res://scripts/loot/native_stack_merge.gd")
const EFFECTS=preload("res://scripts/loot/source523_item_effects.gd")
const TRIM=preload("res://scripts/loot/save_provenance_trim.gd")
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
static var busy: bool=false
static var _candidate: Dictionary={}
static var _candidate_kind: String=""
static var _floor_record: Dictionary={}
static var _floor_commit_confirmed: bool=false
static var _partition_parent: String=""

class SupplierView extends Node:
	var host: Node
	var inventory: Dictionary
	var item_instances: Dictionary
	var gold: int
	func _catalog_item_from_source_id(id: String) -> Dictionary:return host._catalog_item_from_source_id(id)
	func source_symbol_reward_record(item_id: int, registered: Dictionary, authored: Dictionary) -> Dictionary:
		return host.source_symbol_reward_record(item_id, registered, authored) if host.has_method("source_symbol_reward_record") else {}


static func authorizes(payload: Dictionary) -> bool:
	return busy and not _candidate.is_empty() and _candidate==payload

## Saves a name-keyed (plain) consumer payload under this owner's seal, so
## the shared writer accepts its growth field (source523_item_effects EXP).
static func sealed_save(world: Node,payload: Dictionary) -> Error:
	if busy:return ERR_BUSY
	busy=true;_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();busy=false
	return saved

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=0 and value<=9007199254740991.0
## Table and save JSON numbers are floats; `in` is type-strict, so an integral
## one is compared as the int it is. Other values are returned unchanged.
static func whole(value: Variant) -> Variant:
	return int(value) if typeof(value)==TYPE_FLOAT and is_finite(value) and value==floorf(value) and absf(value)<=9007199254740991.0 else value

static func profile(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity():return {}
	var definition: Dictionary=D.item_definition(record)
	if definition.is_empty() or definition.get("original_item",{}).get("TestItem")!=false or not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var ammo: Dictionary=load("res://scripts/loot/patch523_ammo.gd").call("current_profile",record)
	if not ammo.is_empty():return {"kind":"ammo","spec":ammo}
	if NATIVE_FIELDS.field(record,"source_category_name")=="Solvent":
		var solvent: Dictionary=load("res://scripts/refine523/bless_refine523_service.gd").call("solvent_use_profile",definition)
		if not solvent.is_empty():return {"kind":"solvent_refine","spec":solvent}
	# TWILIGHT 근사: a reusable TeleportAmulet is projected as a material.
	if record.get("slot")=="material" and EFFECTS.AMULET_REUSABLE and str(EFFECTS.claims(record))=="teleport_location":return {"kind":"teleport_location"}
	if record.get("slot")!="consumable":return {}
	if MANUAL_SCROLLS.RULES.has(int(record.get("source_item_class_id",0))):
		var scroll:Dictionary=MANUAL_SCROLLS.profile(record,definition)
		if not scroll.is_empty():return {"kind":"buff","spec":scroll}
	if FUSION_POINTS.SCROLLS.has(int(record.get("source_item_class_id",0))):
		var points:Dictionary=FUSION_POINTS.profile(record,definition)
		if not points.is_empty():return {"kind":"fusion_points","spec":points}
	if bonus_point_rule(record,definition):return {"kind":"bonus_stat_point","spec":{"can_use_when_invisible":true}}
	var exact_exp: Dictionary=experience_rule(record,definition)
	if not exact_exp.is_empty():return {"kind":"exact_experience","spec":exact_exp}
	var firework:Dictionary=direct_firework_rule(record,definition)
	if not firework.is_empty():return {"kind":"exact_firework","spec":firework}
	if elixir_rule(record,definition):return {"kind":"elixir","spec":{"can_use_when_invisible":true}}
	if half_elixir_charge_rule(record,definition):return {"kind":"half_elixir_charge","spec":{"can_use_when_invisible":true}}
	if half_elixir_reset_rule(record,definition):return {"kind":"half_elixir_reset","spec":{"can_use_when_invisible":true}}
	if record.get("source_item_class_id")==310:
		var cure: Dictionary=load("res://scripts/quests/quest_cure310.gd").call("profile",record)
		if not cure.is_empty():return {"kind":"cure","spec":NATIVE_FIELDS.full(cure).source_use_spec}
	if not record.get("heal_spec",{}).is_empty():
		var metadata: Dictionary=D.hp_use_metadata(record)
		if record.get("source_item_class_id")==233:metadata=load("res://scripts/loot/quest_hp233_use.gd").call("metadata",record)
		elif whole(record.get("source_item_class_id")) in [237,236]:metadata=restoration_metadata(record)
		if metadata.get("ok",false):return {"kind":"hp","metadata":metadata}
	var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
	if spec.get("kind") == "source_event_box" and spec.get("activation_status") == "unrestricted": return {"kind":"bag","spec":spec}
	if spec.get("kind")=="source_skill_book" and (spec.get("activation_status")=="unrestricted" or presentation_only(record,spec)):return {"kind":"skill_book","spec":spec,"runtime_presentation":spec.get("activation_status")!="unrestricted"}
	if spec.get("kind")=="source_mp_dice" and spec.get("activation_status")=="unrestricted":return {"kind":"mp","spec":spec}
	if spec.get("kind")=="fixed_card" and spec.get("activation_status")=="unrestricted":return {"kind":"card","spec":spec}
	if spec.get("kind")=="equipment_bless" and spec.get("activation_status")=="unrestricted":return {"kind":"bless","spec":spec}
	if spec.get("kind")=="weapon_mastery_points" and spec.get("activation_status")=="unrestricted":return {"kind":"mastery","spec":spec}
	if spec.get("kind")=="source_bless_points" and spec.get("activation_status")=="unrestricted":return {"kind":"bless_points","spec":spec}
	if spec.get("kind")=="source_time_recharge" and spec.get("activation_status")=="unrestricted":return {"kind":"time_recharge","spec":spec}
	if spec.get("kind")=="source_timed_buff" and spec.get("activation_status")=="unrestricted" and not spec.get("typed_effects",{}).is_empty():return {"kind":"buff","spec":spec}
	if spec.get("kind") in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"] and (spec.get("activation_status")=="unrestricted" or presentation_only(record,spec)):return {"kind":"bag","spec":spec,"runtime_presentation":spec.get("activation_status")!="unrestricted"}
	if spec.get("kind") in ["source_selectable_reward","source_selectable_bag"] and (spec.get("activation_status")=="unrestricted" or presentation_only(record,spec)):return {"kind":"selection","spec":spec,"runtime_presentation":spec.get("activation_status")!="unrestricted"}
	if spec.get("kind")=="source_timed_buff" and presentation_only(record,spec):return {"kind":"buff","spec":spec,"runtime_presentation":true}
	var regen: Script=load("res://scripts/quests/quest_regen523.gd")
	if not regen.call("contract",record).is_empty():return {"kind":"buff","runtime_regen":true}
	var original_buff: Script=load("res://scripts/quests/quest_source_buffs523.gd")
	var expanded: Dictionary=original_buff.call("profile",record)
	if NATIVE_FIELDS.full(expanded).get("source_use_spec",{}).get("activation_status")=="unrestricted":return {"kind":"buff","spec":NATIVE_FIELDS.full(expanded).source_use_spec}
	# Original teleport scroll / Ainhasad charge / RegenHP-RegenMP food.
	var source_effect: String=str(EFFECTS.claims(record))
	if source_effect=="food":return {"kind":"buff","runtime_food":true}
	if source_effect in ["teleport","ain","teleport_location"]:return {"kind":source_effect}
	return {}

## Original 146402 grants one unallocated bonus stat, not an ordinary elixir.
## Never infer this consumer by display name or apply it to the two cap items.
static func bonus_point_rule(record:Dictionary,definition:Dictionary)->bool:
	if whole(record.get("source_item_class_id"))!=146402 or NATIVE_FIELDS.field(record,"source_category_name")!="BonusStatRecharger":return false
	var raw:Dictionary=definition.get("original_item",{})
	var rows:Array=definition.get("item_bonus",[])
	if whole(raw.get("ID"))!=146402 or raw.get("TestItem")!=false or whole(raw.get("LevelLimitMin"))!=89 or whole(raw.get("LevelLimitMax"))!=0 or whole(raw.get("TargettingTypeID"))!=1 or raw.get("ServiceRegionCode")!="" or raw.get("CanUseWhenInvisible")!=true or rows.size()!=1:return false
	var r:Dictionary=rows[0];var b:Dictionary=r.get("bonus",{})
	return whole(r.get("ID"))==228432 and r.get("IsPossession")==false and whole(b.get("ID"))==726502 and r.get("bonus_type",{}).get("Name")=="BonusSubStatAmount" and r.get("unit",{}).get("Name")=="Value" and whole(b.get("Value"))==1 and whole(b.get("BonusApplicationTypeID"))==0 and whole(b.get("BonusApplicationTargetID"))==0

static func use_bonus_point(world:Node,uid:String,owned:Dictionary)->Dictionary:
	if busy or world.level<89 or not integer(world.stat_points) or int(world.stat_points)>=9007199254740991:return _failure("보너스 스탯 조건 미충족 · 아이템 보존")
	var live:Dictionary=proof(world,uid)
	if live.is_empty() or live!=owned or not bonus_point_rule(live.record,D.definition_id("146402")):return _failure("깨달은자의 눈 원본 개체 확인 실패 · 아이템 보존")
	var paid:Dictionary=stage_debit(world,[{"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt}])
	if not paid.get("ok",false):return _failure("깨달은자의 눈 수량 확인 실패 · 아이템 보존")
	var payload:Dictionary=paid.overrides
	payload["stat_points"]=int(world.stat_points)+1
	# This narrow seal is never acquired by generic consumables or an arbitrary save.
	busy=true;_candidate_kind="original_146402_point";_candidate=payload.duplicate(true)
	var saved:Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:return _failure("보너스 스탯 저장 실패 · 포인트와 아이템 보존")
	world.inventory=payload.inventory;world.item_instances=payload.item_instances
	world.consumable_service.import_state(payload.consumable_state)
	world.stat_points=payload.stat_points;world.deferred_save.cancel()
	return {"ok":true,"handled":true,"saved":true,"consumed":1,"message":"보너스 스탯 +1 · 캐릭터 능력치에서 분배하세요"}

## Take the selected physical scroll only after the entire original reward
## lane (including all nonzero candidates) is playable for this installation.
static func use_fusion_points(world:Node,uid:String,owned:Dictionary,spec:Dictionary)->Dictionary:
	var live:Dictionary=proof(world,uid)
	if live.is_empty() or live!=owned or world._item_locked(str(live.record.get("name","")),uid):return _failure("원본 합성 포인트 주문서의 선택 개체를 확인하지 못했습니다 · 아이템 보존")
	var category:String=str(spec.get("category",""));var grade:String=str(spec.get("grade",""))
	var cards:RefCounted=world.card_draw_fusion
	if int(cards.pity.get(category,{}).get(grade,0))>=FUSION_POINTS.LIMIT:return _failure("합성 시도 보상을 먼저 받으세요 · 주문서 보존")
	if not FUSION_POINTS.reward(world,category,grade).get("ok",false):return _failure("원본 합성 포인트 보상 자료 확인 필요 · 주문서 보존")
	var paid:Dictionary=stage_debit(world,[{"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt}])
	if not paid.get("ok",false):return _failure("원본 합성 포인트 주문서 수량 확인 실패 · 아이템 보존")
	var before:Dictionary=cards.export_state()
	if not cards.credit_original_points(category,grade):return _failure("합성 포인트가 가득 찼습니다 · 주문서 보존")
	var payload:Dictionary=paid.overrides
	payload["card_draw_fusion"]=cards.export_state()
	cards.import_state(before)
	if sealed_save(world,payload)!=OK:return _failure("합성 포인트 저장 실패 · 포인트와 주문서 보존")
	world.inventory=payload.inventory;world.item_instances=payload.item_instances
	world.consumable_service.import_state(payload.consumable_state)
	cards.import_state(payload.card_draw_fusion);world.deferred_save.cancel()
	var count:int=cards.pity[category][grade]
	return {"ok":true,"handled":true,"saved":true,"consumed":1,"message":"%s %s 합성 포인트 +1 · %d/%d" % [category,grade,count,FUSION_POINTS.LIMIT]}

static func authorizes_bonus_point(world:Node,staged:Dictionary)->bool:
	return _candidate_kind=="original_146402_point" and staged.size()==4 and staged.has("inventory") and staged.has("item_instances") and staged.has("consumable_state") and integer(world.stat_points) and staged.get("stat_points")==int(world.stat_points)+1 and authorizes(staged)

## The four permanent server-keeper items, not their same-color dated SKUs.
## Reward is solely the exact authored above-player effect; no hidden buff.
const DIRECT_FIREWORKS:Dictionary={
	127971:[184341,585101,17447], 127981:[184361,585121,17446],
	127991:[184381,585141,17458], 128001:[184401,585161,17459]
}

## Dated fireworks have a separate DeleteTime relation (direct or Korean
## DateTimes ID). They use the game's existing date policy and the same
## atomic original effect transaction as the permanent fireworks.
const DATED_FIREWORKS: Array[int] = [
	126533,126543,126553,126563,126573,126583,126593,126603,126613,126623,
	127133,127143,127153,127163,127173,127183,127193,127203,127213,127223,
	127233,127243,127253,168564,222753,271828,271848,
]

static func direct_firework_rule(record: Dictionary, definition: Dictionary) -> Dictionary:
	var id: int = int(record.get("source_item_class_id",0))
	var dated: bool = id in DATED_FIREWORKS
	if not dated and not DIRECT_FIREWORKS.has(id): return {}
	if NATIVE_FIELDS.field(record,"source_category_name") != "Potion": return {}
	var raw: Dictionary = definition.get("original_item",{})
	var rows: Array = definition.get("item_bonus",[])
	if whole(raw.get("ID")) != id or raw.get("TestItem") != false or whole(raw.get("CategoryID")) != 3 or whole(raw.get("TargettingTypeID")) != 1 or raw.get("ServiceRegionCode") != "": return {}
	if not dated and (whole(raw.get("LevelLimitMin")) != 0 or whole(raw.get("LevelLimitMax")) != 0 or raw.get("CanUseWhenInvisible") != true): return {}
	if rows.size() != (2 if dated else 1): return {}
	var sprite: int = 0
	var deadline: int = 0
	for row: Dictionary in rows:
		if row.get("bonus_type",{}).get("Name") == "DeleteTime":
			deadline = preload("res://scripts/loot/current523_native_item_projection.gd").delete_time_stamp(row)
			continue
		var bonus: Dictionary = row.get("bonus",{})
		if sprite != 0 or row.get("IsPossession") != false or row.get("bonus_type",{}).get("Name") != "ItemConsumeEffectSpriteID" or row.get("unit",{}).get("Name") != "SpriteID" or bonus.get("BonusApplicationTypeID") != 0 or bonus.get("BonusApplicationTargetID") != 0 or not integer(bonus.get("Value")): return {}
		sprite = int(bonus.Value)
		if not dated and [whole(row.get("ID")),whole(bonus.get("ID")),sprite] != DIRECT_FIREWORKS[id]: return {}
	if sprite <= 0 or (dated and (deadline <= 0 or deadline != NATIVE_FIELDS.field(record,"source_delete_time_raw",-1))): return {}
	return {"sprite_id":sprite,"can_use_when_invisible":raw.get("CanUseWhenInvisible",false)}

static func use_exact_firework(world:Node,uid:String,owned:Dictionary)->Dictionary:
	if busy:return _failure("다른 아이템을 처리 중입니다 · 폭죽 보존")
	var live:Dictionary=proof(world,uid)
	if live.is_empty() or live!=owned:return _failure("원본 폭죽 실물 확인 실패 · 아이템 보존")
	var definition:Dictionary=D.item_definition(live.record)
	var rule:Dictionary=direct_firework_rule(live.record,definition)
	if rule.is_empty():return _failure("원본 폭죽 규칙 확인 필요 · 아이템 보존")
	var preview:Node2D=world.player.original_source_preview
	if not is_instance_valid(preview) or not preview.is_inside_tree():return _failure("원본 폭죽 연출을 불러올 수 없습니다 · 아이템 보존")
	var paid:Dictionary=stage_debit(world,[{"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt}])
	if not paid.get("ok",false):return _failure("폭죽 수량 확인 실패 · 아이템 보존")
	# Nothing is attached or visible until the existing writer commits. A
	# missing/corrupt bank or a save failure neither consumes nor displays.
	var overlay:Node2D=preview.prepare_current_source_item_consume(definition.original_item,int(rule.sprite_id),5)
	if not is_instance_valid(overlay):return _failure("원본 폭죽 연출을 불러올 수 없습니다 · 아이템 보존")
	var payload:Dictionary=paid.overrides
	if sealed_save(world,payload)!=OK:
		overlay.free()
		return _failure("폭죽 저장 실패 · 아이템 보존")
	world.inventory=payload.inventory;world.item_instances=payload.item_instances
	world.consumable_service.import_state(payload.consumable_state);world.deferred_save.cancel()
	preview.publish_prepared_item_consume(overlay,world.player.global_position)
	return {"ok":true,"handled":true,"saved":true,"consumed":1,"message":str(live.record.name)+" 사용"}

## ItemClass -> [min level, raw EXP, exact ItemBonus ID, exact Bonus ID].
## Each original Korean description agrees with the numeric value and min level.
## The rank-four fruit (170214) declares 500000 and says 1000000: not bound.
const DIRECT_EXP_REWARDS: Dictionary={
	170184:[40,2000000,283204,969234], 170194:[40,1500000,283214,969244],
	170204:[40,1000000,283224,969254], 181273:[45,2000000,315283,1046803],
	234598:[40,4000000,449418,1413528], 234608:[40,3000000,449428,1413538],
	234618:[40,2000000,449438,1413548], 328188:[40,4000000,695268,2027458],
	328198:[40,3000000,695278,2027468], 328208:[40,2000000,695288,2027478],
	216103:[70,356454638,403663,1252173]
}

static func direct_experience_rule(record:Dictionary,definition:Dictionary)->Dictionary:
	var id: int=int(record.get("source_item_class_id",0))
	if not DIRECT_EXP_REWARDS.has(id) or NATIVE_FIELDS.field(record,"source_category_name")!="Potion":return {}
	var expected:Array=DIRECT_EXP_REWARDS[id]
	var raw:Dictionary=definition.get("original_item",{})
	var rows:Array=definition.get("item_bonus",[])
	if whole(raw.get("ID"))!=id or raw.get("TestItem")!=false or whole(raw.get("CategoryID"))!=3 or whole(raw.get("LevelLimitMin"))!=expected[0] or whole(raw.get("LevelLimitMax"))!=0 or whole(raw.get("TargettingTypeID"))!=1 or raw.get("ServiceRegionCode")!="" or raw.get("CanUseWhenInvisible")!=true:return {}
	var expected_rows:Dictionary={expected[2]:[expected[3],"Experience","Value",expected[1]]}
	# The level-70 Arakne dose alone has these two extra direct-use rows.
	# Neither same-name expired dose has this exact ItemClass ID.
	if id==216103:
		expected_rows[403643]=[1252153,"ItemConsumeDelay","MilliSeconds",3]
		expected_rows[403653]=[1252163,"ItemConsumeEffectSpriteID","SpriteID",751]
	if rows.size()!=expected_rows.size():return {}
	for r:Dictionary in rows:
		var key:Variant=whole(r.get("ID"))
		if not expected_rows.has(key):return {}
		var tuple:Array=expected_rows[key]
		var bonus:Dictionary=r.get("bonus",{})
		if r.get("IsPossession")!=false or whole(bonus.get("ID"))!=tuple[0] or r.get("bonus_type",{}).get("Name")!=tuple[1] or r.get("unit",{}).get("Name")!=tuple[2] or whole(bonus.get("Value"))!=tuple[3] or whole(bonus.get("BonusApplicationTypeID"))!=0 or whole(bonus.get("BonusApplicationTargetID"))!=0:return {}
		expected_rows.erase(key)
	var text:String=str(SOURCE.row("DescData_Korean",int(raw.get("StoryDescID",0))).get("Description","")).replace(",","").replace(char(13),"").replace(char(10)," ")
	if not ("EXP %d을 획득" % int(expected[1])) in text or not ("%d레벨 부터 사용가능" % int(expected[0])) in text:return {}

	var rule:Dictionary={"source_exp":expected[1],"minimum_level":expected[0],"can_use_when_invisible":true}
	if id==216103:
		rule["consume_delay_ms"]=3
		rule["consume_effect_sprite_id"]=751
	return rule

static func experience_rule(record:Dictionary,definition:Dictionary)->Dictionary:
	if record.get("source_item_class_id")==CATALYST.ITEM_ID:return CATALYST.profile(record,definition)
	return direct_experience_rule(record,definition)

static func use_exact_experience(world:Node,uid:String,owned:Dictionary)->Dictionary:
	if busy or not integer(world.experience) or not integer(world.exp_need) or world.exp_need<=0:return _failure("경험치 저장 상태 확인 필요 · 아이템 보존")
	var live:Dictionary=proof(world,uid)
	if live.is_empty() or live!=owned:return _failure("경험치 아이템 실물 확인 실패 · 아이템 보존")
	var definition:Dictionary=D.item_definition(live.record)
	var rule:Dictionary=experience_rule(live.record,definition)
	if rule.is_empty() or world.level<int(rule.minimum_level):return _failure("원본 경험치 아이템 레벨 조건 불충족 · 아이템 보존")
	if float(world.item_use_cooldowns.get("m523:item:"+str(int(live.record.source_item_class_id)),0.0))>0:return _failure("원본 아이템 재사용 대기")
	var catalyst:bool=rule.get("growth_catalyst",false)
	if catalyst:
		if not CATALYST.before_issue_end(Time.get_unix_time_from_system(),int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540))):
			return _failure("원본 물약 사용 기한이 끝났습니다 · 아이템 보존")
		if world.active_item_buffs.has(CATALYST.ACTIVE_KEY):return _failure("이미 같은 효과가 적용 중이거나 보상 수령 대기 중입니다 · 아이템 보존")
		var problem:String=buff_rule_problem(world,rule)
		if not problem.is_empty():return _failure(problem)
	var gained:int=EFFECTS.twilight_experience(int(rule.source_exp))
	if gained<=0 or int(world.experience)>9007199254740991-gained:return _failure("경험치 결과 수치 범위 오류 · 아이템 보존")
	var before_level:int=world.level
	var staged_growth:Dictionary=world.monsterbook523_runtime.progression_overrides(gained)
	if staged_growth.is_empty():return _failure("경험치 증가가 확인되지 않았습니다 · 아이템 보존")
	var paid:Dictionary=stage_debit(world,[{"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt}])
	if not paid.get("ok",false):return _failure("경험치 아이템 수량 확인 실패 · 아이템 보존")
	var payload:Dictionary=paid.overrides
	payload.merge(staged_growth,true)
	if catalyst:
		var buffs:Dictionary=world.active_item_buffs.duplicate(true)
		var value:Dictionary=CATALYST.EFFECTS.duplicate()
		value.merge({"remaining":3600.0,"duration":3600.0,"source_buff_class":rule.source_buff_class,"source_buff_group":rule.source_buff_group,
			"source_item_class_id":CATALYST.ITEM_ID,"source_snapshot":"patch523",CATALYST.KEY:{"uid":uid,"receipt":owned.receipt.duplicate(true)}})
		buffs[CATALYST.ACTIVE_KEY]=value
		payload["active_item_buffs"]=buffs
	if rule.has("consume_delay_ms"):
		payload["item_use_cooldowns"]=load("res://scripts/loot/patch523_item_use.gd").call("next_cooldowns",world,live.record,rule)
	busy=true;_candidate_kind="original_exp_reward";_candidate=payload.duplicate(true)
	var saved:Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:return _failure("경험치 저장 실패 · 수량과 능력치 보존")
	world.inventory=payload.inventory;world.item_instances=payload.item_instances
	world.consumable_service.import_state(payload.consumable_state)
	if payload.has("item_use_cooldowns"):world.item_use_cooldowns=payload.item_use_cooldowns
	if catalyst:world.active_item_buffs=payload.active_item_buffs
	for key: String in staged_growth:
		world.set("attack_power" if key=="attack" else key,int(staged_growth[key]))
	world.deferred_save.cancel()
	if world.level>before_level:
		var reached:Array=range(before_level+1,int(world.level)+1)
		world._play_original_level_up(reached)
	if rule.has("consume_effect_sprite_id"):
		world.option_awakening.combat.emit_sprite(int(rule.consume_effect_sprite_id),world.player,definition.original_item)
	return {"ok":true,"handled":true,"saved":true,"consumed":1,"message":"경험치 +%d%s" % [gained, " · Lv.%d" % int(world.level) if world.level>before_level else ""]}

static func authorizes_experience_reward(staged:Dictionary)->bool:
	return _candidate_kind=="original_exp_reward" and authorizes(staged)

## Commit the exact finished buff and its separate physical crafting material
## in one snapshot. A failed grant or writer never clears the entitlement.
static func finish_growth_catalyst(world:Node,key:String)->bool:
	var buff:Dictionary=world.active_item_buffs.get(key,{})
	var proof_row:Variant=buff.get(CATALYST.KEY)
	if busy or not proof_row is Dictionary or float(buff.get("remaining",1.0))>0.0:return false
	var receipt:Variant=proof_row.get("receipt")
	if not receipt is Dictionary or receipt.get("item_class_id")!=CATALYST.ITEM_ID or not receipt_valid(receipt,str(proof_row.get("uid",""))):return false
	var record:Dictionary=D.definition_id(str(CATALYST.ITEM_ID)).get("native_record",{})
	if key!=CATALYST.ACTIVE_KEY or CATALYST.profile(record,D.item_definition(record)).is_empty() or not world._patch523_item_allowed():return false
	var reward:Dictionary=CATALYST.reward()
	if reward.is_empty():return false
	var given:Dictionary=load("res://scripts/loot/patch523_item_inventory.gd").call("stage",world,[reward],{"kind":"source_growth_catalyst523_expiry","input_physical_id":proof_row.uid,"buff_class_id":CATALYST.BUFF_ID})
	if not given.get("ok",false):return false
	var payload:Dictionary=given.overrides
	payload["active_item_buffs"]=world.active_item_buffs.duplicate(true)
	payload.active_item_buffs.erase(key)
	if sealed_save(world,payload)!=OK:return false
	world.inventory=payload.inventory;world.item_instances=payload.item_instances
	world.active_item_buffs=payload.active_item_buffs
	world.deferred_save.cancel()
	world.hud.refresh_inventory(world.inventory)
	world.hud.append_log("아우라키아 성장 버프 종료 · 명예 주화 15개")
	return true

## ItemClass 4151 grants one ordinary stat point. Keep the existing TWILIGHT
## chosen-stat UI and shared character/stat caps for both forms of elixir.
static func elixir_rule(record: Dictionary, definition: Dictionary) -> bool:
	if whole(record.get("source_item_class_id")) != 4151 or NATIVE_FIELDS.field(record,"source_category_name") != "BonusStatRecharger":
		return false
	var original: Dictionary = definition.get("original_item",{})
	if original.get("TestItem") != false or whole(original.get("LevelLimitMin")) != 50 or whole(original.get("TargettingTypeID")) != 1 or original.get("ServiceRegionCode") != "" or original.get("CanUseWhenInvisible") != true:
		return false
	var rows: Array = definition.get("item_bonus",[])
	if rows.size() != 1: return false
	var row: Dictionary = rows[0]
	var bonus: Dictionary = row.get("bonus",{})
	return (row.get("IsPossession") == false
		and row.get("bonus_type",{}).get("Name") == "BonusStatAmount"
		and row.get("unit",{}).get("Name") == "Value" and whole(bonus.get("Value")) == 1
		and whole(bonus.get("BonusApplicationTypeID")) == 0 and whole(bonus.get("BonusApplicationTargetID")) == 0)

## Original 523 self-use items 185094 and 199263 each charge one point
## into the existing half-elixir owner (not the ordinary elixir stat pool).
static func half_elixir_charge_rule(record: Dictionary, definition: Dictionary) -> bool:
	if whole(record.get("source_item_class_id")) not in [185094,199263] or NATIVE_FIELDS.field(record,"source_category_name") != "HalfElixirRecharger":
		return false
	var original: Dictionary = definition.get("original_item",{})
	if original.get("TestItem") != false or whole(original.get("LevelLimitMin")) != 50 or whole(original.get("TargettingTypeID")) != 1 or original.get("ServiceRegionCode") != "" or original.get("CanUseWhenInvisible") != true:
		return false
	var rows: Array = definition.get("item_bonus",[])
	if rows.size() != 1:return false
	var row: Dictionary = rows[0]
	var bonus: Dictionary = row.get("bonus",{})
	return (row.get("IsPossession") == false and row.get("bonus_type",{}).get("Name") == "HalfElixirPoint"
		and row.get("unit",{}).get("Name") == "Value" and whole(bonus.get("Value")) == 1
		and whole(bonus.get("BonusApplicationTypeID")) == 0 and whole(bonus.get("BonusApplicationTargetID")) == 0)

## Both original candles declare a stackable self-target initializer;
## their original story text describes resetting the ability allocation.
static func half_elixir_reset_rule(record: Dictionary, definition: Dictionary) -> bool:
	if whole(record.get("source_item_class_id")) not in [186024,190754] or whole(record.get("source_bless_raw"))!=1 or NATIVE_FIELDS.field(record,"source_category_name")!="HalfElixirInitializer":return false
	var raw: Dictionary=definition.get("original_item",{})
	var category: Dictionary=definition.get("category",{})
	return (whole(raw.get("ID"))==whole(record.get("source_item_class_id")) and raw.get("TestItem")==false
		and raw.get("ServiceRegionCode")=="" and whole(raw.get("TargettingTypeID"))==1
		and raw.get("CanUseWhenInvisible")==true and whole(raw.get("CategoryID"))==10454
		and whole(category.get("ID"))==10454 and category.get("Name")=="HalfElixirInitializer"
		and category.get("IsStackable")==true and category.get("IsConsumable")==true
		and definition.get("item_bonus",[]).is_empty() and not definition.get("excluded",false))

static func supply_profile(record: Dictionary) -> Dictionary:
	var effect: Dictionary=profile(record)
	if not effect.is_empty():return effect
	var material: Dictionary=spell_material_profile(record)
	if not material.is_empty():return material
	var ticket: Dictionary=draw_ticket_profile(record)
	if not ticket.is_empty():return ticket
	if record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity() or record.get("slot")!="material" or not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return storage_profile(record)
	var definition: Dictionary=D.item_definition(record)
	if definition.get("original_item",{}).get("TestItem")!=false or definition.get("excluded",false):return {}
	# This is a material-owner admission, not individual use/effect activation.
	# Actual recipe rows/choices/limits are still checked by the craft executor.
	if SOURCE.related("ItemCraftInput","ItemClassID",int(record.get("source_item_class_id",0))).is_empty():return storage_profile(record)
	return {"kind":"craft_material","standalone_effect_complete":false}

## Storage stacks (2026-11-13): an original non-equipment item the table fully
## defines (exact typed projection, TestItem false, not a dummy/test row, no
## pending condition or unresolved lifetime) is owned as a receipted physical
## stack even when its use has no table rule or no TWILIGHT owner yet. Using it
## refuses and keeps it; no use effect is invented. Existing wallets (아데나,
## 변신·마법인형·성물 제작 코인, 명예 코인) keep their own owner; their original
## reward rows add to those wallets (patch523_item_inventory.coin_wallet).
const STORAGE_SLOTS: Array[String]=["consumable","material","currency"]
const STORAGE_TEST_MARKERS: Array[String]=["테스트","test"]
## User decision 2026-11-13: rows the original marks unused are excluded like
## test rows ("[혈맹" rows stay storage stacks).
const STORAGE_UNUSED_MARKERS: Array[String]=["미사용","사용안함","사용 안함"]
static func storage_profile(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity():return {}
	if D.equipment(record) or str(record.get("slot","")) not in STORAGE_SLOTS or not D.currency_identity_name(record).is_empty():return {}
	if not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var definition: Dictionary=D.item_definition(record)
	var original: Variant=definition.get("original_item",{})
	if definition.is_empty() or not original is Dictionary or original.get("TestItem")!=false or definition.get("excluded",false):return {}
	if not storage_exclusion(original).is_empty():return {}
	var id: Variant=whole(record.get("source_item_class_id",0))
	if not id is int or id<=0 or whole(original.get("ID",0))!=id:return {}
	if id in preload("res://scripts/cards/native_awakening_supply.gd").IDS:return {}
	return {"kind":"storage","standalone_effect_complete":false,"use_owner":"","source_use_rule":"none"}

## Why a non-test original row is still kept out of storage stacks: an
## original dummy declaration, a test marker in its own Name ("[테스트]",
## "테스트용", "test용") or an unused marker ("미사용", "사용안함"). Empty when
## none applies.
static func storage_exclusion(original: Dictionary) -> String:
	if not preload("res://scripts/quests/source_dummy523.gd").item_evidence(original).is_empty():return "source_dummy_declaration"
	var name_value: String=str(original.get("Name","")).to_lower()
	for marker: String in STORAGE_TEST_MARKERS:
		if name_value.contains(marker):return "source_test_name_marker"
	for marker: String in STORAGE_UNUSED_MARKERS:
		if name_value.contains(marker):return "source_unused_name_marker"
	return ""

## Original draw tickets (ItemCategory LinMarketProduct) are owned as physical
## stacks like materials. Redemption belongs to the owned-ticket service
## (source523_inventory_tickets.gd), which checks the ticket's products and
## pools; an unsupported ticket is explained there and stays owned.
static func draw_ticket_profile(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity() or NATIVE_FIELDS.field(record,"source_category_name")!="LinMarketProduct" or record.get("slot")!="consumable" or not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var definition: Dictionary=D.item_definition(record)
	if definition.get("original_item",{}).get("TestItem")!=false or definition.get("excluded",false):return {}
	return {"kind":"draw_ticket","standalone_effect_complete":false,"use_owner":"source523_inventory_tickets"}

## shallow: the caller only adds this entry and never edits existing ones in
## place (floor pickup); existing entries stay shared with the live bag.
static func stage_grant(record: Dictionary,quantity: int,instances: Dictionary,origin: Dictionary,shallow: bool=false) -> Dictionary:
	if RETIRED_ITEMS.record(record):return {"ok":false,"error":RETIRED_ITEMS.REASON}
	if quantity<1 or not integer(quantity) or origin.is_empty() or supply_profile(record).is_empty():return {"ok":false,"error":"현재 원문 물리 공급 계약 미지원"}
	return _stage_proven_grant(record,quantity,instances,origin,shallow)

## One profile lookup determines both whether the floor item belongs to this
## owner and whether a receipt may be issued. A claimed invalid grant is a
## failure, not permission to fall back to the plain inventory.
static func stage_floor_grant(record: Dictionary,quantity: int,instances: Dictionary) -> Dictionary:
	if RETIRED_ITEMS.record(record):return {"handled":true,"ok":false,"error":RETIRED_ITEMS.REASON}
	if supply_profile(record).is_empty():return {"handled":false}
	if quantity<1 or not integer(quantity):return {"handled":true,"ok":false,"error":"현재 원문 물리 공급 계약 미지원"}
	var result: Dictionary=_stage_proven_grant(record,quantity,instances,{"kind":"source523_floor"},true)
	result["handled"]=true
	return result

static func _stage_proven_grant(record: Dictionary,quantity: int,instances: Dictionary,origin: Dictionary,shallow: bool) -> Dictionary:
	var uid: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while instances.has(uid):uid=Crypto.new().generate_random_bytes(16).hex_encode()
	# The original ItemClass row, definition identity and acquisition detail
	# are not copied into the receipt (save_provenance_trim.gd): full(receipt)
	# reads the row from the installed definition by ItemClass ID.
	if not integer(record.get("source_item_class_id")) or int(record.source_item_class_id)<1:return {"ok":false,"error":"현재 원문 물리 공급 계약 미지원"}
	var receipt: Dictionary=TRIM.receipt({"schema":1,"issued_physical_id":uid,"item_class_id":record.source_item_class_id,"bless_raw":record.source_bless_raw,"granted_quantity":quantity,NATIVE_FIELDS.MARK:true,"source_item_class_id":int(record.source_item_class_id),"origin":origin.duplicate(true)})
	var result: Dictionary=instances.duplicate(not shallow)
	result[uid]={"name":str(record.name),"record":TRIM.record(NATIVE_FIELDS.full(record).duplicate(true)),"level":0,QUANTITY:quantity,RECEIPT:receipt,"source_native_stack_used_quantity":0}
	return {"ok":true,"item_instances":result,"id":uid}

## These pinned source IDs declare enhancement and MaxStackAmount=1
## but no wearable slot. Leave storage level and equipment rules unchanged.
const TOKEN_RANK="source_native_event_enhance_rank"
const TOKEN_IDS=[176372, 176382, 176392, 183132, 183142, 187893, 187903, 187913, 187923, 187933, 187943, 187953, 187963, 187973, 187983, 187993, 188003, 188013, 188023, 188033, 191443, 199421, 199431, 199441, 207584, 207594, 207604, 217468, 217478, 217488, 234774, 234784, 234794, 234824, 241853, 241863, 241873, 266978, 266988, 266998, 277123, 277133, 277143, 322152, 322162, 322172, 323391, 323401, 323411, 328958, 328968, 328978, 337752, 337762, 337772, 349493, 349503, 349513, 364654, 364664, 364674, 374728, 374738, 374748]

static func is_enhancement_token(record: Dictionary) -> bool:
	return record.get("source_m_native_item")==true and int(record.get("source_item_class_id",0)) in TOKEN_IDS and not D.equipment(record)

static func commit_enhancement_token(world: Node, uid: String, scroll_requests: Array, quote: Dictionary) -> Dictionary:
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return _failure("원본 강화 저장 보호 중")
	var target: Dictionary=proof(world,uid)
	if target.is_empty() or not is_enhancement_token(target.record) or world._item_locked(target.record.name,uid) or world._item_locked(target.record.name):
		return _failure("선택한 원본 비착용 강화 개체를 확인하세요")
	var old: Dictionary=world.item_instances[uid]
	var rank: int=int(old.get(TOKEN_RANK,0))
	if world.hp<=0 or not world._patch523_item_allowed() or scroll_requests.size()!=1 or not scroll_requests[0] is Dictionary:return _failure("비착용 토큰의 선택 주문서 확인 필요")
	var scroll: Dictionary=proof(world,str(scroll_requests[0].get("physical_id","")))
	if scroll.is_empty() or int(scroll_requests[0].get("quantity",0))!=int(quote.get("count",-1)):return _failure("선택 주문서 영수증·수량 확인 필요")
	var current: Dictionary=world._source_enhancement_rule(target.record,rank,world._scroll_mode(scroll.record.name),scroll.record.name,old,scroll.record,true)
	if current!=quote:return _failure("비착용 토큰의 단계 또는 원본 강화 규칙 변경")
	if not quote.get("source_rule",false) or not quote.has("group") or int(quote.get("cost",-1))<0 or world.gold<int(quote.cost):
		return _failure("원본 강화 비용 또는 규칙 확인 필요")
	var debit: Dictionary=stage_debit(world,scroll_requests)
	if not debit.get("ok",false):return debit
	var payload: Dictionary=debit.overrides
	var state: Dictionary=payload.consumable_state
	var bag: Dictionary=payload.inventory
	var instances: Dictionary=payload.item_instances
	var next_uid: String=uid
	var split: bool=false
	var candidate_rng:=RandomNumberGenerator.new()
	candidate_rng.seed=world.rng.seed
	candidate_rng.state=world.rng.state
	var roll: float=minf(candidate_rng.randf_range(0.0,100.0),99.999999)
	var next_rank: int=rank
	var kind: String="maintain"
	if roll<float(quote.success):
		var leap: int=candidate_rng.randi_range(0,999999)
		var threshold: int=0
		for r: Dictionary in quote.leaps:
			threshold+=int(r.probability)
			if leap<threshold:next_rank=mini(21,rank+int(r.gain));break
		kind="success"
	elif roll<float(quote.success)+float(quote.no_change):pass
	elif roll<float(quote.success)+float(quote.no_change)+float(quote.decrease):
		next_rank=maxi(0,rank-int(quote.side_effect_level_loss));kind="decrease"
	else:
		next_rank=0;kind="destroy"
	# An unchanged unit can remain in its original receipt. Any material
	# change (including destruction) isolates exactly one old bulk unit.
	if int(target.remaining)>1 and kind!="maintain" and (kind=="destroy" or next_rank!=rank):
		var partition: Dictionary=prepare_partition(world,old,uid,1,state)
		if not partition.get("ok",false):return partition
		split=true;next_uid=partition.child_id
		instances[uid]=partition.parent;instances[next_uid]=partition.child
		state=partition.consumable_state;payload.consumable_state=state
	if kind=="destroy":
		var consumed: Dictionary=proof_entry(instances[next_uid],next_uid)
		if consumed.is_empty() or consumed.remaining!=1:return _failure("소실 대상 1개 증명 실패")
		state[USES][next_uid]=ledger_row(consumed,int(consumed.used)+1,0)
		var key: String=target.record.name
		bag[key]=int(bag.get(key,0))-1
		if bag[key]==0:bag.erase(key)
		instances.erase(next_uid)
	elif next_rank!=rank:
		if next_rank==0:instances[next_uid].erase(TOKEN_RANK)
		else:instances[next_uid][TOKEN_RANK]=next_rank
	payload["gold"]=int(world.gold)-int(quote.cost)
	payload["patch523_transaction_rng"]={"schema":1,"seed":str(candidate_rng.seed),"state":str(candidate_rng.state)}
	busy=true;_candidate_kind="enhancement_token_partition" if split else "enhancement_token";_partition_parent=uid;_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";_partition_parent="";busy=false
	if saved!=OK:
		if not str(world.patch523_owner_state_problem).is_empty():return _failure(world.patch523_owner_state_problem)
		return _failure("비착용 아이템 강화 저장 실패 · 아이템과 재화 보존")
	world.inventory=bag;world.item_instances=instances;world.consumable_service.import_state(state)
	world.gold=int(payload.gold);world.rng.state=candidate_rng.state
	world.deferred_save.cancel()
	return {"ok":true,"result":kind,"level":next_rank,"physical_id":next_uid}

static func proof(world: Node,uid: String) -> Dictionary:
	return proof_entry(world.item_instances.get(uid),uid)

## proof_entry is pure for (uid, entry, installed definition): the ownership
## checks call it for every physical stack on every save, pickup and bag merge
## (~1 ms each: the definition record is rebuilt). Results are reused while
## the entry is equal to the one proven and the definition identity is the
## same; callers get their own top-level copy.
const PROOF_CACHE_LIMIT := 4096
static var _proof_cache: Dictionary = {}
static var _proof_identity: Variant = null

static var _last_valid_inputs: Array = []

static func clear_proof_cache() -> void:
	_proof_cache.clear();_proof_identity=null;_last_valid_inputs=[]

static func proof_entry(entry: Variant,uid: String) -> Dictionary:
	if not entry is Dictionary:return {}
	_select_proof_archive()
	return _proof_entry_readonly(entry,uid).duplicate(false)

static func _select_proof_archive() -> void:
	var identity: Variant=SOURCE.identity()
	if identity!=_proof_identity:_proof_cache.clear();_proof_identity=identity

## Cache projections are read-only to callers of this internal validator.
## Public proof_entry still hands out a separate top-level dictionary.
static func _proof_entry_readonly(entry: Variant,uid: String) -> Dictionary:
	if not entry is Dictionary:return {}
	var cached: Variant=_proof_cache.get(uid)
	if cached is Array and cached[0]==entry:return cached[1]
	var result: Dictionary=_proof_entry(entry,uid)
	if _proof_cache.size()>=PROOF_CACHE_LIMIT:_proof_cache.clear()
	_proof_cache[uid]=[(entry as Dictionary).duplicate(true),result.duplicate(true)]
	return result

static func _proof_entry(entry: Variant,uid: String) -> Dictionary:
	if not entry is Dictionary or not entry.get("record") is Dictionary or not entry.get(RECEIPT) is Dictionary:return {}
	var record: Dictionary=D.current_owned_record(entry.record)
	if supply_profile(record).is_empty() or entry.get("name")!=record.get("name") or entry.get("level")!=0:return {}
	var receipt: Dictionary=entry[RECEIPT]
	if not receipt_valid(receipt,uid) or (not NATIVE_FIELDS.lazy(receipt) and receipt.get("source_original_item")!=NATIVE_FIELDS.full(record).get("source_original_item")) or receipt.get("item_class_id")!=record.get("source_item_class_id") or receipt.get("bless_raw")!=record.get("source_bless_raw"):return {}
	var remaining: Variant=entry.get(QUANTITY);var used: Variant=entry.get("source_native_stack_used_quantity");var granted: Variant=receipt.get("granted_quantity");var transferred: Variant=entry.get(TRANSFERRED,0)
	if not integer(remaining) or not integer(used) or not integer(granted) or not integer(transferred) or int(remaining)<1 or int(used)>int(granted)-int(transferred) or int(remaining)!=int(granted)-int(used)-int(transferred):return {}
	if entry.has(TOKEN_RANK) and (not is_enhancement_token(record) or not integer(entry[TOKEN_RANK]) or int(entry[TOKEN_RANK]) not in range(1,22) or int(remaining)!=1):return {}
	return {"record":record,"remaining":int(remaining),"used":int(used),"transferred":int(transferred),"receipt":receipt,"first_grant_receipt":first_grant_receipt(receipt),"allocated_quantity":int(granted)}

static func receipt_valid(receipt: Dictionary,uid: String,depth: int=0) -> bool:
	if depth>128 or whole(receipt.get("schema")) not in [1,2,3] or receipt.get("issued_physical_id")!=uid or (receipt.has("source_definition_archive") and receipt.source_definition_archive!=SOURCE.identity()) or not integer(receipt.get("item_class_id")) or not integer(receipt.get("granted_quantity")) or int(receipt.granted_quantity)<1 or not _original_row_ok(receipt) or whole(receipt.get("bless_raw")) not in [1,2,3] or not receipt.get("origin") is Dictionary or receipt.origin.is_empty():return false
	if receipt.schema==1:return true
	if receipt.schema==3:return MERGE.receipt_shape_valid(receipt)
	var origin: Dictionary=receipt.origin
	if origin.get("kind")!="owned_quantity_partition" or not origin.get("partition_id") is String or str(origin.partition_id).length()!=32 or not str(origin.partition_id).is_valid_hex_number(false) or not origin.get("parent_physical_id") is String or origin.parent_physical_id==uid or not origin.get("parent_receipt") is Dictionary:return false
	var parent: Dictionary=origin.parent_receipt
	return receipt_valid(parent,str(origin.parent_physical_id),depth+1) and parent.get("item_class_id")==receipt.item_class_id and parent.get("bless_raw")==receipt.bless_raw and int(receipt.granted_quantity)<=int(parent.granted_quantity)

## A trimmed receipt (no row copy, catalog MARK + the same ItemClass ID) reads
## its row from the installed definition; a full one keeps the exact copy
## check. Either way the row must be the current original ItemClass row.
static func _original_row_ok(receipt: Dictionary) -> bool:
	if NATIVE_FIELDS.lazy(receipt):
		return not receipt.has("source_original_item") and whole(receipt.get("source_item_class_id"))==whole(receipt.get("item_class_id")) and not SOURCE.row("ItemClass",int(receipt.item_class_id)).is_empty()
	return receipt.get("source_original_item")==SOURCE.row("ItemClass",int(receipt.item_class_id))

static func first_grant_receipt(receipt: Dictionary) -> Dictionary:
	var root: Dictionary=receipt
	for depth: int in range(129):
		if whole(root.get("schema")) in [1,3]:return root.duplicate(true)
		if root.get("schema")!=2 or not root.get("origin",{}).get("parent_receipt") is Dictionary:return {}
		root=root.origin.parent_receipt
	return {}

const DISCARD_REASONS: Array[String]=["TWILIGHT_existing_ground_lifetime","TWILIGHT_plain_stack_handoff"]
static func ledger_row(owned: Dictionary,used: int,remaining: int,discarded: int=0,reason: String="TWILIGHT_existing_ground_lifetime") -> Dictionary:
	var row: Dictionary={"receipt":owned.receipt.duplicate(true),"used_quantity":used,"remaining_quantity":remaining}
	if int(owned.get("transferred",0))>0:row["transferred_quantity"]=int(owned.transferred)
	if discarded>0:row["discarded_quantity"]=discarded;row["discard_reason"]=reason
	return row

# Comparison-only counterpart of ledger_row. Stored/output rows still own a
# detached receipt. Dictionary equality is type-sensitive (1 != 1.0 there),
# so use is_same for scalar fields rather than numeric Variant equality.
static func _ledger_row_matches(value: Variant,owned: Dictionary,used: int,remaining: int,discarded: int=0,reason: String="TWILIGHT_existing_ground_lifetime") -> bool:
	if not value is Dictionary: return false
	var transferred: int=int(owned.get("transferred",0))
	if value.size()!=3+int(transferred>0)+2*int(discarded>0): return false
	if not is_same(value.get("used_quantity"),used) or not is_same(value.get("remaining_quantity"),remaining): return false
	if transferred>0 and not is_same(value.get("transferred_quantity"),transferred): return false
	if discarded>0 and (not is_same(value.get("discarded_quantity"),discarded) or not is_same(value.get("discard_reason"),reason)): return false
	var receipt: Variant=value.get("receipt")
	return receipt is Dictionary and receipt==owned.receipt

static func _failure(reason: String) -> Dictionary:
	return {"handled":true,"ok":false,"saved":false,"consumed":0,"reason":reason}

## Standalone callers publish speed immediately. The inventory activation
## owner publishes all committed buff stats once for either dispatch route.
static func try_use(world: Node,item_name: String,selected: String="",update_buff_speed_now: bool=true) -> Dictionary:
	return (load("res://scripts/loot/current523_native_stack.gd") as Script).call("_try_use_impl",world,item_name,selected,false,update_buff_speed_now)

static func try_use_loading(world: Node,item_name: String,selected: String,update_buff_speed_now: bool=true) -> Dictionary:
	return await _try_use_impl(world,item_name,selected,true,update_buff_speed_now)

static func _try_use_impl(world: Node,item_name: String,selected: String,loading: bool,update_buff_speed_now: bool) -> Dictionary:
	var named: Dictionary=world._find_catalog_item_record(item_name)
	if RETIRED_ITEMS.retired_reference(item_name) or RETIRED_ITEMS.record(named) or RETIRED_ITEMS.QUEST_ONLY.matches_reference(named,item_name):return _failure(RETIRED_ITEMS.REASON)
	if not selected.is_empty() and RETIRED_ITEMS.record(world.item_instances.get(selected,{}).get("record",{})):return _failure(RETIRED_ITEMS.REASON)
	var catalog_action: Dictionary = CATALOG_STACK.action_record(world,named) if selected.is_empty() and named.get("name") == item_name else {}
	# A plain name-keyed stack (as the 523 shop sells it) of an original
	# teleport/Ainhasad/food item has its own owner; it shows its own message.
	if selected.is_empty():
		var handled: bool
		if loading: handled = await EFFECTS.try_use_plain_loading(world,item_name,named,catalog_action)
		else: handled = EFFECTS.try_use_plain(world,item_name,named,catalog_action)
		if handled: return {"handled":true,"ok":false,"silent":true}
	# Old name-keyed quest rewards predate physical receipts. The quest
	# owner verifies their historical source before the native UID gate.
	if int(named.get("source_item_class_id",0)) in [139781,289172,289182,289202,306611,306621,306631,306641] and load("res://scripts/quests/quest_fixed_cards523.gd").call("try_use_legacy",world,item_name,selected,named):
		return {"handled":true,"silent":true}
	var selected_entry: Variant=world.item_instances.get(selected,{})
	var catalog_bag: bool = not catalog_action.is_empty() and profile(catalog_action).get("kind") == "bag"
	var named_profile: Dictionary=profile(named)
	var claims: bool=catalog_bag or (not named_profile.is_empty() and named_profile.get("kind") not in ["half_elixir_charge","half_elixir_reset"]) or (selected_entry is Dictionary and selected_entry.has(RECEIPT))
	if not claims:
		for entry: Variant in world.item_instances.values():
			if entry is Dictionary and entry.get("name")==item_name and entry.has(RECEIPT):claims=true;break
	if not claims:return {"handled":false}
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return _failure("원본 소비 저장 보호 중 · 물리 수량 보존")
	if not world._patch523_item_allowed() or world.hp<=0 or world._option_awakening_busy():return _failure("현재 사용·생존 상태 조건 미충족")
	var uid: String="";var owned: Dictionary={};var total: int=0;var has_physical: bool=false
	for id: String in world.item_instances:
		var entry: Variant=world.item_instances[id]
		if not entry is Dictionary or entry.get("name")!=item_name:continue
		has_physical=true
		if not entry.has(RECEIPT):continue
		var current: Dictionary=proof(world,id)
		if current.is_empty():return _failure("원본 물리 소유·최초량·잔량 증명 불일치")
		if total>9007199254740991-int(current.remaining):return _failure("물리 수량 정수 범위 초과")
		total+=int(current.remaining)
		if uid.is_empty() and (selected.is_empty() or selected==id) and not world._item_locked(item_name,id):uid=id;owned=current
	if not has_physical and selected.is_empty() and named.get("name")==item_name and integer(world.inventory.get(item_name,0)) and int(world.inventory.get(item_name,0))>0 and not world._item_locked(item_name):
		# Older name-keyed acceleration stacks have no physical receipt. Their
		# existing atomic buff owner can debit the exact catalog balance directly.
		var plain: Dictionary=profile(named)
		var plain_spec: Dictionary=plain.get("spec",{})
		if plain.get("kind")=="buff" and MANUAL_SCROLLS.RULES.has(int(named.get("source_item_class_id",0))) and plain_spec.get("activation_status")=="unrestricted":
			if preload("res://scripts/loot/patch523_item_use.gd").try_use(world,named):return {"handled":true,"silent":true}
		if plain.get("kind")=="buff" and int(plain_spec.get("acceleration_stage",0))>0 and plain_spec.get("activation_status")=="unrestricted":
			var restriction: String=_buff_territory_problem(world,plain_spec)
			if not restriction.is_empty():return _failure(restriction)
			if preload("res://scripts/loot/patch523_item_use.gd").try_use(world,named):return {"handled":true,"silent":true}
	if catalog_bag:
		if has_physical or world._item_locked(item_name) or not CATALOG_STACK.holds_plain(world,item_name):
			return _failure("선택한 기존 상자 수량 또는 잠금 상태를 확인하세요")
		owned = {"ownership_kind":"catalog","record":catalog_action,"key":item_name,"remaining":int(world.inventory[item_name]),
			"receipt":{"source":named.source,"source_id":named.sourceId,"inventory_key":item_name,"item_class_id":catalog_action.source_item_class_id}}
	elif not integer(world.inventory.get(item_name,0)) or total>int(world.inventory.get(item_name,0)) or uid.is_empty() or world._item_locked(item_name):return _failure("선택 물리 개체·잠금·소지 수량 확인 필요 · 이름만 같은 보유품 보존")
	var record: Dictionary=owned.record;var effect: Dictionary=profile(record)
	if effect.is_empty() and not draw_ticket_profile(record).is_empty():return {"handled":false} # The owned-ticket service redeems it.
	if effect.is_empty() and not mystery_card_rule(record).is_empty():return use_mystery_card(world,uid,owned,record)
	if effect.is_empty() and plain_owner(world,item_name,record):
		# 주문서 (강화·귀환): the existing name-keyed owner (as the 523 shop
		# sells it) uses the item; the receipted stack is handed to it first.
		var handed: Dictionary=handoff_plain(world,item_name)
		if not handed.get("ok",false):return handed
		return {"handled":false}
	if effect.is_empty() and str(NATIVE_FIELDS.full(record).get("source_use_spec",{}).get("kind","")) in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward","source_selectable_bag"]:
		# A box whose original rewards are all test/excluded rows (or another
		# unsupported rule) is kept and says so instead of staying silent.
		return _failure("원본 보상 구성을 지원하지 않는 상자라 열 수 없습니다 · 상자 보존")
	if effect.is_empty() and supply_profile(record).get("kind")=="storage":return _failure("원본 표에 이 아이템의 사용 규칙이 없거나 아직 연결되지 않았습니다 · 보관용 · 아이템 보존")
	if effect.is_empty():return _failure("원본 소비 재료입니다 · 해당 스킬·제작에서 물리 개체와 수량을 확인하세요")
	if effect.kind=="ammo":return {"handled":false} # Existing inventory activation wears the selected physical ammunition.
	var use_owner: Resource=load("res://scripts/loot/patch523_item_use.gd")
	var problem: String=str(use_owner.call("eligibility",world,record))
	if not problem.is_empty():return _failure(problem)
	var details: Dictionary=effect.get("metadata",{});var spec: Dictionary=effect.get("spec",{})
	if effect.kind=="buff":
		spec=timed_buff_spec(world,record,effect)
		if spec.is_empty():
			if effect.get("runtime_regen",false):return _failure("기존 MP 재생 주기 설정·원본 조건 확인 필요 · 물약 보존")
			if effect.get("runtime_food",false):return _failure("기존 음식 회복 주기 설정·원본 조건 확인 필요 · 아이템 보존")
			return _failure("기존 표시 메타데이터·기간 정책에서 사용을 보류합니다 · 아이템 보존")
	if not bool(details.get("can_use_when_invisible",spec.get("can_use_when_invisible",false))) and world.is_player_concealed():return _failure("원본 조건: 은신 중 사용할 수 없습니다")
	var cooldown_key: String="m523:item:"+str(record.source_item_class_id)
	if float(world.item_use_cooldowns.get(cooldown_key,0.0))>0:return _failure("원본 아이템 재사용 대기")
	if effect.kind=="buff":
		var territory_started:int=FRAME_HITCH.now()
		var restriction: String=_buff_territory_problem(world,spec)
		FRAME_HITCH.detail("item.buff_territory",territory_started)
		if not restriction.is_empty():return _failure(restriction)
		var rule: String=buff_rule_problem(world,spec)
		if not rule.is_empty():return _failure(rule)
	if effect.kind=="elixir":
		world.consumable_service.open_owned_elixir(uid,owned)
		return {"handled":true,"silent":true}
	if effect.kind=="solvent_refine":
		if not world.hud.has_method("open_bless_refine523"):return _failure("원본 용해제 대상 선택 화면이 없습니다 · 아이템 보존")
		world.hud.call("open_bless_refine523",uid)
		return {"handled":true,"silent":true,"saved":false,"consumed":0}
	if effect.kind=="cure":return load("res://scripts/quests/quest_cure310.gd").call("perform",world,record,uid)
	if effect.kind=="skill_book":return learn_skill_book(world,uid,owned,record,spec)
	if effect.kind=="card":return use_fixed_card(world,uid,owned,record,spec)
	if effect.kind=="bonus_stat_point":return use_bonus_point(world,uid,owned)
	if effect.kind=="fusion_points":return use_fusion_points(world,uid,owned,spec)
	if effect.kind=="exact_experience":return use_exact_experience(world,uid,owned)
	if effect.kind=="exact_firework":return use_exact_firework(world,uid,owned)
	if effect.kind=="half_elixir_charge":return use_half_elixir_charge(world,uid,owned,record)
	if effect.kind=="half_elixir_reset":return open_half_elixir_reset(world,uid,owned,record)
	if effect.kind=="mastery":return use_mastery_points(world,uid,owned,record,spec)
	if effect.kind=="bless_points":return use_bless_points(world,uid,owned,record,spec)
	if effect.kind=="time_recharge":return use_time_recharge(world,uid,owned,record,spec)
	# A bless scroll needs a target: the existing blessing chooser opens and its
	# confirmation debits the physical scroll (consumable_service.apply_bless_scroll).
	if effect.kind=="bless":
		world.consumable_service.call("_use_bless_scroll",item_name,uid)
		return {"handled":true,"ok":false,"silent":true}
	if effect.kind=="selection":return selection_pending(world,uid,owned,record,spec)
	if effect.kind=="bag":return use_bag(world,uid,owned,record,spec)
	var prepared: Dictionary={}
	if effect.kind in ["teleport","ain","teleport_location"]:
		prepared=EFFECTS.prepare(world,record,str(effect.kind))
		if not prepared.get("ok",false):return _failure(str(prepared.get("reason","원본 사용 조건 확인 필요 · 아이템 보존")))
		spec={"consume_delay_ms":int(prepared.get("consume_delay_ms",0)),"consume_effect_sprite_id":int(prepared.get("consume_sprite_id",0))}
	var maximum: int=world._effective_max_hp() if effect.kind=="hp" else (world._effective_max_mp() if effect.kind=="mp" else 0)
	var before: int=int(world.hp if effect.kind=="hp" else (world.mp if effect.kind=="mp" else 0))
	if effect.kind in ["hp","mp"] and before>=maximum:return _failure("HP가 가득 찼습니다" if effect.kind=="hp" else "MP가 가득 찼습니다")
	var parameters: Dictionary=world._source_hp_potion_parameters(0) if effect.kind=="hp" else {}
	if effect.kind=="hp" and float(world.item_use_cooldowns.get(str(parameters.cooldown_key),0.0))>0:return _failure("HP 물약 재사용 대기")
	var is_buff: bool=effect.kind=="buff"
	var buff_phase: int=FRAME_HITCH.now() if is_buff else 0
	var state: Dictionary=world.consumable_service.export_state()
	var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return _failure("기존 원본 물리 소비 장부 형식 보존")
	if int(owned.used)+int(owned.transferred)==0 and ledger.has(uid):return _failure("물리 공급 영수증과 기존 사용 장부 불일치")
	if int(owned.used)+int(owned.transferred)>0 and not _ledger_row_matches(ledger.get(uid),owned,int(owned.used),int(owned.remaining)):return _failure("물리 잔량과 원본 사용 장부 불일치")
	var candidate_rng:=RandomNumberGenerator.new();candidate_rng.seed=world.rng.seed;candidate_rng.state=world.rng.state
	var amount: int=0
	if effect.kind=="hp":
		amount=D.healing_amount(record,candidate_rng,0)
		parameters=world._source_hp_potion_parameters(amount)
		amount=world.patch523_npc_spells.extensions.healing(int(parameters.heal_amount),true)
	elif effect.kind=="mp":
		amount=int(spec.base)
		for die: int in range(int(spec.dice_number)):amount+=candidate_rng.randi_range(1,int(spec.dice_spot_count))
	var after: int=mini(maximum,before+amount)
	# A timed buff edits only the selected physical's two scalar counters.
	# All other rows are read-only until this synchronous commit returns.
	# Keep the frozen authorization copy and the writer's detached payload.
	var bag: Dictionary=world.inventory.duplicate(not is_buff)
	var instances: Dictionary=world.item_instances.duplicate(not is_buff)
	# TWILIGHT 근사: a reusable teleport amulet moves without a physical debit.
	var reusable: bool=bool(prepared.get("reusable",false))
	if not reusable:
		bag[item_name]=int(bag[item_name])-1
		if int(bag[item_name])==0:bag.erase(item_name)
		if owned.remaining==1:instances.erase(uid)
		else:
			if is_buff:instances[uid]=(instances[uid] as Dictionary).duplicate()
			instances[uid][QUANTITY]=int(owned.remaining)-1
			instances[uid].source_native_stack_used_quantity=int(owned.used)+1
		# export_state() already owns this ledger in the timed-buff candidate.
		if not is_buff:ledger=ledger.duplicate(true)
		ledger[uid]=ledger_row(owned,int(owned.used)+1,int(owned.remaining)-1)
		state[USES]=ledger
	var cooldowns: Dictionary=world.item_use_cooldowns.duplicate(true)
	var reuse_delay: float=float(details.get("source_reuse_delay_seconds",0)) if effect.kind=="hp" else (float(spec.get("reuse_delay_seconds",0)) if effect.kind=="mp" else 0.0)
	var delay: float=maxf(float(details.get("source_consume_delay_ms",spec.get("consume_delay_ms",0)))/1000.0,reuse_delay)
	if delay>0:cooldowns[cooldown_key]=delay;cooldowns[item_name]=delay
	if effect.kind=="hp":cooldowns[str(parameters.cooldown_key)]=float(parameters.cooldown_seconds)
	var payload: Dictionary={"inventory":bag,"item_instances":instances,"consumable_state":state,"item_use_cooldowns":cooldowns,"patch523_transaction_rng":{"schema":1,"seed":str(candidate_rng.seed),"state":str(candidate_rng.state)}}
	if effect.kind=="buff":
		var source: Dictionary=spec.get("source_buff_class",{});var group: Dictionary=spec.get("source_buff_group",{})
		if source.is_empty() or group.is_empty() or float(spec.get("duration_seconds",0))<=0:return _failure("원본 버프 수치·기간·그룹 연결 필요")
		var buffs: Dictionary=world.active_item_buffs.duplicate(true)
		for key: String in buffs.keys():
			var previous: Dictionary=buffs[key]
			if not previous.get("source_buff_class") is Dictionary:continue
			var old: Dictionary=previous.source_buff_class
			if old.get("ID")==source.get("ID") or (not group.get("IsAllowOverlap",false) and old.get("BuffGroupID")==source.get("BuffGroupID")):buffs.erase(key)
		var value: Dictionary=spec.typed_effects.duplicate(true)
		value.merge({"remaining":float(spec.duration_seconds),"duration":float(spec.duration_seconds),"source_buff_class":source.duplicate(true),"source_buff_group":group.duplicate(true),"source_item_class_id":int(record.source_item_class_id),"source_snapshot":"patch523"})
		buff_runtime_fields(world,spec,value)
		buffs[MANUAL_SCROLLS.active_key(record,spec,item_name)]=value;payload["active_item_buffs"]=buffs
		payload["hp"]=mini(world.hp,world._effective_max_hp(-1,buffs));payload["mp"]=mini(world.mp,world._effective_max_mp(buffs))
	elif effect.kind in ["teleport","ain","teleport_location"]:
		if prepared.has("ainhasad_state"):payload["ainhasad_state"]=prepared.ainhasad_state
		if prepared.has("experience"):payload["experience"]=int(prepared.experience)
	else:payload["hp" if effect.kind=="hp" else "mp"]=after
	var previous_position: Vector2=world.player.global_position
	if prepared.has("destination"):
		if loading and not await world.prepare_map_point(prepared.destination):
			return {"handled":true,"ok":false,"silent":true}
		world.consumable_service._teleport_player(prepared.destination)
	busy=true;_candidate=payload.duplicate(true)
	if is_buff:buff_phase=FRAME_HITCH.detail_next("item.buff_stage",buff_phase)
	var saved: Error=OK
	var potion_deferred: bool=false
	if prepared.has("travel"):
		# Fixed-destination teleport: the arrival's checkpoint save carries the
		# physical debit (current523_map_travel_payment); a refused move keeps it.
		var moved: Dictionary
		if loading: moved = await world.item523_teleport_land_loading(int(prepared.travel.land_id),prepared.travel.bounds,payload)
		else: moved = world.item523_teleport_land(int(prepared.travel.land_id),prepared.travel.bounds,payload)
		_candidate.clear()
		if not moved.get("ok",false):
			busy=false
			if moved.get("uncertain",false):world.patch523_owner_state_problem="원본 물리 소비 저장 실패·결과 미확정 · 다시 불러오기 전 저장·재사용 중지"
			return _failure(str(moved.get("reason","이동 실패"))+(" · 정상 저장 불러오기 필요" if moved.get("uncertain",false) else " · 주문서 보존"))
	elif effect.kind in ["hp","mp"] and reuse_delay<=0.0 and not prepared.has("destination"):
		# HP/MP potions: checked as their save would check them, committed in
		# memory, written by the coalesced background save (user decision
		# 2026-11-21, option A: a full save per potion was ~0.4 s on the phone).
		potion_deferred=true
		if not override_error(world,payload).is_empty():
			_candidate.clear();busy=false
			return _failure("원본 물약 사용 후보 확인 실패 · 물약 보존")
	else:
		saved=world._save_game(true,payload)
	_candidate.clear()
	if is_buff:buff_phase=FRAME_HITCH.detail_next("item.buff_save",buff_phase)
	if saved!=OK:
		if prepared.has("destination"):world.consumable_service._teleport_player(previous_position)
		world.patch523_owner_state_problem="원본 물리 소비 저장 실패·결과 미확정 · 다시 불러오기 전 저장·재사용 중지"
		busy=false;return _failure(world.patch523_owner_state_problem)
	world.inventory=bag;world.item_instances=instances;world.item_use_cooldowns=cooldowns;world.consumable_service.import_state(state)
	world.rng.seed=candidate_rng.seed;world.rng.state=candidate_rng.state
	if effect.kind=="hp":world.hp=after;world._source_hp_potion_committed(amount)
	elif effect.kind=="mp":world.mp=after
	elif effect.kind in ["teleport","ain","teleport_location"]:EFFECTS.commit(world,prepared)
	else:
		world.active_item_buffs=payload.active_item_buffs;world.hp=int(payload.hp);world.mp=int(payload.mp)
		if update_buff_speed_now:
			world._invalidate_equipment_static();world._refresh_speed_modifiers()
	if potion_deferred:world._request_general_save()
	else:world.deferred_save.cancel()
	busy=false
	var sprite: int=int(details.get("consume_effect_sprite_id",spec.get("consume_effect_sprite_id",0)))
	if sprite>0:world.option_awakening.combat.emit_sprite(sprite,world.player)
	var message: String=str(prepared.get("message","")) if not prepared.is_empty() else "%s · 원본 버프 %s" % [str(NATIVE_FIELDS.field(record,"source_display_name")),world._format_seconds_short(float(spec.get("duration_seconds",0)))] if effect.kind=="buff" else "%s · %s %d 회복" % [str(NATIVE_FIELDS.field(record,"source_display_name")),"HP" if effect.kind=="hp" else "MP",after-before]
	if is_buff:FRAME_HITCH.detail("item.buff_apply",buff_phase)
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":0 if reusable else 1,"physical_id":uid,"remaining_quantity":int(owned.remaining) if reusable else int(owned.remaining)-1,"message":message,"effect_kind":str(effect.kind)}
	return committed_use_context(result,record,sprite,sprite>0,"current523_native_stack.try_use")

## The same duration and original effect identity drive manual use and AUTO.
static func timed_buff_spec(world: Node, record: Dictionary, effect: Dictionary) -> Dictionary:
	var spec: Dictionary = effect.get("spec", {})
	if effect.get("runtime_regen", false):
		var resolved: Dictionary = load("res://scripts/quests/quest_regen523.gd").action(world,record)
		spec = NATIVE_FIELDS.full(resolved).get("source_use_spec", {})
	elif effect.get("runtime_presentation", false) or effect.get("runtime_food", false):
		var resolved: Dictionary = load("res://scripts/loot/patch523_item_use.gd").action_record(world,record)
		spec = NATIVE_FIELDS.full(resolved).get("source_use_spec", {})
	return spec if spec.get("activation_status") == "unrestricted" else {}

static func _buff_territory_problem(world: Node,spec: Dictionary) -> String:
	if spec.has("source_trial_tower_territory_id"):
		if int(spec.source_trial_tower_territory_id)!=10353 or not world._trial_tower_item_land_active():return "원본 시련의 탑 층에서만 사용할 수 있습니다 · 아이템 보존"
		var allowed:Variant=EFFECTS.consume_areas([10353])
		if not allowed is Array or allowed.size()!=100 or not EFFECTS._inside(world,allowed,world.player.global_position):return "시련의 탑 원본 사용 좌표 밖입니다 · 아이템 보존"
	if spec.get("forbidden_territory_class_ids",[]).is_empty():return ""
	var areas: Variant=EFFECTS.forbidden_areas({"territory_class_ids":spec.forbidden_territory_class_ids})
	if areas==null:return "원본 사용 불가 지역 입력 확인 실패 · 아이템 보존"
	return "원본 조건: 이 지역에서는 사용할 수 없습니다" if EFFECTS._forbidden(world,areas,world.player.global_position) else ""

# Existing save/load owner uses these pure candidate guards. No game load or
# validation command is executed while implementing this boundary.
## A stored original item whose use the existing name-keyed owner performs
## exactly like the 523 shop's plain stack: 강화 주문서 (World._scroll_kind,
## the enhancement window) and 귀환 주문서 (regional_return, original 239).
static func plain_owner(world: Node,item_name: String,record: Dictionary) -> bool:
	if not storage_profile(record).get("kind")=="storage":return false
	if world.has_method("_scroll_kind") and not str(world._scroll_kind(item_name)).is_empty():return true
	return preload("res://scripts/quickslots/regional_return.gd").supported(item_name,record)

## Hands every receipted physical stack named `item_name` to the plain
## name-keyed stack: the bag count is unchanged, each physical entry leaves
## with a ledger row whose remaining units are discarded with the reason
## TWILIGHT_plain_stack_handoff, and the change is saved before the plain
## owner runs. A locked entry or a refused save keeps everything.
static func handoff_plain(world: Node,item_name: String) -> Dictionary:
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return _failure("원본 소비 저장 보호 중 · 물리 수량 보존")
	var instances: Dictionary=world.item_instances.duplicate(true)
	var state: Dictionary=world.consumable_service.export_state()
	var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return _failure("원본 물리 사용 장부 형식 보존")
	ledger=ledger.duplicate(true)
	var handed: int=0
	for uid: String in world.item_instances:
		var entry: Variant=world.item_instances[uid]
		if not entry is Dictionary or entry.get("name")!=item_name or not entry.has(RECEIPT):continue
		if world._item_locked(item_name,uid):return _failure("잠긴 개체가 있어 사용할 수 없습니다 · 아이템 보존")
		var owned: Dictionary=proof(world,uid)
		if owned.is_empty():return _failure("원본 물리 소유·최초량·잔량 증명 불일치")
		ledger[uid]=ledger_row(owned,int(owned.used),0,int(owned.remaining),"TWILIGHT_plain_stack_handoff")
		instances.erase(uid);handed+=1
	if handed==0:return {"ok":true,"handed":0}
	state[USES]=ledger
	var overrides: Dictionary={"inventory":world.inventory.duplicate(true),"item_instances":instances,"consumable_state":state}
	busy=true;_candidate_kind="plain_handoff";_candidate=overrides.duplicate(true)
	var issue: String=override_error(world,overrides)
	var saved: Error=world._save_game(true,overrides) if issue.is_empty() else ERR_INVALID_DATA
	_candidate.clear();_candidate_kind="";busy=false
	if not issue.is_empty():return _failure(issue)
	if saved!=OK:return _failure("원본 물리 묶음 저장 실패 · 아이템 보존")
	world.item_instances=instances;world.consumable_service.import_state(state);clear_proof_cache()
	return {"ok":true,"handed":handed}

## 원본 버프 사용 규칙 (2026-11-21): the level its effect ends at
## (EraseBuffOnExperience / EraseOnLevel), IgnoreUseItemDuringBuff (not while
## the same buff runs) and CannotUseBuffGroup (not while that group runs).
static func buff_rule_problem(world: Node,spec: Dictionary) -> String:
	if spec.has("buff_delete_time_raw"):
		var deadline := D.source_deadline_unix(int(spec.buff_delete_time_raw), int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if deadline == -1 or (not D.rotate_ended_dates and deadline <= Time.get_unix_time_from_system()):
			return "원본 버프 적용 기한 만료 · 아이템 보존"
	var erase_level: int=int(spec.get("erase_at_level",0))
	if erase_level>0 and int(world.level)>=erase_level:return "원본 조건: 버프 효과는 Lv.%d까지만 적용됩니다 · 아이템 보존" % (erase_level-1)
	var own: int=int(spec.get("buff_class_id",0))
	var groups: Array=spec.get("cannot_use_buff_groups",[])
	for value: Variant in world.active_item_buffs.values():
		if not value is Dictionary or not value.get("source_buff_class") is Dictionary:continue
		var active: Dictionary=value.source_buff_class
		if spec.get("ignore_use_during_buff",false) and int(active.get("ID",0))==own:return "이미 같은 효과가 적용 중입니다 · 아이템 보존"
		if int(active.get("BuffGroupID",0)) in groups:return "함께 사용할 수 없는 효과가 적용 중입니다 · 아이템 보존"
	return ""

## Runtime fields of an applied original item buff: regeneration ticks on
## the existing TWILIGHT regeneration interval, the absolute end of a real-time
## buff and the level it ends at.
static func buff_runtime_fields(world: Node,spec: Dictionary,value: Dictionary) -> void:
	var regen_hp: int=int(value.get("regen_hp",0));var regen_mp: int=int(value.get("regen_mp",0))
	if regen_hp>0 or regen_mp>0:
		value["hp_regen_tick"]=regen_hp;value["mp_regen_tick"]=regen_mp
		value["tick_interval"]=float(load("res://scripts/quests/quest_regen523.gd").call("interval",world));value["tick_elapsed"]=0.0
	if spec.get("absolute_time",false):value["absolute_until"]=Time.get_unix_time_from_system()+float(spec.get("duration_seconds",0))
	if spec.has("buff_delete_time_raw"):
		var deadline := D.source_deadline_unix(int(spec.buff_delete_time_raw), int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		# Historical event windows follow the same offline rotation as bag items.
		if not D.rotate_ended_dates or deadline > Time.get_unix_time_from_system():
			value["source_buff_delete_at"] = deadline
			value["remaining"] = minf(float(value.remaining), maxf(0.0, deadline - Time.get_unix_time_from_system()))
	if int(spec.get("erase_at_level",0))>0:value["erase_at_level"]=int(spec.erase_at_level)
	if spec.get("source_trial_tower_territory_id")==10353:value["source_trial_tower_territory_id"]=10353

static func state_error(inventory: Variant,instances: Variant,state: Variant,warehouse: Variant={},floor: Variant=[],dormant: Dictionary={}) -> String:
	if not inventory is Dictionary or not instances is Dictionary or not state is Dictionary or not warehouse is Dictionary or not floor is Array:return "원본 물리 수량 저장 후보 형식 확인 필요"
	var stored: Variant=warehouse.get("instances",{});var stored_counts: Variant=warehouse.get("stacks",{})
	if not stored is Dictionary or not stored_counts is Dictionary:return "원본 창고 물리 저장 형식 확인 필요"
	var all: Dictionary=instances.duplicate()
	for uid: String in stored:
		if not stored[uid] is Dictionary or not stored[uid].has(RECEIPT):continue
		if stored[uid].has(TOKEN_RANK):return "강화된 비착용 토큰 창고 이동 미연결"
		if all.has(uid):return "소지·창고 원본 개체 ID 중복 · 저장 보존"
		all[uid]=stored[uid]
	# Resolve at most once per synchronous validation, and only if there is
	# a receipt to prove. Empty/legacy bags don't touch the original archive.
	var proof_archive_selected: bool=false
	var floor_proofs: Dictionary={}
	for entry: Variant in floor:
		if not entry is Dictionary:return "바닥 소유 기록 형식 확인 필요"
		var physical: Variant=entry.get("physical_item",{})
		if not physical is Dictionary or not physical.get("data") is Dictionary or not physical.data.has(RECEIPT):continue
		var uid: String=str(physical.get("id",""))
		if physical.data.has(TOKEN_RANK):return "강화된 비착용 토큰 바닥 이동 미연결"
		if not proof_archive_selected:
			_select_proof_archive()
			proof_archive_selected=true
		var owned: Dictionary=_proof_entry_readonly(physical.data,uid)
		if uid.is_empty() or all.has(uid) or owned.is_empty() or entry.get("player_dropped")!=true or not integer(entry.get("quantity")) or int(entry.quantity)<1 or int(owned.remaining)!=int(entry.quantity) or entry.get("item_name")!=physical.data.get("name") or entry.get("item_record")!=physical.data.get("record"):return "바닥 원본 개체·잔량·출처 중복 또는 불일치"
		all[uid]=physical.data;floor_proofs[uid]=owned
	# Offline character ownership proves shared quantity journals without
	# granting their items or counting their bag weight in this session.
	for uid: String in dormant:
		if all.has(uid):return "다른 캐릭터와 원본 물리 개체 ID 중복 · 저장 보존"
		all[uid]=dormant[uid]
	if not state.get(USES,{}) is Dictionary:return "원본 소비 장부 형식 보존 필요"
	var selected_ammo: Variant=state.get(AMMO_EQUIPPED,{})
	if not selected_ammo is Dictionary:return "원본 탄약 선택 소유 형식 확인 필요"
	if not selected_ammo.is_empty():
		if selected_ammo.get("ownership_kind")=="quest":
			var issue: String=quest_ammo_state_error(instances,state,selected_ammo)
			if not issue.is_empty():return issue
		else:
			if selected_ammo.size()!=3 or not selected_ammo.get("physical_id") is String:return "원본 탄약 선택 개체 증명 필요"
			if not proof_archive_selected:
				_select_proof_archive()
				proof_archive_selected=true
			var selected: Dictionary=_proof_entry_readonly(instances.get(selected_ammo.physical_id),selected_ammo.physical_id)
			if selected.is_empty():
				# Pure staged last-unit debit keeps only its inactive spent receipt.
				var spent: Variant=state.get(USES,{}).get(selected_ammo.physical_id,{})
				if not spent is Dictionary or spent.get("receipt")!=selected_ammo.get("receipt") or spent.get("remaining_quantity")!=0 or not integer(spent.get("used_quantity")) or int(spent.used_quantity)<1:return "원본 탄약 소지 개체 또는 정확한 마지막 소비 영수증 보존 필요"
			elif profile(selected.record).get("kind")!="ammo" or selected.record.get("name")!=selected_ammo.get("name") or selected.receipt!=selected_ammo.get("receipt"):return "착용한 원본 탄약은 실제 소지 개체·최초 영수증을 유지해야 합니다"
	var ammo_rng: Variant=state.get(AMMO_RNG,{})
	if not ammo_rng is Dictionary:return "원본 탄약 독립 난수 저장 형식 보존 필요"
	if not ammo_rng.is_empty() and (ammo_rng.size()!=3 or ammo_rng.get("schema")!=1 or not ammo_rng.get("seed") is String or not ammo_rng.get("state") is String or not str(ammo_rng.seed).is_valid_int() or not str(ammo_rng.state).is_valid_int()):return "원본 탄약 독립 난수 저장 증명 불일치"
	var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return "원본 물리 사용 장부 형식 확인 필요"
	var totals: Dictionary={};var stored_totals: Dictionary={}
	for uid: String in all:
		var entry: Variant=all[uid]
		if not entry is Dictionary or not entry.has(RECEIPT):continue
		if not proof_archive_selected:
			_select_proof_archive()
			proof_archive_selected=true
		var owned: Dictionary=floor_proofs[uid] if floor_proofs.has(uid) else _proof_entry_readonly(entry,uid)
		if owned.is_empty():return "원본 물리 개체·최초량·잔량 증명 불일치"
		if int(owned.used)+int(owned.transferred)==0 and ledger.has(uid):return "원본 최초 소유와 소비 장부 불일치"
		if int(owned.used)+int(owned.transferred)>0 and not _ledger_row_matches(ledger.get(uid),owned,int(owned.used),int(owned.remaining)):return "원본 물리 잔량·소비 장부 불일치"
		if floor_proofs.has(uid) or dormant.has(uid):continue
		var name_value: String=str(entry.name)
		var amounts: Dictionary=stored_totals if stored.has(uid) else totals
		var previous: int=int(amounts.get(name_value,0))
		if previous>9007199254740991-int(owned.remaining):return "원본 물리 수량 범위 초과"
		amounts[name_value]=previous+int(owned.remaining)
	for name_value: String in totals:
		if not integer(inventory.get(name_value,0)) or int(inventory.get(name_value,0))<int(totals[name_value]):return "원본 물리 잔량보다 소지 수량이 적습니다 · 기존 저장 보존"
	for name_value: String in stored_totals:
		if not integer(stored_counts.get(name_value,0)) or int(stored_counts.get(name_value,0))<int(stored_totals[name_value]) or int(stored_counts.get(name_value,0))>1000000:return "원본 창고 물리 수량·저장 범위 불일치"
	for uid: String in ledger:
		var entry: Variant=ledger[uid]
		if not entry is Dictionary or not entry.get("receipt") is Dictionary or not integer(entry.get("used_quantity")) or not integer(entry.get("remaining_quantity")):return "원본 소비 장부 행 형식 확인 필요"
		var receipt: Dictionary=entry.receipt
		# An exact active native match above already proved this receipt for
		# the same uid and archive. Ledger-only rows still prove independently.
		var physical: Variant=all.get(uid)
		if not (physical is Dictionary and physical.has(RECEIPT)) and not receipt_valid(receipt,uid):return "원본 소비 장부 출처 확인 필요"
		var disposed: Variant=entry.get("discarded_quantity",0);var transferred: Variant=entry.get("transferred_quantity",0)
		if not integer(disposed) or not integer(transferred) or int(entry.used_quantity)+int(disposed)+int(transferred)<1 or int(entry.used_quantity)>int(receipt.granted_quantity)-int(disposed)-int(transferred) or int(entry.remaining_quantity)!=int(receipt.granted_quantity)-int(entry.used_quantity)-int(disposed)-int(transferred):return "원본 장부 최초량·사용량·잔량·분할량·소멸량 불일치"
		if int(disposed)>0 and (entry.get("discard_reason") not in DISCARD_REASONS or int(entry.remaining_quantity)!=0):return "원본 바닥 소멸 출처·잔량 확인 필요"
		if int(entry.remaining_quantity)>0 and not all.has(uid):return "남은 원본 물리 개체가 없습니다 · 소비 장부 보존"
		if int(entry.remaining_quantity)==0 and all.has(uid):return "소비 완료 원본 개체의 중복 소유 보존 중지"
	var merged: String=MERGE.merges_error(all,ledger,state.get(MERGES,{}),state.get(PARTITIONS,{}))
	if not merged.is_empty():return merged
	return partition_error(all,ledger,state.get(PARTITIONS,{}),state.get(MERGES,{}))

## Borrowed views are private to this synchronous validator. Keep source
## expiry at the same boundary; the proof memo still stores an owned copy.
static func _validation_consumables(world: Node) -> Variant:
	var service: Object=world.consumable_service
	return service.native_stack_validation_state() if service.has_method("native_stack_validation_state") else service.export_state()

static func _validation_warehouse(world: Node) -> Variant:
	var warehouse: Object=world.warehouse
	return warehouse.native_stack_validation_state() if warehouse.has_method("native_stack_validation_state") else warehouse.snapshot()

static func _validation_floor(world: Node) -> Variant:
	var ground: Object=world.ground_loot
	return ground.native_stack_validation_records() if ground.has_method("native_stack_validation_records") else world._ground_drops_snapshot()

## A staged floor may contain legacy non-receipted rows. Match the first row
## for a physical ID exactly as floor_physical() did: no sorting, coercion of
## numeric IDs, or overwriting the first row with a later duplicate.
static func _floor_transition_index(floor: Array) -> Dictionary:
	var result: Dictionary={}
	for row: Dictionary in floor:
		var physical: Variant=row.get("physical_item",{})
		if not physical is Dictionary:continue
		var uid: Variant=physical.get("id")
		if not (uid is String or uid is StringName):continue
		var key: String=str(uid)
		if not result.has(key):result[key]=physical.get("data",{})
	return result

static func override_error(world: Node,overrides: Dictionary) -> String:
	var inventory: Variant=overrides.get("inventory",world.inventory)
	var instances: Variant=overrides.get("item_instances",world.item_instances)
	var state: Variant=(overrides["consumable_state"] if overrides.has("consumable_state") else _validation_consumables(world))
	var warehouse: Variant=(overrides["warehouse"] if overrides.has("warehouse") else _validation_warehouse(world))
	var floor: Variant=overrides["ground_drops"] if overrides.has("ground_drops") else _validation_floor(world)
	var dormant: Dictionary=world.call("dormant_character_items") if world.has_method("dormant_character_items") else {}
	# A dungeon-ledger-only save stages no native ownership fields. It has the
	# same native inputs and transition as an ordinary save. Reuse proof only
	# on the same deeply compared inventory/instances/consumables/warehouse/
	# floor/dormant characters and source definition; any change revalidates.
	var inputs: Array=[inventory,instances,state,warehouse,floor,dormant,SOURCE.identity()]
	var plain: bool=overrides.is_empty() or (overrides.size()==1 and overrides.has("source_dungeon_play"))
	var unchanged: bool=plain and not _last_valid_inputs.is_empty() and _last_valid_inputs==inputs
	if not unchanged:
		var issue: String=state_error(inventory,instances,state,warehouse,floor,dormant)
		if not issue.is_empty():_last_valid_inputs=[];return issue
		_last_valid_inputs=inputs.duplicate(true) if plain else []
	var ledger: Dictionary=state.get(USES,{})
	# A plain/native-neutral save uses the live bag as the candidate. The ownership
	# proof above (or an exact cached match) already checked every receipt.
	# The second pass exists to check before/after transitions of staged saves.
	if not plain:
		var token_owner: bool=authorizes(overrides) and _candidate_kind in ["enhancement_token","enhancement_token_partition"]
		for uid: String in instances:
			var entry: Variant=instances[uid]
			if entry is Dictionary and entry.has(TOKEN_RANK) and entry.get(TOKEN_RANK)!=world.item_instances.get(uid,{}).get(TOKEN_RANK) and not token_owner:return "비착용 강화 랭크 승인 필요"
		for uid: String in world.item_instances:
			var previous: Variant=world.item_instances[uid]
			if not previous is Dictionary or not previous.has(RECEIPT):continue
			var next: Variant=instances.get(uid)
			# The full candidate proof above already validated this exact entry.
			# A changed or removed live entry still needs both transition proofs.
			if is_same(next,previous):continue
			var before: Dictionary=proof_entry(previous,uid)
			if before.is_empty():return "기존 원본 물리 증명 보존 필요"
			if next==previous:continue
			if token_owner and uid==_partition_parent:continue
			if previous.has(TOKEN_RANK):return "강화된 비착용 토큰의 사용·이전 소유자 미연결"
			if authorizes(overrides) and _candidate_kind in ["partition_warehouse","partition_drop"] and uid==_partition_parent:continue
			if next==null and authorizes(overrides) and _candidate_kind=="warehouse_transfer" and warehouse.get("instances",{}).get(uid)==previous:continue
			if next==null and authorizes(overrides) and _candidate_kind=="floor_drop" and floor_physical(floor,uid)==previous:continue
			if next==null and authorizes(overrides) and _candidate_kind=="plain_handoff" and _ledger_row_matches(ledger.get(uid),before,int(before.used),0,int(before.remaining),"TWILIGHT_plain_stack_handoff"):continue
			var remaining: int=0
			if next!=null:
				var after: Dictionary=proof_entry(next,uid)
				if after.is_empty():return "원본 물리 잔량 변경 후보 불일치"
				remaining=int(after.remaining)
				var expected: Dictionary=previous.duplicate(true)
				expected[QUANTITY]=remaining;expected.source_native_stack_used_quantity=int(before.used)+int(before.remaining)-remaining
				if next!=expected:return "원본 물리 개체의 출처·다른 필드 변경 금지"
			var consumed: int=int(before.remaining)-remaining
			if consumed<1 or not _ledger_row_matches(ledger.get(uid),before,int(before.used)+consumed,remaining):return "원본 물리 차감과 사용 장부 공동 저장 필요"
	for uid: String in world.warehouse.instances:
		var previous: Variant=world.warehouse.instances[uid]
		if not previous is Dictionary or not previous.has(RECEIPT):continue
		if warehouse.get("instances",{}).get(uid)==previous:continue
		if authorizes(overrides) and _candidate_kind=="partition_warehouse" and uid==_partition_parent:continue
		if authorizes(overrides) and _candidate_kind=="warehouse_transfer" and instances.get(uid)==previous:continue
		return "창고 원본 개체의 정확한 이동 소유자 필요 · 영수증 보존"
	var old_floor: Dictionary={}
	var floor_index: Variant=null
	for record: Dictionary in world.ground_loot.records.values():
		var physical: Variant=record.get("physical_item",{})
		if not physical is Dictionary or not physical.get("data") is Dictionary or not physical.data.has(RECEIPT):continue
		var uid: String=str(physical.get("id",""));old_floor[uid]=record
		if floor_index==null:floor_index=_floor_transition_index(floor)
		if floor_index.get(uid,{})==physical.data:continue
		if authorizes(overrides) and _candidate_kind=="floor_pickup" and instances.get(uid)==physical.data:continue
		if authorizes(overrides) and _candidate_kind=="floor_expire" and _floor_record==record:
			var owned: Dictionary=proof_entry(physical.data,uid)
			if not owned.is_empty() and _ledger_row_matches(ledger.get(uid),owned,int(owned.used),0,int(owned.remaining)):continue
		return "바닥 원본 물리 개체의 정확한 습득·소멸 소유자 필요"
	var old_consumables: Dictionary=state if not overrides.has("consumable_state") else _validation_consumables(world)
	if old_consumables.get(AMMO_EQUIPPED,{})!=state.get(AMMO_EQUIPPED,{}) and not (authorizes(overrides) and _candidate_kind in ["ammo_equip","ammo_consume"]):return "원본 탄약 개체 착용은 정확한 소유자 저장이 필요합니다"
	if old_consumables.get(AMMO_RNG,{})!=state.get(AMMO_RNG,{}) and not (authorizes(overrides) and _candidate_kind=="ammo_consume"):return "원본 탄약 독립 난수 변경은 실제 소비 소유자 저장이 필요합니다"
	# Shot, skill-material and box-result journals are no longer kept
	# (save_journal_trim: history no rule reads). The debit itself stays in
	# the bag quantity and use ledger checked above.
	var previous_partitions: Variant=old_consumables.get(PARTITIONS,{})
	var next_partitions: Variant=state.get(PARTITIONS,{})
	if not previous_partitions is Dictionary or not next_partitions is Dictionary:return "기존 물리 분할 장부 형식 보존"
	for id: String in previous_partitions:
		if next_partitions.get(id)!=previous_partitions[id]:return "원본 물리 분할 이력 변경 금지"
	for id: String in next_partitions:
		if not previous_partitions.has(id) and not (authorizes(overrides) and _candidate_kind in ["partition_warehouse","partition_drop","enhancement_token_partition"]):return "새 물리 분할은 정확한 이전 소유자 거래가 필요합니다"
	# Bag stacking runs only through world._merge_native_stacks (in memory, then
	# the next save); a transaction may neither rewrite nor add merge history.
	if old_consumables.get(MERGES,{})!=state.get(MERGES,{}):return "원본 묶음 병합 이력 변경 금지"
	var old_ledger: Variant=old_consumables.get(USES,{})
	if not old_ledger is Dictionary:return "기존 원본 사용 장부 보존 필요"
	for uid: String in old_ledger:
		if ledger.get(uid)==old_ledger[uid]:continue
		if authorizes(overrides) and _candidate_kind in ["partition_warehouse","partition_drop"] and uid==_partition_parent:continue
		if not world.item_instances.has(uid) or not world.item_instances[uid].has(RECEIPT):
			if authorizes(overrides) and _candidate_kind=="floor_expire" and old_floor.has(uid):continue
			return "이미 끝난 원본 사용 영수증 변경 금지"
	return ""

static func stage_debit(world: Node,requests: Array) -> Dictionary:
	var bag: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	var state: Dictionary=world.consumable_service.export_state()
	var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return _failure("원본 물리 사용 장부 형식 보존")
	ledger=ledger.duplicate(true)
	var seen: Dictionary={};var selections: Array=[]
	for request: Variant in requests:
		if not request is Dictionary or request.size()!=5:return _failure("원본 물리 재료 요청5필드 필요")
		for key: String in ["physical_id","quantity","expected_quantity","expected_remaining","source_native_stack_receipt"]:
			if not request.has(key):return _failure("원본 물리 재료 요청 필드 누락")
		var uid: Variant=request.physical_id
		if not uid is String or uid.is_empty() or seen.has(uid):return _failure("원본 물리 개체 중복 요청 금지")
		if world.item_instances.get(uid,{}) is Dictionary and world.item_instances.get(uid,{}).has(TOKEN_RANK):return _failure("강화된 비착용 토큰의 전용 소비자 미연결 · 보유 보존")
		var owned: Dictionary=proof(world,uid)
		if owned.is_empty() or not integer(request.quantity) or int(request.quantity)<1 or int(request.quantity)>int(owned.remaining) or request.expected_quantity!=owned.remaining or request.expected_remaining!=int(owned.remaining)-int(request.quantity) or request.source_native_stack_receipt!=owned.receipt:return _failure("선택한 원본 물리 재료·수량·예상 잔량 불일치")
		var name_value: String=str(owned.record.name)
		if RETIRED_ITEMS.record(owned.record):return _failure(RETIRED_ITEMS.REASON)
		if world._item_locked(name_value,uid) or world._item_locked(name_value) or not integer(bag.get(name_value,0)) or int(bag.get(name_value,0))<int(request.quantity):return _failure("원본 재료 잠금·소지 수량 불일치")
		var deadline: String=D.deadline_problem(owned.record,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if not deadline.is_empty():return _failure(deadline)
		var used: int=int(owned.used)+int(request.quantity);var remaining: int=int(request.expected_remaining)
		bag[name_value]=int(bag[name_value])-int(request.quantity)
		if int(bag[name_value])==0:bag.erase(name_value)
		if remaining==0:instances.erase(uid)
		else:instances[uid][QUANTITY]=remaining;instances[uid].source_native_stack_used_quantity=used
		ledger[uid]=ledger_row(owned,used,remaining)
		selections.append({"physical_id":uid,"inventory_key":name_value,"quantity":int(request.quantity),"remaining_after":remaining,"source_native_stack_receipt":owned.receipt.duplicate(true)})
		seen[uid]=true
	state[USES]=ledger
	var overrides: Dictionary={"inventory":bag,"item_instances":instances,"consumable_state":state}
	var issue: String=override_error(world,overrides)
	if not issue.is_empty():return _failure(issue)
	return {"ok":true,"overrides":overrides,"selections":selections}

static func join_craft_output(world: Node,book: RefCounted,transaction: Dictionary,context: Dictionary) -> Dictionary:
	var output: Dictionary=transaction.get("selected_output",{})
	var quantity: Variant=transaction.get("result_quantity",0)
	if not integer(quantity):return _failure("원본 제작 출력 수량 형식 확인 필요")
	if int(quantity)==0 or output.get("empty_result",false) or output.get("physical",false):return transaction
	var retained: Variant=transaction.get("source_native_retained_output_quantity",0)
	if not integer(retained) or int(retained)>int(quantity):return _failure("원본 반환 수량·출력 수량 불일치")
	quantity=int(quantity)-int(retained)
	if int(quantity)==0:return transaction # Exact old selected units already remain owned.
	var record: Dictionary=book.record(str(output.get("source_id","")),int(output.get("bless_code",0)))
	if record.is_empty():return _failure("원본 제작 출력 정의 미연결 · 재료 보존")
	if output.get("wallet_currency",false) and str(output.get("source_id"))=="26" and record.get("name")=="아데나":return transaction
	var supply: Script=load("res://scripts/cards/native_awakening_supply.gd")
	var typed: bool=supply.call("exact",record,int(output.get("source_id",0)))
	if not typed and record.get("source_projection")!="current523_original_typed_game_dto_v1":return transaction
	if int(output.get("level",-1))!=0 or not integer(transaction.inventory.get(str(record.get("name","")),0)) or int(transaction.inventory.get(str(record.get("name","")),0))<int(quantity):return _failure("원본 제작 출력 강화·소지 수량 불일치")
	var origin: Dictionary={"kind":"source523_compiled_craft","recipe_id":str(context.get("source_recipe_id","")),"rules_sha256":book.digest,"source_output":output.duplicate(true),"source_craft_receipt_id":str(transaction.get("source_craft_receipt_id","")),"selected_native_inputs":context.get("quest_material_review",{}).get("native_requests",[]).duplicate(true)}
	var granted: Dictionary=supply.call("stage_grant",record,int(quantity),transaction.item_instances,origin) if typed else stage_grant(record,int(quantity),transaction.item_instances,origin)
	if not granted.get("ok",false):return _failure("원본 제작 비장비 출력의 물리 소유·사용 계약 연결 대기 · 재료와 난수 보존")
	transaction.item_instances=granted.item_instances
	var receipt_id: String=str(transaction.get("source_craft_receipt_id",""))
	if not receipt_id.is_empty() and transaction.get("consumable_state",{}).get("source_quest_craft_receipts",{}).has(receipt_id):transaction.consumable_state.source_quest_craft_receipts[receipt_id].output_physical_ids.append(str(granted.id))
	return transaction

static func can_supply(record: Dictionary,inventory: Dictionary,instances: Dictionary) -> bool:
	if supply_profile(record).is_empty():return false
	var name_value: String=str(record.get("name",""));var total: int=0
	for uid: String in instances:
		var entry: Variant=instances[uid]
		if not entry is Dictionary or entry.get("name")!=name_value:continue
		var owned: Dictionary=proof_entry(entry,uid)
		if owned.is_empty() or owned.record.get("sourceId")!=record.get("sourceId") or owned.record.get("source_bless_raw")!=record.get("source_bless_raw"):return false
		if total>9007199254740991-int(owned.remaining):return false
		total+=int(owned.remaining)
	return integer(inventory.get(name_value,0)) and int(inventory.get(name_value,0))>=total

static func transfer_warehouse(world: Node,item_name: String,quantity: int,direction: String,uid: String) -> Dictionary:
	if direction not in ["deposit","withdraw"]:return {"handled":false}
	var source: Dictionary=world.item_instances if direction=="deposit" else world.warehouse.instances
	var claims: bool=false
	for entry: Variant in source.values():
		if entry is Dictionary and entry.get("name")==item_name and entry.has(RECEIPT):claims=true;break
	if not claims:return {"handled":false}
	if busy or not str(world.patch523_owner_state_problem).is_empty() or world.quest_service.save_blocked:return _failure("원본 창고 거래 저장 보호 중")
	if source.get(uid,{}) is Dictionary and source.get(uid,{}).has(TOKEN_RANK):return _failure("강화된 비착용 토큰은 창고 이동 미연결 · 보유 보존")
	var owned: Dictionary=proof_entry(source.get(uid),uid)
	if owned.is_empty() or owned.record.get("name")!=item_name:return _failure("이동할 실제 원본 묶음 개체를 선택하세요")
	if quantity<1 or quantity>99 or quantity>int(owned.remaining):return _failure("선택한 원본 묶음의 실제 잔량 안에서 수량을 지정하세요")
	if world._item_locked(item_name,uid) or world._item_locked(item_name):return _failure("잠긴 원본 개체는 이동할 수 없습니다")
	if direction=="deposit" and (NATIVE_FIELDS.full(owned.receipt).source_original_item.get("IsStorable")!=true or world._is_instance_equipped(uid)):return _failure("원본 보관 제한·장착 조건 미충족")
	if direction=="withdraw" and world._inventory_total_weight()+quantity*maxi(0,int(world.item_weight_index.get(item_name,3)))>world._carrying_capacity():return _failure("기존 소지 무게 한도 초과")
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	var warehouse: Dictionary=world.warehouse.snapshot()
	var from_counts: Dictionary=inventory if direction=="deposit" else warehouse.stacks
	var to_counts: Dictionary=warehouse.stacks if direction=="deposit" else inventory
	var from_instances: Dictionary=instances if direction=="deposit" else warehouse.instances
	var to_instances: Dictionary=warehouse.instances if direction=="deposit" else instances
	if not integer(from_counts.get(item_name,0)) or int(from_counts.get(item_name,0))<quantity or not integer(to_counts.get(item_name,0)) or int(to_counts.get(item_name,0))>9007199254740991-quantity or to_instances.has(uid):return _failure("원본 창고 수량·개체 ID 충돌 · 기존 보유 보존")
	if direction=="deposit" and int(to_counts.get(item_name,0))>1000000-quantity:return _failure("기존 창고 저장 수량 한도 초과")
	var moved_uid: String=uid;var partition: Dictionary={}
	if quantity<int(owned.remaining):
		partition=prepare_partition(world,from_instances[uid],uid,quantity,world.consumable_service.export_state())
		if not partition.get("ok",false):return partition
		moved_uid=str(partition.child_id)
	from_counts[item_name]=int(from_counts[item_name])-quantity
	if int(from_counts[item_name])==0:from_counts.erase(item_name)
	to_counts[item_name]=int(to_counts.get(item_name,0))+quantity
	if partition.is_empty():to_instances[uid]=from_instances[uid].duplicate(true);from_instances.erase(uid)
	else:from_instances[uid]=partition.parent;to_instances[moved_uid]=partition.child
	var payload: Dictionary={"inventory":inventory,"item_instances":instances,"warehouse":warehouse}
	if not partition.is_empty():payload["consumable_state"]=partition.consumable_state
	busy=true;_candidate_kind="partition_warehouse" if not partition.is_empty() else "warehouse_transfer";_partition_parent=uid if not partition.is_empty() else "";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";_partition_parent=""
	if saved!=OK:
		world.patch523_owner_state_problem="원본 창고 저장 실패·결과 미확정 · 정상 저장 불러오기 전 재이동 중지"
		busy=false;return _failure(world.patch523_owner_state_problem)
	world.inventory=inventory;world.item_instances=instances;world.warehouse.stacks=warehouse.stacks;world.warehouse.instances=warehouse.instances
	if payload.has("consumable_state"):world.consumable_service.import_state(payload.consumable_state)
	world.deferred_save.cancel();busy=false
	return {"handled":true,"ok":true,"saved":true,"physical_id":moved_uid,"parent_physical_id":uid,"quantity":quantity,"direction":direction,"message":"원본 영수증과 실제 수량을 보존해 창고 이동했습니다"}

static func floor_physical(floor: Array,uid: String) -> Dictionary:
	for record: Dictionary in floor:
		if record.get("physical_item",{}).get("id")==uid:return record.physical_item.get("data",{})
	return {}

static func can_remove_floor(record: Dictionary) -> bool:
	if not busy or not _floor_commit_confirmed or _candidate_kind not in ["floor_pickup","floor_expire"] or _floor_record!=record:return false
	for next: Dictionary in _candidate.get("ground_drops",[]):
		if next.get("id")==record.get("id"):return false
	return true

static func _floor_payload(record: Dictionary) -> Dictionary:
	var physical: Variant=record.get("physical_item")
	if not physical is Dictionary or not physical.get("data") is Dictionary or not physical.data.has(RECEIPT):return {}
	var uid: String=str(physical.get("id",""));var owned: Dictionary=proof_entry(physical.data,uid)
	if owned.is_empty() or not integer(record.get("quantity")) or int(record.quantity)<1 or int(owned.remaining)!=int(record.quantity) or record.get("player_dropped")!=true or record.get("item_name")!=physical.data.get("name") or record.get("item_record")!=physical.data.get("record"):return {}
	return {"uid":uid,"owned":owned,"physical":physical.data}

static func _clear_floor_candidate() -> void:
	_candidate.clear();_candidate_kind="";_floor_record.clear();_floor_commit_confirmed=false;_partition_parent="";busy=false

## Moves `quantity` units of one physical original stack to the floor as one
## floor record (a partition child with exactly that remaining quantity).
static func drop(world: Node,reference: String,requested_position: Vector2,quantity: int=1) -> Dictionary:
	var selected: Dictionary=world._parse_enhancement_target(reference)
	var name_value: String=str(selected.get("name",""));var uid: String=str(selected.get("id",""))
	var claims: bool=false
	for entry: Variant in world.item_instances.values():
		if entry is Dictionary and entry.get("name")==name_value and entry.has(RECEIPT):claims=true;break
	if not claims:return {"handled":false}
	if busy or not str(world.patch523_owner_state_problem).is_empty() or world.quest_service.save_blocked:return _failure("원본 바닥 이동 저장 보호 중")
	if world.item_instances.get(uid,{}).has(TOKEN_RANK):return _failure("강화된 비착용 토큰은 바닥 이동 미연결 · 보유 보존")
	var owned: Dictionary=proof(world,uid)
	if owned.is_empty() or owned.record.get("name")!=name_value:return _failure("바닥으로 이동할 실제 원본 개체를 선택하세요")
	if world.hp<=0 or world.death_recovery.blocked() or world._item_locked(name_value,uid) or world._item_locked(name_value) or world._is_instance_equipped(uid) or NATIVE_FIELDS.full(owned.receipt).source_original_item.get("IsDroppable")!=true:return _failure("원본 내려놓기·잠금·장착·생존 조건 미충족")
	if not requested_position.is_finite():return _failure("유효한 바닥 좌표 필요")
	if quantity<1 or quantity>int(owned.remaining):return _failure("내려놓을 원본 수량 범위 초과")
	var point: Vector2=world.player.global_position+(requested_position-world.player.global_position).limit_length(96.0)
	if not world._is_walkable_world(point) or not world._has_line_of_sight_world(world.player.global_position,point):point=world.player.global_position
	var physical: Dictionary=world.item_instances[uid].duplicate(true)
	var moved_uid: String=uid;var partition: Dictionary={}
	if int(owned.remaining)>quantity:
		partition=prepare_partition(world,physical,uid,quantity,world.consumable_service.export_state())
		if not partition.get("ok",false):return partition
		physical=partition.child;moved_uid=str(partition.child_id)
	var record: Dictionary=world.ground_loot.stage_spawn(name_value,point,quantity,"",{"player_dropped":true,"item_record":physical.record.duplicate(true),"physical_item":{"id":moved_uid,"data":physical}})
	if record.is_empty():return _failure("기존 바닥 배치 공간 없음 · 소유 보존")
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	if not integer(inventory.get(name_value,0)) or int(inventory[name_value])<quantity:return _failure("원본 소지 수량 불일치")
	inventory[name_value]=int(inventory[name_value])-quantity
	if int(inventory[name_value])==0:inventory.erase(name_value)
	if partition.is_empty():instances.erase(uid)
	else:instances[uid]=partition.parent
	var floor: Array=world._ground_drops_snapshot();floor.append(record.duplicate(true))
	var payload: Dictionary={"inventory":inventory,"item_instances":instances,"ground_drops":floor}
	if not partition.is_empty():payload["consumable_state"]=partition.consumable_state
	busy=true;_candidate_kind="partition_drop" if not partition.is_empty() else "floor_drop";_partition_parent=uid if not partition.is_empty() else "";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	if saved!=OK:
		world.patch523_owner_state_problem="원본 바닥 이동 저장 실패·결과 미확정 · 정상 저장 불러오기 전 재이동 중지";_clear_floor_candidate();return _failure(world.patch523_owner_state_problem)
	var view: Button=world.ground_loot.publish_spawn(record)
	if view==null:
		world.patch523_owner_state_problem="원본 바닥 이동 저장 후 표시 채택 미확정 · 정상 저장 불러오기 필요";_clear_floor_candidate();return _failure(world.patch523_owner_state_problem)
	world.inventory=inventory;world.item_instances=instances
	if payload.has("consumable_state"):world.consumable_service.import_state(payload.consumable_state)
	world.deferred_save.cancel();_clear_floor_candidate()
	return {"handled":true,"ok":true,"saved":true,"physical_id":moved_uid,"parent_physical_id":uid,"quantity":quantity,"message":"원본 물리 개체 %d개를 바닥으로 이동했습니다" % quantity}

static func collect_floor(world: Node,view: Button,record: Dictionary) -> Dictionary:
	var envelope: Variant=record.get("physical_item",{})
	if not envelope is Dictionary:return {"handled":false}
	var physical: Variant=envelope.get("data",{})
	if not physical is Dictionary or not physical.has(RECEIPT):return {"handled":false}
	if busy or not str(world.patch523_owner_state_problem).is_empty() or world.quest_service.save_blocked:return _failure("원본 바닥 습득 저장 보호 중")
	var source: Dictionary=_floor_payload(record)
	if source.is_empty() or not world.ground_loot.valid_view(view) or world.item_instances.has(source.uid) or world.warehouse.instances.has(source.uid) or world.hp<=0:return _failure("원본 바닥 개체·소유·생존 조건 불일치")
	var point: Array=record.get("position",[])
	if point.size()!=2:return _failure("바닥 좌표 구조 오류")
	var destination:=Vector2(float(point[0]),float(point[1]))
	if not destination.is_finite() or world.player.global_position.distance_to(destination)>world.GROUND_PICKUP_RADIUS or Time.get_ticks_msec()-int(view.get("visible_since"))<world.ground_loot.MIN_VISIBLE_MS or not world._has_line_of_sight_world(world.player.global_position,destination):return _failure("기존 바닥 습득 거리·시간·시야 조건 미충족")
	var name_value: String=str(source.physical.name)
	var units: int=int(source.owned.remaining)
	if world._inventory_total_weight()+maxi(0,int(world.item_weight_index.get(name_value,3)))*units>world._carrying_capacity():return _failure("기존 소지 무게 한도 초과")
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	if not integer(inventory.get(name_value,0)) or int(inventory.get(name_value,0))>=9007199254740991-units:return _failure("원본 습득 수량 범위 초과")
	inventory[name_value]=int(inventory.get(name_value,0))+units;instances[source.uid]=source.physical.duplicate(true)
	var floor: Array=[];var found: bool=false
	for previous: Dictionary in world._ground_drops_snapshot():
		if previous.get("id")==record.get("id"):
			if found or previous!=record:return _failure("선택 바닥 상태 변경")
			found=true
		else:floor.append(previous)
	if not found:return _failure("선택 바닥 개체가 없습니다")
	var payload: Dictionary={"inventory":inventory,"item_instances":instances,"ground_drops":floor}
	busy=true;_candidate_kind="floor_pickup";_candidate=payload.duplicate(true);_floor_record=record.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	if saved!=OK:
		world.patch523_owner_state_problem="원본 재습득 저장 실패·결과 미확정 · 정상 저장 불러오기 전 재사용 중지";_clear_floor_candidate();return _failure(world.patch523_owner_state_problem)
	_floor_commit_confirmed=true
	var taken: Dictionary=world.ground_loot.take(view,world.player.global_position,world.GROUND_PICKUP_RADIUS)
	if taken.is_empty():
		world.patch523_owner_state_problem="원본 재습득 저장 후 바닥 채택 미확정 · 정상 저장 불러오기 필요";_clear_floor_candidate();return _failure(world.patch523_owner_state_problem)
	world.inventory=inventory;world.item_instances=instances;world.deferred_save.cancel();_clear_floor_candidate()
	return {"handled":true,"ok":true,"saved":true,"record":taken}

static func expire_floor(world: Node,record: Dictionary) -> bool:
	if busy or not str(world.patch523_owner_state_problem).is_empty() or world.quest_service.save_blocked:return false
	var source: Dictionary=_floor_payload(record)
	if source.is_empty() or world.ground_loot.records.get(str(record.get("id","")))!=record or not is_finite(float(record.get("expires_at",INF))) or float(record.get("expires_at",INF))>Time.get_unix_time_from_system():return false
	var state: Dictionary=world.consumable_service.export_state();var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return false
	ledger=ledger.duplicate(true);ledger[source.uid]=ledger_row(source.owned,int(source.owned.used),0,int(source.owned.remaining));state[USES]=ledger
	var floor: Array=[]
	for previous: Dictionary in world.ground_loot.records.values():
		if previous.get("id")!=record.get("id"):floor.append(previous.duplicate(true))
	var payload: Dictionary={"ground_drops":floor,"consumable_state":state}
	busy=true;_candidate_kind="floor_expire";_candidate=payload.duplicate(true);_floor_record=record.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	if saved!=OK:
		world.patch523_owner_state_problem="원본 바닥 유효시간 소멸 저장 실패·결과 미확정 · 정상 저장 불러오기 필요";_clear_floor_candidate();return false
	_floor_commit_confirmed=true
	if not world.ground_loot._remove(str(record.id)):
		world.patch523_owner_state_problem="원본 바닥 소멸 저장 후 채택 미확정 · 정상 저장 불러오기 필요";_clear_floor_candidate();return false
	world.consumable_service.import_state(state);world.deferred_save.cancel();_clear_floor_candidate()
	return true

static func partition_error(all: Dictionary,ledger: Dictionary,partitions: Variant,merges: Variant={}) -> String:
	if not partitions is Dictionary:return "원본 물리 분할 장부 형식 확인 필요"
	var receipts: Dictionary={};var transferred: Dictionary={};var by_parent: Dictionary={}
	for uid: String in all:
		if all[uid] is Dictionary and all[uid].has(RECEIPT):receipts[uid]=all[uid][RECEIPT];transferred[uid]=int(all[uid].get(TRANSFERRED,0))
	for uid: String in ledger:
		receipts[uid]=ledger[uid].receipt;transferred[uid]=int(ledger[uid].get("transferred_quantity",0))
	MERGE.add_absorbed(receipts,transferred,merges)
	for id: String in partitions:
		var event: Variant=partitions[id]
		if not event is Dictionary or event.get("schema")!=1 or not event.get("parent_id") is String or not event.get("child_id") is String or event.parent_id==event.child_id or not event.get("parent_receipt") is Dictionary or not event.get("child_receipt") is Dictionary:return "원본 분할 거래 정체 확인 필요"
		for key: String in ["quantity","before_remaining","after_remaining","before_transferred","after_transferred","used_at_partition"]:
			if not integer(event.get(key)):return "원본 분할 수량 형식 불일치"
		if int(event.quantity)<1 or int(event.quantity)>=int(event.before_remaining) or int(event.after_remaining)!=int(event.before_remaining)-int(event.quantity) or int(event.after_transferred)!=int(event.before_transferred)+int(event.quantity):return "원본 분할 전후 잔량 불일치"
		if not receipt_valid(event.parent_receipt,event.parent_id) or not receipt_valid(event.child_receipt,event.child_id) or receipts.get(event.parent_id)!=event.parent_receipt or receipts.get(event.child_id)!=event.child_receipt:return "원본 분할 부모·자식 영수증 보존 필요"
		var child: Dictionary=event.child_receipt
		if child.schema!=2 or child.origin.get("partition_id")!=id or child.origin.get("parent_physical_id")!=event.parent_id or child.origin.get("parent_receipt")!=event.parent_receipt or child.granted_quantity!=event.quantity or int(event.before_remaining)+int(event.before_transferred)+int(event.used_at_partition)!=int(event.parent_receipt.granted_quantity):return "원본 지급량과 분할 배정량의 불변 관계 불일치"
		if not by_parent.has(event.parent_id):by_parent[event.parent_id]=[]
		by_parent[event.parent_id].append(event)
	for uid: String in receipts:
		var receipt: Dictionary=receipts[uid]
		if receipt.get("schema")==2:
			var event: Variant=partitions.get(str(receipt.origin.partition_id))
			if not event is Dictionary or event.get("child_id")!=uid or event.get("child_receipt")!=receipt:return "근거 없는 원본 분할 소유 생성 금지"
		var events: Array=by_parent.get(uid,[]);events.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.before_transferred)<int(b.before_transferred))
		var amount: int=0
		for event: Dictionary in events:
			if int(event.before_transferred)!=amount:return "원본 분할 장부 순서·합계 불일치"
			amount+=int(event.quantity)
		if amount!=int(transferred.get(uid,0)):return "원본 물리 이전량과 분할 장부 합계 불일치"
	return ""

static func prepare_partition(world: Node,parent: Dictionary,uid: String,quantity: int,state: Dictionary) -> Dictionary:
	var owned: Dictionary=proof_entry(parent,uid)
	if owned.is_empty() or quantity<1 or quantity>=int(owned.remaining):return _failure("실제 원본 잔량 안의 부분 수량 필요")
	var events: Variant=state.get(PARTITIONS,{})
	var ledger: Variant=state.get(USES,{})
	if not events is Dictionary or not ledger is Dictionary:return _failure("원본 분할·사용 장부 형식 보존")
	var child_id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while world.item_instances.has(child_id) or world.warehouse.instances.has(child_id) or not floor_physical(world.ground_loot.records.values(),child_id).is_empty() or ledger.has(child_id):child_id=Crypto.new().generate_random_bytes(16).hex_encode()
	var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while events.has(id):id=Crypto.new().generate_random_bytes(16).hex_encode()
	var receipt: Dictionary=owned.receipt.duplicate(true);receipt.schema=2;receipt.issued_physical_id=child_id;receipt.granted_quantity=quantity
	receipt.origin={"kind":"owned_quantity_partition","partition_id":id,"parent_physical_id":uid,"parent_receipt":owned.receipt.duplicate(true)}
	var child: Dictionary=parent.duplicate(true);child[QUANTITY]=quantity;child[RECEIPT]=receipt;child.source_native_stack_used_quantity=0;child.erase(TRANSFERRED)
	var after: Dictionary=parent.duplicate(true);after[QUANTITY]=int(owned.remaining)-quantity;after[TRANSFERRED]=int(owned.transferred)+quantity
	var next_owned: Dictionary=owned.duplicate(true);next_owned.transferred=int(owned.transferred)+quantity
	events=events.duplicate(true);events[id]={"schema":1,"parent_id":uid,"child_id":child_id,"quantity":quantity,"before_remaining":owned.remaining,"after_remaining":after[QUANTITY],"before_transferred":owned.transferred,"after_transferred":after[TRANSFERRED],"used_at_partition":owned.used,"parent_receipt":owned.receipt.duplicate(true),"child_receipt":receipt.duplicate(true)}
	ledger=ledger.duplicate(true);ledger[uid]=ledger_row(next_owned,int(owned.used),int(after[QUANTITY]))
	var result: Dictionary=state.duplicate(true);result[PARTITIONS]=events;result[USES]=ledger
	return {"ok":true,"parent":after,"child":child,"child_id":child_id,"consumable_state":result,"partition_id":id}

# Exact source-reader -> existing physical native-use boundary. Original raw
# ItemClass and opaque immutable ownership proof stay separate arguments.
static func use_owned_original(world: Node,original_item: Dictionary,request: Dictionary) -> Dictionary:
	if RETIRED_ITEMS.item(original_item.get("ID")):return _failure(RETIRED_ITEMS.REASON)
	if request.size()!=5:return _failure("원문 소모품 선택 소유 요청5필드 필요")
	var quest: bool=request.has("quest_reward_receipt")
	var field: String="quest_reward_receipt" if quest else "source_native_stack_receipt"
	for key: String in ["physical_id","quantity","expected_quantity","expected_remaining",field]:
		if not request.has(key):return _failure("원문 소모품 소유 증명 필드 누락")
	if not request.physical_id is String or request.physical_id.is_empty() or not integer(request.quantity) or int(request.quantity)!=1 or not integer(request.expected_quantity) or not integer(request.expected_remaining):return _failure("원문 소모품은 실제 선택 개체의1단위와 정확한 정수 잔량을 지정하세요")
	if quest:return use_quest_original_bag(world,original_item,request)
	var owned: Dictionary=proof(world,request.physical_id)
	if owned.is_empty():return _failure("원문 행·선택 개체·최초량·현재 잔량 증명 불일치")
	# A receipt proves ownership, but compact receipts are not item records.
	# proof() verifies and returns the canonical record separately.
	var item: Dictionary=NATIVE_FIELDS.full(owned.record).get("source_original_item",{})
	if item.is_empty() or original_item!=item or original_item!=SOURCE.row("ItemClass",int(owned.receipt.item_class_id)) or request.source_native_stack_receipt!=owned.receipt or request.expected_quantity!=owned.remaining or request.expected_remaining!=int(owned.remaining)-1:return _failure("원문 행·선택 개체·최초량·현재 잔량 증명 불일치")
	if profile(owned.record).is_empty():
		var result: Dictionary=_failure("해당 원문 소모품의 실제 효과 소유자 연결 대기 · 소유와 영수증 보존")
		result["source_use_supported"]=false;result["source_problem"]="current_original_effect_owner_required"
		return result
	return try_use(world,str(owned.record.name),str(request.physical_id))

static func use_quest_original_bag(world: Node,original_item: Dictionary,request: Dictionary) -> Dictionary:
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return _failure("원본 상자 저장 보호 중")
	var uid: String=str(request.physical_id);var owned: Dictionary=QUEST_OWN.proof(world,uid)
	if not owned.get("ok",false) or owned.get("source_use_immediately",true) or original_item!=owned.get("source_item") or SOURCE.approximated_item(original_item)!=SOURCE.row("ItemClass",int(owned.get("item_class_id",0))) or world.item_instances.get(uid,{}).get("quest_reward_receipt")!=request.quest_reward_receipt or request.expected_quantity!=owned.quantity or request.expected_remaining!=int(owned.quantity)-1:return _failure("원본 퀘스트 상자 지급·물리 잔량 증명 불일치")
	if world.hp<=0 or not world._patch523_item_allowed() or world._option_awakening_busy() or world._item_locked(str(owned.inventory_key),uid) or world._item_locked(str(owned.inventory_key)):return _failure("원본 상자 생존·사용·잠금 조건 미충족")
	var definition: Dictionary=D.definition_id(str(int(owned.item_class_id)))
	var record: Dictionary=D.variant_item(definition.get("native_record",{}),int(owned.bless_code_id))
	var executor: Script=load("res://scripts/loot/patch523_item_use.gd")
	record=executor.call("action_record",world,record)
	var issue: String=str(executor.call("eligibility",world,record))
	if not issue.is_empty():return _failure(issue)
	var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
	if spec.get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward","source_selectable_bag","source_skill_book","fixed_card"] or spec.get("activation_status")!="unrestricted":return _failure("원본 퀘스트 아이템의 현재 효과 소유자 연결 대기")
	if world.is_player_concealed() and not spec.get("can_use_when_invisible",false):return _failure("원본 조건: 은신 중 사용할 수 없습니다")
	if float(world.item_use_cooldowns.get("m523:item:"+str(int(owned.item_class_id)),0.0))>0:return _failure("원본 상자 재사용 대기")
	var selected_owned: Dictionary={"record":record,"remaining":int(owned.quantity),"receipt":request.quest_reward_receipt,"ownership_kind":"quest"}
	if spec.kind=="source_skill_book":return learn_skill_book(world,uid,selected_owned,record,spec)
	if spec.kind=="fixed_card":return use_fixed_card(world,uid,selected_owned,record,spec)
	if spec.kind in ["source_selectable_reward","source_selectable_bag"]:return selection_pending(world,uid,selected_owned,record,spec)
	return use_bag(world,uid,selected_owned,record,spec)

static func restoration_metadata(record: Dictionary) -> Dictionary:
	var id: int=int(record.get("source_item_class_id",0))
	if id not in [237,236] or record.get("source_bless_raw")!=1:return {"ok":false}
	var values: Dictionary=RESTORATION._source_items()
	var definition: Dictionary=D.item_definition(record);var raw: Dictionary=definition.get("original_item",{})
	var held: Dictionary=RESTORATION.source_provenance.get("selected_inputs",{}).get(str(id),{})
	if values.get(str(id),{}).is_empty() or RESTORATION.source_input_identity!=SOURCE.identity() or held.get("item_class")!=raw or raw.get("TargettingTypeID")!=1 or not str(raw.get("ServiceRegionCode","")).is_empty() or definition.get("category",{}).get("Name")!="Potion" or definition.get("category",{}).get("IsConsumable")!=true:return {"ok":false}
	var spec: Dictionary=values[str(id)];var heal: Dictionary=record.get("heal_spec",{})
	if heal.get("HPRestoration",0)!=spec.base or heal.get("HPRestorationDiceNumber",0)!=spec.dice_count or heal.get("HPRestorationDiceSpotCount",0)!=spec.dice_sides:return {"ok":false}
	var allowed: Dictionary={"HPRestoration":"Value","HPRestorationDiceNumber":"Value","HPRestorationDiceSpotCount":"Value","ItemConsumeDelay":"MilliSeconds","ItemConsumeEffectSpriteID":"SpriteID","AutoUseRegistrable":"TrueFalse"}
	var seen: Dictionary={};var result: Dictionary={"ok":true,"can_use_when_invisible":raw.get("CanUseWhenInvisible",false),"auto_use_registrable":false,"consume_effect_sprite_id":0}
	for row: Dictionary in definition.get("item_bonus",[]):
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""));var bonus: Dictionary=row.get("bonus",{})
		if not allowed.has(name_value) or seen.has(name_value) or row.get("IsPossession")!=false or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or row.get("unit",{}).get("Name")!=allowed[name_value]:return {"ok":false}
		seen[name_value]=true
		if name_value=="AutoUseRegistrable":
			if whole(bonus.get("Value")) not in [0,1]:return {"ok":false}
			result.auto_use_registrable=bonus.Value==1
		elif name_value=="ItemConsumeDelay":result["source_consume_delay_ms"]=int(bonus.Value)
		elif name_value=="ItemConsumeEffectSpriteID":result.consume_effect_sprite_id=int(bonus.Value)
	# AutoUseRegistrable is optional: the 523 rows of #236/#237 carry only the
	# five restoration/consume rows (no AutoUseRegistrable => not auto-use).
	for required: String in ["HPRestoration","HPRestorationDiceNumber","HPRestorationDiceSpotCount","ItemConsumeDelay","ItemConsumeEffectSpriteID"]:
		if not seen.has(required):return {"ok":false}
	return result if result.get("source_consume_delay_ms")==1000 else {"ok":false}

static func presentation_only(record: Dictionary,spec: Dictionary) -> bool:
	if spec.get("activation_status")!="blocked" or spec.get("blocked_reasons",[]).is_empty():return false
	var flags: Dictionary={"UIShowFilter":"Value","NoAnnounce":"TrueFalse"};var recognized: Dictionary={}
	for row: Dictionary in D.item_definition(record).get("item_bonus",[]):
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""))
		if not flags.has(name_value):continue
		if row.get("IsPossession")!=false or row.get("bonus",{}).get("BonusApplicationTypeID")!=0 or row.bonus.get("BonusApplicationTargetID")!=0 or row.get("unit",{}).get("Name")!=flags[name_value] or whole(row.bonus.get("Value")) not in [0,1]:return false
		recognized["unsupported_item_bonus:"+name_value]=true
	if recognized.is_empty():return false
	for reason: String in spec.blocked_reasons:
		if recognized.has(reason):continue
		if reason in ["source_item_lifetime_unresolved","conditional_or_possession_item_bonus:DeleteTime"] and NATIVE_FIELDS.has_field(record,"source_delete_time_raw") and not record.get("source_delete_time_unresolved",false):continue
		return false
	return true

static func current_class(world: Node) -> int:
	var matches: Array=[]
	for entry: Dictionary in preload("res://scripts/lineagem_base508.gd").cards().get("classes",[]):
		var raw: Variant=entry.get("source_original")
		if entry.get("name")==world.job_class and raw is Dictionary and integer(raw.get("ID")) and raw.get("CanCreateClient")==true and SOURCE.row("Class",int(raw.ID))==raw:matches.append(int(raw.ID))
	return int(matches[0]) if matches.size()==1 else 0

static func use_bag(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	var described: bool = spec.get("kind") == "source_event_box"
	var weighted: bool = spec.get("kind") in ["source_weighted_bag","mixed_rewards_bag"]
	if spec.get("activation_status")!="unrestricted" or (not described and not weighted and spec.get("kind")!="guaranteed_bag"):return _failure("원본 상자 실행 정의 연결 필요")
	var requirements: Dictionary=spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or not str(requirements.get("service_region_code","")).is_empty():return _failure("원본 상자 사용 대상·서비스 조건 미지원")
	if weighted and not world.ui_preferences.get("patch523_source_reward_bags_enabled",true):return _failure("기존 원본 확률상자 선택 정책이 꺼져 있습니다 · 상자 보존")
	var class_id: int=current_class(world);var needs_class: bool=weighted
	for reward: Dictionary in spec.get("rewards",[]):
		if not reward.get("class_ids",[]).is_empty():needs_class=true
	if needs_class and class_id<=0:return _failure("정확한 현재 원본 직업 정체 연결 필요 · 클래스 풀을 합치지 않습니다")
	var executor: Script=load("res://scripts/loot/patch523_item_use.gd")
	var supplier: Script=load("res://scripts/loot/patch523_item_inventory.gd")
	var view:=SupplierView.new();view.host=world;view.inventory=world.inventory;view.item_instances=world.item_instances;view.gold=world.gold
	# Every eligible positive candidate must have a real registered supplier.
	# Missing candidates never disappear or renormalize a random pool.
	# TWILIGHT 근사 (2): LuckyBagLimitedItemPossession — refused while that many are owned.
	for limit: Dictionary in spec.get("approx_possession_limits",[]):
		var held: int=0
		for key: Variant in world.item_instances:
			var value: Variant=world.item_instances[key]
			if value is Dictionary and value.get("record") is Dictionary and int(value.record.get("source_item_class_id",0))==int(limit.item_class_id):
				var stack: Dictionary=proof(world,str(key))
				held+=int(stack.get("remaining",1)) if not stack.is_empty() else 1
		if held>=int(limit.max):view.free();return _failure("원본 조건: 이미 보유한 아이템이라 열 수 없습니다 · 상자 보존 (TWILIGHT 근사)")
	for reward: Dictionary in spec.get("rewards",[]):
		if not executor.call("class_matches",reward.get("class_ids",[]),class_id) and not class_id in spec.get("approx_class_pool",[]):continue
		if reward.get("entity_type_id")==0 and int(reward.get("probability_raw",0))<=0:continue
		if reward.has("approx_card"):
			if card_binding(world,str(reward.approx_card.card_kind),int(reward.approx_card.card_id)).is_empty():view.free();return _failure("지급할 원본 카드 자료가 미설치 상태입니다 · 상자 보존")
			continue
		var definition: Dictionary=D.definition_id(str(int(reward.get("item_class_id",0))))
		var item: Dictionary=D.variant_item(definition.get("native_record",{}),int(reward.get("bless_raw",0)))
		if item.is_empty() or definition.get("original_item",{}).get("TestItem")!=false or definition.get("excluded",false) or not NATIVE_FIELDS.field(item,"source_condition_pending",[]).is_empty():view.free();return _failure("전체 원본 보상 정체·사용 공급 조건 미연결 · 후보 제거 없이 상자 보존")
		var deadline: String=D.deadline_problem(item,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if not deadline.is_empty():view.free();return _failure(deadline)
		var quote_origin := {"kind":"source_native_bag_candidate_quote","input_physical_id":uid}
		if described: quote_origin["story_desc_id"] = spec.story_desc_id
		else: quote_origin["entity_id"] = reward.source_entity_id
		var ready: Dictionary=supplier.call("stage",view,[{"item_class_id":int(reward.item_class_id),"amount":int(reward.amount),"bless_raw":int(reward.bless_raw),"enchant":int(reward.enchant)}],quote_origin)
		if not ready.get("ok",false):view.free();return _failure(str(ready.get("error","전체 원본 보상 공급자 연결 대기")))
	view.free()
	var candidate_rng:=RandomNumberGenerator.new();candidate_rng.seed=world.rng.seed;candidate_rng.state=world.rng.state
	var selected: Dictionary=executor.call("select_rewards",spec,class_id,candidate_rng,clampi(int(world.ui_preferences.get("patch523_reward_bag_draw_count",1)),1,10))
	if not selected.get("ok",false):return _failure("원본 전체 보상 풀·선택 계약 불일치")
	var origin: Dictionary
	var evidence: Dictionary
	if described:
		origin = {"kind":"twilight_event_box_from_description","story_desc_id":spec.story_desc_id,"omitted_quest_ids":spec.omitted_quest_ids,"approximation":spec.approximation}
		evidence = {"story_desc_id":spec.story_desc_id,"class_id":class_id}
	else:
		origin = {"kind":"current_original_native_bag","lucky_bag_class_id":spec.lucky_bag_class_id,"draw_count_origin":spec.get("draw_count_origin","all_source_IsGiven")}
		evidence = {"original_lucky_bag_class":spec.original_lucky_bag_class.duplicate(true),"class_id":class_id,"draw_count_origin":spec.get("draw_count_origin","all_source_IsGiven")}
	return commit_owned_rewards(world,uid,owned,record,spec,selected.rewards,candidate_rng,origin,evidence)

# Source UI receives this immutable proposal; it never creates a dialog or
# consumes an input. Confirmation re-reads source/ownership rather than trusting it.
static func selection_pending(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	var lifetime: int=int(spec.get("source_owned_lifetime_seconds",0))
	if lifetime>0:
		var owner: Variant=world.get("item_life523")
		if not owner is RefCounted or owner.life_seconds(record)!=lifetime or owner.remaining(uid)<=0:
			return _failure("선택 상자의 수명이 끝났거나 현재 소유 시점을 확인할 수 없습니다 · 상자 보존")
	var bag: bool=spec.get("kind")=="source_selectable_bag"
	if spec.get("kind") not in ["source_selectable_reward","source_selectable_bag"] or spec.get("activation_status")!="unrestricted" or whole(spec.get("select_max_count"))!=1:return _failure("원문 선택 보상 규칙 연결 대기")
	var class_id: int=current_class(world)
	if class_id<=0 or class_id not in spec.get("source_class_domain",[]) or (not bag and whole(spec.get("original_reward",{}).get("row",{}).get("CharacterClassID")) not in [0,class_id]):return _failure("원문 선택 보상의 실제 직업 조건 불일치")
	var requirements: Dictionary=spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or not str(requirements.get("service_region_code","")).is_empty():return _failure("원문 선택 보상 사용 대상·서비스 조건 미지원")
	var choices: Array=[]
	for reward: Dictionary in spec.get("rewards",[]):
		if RETIRED_ITEMS.item(reward.get("item_class_id")):continue
		if not reward.get("class_ids",[]).is_empty() and class_id not in reward.class_ids:continue
		if reward.has("exact_choice_card") and card_binding(world,str(reward.exact_choice_card.card_kind),int(reward.exact_choice_card.card_id)).is_empty():
			return _failure("선택 보상의 원본 카드 일부를 아직 불러올 수 없습니다 · 상자 보존")
		choices.append(reward.duplicate(true))
	if choices.is_empty():return _failure("원문 직업에 맞는 선택 보상이 없습니다")
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1}
	request["quest_reward_receipt" if owned.get("ownership_kind")=="quest" else RECEIPT]=owned.receipt.duplicate(true)
	var result: Dictionary=_failure("원본 UI에서 보상을 선택하세요 · 선택 전 아이템과 잔량 보존")
	result.merge({"requires_original_selection":true,"original_item":NATIVE_FIELDS.full(record).source_original_item.duplicate(true),"ownership_request":request,"source_entities":spec.source_entities.duplicate(true),"choices":choices,"claim_method":"consumable_service.claim_owned_original_selection","selection_kind":spec.kind,"select_max_count":1,"new_ui_created":false})
	if bag:result.merge({"lucky_bag_class_id":spec.lucky_bag_class_id,"entity_id_namespace":"LuckyBagEntityView.ID"})
	else:result.merge({"select_reward_id":spec.select_reward_id,"reward_id":spec.reward_id,"entity_id_namespace":"ComplexRewardEntity.ID" if spec.get("source_complex_reward",false) else "SelectRewardEntity.ID"})
	if spec.get("source_complex_reward",false):result["fixed_rewards"]=spec.get("fixed_rewards",[]).duplicate(true) # preview only; never accepted from the request
	return result

static func quote_original_selection(world: Node,original_item: Dictionary,request: Dictionary) -> Dictionary:
	if not integer(original_item.get("ID")):return _failure("원문 ItemClass.ID 필요")
	var definition: Dictionary=D.definition_id(str(int(original_item.ID)))
	if definition.get("original_item")!=original_item or NATIVE_FIELDS.full(definition.get("native_record",{})).get("source_use_spec",{}).get("kind") not in ["source_selectable_reward","source_selectable_bag"]:return _failure("원문 선택 보상 정의가 아닙니다")
	return use_owned_original(world,original_item,request)

static func claim_original_selection(world: Node,original_item: Dictionary,request: Dictionary,entity_id: int) -> Dictionary:
	# Validate selection kind BEFORE calling the use entrypoint: a non-selection
	# item must never be consumed by a request aimed at a different UI action.
	if request.size()!=5 or not request.get("physical_id") is String or not integer(entity_id) or entity_id<=0:return _failure("선택 개체·원문 선택 행 ID 요청 불일치")
	var uid: String=request.physical_id;var owned: Dictionary={}
	if request.has("quest_reward_receipt"):
		var quest: Dictionary=QUEST_OWN.proof(world,uid)
		if not quest.get("ok",false):return _failure("선택 보상 퀘스트 소유 증명 불일치")
		var definition: Dictionary=D.definition_id(str(int(quest.item_class_id)))
		owned={"record":D.variant_item(definition.get("native_record",{}),int(quest.bless_code_id)),"remaining":quest.quantity,"receipt":request.quest_reward_receipt,"ownership_kind":"quest"}
	else:owned=proof(world,uid)
	if owned.is_empty() or NATIVE_FIELDS.full(owned.get("record",{})).get("source_use_spec",{}).get("kind") not in ["source_selectable_reward","source_selectable_bag"]:return _failure("원문 선택 보상 소유 개체가 아닙니다")
	var pending: Dictionary=use_owned_original(world,original_item,request)
	if not pending.get("requires_original_selection",false):return pending
	var choices: Array=[]
	for reward: Dictionary in pending.choices:
		if reward.get("source_entity_id")==entity_id:choices.append(reward.duplicate(true))
	if choices.size()!=1:return _failure("현재 원문 직업·선택 행 ID 선택 불일치")
	var selected: Dictionary=choices[0];var record: Dictionary=owned.record
	var executor: Script=load("res://scripts/loot/patch523_item_use.gd")
	record=executor.call("action_record",world,record)
	var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
	if selected.has("exact_choice_card"):
		var rng_snapshot:=RandomNumberGenerator.new()
		rng_snapshot.seed=world.rng.seed;rng_snapshot.state=world.rng.state
		return commit_owned_rewards(world,uid,owned,record,spec,[selected],rng_snapshot,
			{"kind":"current_original_selected_card","reward_id":spec.reward_id,"select_reward_id":spec.select_reward_id,"selection_entity_id":entity_id},{})
	var output: Dictionary=D.definition_id(str(int(selected.get("item_class_id",0))))
	var item: Dictionary=D.variant_item(output.get("native_record",{}),int(selected.get("bless_raw",0)))
	if item.is_empty() or output.get("original_item",{}).get("TestItem")!=false or output.get("excluded",false) or not NATIVE_FIELDS.field(item,"source_condition_pending",[]).is_empty():return _failure("선택한 원문 보상 공급 정체·조건 연결 대기")
	var deadline: String=D.deadline_problem(item,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
	if not deadline.is_empty():return _failure(deadline)
	if spec.get("kind")=="source_selectable_bag":return claim_bag_selection(world,uid,owned,record,spec,selected,entity_id)
	var local_initial: bool=selected.get("enchant")==null and D.equipment(item)
	if local_initial and not world.ui_preferences.get("patch523_select_reward_initial_zero_enabled",true):return _failure("선택 장비 초기 +0 자체 규칙 사용 안함 · 상자 보존")
	selected["original_initial_enchant"]=selected.get("enchant")
	selected["initial_enchant_origin"]="twilight_configured_default_zero" if local_initial else "not_equipment_initial_enchant"
	selected["enchant"]=0 # Original Reward has no initial enchant field; policy is explicit above.
	var candidate_rng:=RandomNumberGenerator.new();candidate_rng.seed=world.rng.seed;candidate_rng.state=world.rng.state
	var origin: Dictionary={"kind":"current_original_selected_reward","reward_id":spec.reward_id,"select_reward_id":spec.select_reward_id,"selection_entity_id":entity_id,"initial_enchant_origin":selected.initial_enchant_origin,"original_initial_enchant":selected.original_initial_enchant}
	var evidence: Dictionary={"original_reward":spec.original_reward.duplicate(true),"original_select_reward":spec.original_select_reward.duplicate(true),"class_id":current_class(world),"selection_entity_id":entity_id,"initial_enchant_origin":selected.initial_enchant_origin,"original_initial_enchant":selected.original_initial_enchant}
	var rewards: Array=[selected]
	if spec.get("source_complex_reward",false):
		origin["kind"]="current_original_complex_selected_reward"
		var fixed: Array=spec.get("fixed_rewards",[])
		if fixed.size()!=1:return _failure("원문 확정 보상 자료 불일치 · 상자 보존")
		var guaranteed: Dictionary=fixed[0].duplicate(true)
		var guaranteed_definition: Dictionary=D.definition_id(str(whole(guaranteed.get("item_class_id"))))
		var guaranteed_item: Dictionary=D.variant_item(guaranteed_definition.get("native_record",{}),whole(guaranteed.get("bless_raw")))
		if guaranteed_item.is_empty() or guaranteed_definition.get("original_item",{}).get("TestItem")!=false or guaranteed_definition.get("excluded",false) or D.equipment(guaranteed_item) or not NATIVE_FIELDS.field(guaranteed_item,"source_condition_pending",[]).is_empty():return _failure("원문 확정 보상 공급 조건 미연결 · 상자 보존")
		var fixed_deadline: String=D.deadline_problem(guaranteed_item,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if not fixed_deadline.is_empty():return _failure(fixed_deadline)
		guaranteed["original_initial_enchant"]=null
		guaranteed["initial_enchant_origin"]="not_equipment_initial_enchant"
		guaranteed["enchant"]=0
		rewards.push_front(guaranteed)
	return commit_owned_rewards(world,uid,owned,record,spec,rewards,candidate_rng,origin,evidence)

## The chosen LuckyBagEntityView row is granted as the table states it:
## item, amount, ItemBlessCodeID and ItemEnchant (no local initial-level rule).
static func claim_bag_selection(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary,selected: Dictionary,entity_id: int) -> Dictionary:
	if not integer(selected.get("enchant")) or not integer(selected.get("amount")) or int(selected.amount)<1:return _failure("선택한 원본 상자 행의 수량·강화 값 확인 필요")
	var candidate_rng:=RandomNumberGenerator.new();candidate_rng.seed=world.rng.seed;candidate_rng.state=world.rng.state
	var origin: Dictionary={"kind":"current_original_selected_bag_reward","lucky_bag_class_id":spec.lucky_bag_class_id,"selection_entity_id":entity_id,"select_count_origin":spec.get("select_count_origin","")}
	var evidence: Dictionary={"original_lucky_bag_class":spec.original_lucky_bag_class.duplicate(true),"class_id":current_class(world),"selection_entity_id":entity_id,"select_count_origin":spec.get("select_count_origin","")}
	return commit_owned_rewards(world,uid,owned,record,spec,[selected],candidate_rng,origin,evidence)

static func commit_owned_rewards(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary,rewards: Array,candidate_rng: RandomNumberGenerator,origin: Dictionary,_evidence: Dictionary) -> Dictionary:
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}
	var is_quest: bool=owned.get("ownership_kind")=="quest"
	var paid: Dictionary={}
	if owned.get("ownership_kind") == "catalog":
		var key: String = str(owned.key)
		var current: Dictionary = CATALOG_STACK.action_record(world,world._find_catalog_item_record(key))
		if current != record or profile(current).get("kind") != "bag" or world._item_locked(key) or not CATALOG_STACK.holds_plain(world,key) or int(world.inventory[key]) != int(owned.remaining):
			return _failure("기존 상자의 원본 식별·수량이 바뀌었습니다")
		var balance: Dictionary = world.inventory.duplicate()
		if not spec.get("approx_reusable",false):
			if int(balance[key]) == 1: balance.erase(key)
			else: balance[key] = int(balance[key])-1
		paid = {"ok":true,"overrides":{"inventory":balance,"item_instances":world.item_instances}}
	elif is_quest:
		request.erase("source_native_stack_receipt");request["quest_reward_receipt"]=owned.receipt.duplicate(true)
		paid=QUEST_CONSUME.stage(world,[request],str(SOURCE.identity().source_sha256))
	elif spec.get("approx_reusable",false):
		# TWILIGHT 근사 (2): InfiniteAmount — the bag stays (no debit); the reuse wait applies.
		paid={"ok":true,"overrides":{"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true),"consumable_state":world.consumable_service.export_state()},"selections":[{"physical_id":uid,"quantity":0,"approx_reusable":true}]}
	else:paid=stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","원본 상자 입력 차감 소유자 연결 필요"))))
	var view:=SupplierView.new();view.host=world;view.inventory=paid.overrides.inventory;view.item_instances=paid.overrides.item_instances;view.gold=world.gold
	var grants: Array=[];var cards: Array=[]
	for reward: Dictionary in rewards:
		if reward.has("approx_card") or reward.has("exact_choice_card"):cards.append(reward);continue
		grants.append({"item_class_id":int(reward.item_class_id),"amount":int(reward.amount),"bless_raw":int(reward.bless_raw),"enchant":int(reward.enchant)})
	origin=origin.duplicate(true)
	origin.merge({"source_definition_archive":SOURCE.identity(),"input_physical_id":uid,"input_receipt":owned.receipt.duplicate(true),"input_ownership_kind":owned.get("ownership_kind","native"),"source_rewards":rewards.duplicate(true)})
	var supplier: Script=load("res://scripts/loot/patch523_item_inventory.gd")
	var awarded: Dictionary=supplier.call("stage",view,grants,origin) if not grants.is_empty() else {"ok":true,"overrides":paid.overrides.duplicate(true)}
	view.free()
	if not awarded.get("ok",false):return _failure(str(awarded.get("error","원본 상자 결과 지급 후보 연결 실패")))
	var payload: Dictionary=awarded.overrides
	if not payload.has("gold"):payload["gold"]=world.gold
	# TWILIGHT 근사 (2): a test card item reward is the card itself, given to the card owner.
	var card_outcomes: Array=[]
	if not cards.is_empty():
		var scratch: Object=preload("res://scripts/card_draw_fusion.gd").new()
		scratch.configure(world.catalog_db);scratch.import_state(world.card_draw_fusion.export_state())
		for reward: Dictionary in cards:
			var exact: bool=reward.has("exact_choice_card")
			var binding: Dictionary=reward.get("exact_choice_card",reward.get("approx_card",{}))
			var category: String=str(binding.card_kind)
			var card: Dictionary=card_binding(world,category,int(binding.card_id))
			if card.is_empty():return _failure("지급할 원본 카드 자료가 미설치 상태입니다 · 상자 보존")
			for copy: int in range(maxi(1,int(reward.get("amount",1)))):
				var identity: Dictionary={"source_snapshot":"patch523","item_class_id":int(reward.item_class_id),"card_id":int(binding.card_id),"buff_card_cannot_swap":false,"bless":int(reward.get("bless_raw",1)),"input_physical_id":uid,"input_receipt":owned.receipt.duplicate(true)}
				if exact:identity["selection_entity_id"]=int(reward.source_entity_id)
				else:identity["approximation"]="TWILIGHT_BAG_TEST_CARD_REWARD"
				var outcome: Dictionary=scratch.receive_source_card(category,card,identity)
				if not outcome.get("ok",false):return _failure(str(outcome.get("error","원본 카드 지급 실패"))+" · 상자 보존")
				card_outcomes.append({"category":category,"name":str(card.get("name","")),"exact_choice":exact})
		payload["card_draw_fusion"]=scratch.export_state()
	var weight: int=world._inventory_total_weight();var keys: Dictionary={}
	for key: String in world.inventory:keys[key]=true
	for key: String in payload.inventory:keys[key]=true
	for key: String in keys:weight+=(int(payload.inventory.get(key,0))-int(world.inventory.get(key,0)))*maxi(0,int(world.item_weight_index.get(key,3)))
	if weight>world._carrying_capacity():return _failure("기존 소지 무게 한도 초과 · 상자와 전체 결과 보존")
	var state: Dictionary=paid.overrides.get("consumable_state",world.consumable_service.export_state())
	# One opening id for this result (visual commit key); the result itself is
	# the granted items, not a kept journal row.
	var receipt_id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	state.erase(BAG_USES);payload["consumable_state"]=state
	var executor: Script=load("res://scripts/loot/patch523_item_use.gd")
	payload["item_use_cooldowns"]=executor.call("next_cooldowns",world,record,spec)
	payload["patch523_transaction_rng"]={"schema":1,"seed":str(candidate_rng.seed),"state":str(candidate_rng.state)}
	if is_quest:
		payload["quest_state"]=paid.overrides.quest_state
		if not QUEST_CONSUME.matches_payload(world,paid,payload):return _failure("원본 상자의 실제 지급 후보와 선택 사용 영수증 불일치")
	busy=true;_candidate_kind="bag_use";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind=""
	if saved!=OK:
		world.patch523_owner_state_problem="원본 상자 저장 실패·결과 미확정 · 정상 저장 불러오기 전 재개봉 중지";busy=false;return _failure(world.patch523_owner_state_problem)
	if is_quest and not world.quest_service.import_state(payload.quest_state):
		world.patch523_owner_state_problem="원본 상자 저장 후 퀘스트 영수증 채택 미확정 · 정상 저장 불러오기 필요";busy=false;return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.gold=int(payload.gold);world.item_use_cooldowns=payload.item_use_cooldowns;world.consumable_service.import_state(state)
	if payload.has("card_draw_fusion"):
		world.card_draw_fusion.import_state(payload.card_draw_fusion);world._invalidate_equipment_static()
		if world.get("card_collections")!=null:world.card_collections.invalidate()
		for card: Dictionary in card_outcomes:world.hud.append_log("원본 상자 카드 지급 · %s (%s)%s" % [card.name,card.category,"" if card.exact_choice else " · TWILIGHT 근사"])
	world.rng.seed=candidate_rng.seed;world.rng.state=candidate_rng.state;world.deferred_save.cancel();busy=false
	var sprite: int=int(spec.get("consume_effect_sprite_id",0))
	if sprite>0:world.option_awakening.combat.emit_sprite(sprite,world.player)
	var kept: bool=bool(spec.get("approx_reusable",false)) and not is_quest
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":0 if kept else 1,"physical_id":uid,"remaining_quantity":int(owned.remaining) if kept else int(owned.remaining)-1,"source_bag_receipt_id":receipt_id,"rewards":rewards,"cards":card_outcomes,"message":"원본 선택 보상을 지급했습니다" if spec.kind in ["source_selectable_reward","source_selectable_bag"] else "원본 상자 보상을 지급했습니다"}
	if spec.kind == "source_event_box":
		result.message = "발록 이벤트 상자 보상을 지급했습니다 · TWILIGHT 추정"
		if not spec.omitted_quest_ids.is_empty(): result.message += " · 종료된 퀘스트 이용권 제외"
	return committed_use_context(result,record,sprite,sprite>0,"current523_native_stack.commit_owned_rewards")


## The one registered collection card for an original BuffCard ID, bound the
## way the owned-ticket service binds pool members (deck, source ID, grade,
## merge/swap flags and registration in the card owner); {} otherwise.
static func card_binding(world: Node,category: String,card_id: int) -> Dictionary:
	var original: Dictionary=SOURCE.row("BuffCard",card_id);var found: Array=[]
	if original.is_empty():return {}
	var suffix: String=str(int(original.get("BuffCardDeckID",0)))+":"+str(card_id)
	for card: Variant in world.catalog_db.get(category,[]):
		if not card is Dictionary or int(card.get("source_card_id",0))!=card_id:continue
		if card.get("source") not in ["lineagem_base508","lineagem_patch523"] or str(card.get("sourceId","")) not in ["m508:"+suffix,"m523:"+suffix] or int(card.get("source_deck_id",0))!=int(original.BuffCardDeckID):continue
		if int(card.get("source_grade_id",0))!=int(original.GradeID) or card.get("source_merge_out_disabled",false)!=original.get("IsNoMergeOut") or card.get("source_swap_out_disabled",false)!=original.get("IsNoSwapOut"):continue
		found.append(card)
	if found.size()!=1:return {}
	var identity: String=world.card_draw_fusion.card_id(found[0])
	if not world.card_draw_fusion.known_ids.get(category,{}).has(identity):return {}
	return found[0]

## The owned physical stack of an original bless scroll, ready for one debit:
## {} when the name is not one; {"error"} when its conditions refuse it.
static func bless_scroll_owned(world: Node,scroll_name: String,selected_uid: String="") -> Dictionary:
	if selected_uid.is_empty() and profile(world._find_catalog_item_record(scroll_name)).get("kind")!="bless":
		var has_receipt: bool=world.item_instances.values().any(func(entry: Variant) -> bool:return entry is Dictionary and entry.get("name")==scroll_name and entry.has(RECEIPT))
		if not has_receipt:return {}
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return {"error":"원본 소비 저장 보호 중 · 물리 수량 보존"}
	if world.hp<=0 or world._option_awakening_busy() or world._item_locked(scroll_name):return {"error":"현재 사용·잠금 조건 미충족"}
	var ids: Array=[selected_uid] if not selected_uid.is_empty() else world.item_instances.keys()
	for id: String in ids:
		var entry: Variant=world.item_instances.get(id)
		if not entry is Dictionary or entry.get("name")!=scroll_name or not entry.has(RECEIPT) or world._item_locked(scroll_name,id):continue
		var owned: Dictionary=proof(world,id)
		if owned.is_empty():return {"error":"원본 물리 소유·최초량·잔량 증명 불일치"}
		var problem: String=str(load("res://scripts/loot/patch523_item_use.gd").call("eligibility",world,owned.record))
		if not problem.is_empty():return {"error":problem}
		var effect: Dictionary=profile(owned.record)
		var spec: Dictionary=effect.get("spec",{})
		if effect.get("kind")!="bless" or spec.get("kind")!="equipment_bless":return {"error":"원본 축복 주문서 정의 연결 필요"}
		if not effect.get("metadata",{}).get("can_use_when_invisible",spec.get("can_use_when_invisible",false)) and world.is_player_concealed():return {"error":"원본 조건: 은신 중 사용할 수 없습니다"}
		if float(world.item_use_cooldowns.get("m523:item:"+str(owned.record.source_item_class_id),0))>0:return {"error":"원본 아이템 재사용 대기"}
		return {"uid":id,"owned":owned,"record":owned.record,"spec":spec,"request":{"physical_id":id,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}}
	return {"error":"선택 물리 개체·잠금·소지 수량 확인 필요"}

## Use one exact physical receipt and stage the point and debit in one save.
static func use_half_elixir_charge(world: Node,uid: String,owned: Dictionary,record: Dictionary) -> Dictionary:
	var runtime: Variant=world.get("half_elixir")
	if runtime==null:return _failure("하프 엘릭서 기능 연결 필요 · 아이템 보존")
	var definition: Dictionary=D.item_definition(record)
	var plan: Dictionary=runtime.plan_native_charge(whole(record.get("source_item_class_id")),definition.get("original_item",{}))
	if not plan.get("ok",false):return _failure(str(plan.get("message"))+" · 아이템 보존")
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt}
	var paid: Dictionary=stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","하프 엘릭서 수량 차감 검증 실패"))))
	var payload: Dictionary=paid.overrides
	payload[runtime.KEY]=plan.state
	busy=true
	runtime.busy=true
	var saved: Error=world._save_game(true,payload)
	runtime.busy=false
	busy=false
	if saved!=OK:return _failure("하프 엘릭서 저장 실패 · 포인트와 아이템 보존")
	world.inventory=payload.inventory
	world.item_instances=payload.item_instances
	world.consumable_service.import_state(payload.consumable_state)
	runtime.accept(plan.state)
	world.deferred_save.cancel()
	return {"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"message":"하프 엘릭서 능력치 포인트 +1"}

static func open_half_elixir_reset(world: Node,uid: String,owned: Dictionary,record: Dictionary) -> Dictionary:
	var runtime: Variant=world.get("half_elixir")
	if runtime==null or not world.hud.has_method("confirm_action"):return _failure("하프 엘릭서 초기화 확인창을 사용할 수 없습니다")
	var raw: Dictionary=D.item_definition(record).get("original_item",{})
	var plan: Dictionary=runtime.plan_native_reset(whole(record.get("source_item_class_id")),raw)
	if not plan.get("ok",false):return _failure(str(plan.get("message"))+" · 촛불 보존")
	var before: Dictionary={"revision":runtime.state.revision,"receipt":owned.receipt.duplicate(true),"remaining":owned.remaining}
	world.hud.confirm_action(str(record.name),"촛불 1개를 소모하고 하프 엘릭서 능력치 투자만 초기화합니다. 총 포인트와 확장 단계는 보존됩니다.","초기화",func(_count: int) -> void:
		var result: Dictionary=commit_half_elixir_reset(world,uid,before)
		world.hud.show_message(str(result.get("message",result.get("reason","하프 엘릭서 초기화 불가"))))
		if result.get("ok",false):world._update_hud();world.hud.refresh_inventory(world.inventory)
	)
	return {"handled":true,"silent":true}

static func commit_half_elixir_reset(world: Node,uid: String,before: Dictionary) -> Dictionary:
	var runtime: Variant=world.get("half_elixir")
	if runtime==null or busy or not world._patch523_item_allowed() or world.hp<=0 or world._option_awakening_busy() or runtime.state.revision!=before.get("revision"):return _failure("상태가 바뀌었습니다 · 촛불을 다시 선택하세요")
	var owned: Dictionary=proof(world,uid)
	if owned.is_empty() or owned.receipt!=before.get("receipt") or owned.remaining!=before.get("remaining"):return _failure("선택한 촛불의 소유 상태가 바뀌었습니다 · 아이템 보존")
	var record: Dictionary=owned.record
	if profile(record).get("kind")!="half_elixir_reset":return _failure("원본 촛불 정의가 일치하지 않습니다 · 아이템 보존")
	var restriction: String=str(load("res://scripts/loot/patch523_item_use.gd").call("eligibility",world,record))
	if not restriction.is_empty():return _failure(restriction)
	var plan: Dictionary=runtime.plan_native_reset(whole(record.get("source_item_class_id")),D.item_definition(record).get("original_item",{}))
	if not plan.get("ok",false):return _failure(str(plan.get("message"))+" · 촛불 보존")
	var paid: Dictionary=stage_debit(world,[{"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,
		"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt}])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","하프 엘릭서 수량 차감 검증 실패"))))
	var payload: Dictionary=paid.overrides
	payload[runtime.KEY]=plan.state
	busy=true
	runtime.busy=true
	var saved: Error=world._save_game(true,payload)
	runtime.busy=false
	busy=false
	if saved!=OK:return _failure("하프 엘릭서 초기화 저장 실패 · 투자와 촛불 보존")
	world.inventory=payload.inventory
	world.item_instances=payload.item_instances
	world.consumable_service.import_state(payload.consumable_state)
	runtime.accept(plan.state)
	world.hp=mini(world.hp,world._effective_max_hp())
	world.deferred_save.cancel()
	return {"handled":true,"ok":true,"saved":true,"message":"하프 엘릭서 능력치 투자 초기화 · 총 포인트와 확장 단계 보존"}

## A weapon mastery point item: the existing mastery owner plans the original
## points for the normalized weapon type and saves them together with the
## one-unit physical debit.
static func use_mastery_points(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	if spec.get("kind")!="weapon_mastery_points" or spec.get("activation_status")!="unrestricted":return _failure("원본 숙련 아이템 정의 연결 필요")
	var requirements: Dictionary=spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or not str(requirements.get("service_region_code","")).is_empty():return _failure("원본 숙련 아이템 사용 대상·서비스 조건 미지원")
	var runtime: Variant=world.get("weapon_mastery")
	if runtime==null or not bool(runtime.enabled):return _failure("무기 숙련 원본 팩을 확인할 수 없습니다 · 아이템 보존")
	var weapon: int=int(runtime.core.normalize_weapon(int(spec.get("weapon_type",0))))
	if weapon<=0:return _failure("원본 무기 종류를 숙련에 연결할 수 없습니다 · 아이템 보존")
	var plan: Dictionary=runtime.core.plan_points(runtime.state,weapon,str(int(spec.get("points",0))),runtime._receipt("native_mastery_point_item"))
	if not plan.get("ok",false):return _failure(str(runtime.reason_text(str(plan.get("reason",""))))+" · 아이템 보존")
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}
	var paid: Dictionary=stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","원본 숙련 아이템 차감 소유자 연결 필요"))))
	var resources: Dictionary=paid.overrides.duplicate(true)
	resources["item_use_cooldowns"]=load("res://scripts/loot/patch523_item_use.gd").call("next_cooldowns",world,record,spec)
	busy=true
	var committed: Dictionary=runtime._commit(plan,resources)
	busy=false
	if not committed.get("ok",false):
		if committed.get("committed",false):world.patch523_owner_state_problem="원본 숙련 아이템 저장 후 적용 미확정 · 정상 불러오기 전 재사용 중지"
		return _failure(str(runtime.reason_text(str(committed.get("reason",""))))+" · 아이템 보존")
	world.consumable_service.import_state(resources.consumable_state);world.item_use_cooldowns=resources.item_use_cooldowns;world.deferred_save.cancel()
	var message: String="%s 사용 · 무기 숙련치 +%d" % [str(NATIVE_FIELDS.field(record,"source_display_name",record.get("name",""))),int(spec.points)]
	world.hud.append_log(message)
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"weapon_type":weapon,"points":int(spec.points),"message":message}
	return committed_use_context(result,record,0,false,"current523_native_stack.use_mastery_points")

## 축복 포인트 충전: one physical unit is debited through its grant receipt and
## the original IntangibleItemAmount is added to the existing symbol (문양)
## blessing points (growth state "points", ledger "recharged") in one save.
static func use_bless_points(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	if spec.get("kind")!="source_bless_points" or spec.get("activation_status")!="unrestricted" or not integer(spec.get("points")) or int(spec.points)<=0:return _failure("원본 축복 포인트 아이템 정의 연결 필요")
	var requirements: Dictionary=spec.get("item_requirements",{})
	if whole(requirements.get("targetting_type_id"))!=1 or not str(requirements.get("service_region_code","")).is_empty():return _failure("원본 축복 포인트 아이템 사용 대상·서비스 조건 미지원")
	var growth: Variant=world.get("growth")
	if growth==null or bool(growth.busy):return _failure("문양 축복 포인트 처리 중 · 아이템 보존")
	var next: Dictionary=growth.state.duplicate(true)
	if not integer(next.get("points")) or int(next.points)>9007199254740991-int(spec.points):return _failure("문양 축복 포인트 형식·범위 확인 필요 · 아이템 보존")
	next.points=int(next.points)+int(spec.points)
	if not next.has("economy"):next["economy"]={}
	next.economy["recharged"]=int(next.economy.get("recharged",0))+int(spec.points)
	next.revision=int(next.get("revision",0))+1
	if not str(growth.validate(next)).is_empty():return _failure("문양 축복 포인트 상태 검증 실패 · 아이템 보존")
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}
	var paid: Dictionary=stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","원본 축복 포인트 아이템 차감 소유자 연결 필요"))))
	var payload: Dictionary=paid.overrides.duplicate(true)
	payload["growth"]=next
	payload["item_use_cooldowns"]=load("res://scripts/loot/patch523_item_use.gd").call("next_cooldowns",world,record,spec)
	busy=true
	var saved: Error=world._save_game(true,payload)
	busy=false
	if saved!=OK:return _failure("원본 축복 포인트 아이템 저장 실패 · 아이템과 포인트 보존 (%d)" % saved)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.item_use_cooldowns=payload.item_use_cooldowns;world.consumable_service.import_state(payload.consumable_state)
	growth.state=next;world.deferred_save.cancel()
	var message: String="%s 사용 · 축복 포인트 +%d (보유 %d)" % [str(NATIVE_FIELDS.field(record,"source_display_name",record.get("name",""))),int(spec.points),int(next.points)]
	world.hud.append_log(message)
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"points":int(spec.points),"message":message}
	return committed_use_context(result,record,0,false,"current523_native_stack.use_bless_points")

## 시간 충전석 — TWILIGHT 근사(근거 약함) (2026-11-17, docs/items523_remaining_missing_rules.md 12.2). While the own map time is in effect
## (current523_aden_play_controller.recharge_map_time) one physical unit is debited and
## saved first, then the group is charged in the map time pool; a refused charge puts
## the unit back. Otherwise the existing dungeon window recharge (dungeon_play.recharge,
## the same pools the 던전 창 시간 충전 button fills) is used when it knows the item; with
## neither, the stone is kept and a notice explains why.
static func use_time_recharge(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	if spec.get("kind")!="source_time_recharge" or spec.get("activation_status")!="unrestricted" or not integer(spec.get("seconds")) or int(spec.seconds)<=0 or not spec.get("group") is Dictionary or spec.group.is_empty():return _failure("원본 시간 충전석 정의 연결 필요")
	var label: String=str(NATIVE_FIELDS.field(record,"source_display_name",record.get("name","")))
	var hours: String=("%d시간" % int(int(spec.seconds)/3600)) if int(spec.seconds)%3600==0 else ("%d분" % int(int(spec.seconds)/60))
	var controller: Object=world.call("_aden_play_controller") if world.has_method("_aden_play_controller") else null
	var in_effect: bool=controller!=null and controller.has_method("map_time_in_effect") and bool(controller.call("map_time_in_effect"))
	var play: Variant=world.get("dungeon_play")
	var item_id: int=int(whole(record.get("source_item_class_id",0)))
	var dungeon: bool=not in_effect and play is Object and play.has_method("recharge") and play.get("rules")!=null and play.rules.recharge_by_item.has(item_id)
	if not in_effect and not dungeon:return _failure("%s: 현재 맵 시간 제한이 꺼져 있어(무제한 개방) 충전할 시간이 없습니다 · 아이템 보존" % label)
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}
	var paid: Dictionary=stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","원본 시간 충전석 차감 소유자 연결 필요"))))
	var restore: Dictionary={"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true),"item_use_cooldowns":world.item_use_cooldowns.duplicate(true),"consumable_state":world.consumable_service.export_state()}
	var payload: Dictionary=paid.overrides.duplicate(true)
	payload["item_use_cooldowns"]=load("res://scripts/loot/patch523_item_use.gd").call("next_cooldowns",world,record,spec)
	busy=true
	var saved: Error=world._save_game(true,payload)
	busy=false
	if saved!=OK:return _failure("%s 저장 실패 · 아이템과 시간 보존 (%d)" % [label,saved])
	# The debit is in memory before the charge: the dungeon window commit saves the world.
	_apply_bag(world,payload)
	var charged: Dictionary={}
	if dungeon:
		var before_bonus: int=int(play.pool(int(spec.group_id),int(Time.get_unix_time_from_system())).bonus)
		charged=play.recharge(item_id,-1,false)
		if charged.get("ok",false):charged.merge({"recharged_ms":int(spec.seconds)*1000,"dungeon_bonus_seconds":[before_bonus,int(play.pool(int(spec.group_id),int(Time.get_unix_time_from_system())).bonus)]},true)
	else:charged=controller.call("recharge_map_time",spec.group,int(spec.seconds))
	if not charged.get("ok",false):
		_apply_bag(world,restore)
		busy=true
		var back: Error=world._save_game(true,restore)
		busy=false
		var why: String="충전 상한(TimeLimit + MaxRechargeTime) 도달" if str(charged.get("reason",""))=="map_time_recharge_full" else str(charged.get("reason",""))
		if back!=OK:return _failure("%s: 시간 충전 실패(%s) · 아이템 복구 저장 실패 (%d)" % [label,why,back])
		return _failure("%s: 시간 충전 보류 · %s · 아이템 보존" % [label,why])
	world.deferred_save.cancel()
	var message: String=""
	if dungeon:message="%s 사용 · 던전 이용 시간 +%s (던전 창 시간 풀)" % [label,hours]
	else:
		var minutes: int=int(int(charged.get("group_remaining_ms",{}).get(str(int(spec.group_id)),0))/60000)
		message="%s 사용 · 맵 이용 시간 +%d분 (남은 %d시간 %d분)" % [label,int(int(charged.get("recharged_ms",0))/60000),int(minutes/60),minutes%60]
	world.hud.append_log(message)
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"recharged_ms":int(charged.get("recharged_ms",0)),"route":"dungeon_play" if dungeon else "own_map_time","map_time":charged.duplicate(true),"message":message}
	return committed_use_context(result,record,0,false,"current523_native_stack.use_time_recharge")

static func _apply_bag(world: Node,payload: Dictionary) -> void:
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.item_use_cooldowns=payload.item_use_cooldowns
	if payload.has("consumable_state"):world.consumable_service.import_state(payload.consumable_state)

## A card item: one physical unit is debited through its grant receipt and the
## exact original card is credited to the existing card owner in one save.
## 미스터리 카드 (ItemCategory ScrollBuffCardRetry with BuffDeckID + GradeID,
## e.g. "[미스터리 변신 카드] 영웅"): one card of that deck and grade. The
## original pool and weights are not in the tables: TWILIGHT 근사, an equal
## draw over that deck's cards of the grade that are not declared excluded,
## not test rows, have no date or server condition and exist in the card
## catalog; the drawn card is given like a fixed card item.
static func mystery_card_rule(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or NATIVE_FIELDS.field(record,"source_category_name")!="ScrollBuffCardRetry":return {}
	var definition: Dictionary=D.item_definition(record)
	var deck: Variant=null;var grade: Variant=null
	for row: Dictionary in definition.get("item_bonus",[]):
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""))
		if name_value in ["PlayerValueReturn","TJCouponSeason"]:return {}
		if row.get("IsPossession")!=false:continue
		if name_value=="BuffDeckID":deck=whole(row.get("bonus",{}).get("Value"))
		elif name_value=="GradeID":grade=whole(row.get("bonus",{}).get("Value"))
	if not deck is int or not grade is int or not PROJECTION_DECKS.has(deck):return {}
	return {"deck_id":deck,"grade_id":grade,"card_kind":PROJECTION_DECKS[deck][1]}

const PROJECTION_DECKS={1:["PolymorphCardDeck","변신"],2:["MagicDollCardDeck","마법인형"],98:["HolyStuffCardDeck","성물"]}
static func mystery_card_pool(world: Node,rule: Dictionary) -> Array:
	var pool: Array=[]
	for card: Dictionary in SOURCE.rows("BuffCard"):
		if whole(card.get("BuffCardDeckID"))!=rule.deck_id or whole(card.get("GradeID"))!=rule.grade_id:continue
		if card.get("StartDateTimeID",0)!=0 or card.get("EndDateTimeID",0)!=0 or whole(card.get("ServerLimitSetID",0))!=0:continue
		if not SOURCE.declared_exclusion("BuffCard",card).is_empty():continue
		var lowered: String=str(card.get("Name","")).to_lower()
		if lowered.contains("테스트") or lowered.contains("test"):continue
		if card_binding(world,str(rule.card_kind),int(card.ID)).is_empty():continue
		pool.append(card)
	return pool

static func use_mystery_card(world: Node,uid: String,owned: Dictionary,record: Dictionary) -> Dictionary:
	var rule: Dictionary=mystery_card_rule(record)
	var pool: Array=mystery_card_pool(world,rule)
	if pool.is_empty():return _failure("이 등급의 원본 카드가 없어 사용할 수 없습니다 · 아이템 보존")
	var candidate_rng:=RandomNumberGenerator.new();candidate_rng.seed=world.rng.seed;candidate_rng.state=world.rng.state
	var card: Dictionary=pool[candidate_rng.randi_range(0,pool.size()-1)]
	var deck: Dictionary=SOURCE.row("BuffCardDeck",int(rule.deck_id))
	var spec: Dictionary={"kind":"fixed_card","activation_status":"unrestricted","card_kind":rule.card_kind,"card_id":int(card.ID),"deck_id":rule.deck_id,"original_card":card,"original_deck":deck,"buff_card_cannot_swap":false,"server_limit_set_id":0,
		"item_requirements":{"targetting_type_id":D.item_definition(record).get("original_item",{}).get("TargettingTypeID"),"service_region_code":D.item_definition(record).get("original_item",{}).get("ServiceRegionCode",""),"can_use_when_invisible":true},"approximation":"TWILIGHT 근사: 같은 덱·등급 카드 균등 추첨"}
	var result: Dictionary=use_fixed_card(world,uid,owned,record,spec)
	if result.get("ok",false):world.rng.seed=candidate_rng.seed;world.rng.state=candidate_rng.state
	return result

static func use_fixed_card(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	if spec.get("kind")!="fixed_card" or spec.get("activation_status")!="unrestricted":return _failure("원본 카드 아이템 정의 연결 필요")
	var requirements: Dictionary=spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or not str(requirements.get("service_region_code","")).is_empty():return _failure("원본 카드 아이템 사용 대상·서비스 조건 미지원")
	var server: Dictionary=SERVER.allows(world,spec.get("server_limit_set_id",0))
	if not server.ok:return _failure(str(server.reason)+" · 아이템 보존")
	if world.hud.has_method("is_card_reveal_busy") and world.hud.is_card_reveal_busy():return _failure("카드 결과 연출 중 · 아이템 보존")
	var category: String=str(spec.get("card_kind",""));var card_id: int=int(spec.get("card_id",0))
	if SOURCE.row("BuffCard",card_id)!=spec.get("original_card"):return _failure("원본 카드 정의 변경 감지 · 아이템 보존")
	var card: Dictionary=card_binding(world,category,card_id)
	if card.is_empty():return _failure("지급할 원본 카드 자료가 미설치 상태입니다 · 아이템 보존")
	# A quest-held card ("[원본 보상] …", quest receipt) is debited through the
	# quest reward ledger; a native stack through its physical receipt.
	var is_quest: bool=owned.get("ownership_kind")=="quest"
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1}
	request["quest_reward_receipt" if is_quest else RECEIPT]=owned.receipt.duplicate(true)
	var paid: Dictionary=QUEST_CONSUME.stage(world,[request],str(SOURCE.identity().source_sha256)) if is_quest else stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","원본 카드 아이템 차감 소유자 연결 필요"))))
	var scratch: Object=preload("res://scripts/card_draw_fusion.gd").new()
	scratch.configure(world.catalog_db);scratch.import_state(world.card_draw_fusion.export_state())
	var outcome: Dictionary=scratch.receive_source_card(category,card,{"source_snapshot":"patch523","item_class_id":int(record.source_item_class_id),"card_id":card_id,"cannot_swap":spec.original_card.IsNoSwapOut,"buff_card_cannot_swap":bool(spec.get("buff_card_cannot_swap",false)),"bless":int(record.get("source_bless_raw",1)),"input_physical_id":uid,"input_receipt":owned.receipt.duplicate(true)})
	if not outcome.get("ok",false):return _failure(str(outcome.get("error","원본 카드 지급 실패"))+" · 아이템 보존")
	var payload: Dictionary=paid.overrides.duplicate(true)
	payload["card_draw_fusion"]=scratch.export_state()
	payload["item_use_cooldowns"]=load("res://scripts/loot/patch523_item_use.gd").call("next_cooldowns",world,record,spec)
	if is_quest and not QUEST_CONSUME.matches_payload(world,paid,payload):return _failure("퀘스트 카드 아이템의 실제 잔량·사용 장부 후보 불일치 · 아이템 보존")
	busy=true
	var saved: Error=world._save_game(true,payload)
	busy=false
	if saved!=OK:
		world.patch523_owner_state_problem="원본 카드 아이템 저장 결과 미확정 · 정상 불러오기 전 재사용 중지";return _failure(world.patch523_owner_state_problem)
	if is_quest and not world.quest_service.import_state(payload.quest_state):
		world.patch523_owner_state_problem="퀘스트 카드 아이템 저장 후 장부 채택 미확정 · 정상 불러오기 전 재사용 중지";return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.item_use_cooldowns=payload.item_use_cooldowns
	if payload.has("consumable_state"):world.consumable_service.import_state(payload.consumable_state)
	world.card_draw_fusion.import_state(payload.card_draw_fusion);world.deferred_save.cancel()
	world._invalidate_equipment_static()
	if world.get("card_collections")!=null:world.card_collections.invalidate()
	var message: String="원본 지정 카드 지급 · %s (%s)" % [str(card.get("name","")),category]
	world.hud.append_log(message)
	var sprite: int=int(spec.get("consume_effect_sprite_id",0))
	if sprite>0:world.option_awakening.combat.emit_sprite(sprite,world.player)
	world.hud.set_card_draw_fusion_result(category,message)
	world.hud.present_card_reveal(category,outcome,false)
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"category":category,"card_id":card_id,"results":outcome.results,"message":message}
	return committed_use_context(result,record,sprite,sprite>0,"current523_native_stack.use_fixed_card")

static func native_ammo(record: Dictionary) -> bool:
	return profile(record).get("kind")=="ammo"

# A consumer view only. A raw quest record is never renamed, registered as a
# native physical grant or copied over its original saved instance.
static func ammo_owned(world: Node,uid: String) -> Dictionary:
	var owned: Dictionary=proof(world,uid)
	if not owned.is_empty() and native_ammo(owned.record):
		owned["inventory_key"]=str(owned.record.name);owned["ownership_kind"]="native";return owned
	var quest: Dictionary=QUEST_OWN.proof(world,uid)
	if not quest.get("ok",false) or quest.get("source_use_immediately",true) or quest.get("source_sha256")!=SOURCE.identity().get("source_sha256") or quest.source_item!=SOURCE.row("ItemClass",int(quest.item_class_id)):return {}
	var definition: Dictionary=D.definition_id(str(int(quest.item_class_id)))
	var record: Dictionary=D.variant_item(definition.get("native_record",{}),int(quest.bless_code_id))
	if not native_ammo(record):return {}
	return {"record":record,"remaining":int(quest.quantity),"receipt":world.item_instances[uid].quest_reward_receipt.duplicate(true),"inventory_key":str(quest.inventory_key),"ownership_kind":"quest"}

static func ammo_record(world: Node,name_value: String) -> Dictionary:
	var selected: Variant=world.consumable_service.export_state().get(AMMO_EQUIPPED,{})
	if selected is Dictionary and selected.get("name")==name_value and selected.get("ownership_kind")=="quest":
		var owned: Dictionary=ammo_owned(world,str(selected.get("physical_id","")))
		if not owned.is_empty() and owned.inventory_key==name_value and owned.receipt==selected.get("receipt"):return owned.record
		return {} # Invalid selected raw ownership cannot fall through to a legacy alias.
	return world._find_catalog_item_record(name_value)

static func quest_ammo_state_error(instances: Dictionary,state: Dictionary,selected: Dictionary) -> String:
	if selected.size()!=4 or not selected.get("physical_id") is String or not selected.get("name") is String or not selected.get("receipt") is Dictionary:return "퀘스트 탄약 선택 증명 형식 확인 필요"
	var uid: String=selected.physical_id;var physical: Variant=instances.get(uid)
	if not physical is Dictionary:return "착용한 원본 퀘스트 탄약 소지 개체가 없습니다"
	var receipt: Dictionary=selected.receipt;var record: Variant=physical.get("record")
	if not record is Dictionary or physical.get("quest_reward_receipt")!=receipt or physical.get("name")!=selected.name or record.get("name")!=selected.name or physical.get("level",0)!=0 or record.get("source_pending_use")!=true or record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523" or record.get("source_use_immediately")!=false:return "원본 퀘스트 탄약 소지 키·출처·영수증 보존 필요"
	var id: Variant=receipt.get("item_class_id");var remaining: Variant=physical.get("source_reward_quantity")
	if not integer(id) or int(id)<=0 or receipt.get("schema")!=1 or receipt.get("source_sha256")!=SOURCE.identity().get("source_sha256") or record.get("source_item_class_id")!=id or record.get("sourceId")!="m523:item:"+str(int(id)) or receipt.get("reward_id")!=record.get("source_reward_id") or receipt.get("bless_code_id")!=record.get("source_bless_code_id") or not integer(receipt.get("quantity")) or not integer(remaining) or int(remaining)<1 or int(remaining)>int(receipt.quantity):return "원본 퀘스트 탄약 지급량·잔량·품목 정체 불일치"
	var definition: Dictionary=D.definition_id(str(int(id)))
	if NATIVE_FIELDS.full(record).get("source_original_item")!=definition.get("original_item") or not native_ammo(D.variant_item(definition.get("native_record",{}),int(receipt.get("bless_code_id",0)))):return "원본 퀘스트 탄약 전체 행·효과 계약 불일치"
	# Complete claimed/reward ancestry and item_grants.used_quantity remain the
	# common quest save owner, and are rechecked by ammo_owned at each action.
	return ""

static func ammo_worn(world: Node,name_value: String) -> bool:
	var selected: Variant=world.consumable_service.export_state().get(AMMO_EQUIPPED,{})
	if not selected is Dictionary or selected.is_empty() or world.equipped_ammo!=name_value or world.ammo_unequipped or selected.get("name")!=name_value:return false
	var owned: Dictionary=ammo_owned(world,str(selected.get("physical_id","")))
	return not owned.is_empty() and native_ammo(owned.record) and owned.inventory_key==name_value and owned.receipt==selected.get("receipt") and not world._item_locked(name_value) and not world._item_locked(name_value,str(selected.physical_id))

static func equip_ammo(world: Node,name_value: String,selected_id: String="") -> Dictionary:
	var record: Dictionary=world._find_catalog_item_record(name_value)
	var state: Dictionary=world.consumable_service.export_state();var previous: Variant=state.get(AMMO_EQUIPPED,{})
	if not selected_id.is_empty():
		var requested: Dictionary=ammo_owned(world,selected_id)
		if not requested.is_empty() and requested.inventory_key==name_value:record=requested.record
	elif previous is Dictionary and previous.get("name")==name_value and previous.get("ownership_kind")=="quest":
		selected_id=str(previous.get("physical_id",""));record=ammo_record(world,name_value)
	var native: bool=native_ammo(record)
	if not native and previous=={}:return {"handled":false}
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return _failure("원본 탄약 저장 보호 중")
	if not previous is Dictionary or not world._is_ammo_record(record) or not integer(world.inventory.get(name_value,0)) or int(world.inventory.get(name_value,0))<1:return _failure("실제 소지 탄약 정체·수량 불일치")
	var next_name: String="" if world.equipped_ammo==name_value else name_value
	var next: Dictionary={}
	if native:
		var candidates: Array=[]
		for uid: String in world.item_instances:
			if not selected_id.is_empty() and selected_id!=uid:continue
			var owned: Dictionary=ammo_owned(world,uid)
			if not owned.is_empty() and owned.inventory_key==name_value and native_ammo(owned.record):candidates.append({"id":uid,"owned":owned})
		if candidates.size()!=1:return _failure("착용할 원본 탄약의 실제 물리 개체를 선택하세요 · 자동 대체하지 않습니다")
		var chosen: Dictionary=candidates[0];var owned: Dictionary=chosen.owned
		if world._item_locked(name_value) or world._item_locked(name_value,str(chosen.id)):return _failure("원본 탄약 잠금 상태")
		var issue: String=load("res://scripts/loot/patch523_item_use.gd").call("eligibility",world,owned.record)
		if not issue.is_empty():return _failure(issue)
		if world.equipped_ammo!=name_value or previous.get("physical_id")!=chosen.id:
			next_name=name_value;next={"physical_id":chosen.id,"name":name_value,"receipt":owned.receipt.duplicate(true)}
			if owned.ownership_kind=="quest":next["ownership_kind"]="quest"
	state[AMMO_EQUIPPED]=next
	var payload: Dictionary={"consumable_state":state,"equipped_ammo":next_name,"ammo_unequipped":next_name.is_empty()}
	busy=true;_candidate_kind="ammo_equip";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:
		world.patch523_owner_state_problem="원본 탄약 착용 저장 결과 미확정 · 정상 불러오기 전 재시도 중지";return _failure(world.patch523_owner_state_problem)
	world.equipped_ammo=next_name;world.ammo_unequipped=next_name.is_empty();world.consumable_service.import_state(state);world.deferred_save.cancel()
	return {"handled":true,"ok":true,"saved":true,"consumed":0,"message":"원본 탄약 착용 해제" if next_name.is_empty() else next_name+" 착용 · 실제 소지 개체 선택 보존"}

# Existing shots/skills supply their established ammo cost; no new hit/cost
# formulas. MP and the exact selected physical remainder share this save.
static func consume_ammo(world: Node,name_value: String,quantity: int,mp_cost: int=0,target: Node=null,roll_damage: bool=false,additional_cost: Dictionary={}) -> Dictionary:
	if not native_ammo(ammo_record(world,name_value)):
		var claimed: Variant=world.consumable_service.export_state().get(AMMO_EQUIPPED,{})
		var raw: Dictionary=world._find_catalog_item_record(name_value)
		if (claimed is Dictionary and not claimed.is_empty() and claimed.get("name")==name_value) or (raw.get("source_projection")=="current523_original_typed_game_dto_v1" and NATIVE_FIELDS.field(raw,"source_category_name") in ["Arrow","Bullet","Sting"]):return _failure("선택한 원본 탄약의 현재 소유·정체가 미확인입니다 · 이름 기반 차감으로 대체하지 않습니다")
		return {"handled":false}
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty() or world.hp<=0 or not world._patch523_item_allowed():return _failure("원본 탄약 사용·저장 보호 중")
	var hp_cost: int=0;var legacy_spent: Dictionary={}
	if not additional_cost.is_empty():
		if additional_cost.size() not in [3,4,5] or (additional_cost.size()>=4 and not additional_cost.get("material_requests") is Array) or (additional_cost.size()==5 and not additional_cost.get("resolved_skill") is Dictionary) or not integer(additional_cost.get("hp_cost")) or not additional_cost.get("legacy_spent") is Dictionary or not additional_cost.get("skill_id") is String or str(additional_cost.skill_id).is_empty() or roll_damage:return _failure("기존 스킬 비용 공동 후보 형식 불일치")
		hp_cost=int(additional_cost.hp_cost);legacy_spent=additional_cost.legacy_spent
		if additional_cost.has("resolved_skill"):
			var actual: Dictionary=additional_cost.resolved_skill
			if world.original_skills==null or actual.get("id")!=additional_cost.skill_id or actual.get("mp",0)!=mp_cost or actual.get("hp",0)!=hp_cost:return _failure("실제 기존 스킬 비용 정체 변경")
			var fresh: Dictionary=world.original_skills.material_plan(actual)
			if not str(fresh.get("reason","")).is_empty() or fresh.get("spent")!=legacy_spent or fresh.get("physical_materials",[])!=additional_cost.get("material_requests",[]) or fresh.get("physical_ammo",{}).get("inventory_key")!=name_value or fresh.physical_ammo.get("quantity")!=quantity:return _failure("스킬의 현재 실제 재료·탄약 견적 변경 · 비용 보존")
	if world.hp<=hp_cost:return _failure("스킬 HP 부족 · 탄약과 MP 보존")
	if quantity<1 or mp_cost<0 or world.mp<mp_cost or not ammo_worn(world,name_value) or world._current_ammo_name()!=name_value:return _failure("선택한 원본 탄약·MP·착용 조건 불일치")
	var selected: Dictionary=world.consumable_service.export_state()[AMMO_EQUIPPED]
	var uid: String=selected.physical_id;var owned: Dictionary=ammo_owned(world,uid)
	if owned.is_empty() or int(owned.remaining)<quantity:return _failure("선택한 물리 탄약 잔량 부족 · 다른 개체를 대신 소비하지 않습니다")
	var issue: String=load("res://scripts/loot/patch523_item_use.gd").call("eligibility",world,owned.record)
	if not issue.is_empty():return _failure(issue)
	var is_quest: bool=owned.get("ownership_kind")=="quest"
	var request: Dictionary={"physical_id":uid,"quantity":quantity,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-quantity}
	request["quest_reward_receipt" if is_quest else RECEIPT]=owned.receipt.duplicate(true)
	var requests: Array=[request];requests.append_array(additional_cost.get("material_requests",[]))
	var paid: Dictionary=stage_owned_debits(world,requests)
	if not paid.get("ok",false):return _failure(str(paid.get("reason","원본 탄약 공동 차감 후보 연결 대기")))
	var private_before: Variant=world.consumable_service.export_state().get(AMMO_RNG,{})
	if not private_before is Dictionary:return _failure("원본 탄약 독립 난수 저장 형식 보존 필요")
	var candidate_rng:=RandomNumberGenerator.new()
	if private_before.is_empty():
		# Host implementation stream, not a native probability/seed claim.
		candidate_rng.seed=(str(world.rng.seed)+":current523.ammunition.v1").sha256_text().substr(0,15).hex_to_int()
	else:
		if private_before.get("schema")!=1 or not private_before.get("seed") is String or not private_before.get("state") is String or not str(private_before.seed).is_valid_int() or not str(private_before.state).is_valid_int():return _failure("원본 탄약 독립 난수 상태 불일치")
		candidate_rng.seed=int(private_before.seed);candidate_rng.state=int(private_before.state)
	var damage: int=0;var size_class: String="";var policy: String=str(world.ui_preferences.get("patch523_ammo_damage_rule","uniform"))
	if roll_damage:
		if not is_instance_valid(target):return _failure("원본 탄약 발사 대상 없음 · 수량 보존")
		size_class=str(target.get_meta("size_class","small")).to_lower()
		var ammo: Dictionary=profile(owned.record).spec
		var maximum: int=int(ammo.get("large_damage" if size_class=="large" else "small_damage",0))
		if policy=="maximum":damage=maximum
		elif policy!="disabled":damage=candidate_rng.randi_range(1,maximum) if maximum>0 else 0
	var payload: Dictionary=paid.overrides;var state: Dictionary=payload.get("consumable_state",world.consumable_service.export_state())
	payload["consumable_state"]=state
	# Additional existing skill materials are debited from the already paid
	# ammo candidate, never merged from another whole inventory snapshot.
	for key: String in legacy_spent:
		var amount: Variant=legacy_spent[key]
		if key==name_value or not integer(amount) or int(amount)<1 or not integer(payload.inventory.get(key,0)) or int(payload.inventory.get(key,0))<int(amount) or world._item_locked(key):return _failure("스킬 기존 재료 수량·잠금·중복 차감 조건 불일치")
		for physical: Variant in world.item_instances.values():
			if physical is Dictionary and physical.get("name")==key and (physical.has(RECEIPT) or physical.has("quest_reward_receipt")):return _failure("이 스킬 재료는 별도의 정확한 물리 개체 소비 계약 필요 · 비용 보존")
		payload.inventory[key]=int(payload.inventory[key])-int(amount)
		if payload.inventory[key]==0:payload.inventory.erase(key)
	payload["hp"]=int(world.hp)-hp_cost
	if int(owned.remaining)==quantity:
		state[AMMO_EQUIPPED]={};payload["equipped_ammo"]="";payload["ammo_unequipped"]=true
	# No per-shot journal row: the shot's result is the debited quantity,
	# MP and the ammo RNG state saved below.
	var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	state.erase(AMMO_USES);payload["mp"]=int(world.mp)-mp_cost
	if roll_damage:state[AMMO_RNG]={"schema":1,"seed":str(candidate_rng.seed),"state":str(candidate_rng.state)}
	if not paid.quest_step.is_empty() and not QUEST_CONSUME.matches_payload(world,paid.quest_step,payload):return _failure("퀘스트 탄약 잔량·최초 사용 증명·MP 결과 공동 후보 불일치")
	# The payload is checked exactly as its save would check it (the sealed
	# owner rules), then committed in memory; the coalesced background save
	# writes it (user decision 2026-11-21, option A: a full save per shot was
	# ~0.4 s on the phone). Quest-step shots keep the synchronous save.
	busy=true;_candidate_kind="ammo_consume";_candidate=payload.duplicate(true)
	var deferred: bool=paid.quest_step.is_empty()
	var saved: Error=OK
	if deferred:
		if not override_error(world,payload).is_empty():saved=ERR_INVALID_DATA
	else:
		saved=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:
		if deferred:return _failure("원본 탄약 발사 후보 확인 실패 · 탄약·MP 보존")
		world.patch523_owner_state_problem="원본 탄약 발사 저장 실패·결과 미확정 · 정상 불러오기 전 재발사 중지";return _failure(world.patch523_owner_state_problem)
	if payload.has("quest_state") and not world.quest_service.import_state(payload.quest_state):
		world.patch523_owner_state_problem="퀘스트 탄약 저장 후 장부 채택 미확정 · 정상 불러오기 전 재시도 중지";return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.mp=int(payload.mp);world.hp=int(payload.hp);world.consumable_service.import_state(state)
	if payload.has("equipped_ammo"):world.equipped_ammo=payload.equipped_ammo;world.ammo_unequipped=payload.ammo_unequipped
	if deferred:world._request_general_save()
	else:world.deferred_save.cancel() # Ordinary combat/draw RNG is not advanced by this owner.
	return {"handled":true,"ok":true,"saved":true,"consumed":quantity,"physical_id":uid,"remaining_quantity":int(owned.remaining)-quantity,"source_ammo_receipt_id":id,"damage_bonus":damage,"message":"원본 물리 탄약·MP·발사 기록 저장"}


static func learn_skill_book(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	# Existing skill catalog/engine owns execution. Only exact known current
	# learning can be joined with this quantity owner's selected physical debit.
	if spec.get("kind")!="source_skill_book" or spec.get("activation_status")!="unrestricted" or world.original_skills==null:return _failure("현재 원문 스킬서·학습 소유자 연결 필요")
	var server: Dictionary=SERVER.allows(world,spec.get("server_limit_set_id",0))
	if not server.ok:return _failure(str(server.reason)+" · 스킬서 보존")
	if current_class(world)<=0:return _failure("원문 스킬서의 실제 현재 직업 정체 연결 필요")
	var book: Script=load("res://scripts/loot/patch523_skill_book.gd")
	var issue: String=book.call("source_limit_problem",world,spec)
	if not issue.is_empty():return _failure(issue+" · 현재 학습/실행 의존 미충족")
	var catalog: Object=world.original_skills.catalog;var adapter: Object=book.call("_adapter",catalog)
	if adapter==null or adapter.get_script()!=preload("res://scripts/skills/player_skills523.gd"):return _failure("현재 원문 스킬 프로필 소유자 미설치")
	var evidence: Dictionary={}
	if adapter.get("source_mode")=="original_bound_profiles":
		var original: Variant=adapter.get("source_identity")
		if not original is Dictionary or original.get("source_snapshot")!="patch523" or original.get("source_sha256")!=SOURCE.identity().get("source_sha256") or original.get("source_bytes")!=25031173:return _failure("실제 원문 스킬 프로필 출처 불일치")
		evidence={"kind":"original_bound_profiles","source_sha256":SOURCE.identity().source_sha256,"source_identity":original.duplicate(true)}
	else:
		# No old card/monster input is used; this is the already reviewed new
		# original441-profile skill input, kept distinct from an archive reader.
		if adapter.get("source_mode")!="compiled_pack" or adapter.get("active_sha256")!="256f0ba0944e05b86134b40ed3aea97c71e1073b3947ea6e46cb018b6179926a":return _failure("정확한 새 원문 스킬 프로필 입력 필요")
		evidence={"kind":"compiled_pack","source_sha256":SOURCE.identity().source_sha256,"skill_pack_sha256":str(adapter.get("active_sha256"))}
	var bindings_sha: String=FileAccess.get_file_as_string("res://data/skills/player_skills523_bindings.json").sha256_text()
	if bindings_sha!="497a594e7312ce98dd966b737b1bfb4555072af3c0d5b63d61b8ee2c33075346":return _failure("기존 공개 스킬 바인딩 정체 변경 · 스킬서 보존")
	evidence["binding_sha256"]=bindings_sha;evidence["item_definition_archive"]=SOURCE.identity()
	var identity: Dictionary=book.call("resolve",adapter,spec)
	if identity.is_empty() or identity.get("profile",{}).get("row")!=SOURCE.row("SpellClass",int(spec.spell_class_id)):return _failure("정확한 SpellClass ID·원문 행 SHA·기존 학습 ID 연결 필요")
	var key: String=str(identity.local_skill_id);var skill: Dictionary=catalog.record_for(key)
	if skill.get("id")!=key:return _failure("기존 등록 스킬 정체 불일치")
	var reference: Script=load("res://scripts/quests/quest_reference_learning.gd")
	var learning_only: bool=reference.call("matches",int(record.source_item_class_id),int(spec.spell_class_id),key,str(spec.source_spell_row_sha256))
	if learning_only:
		if catalog.learned.has(key) and catalog.learned[key]!=0:return _failure("이미 학습 기록이 있습니다")
		if not catalog.permitted(skill) or world.level<catalog.minimum_level_for(skill):return _failure("기존 스킬 직업·학습 레벨 조건 미충족")
		for required: String in catalog.relations.get(key,{}).get("requires_skill",[]):
			if int(catalog.learned.get(required,0))<int(catalog.relations[key].get("requires_skill_level",{}).get(required,1)):return _failure("기존 선행 스킬 조건 미충족")
	else:
		if skill.get("runtime_blocked",false):return _failure("현재 주문 실행 소유자 미지원 · 스킬서 보존")
		issue=catalog.reason(skill,true)
		if not issue.is_empty():return _failure(issue)
	var is_quest: bool=owned.get("ownership_kind")=="quest"
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1}
	request["quest_reward_receipt" if is_quest else RECEIPT]=owned.receipt.duplicate(true)
	var paid: Dictionary=QUEST_CONSUME.stage(world,[request],str(SOURCE.identity().source_sha256)) if is_quest else stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason","선택 원문 스킬서 차감 후보 연결 대기")))
	var state: Dictionary=paid.overrides.get("consumable_state",world.consumable_service.export_state())
	var receipts: Variant=state.get("source_skill_book_receipts",[])
	if not receipts is Array:return _failure("기존 스킬서 학습 영수증 보존 필요")
	var learned: Dictionary=catalog.export_state();learned.learned[key]=1
	var learning_record: Dictionary={}
	if learning_only:
		learning_record=reference.call("make_record",world,int(record.source_item_class_id),evidence)
		if not learned.has("source_quest_knowledge"):learned["source_quest_knowledge"]={}
		learned.source_quest_knowledge[key]=learning_record.duplicate(true)
	receipts=receipts.duplicate(true)
	var input_proof: Dictionary={"physical_id":uid,"remaining_before":owned.remaining,"ownership_kind":"quest" if is_quest else "native"}
	input_proof["quest_reward_receipt" if is_quest else RECEIPT]=owned.receipt.duplicate(true)
	var receipt: Dictionary={"source_snapshot":"patch523","source_sha256":SOURCE.identity().source_sha256,"item_definition_archive":SOURCE.identity(),"item_class_id":int(record.source_item_class_id),"bless_raw":int(record.source_bless_raw),"card_id":int(spec.card_id),"spell_class_id":int(spec.spell_class_id),"spell_row_sha256":str(spec.source_spell_row_sha256),"local_skill_id":key,"skill_source_evidence":evidence,"cannot_swap":bool(spec.get("buff_card_cannot_swap",false)),"cannot_stack_card":bool(spec.get("cannot_stack_card",false)),"input":input_proof}
	if learning_only:receipt["source_learning_record"]=learning_record.duplicate(true)
	receipts.append(receipt);state["source_skill_book_receipts"]=receipts
	var payload: Dictionary=paid.overrides.duplicate(true);payload["consumable_state"]=state;payload["original_skill_state"]=learned;payload["item_use_cooldowns"]=load("res://scripts/loot/patch523_item_use.gd").call("next_cooldowns",world,record,spec)
	# Learning/profiles were only quoted above. The shared existing skill
	# catalog state is changed after the exact physical/debit save succeeds.
	if is_quest and not QUEST_CONSUME.matches_payload(world,paid,payload):return _failure("퀘스트 스킬서의 실제 잔량·학습·사용 장부 후보 불일치")
	busy=true;_candidate_kind="skill_book_use";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:
		world.patch523_owner_state_problem="원문 스킬서 저장 결과 미확정 · 정상 불러오기 전 재학습 중지";return _failure(world.patch523_owner_state_problem)
	if is_quest and not world.quest_service.import_state(payload.quest_state):
		world.patch523_owner_state_problem="퀘스트 스킬서 저장 후 장부 채택 미확정 · 정상 불러오기 전 재학습 중지";return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.item_use_cooldowns=payload.item_use_cooldowns;world.consumable_service.import_state(state)
	catalog.source_quest_knowledge=learned.get("source_quest_knowledge",{}).duplicate(true);catalog.learned=learned.learned.duplicate(true);catalog.revision+=1
	world.original_skills.refresh_buffs_after_learning(key);world._refresh_speed_modifiers();world.deferred_save.cancel()
	return {"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"local_skill_id":key,"learning_only":learning_only,"execution_allowed":not learning_only,"message":str(skill.get("name",key))+" 원문 학습 완료 · 실행 대기" if learning_only else str(skill.get("name",key))+" 습득"}


# The existing skill items keys distinguish arrow/bullet cost roles. Their
# selected actual physical item still needs the current gameplay category and
# immutable ownership proof; no spell material or source ID is inferred by name.
static func original_skill_ammo(world: Node,cost_key: String,quantity: int) -> Dictionary:
	if cost_key not in ["화살","총알"] or quantity==0:return {"handled":false}
	var selected: Variant=world.consumable_service.export_state().get(AMMO_EQUIPPED,{})
	if selected=={}:return {"handled":false}
	if not selected is Dictionary or quantity<1:return _failure("선택한 원문 스킬 탄약 증명 형식 불일치")
	var key: String=str(selected.get("name",""));var owned: Dictionary=ammo_owned(world,str(selected.get("physical_id","")))
	var category: String="Arrow" if cost_key=="화살" else "Bullet"
	if owned.is_empty() or owned.inventory_key!=key or owned.receipt!=selected.get("receipt") or NATIVE_FIELDS.field(owned.record,"source_category_name")!=category or not ammo_worn(world,key) or world._current_ammo_name()!=key or quantity>int(owned.remaining):return _failure("선택 원문 탄약의 실제 개체·종류·잔량·착용 조건 미충족")
	return {"handled":true,"ok":true,"inventory_key":key,"physical_id":selected.physical_id,"quantity":quantity,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-quantity,"receipt":owned.receipt.duplicate(true),"ownership_kind":owned.ownership_kind,"cost_role":cost_key}


static func spell_material_profile(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523" or not D.currency_identity_name(record).is_empty():return {} # Currency wallets keep their existing separate owner.
	if record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity() or record.get("source_test_item")!=false or record.get("source_bless_raw")!=1 or D.equipment(record) or not record.get("source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var text: String=FileAccess.get_file_as_string("res://data/skills/player_skills523_bindings.json")
	if text.sha256_text()!="497a594e7312ce98dd966b737b1bfb4555072af3c0d5b63d61b8ee2c33075346":return {}
	var bindings: Variant=JSON.parse_string(text)
	if not bindings is Dictionary or not bindings.get("material_inventory_keys") is Dictionary:return {}
	var definition: Dictionary=D.current_original_definition(record)
	if definition.is_empty():return {}
	var matches: Array=[]
	for type_id: String in bindings.material_inventory_keys:
		var bridge: Variant=bindings.material_inventory_keys[type_id]
		if not bridge is Dictionary or bridge.get("native_item_id")!=record.get("source_item_class_id"):continue
		for row: Dictionary in definition.get("item_bonus",[]):
			if row.get("IsPossession")==false and row.get("bonus",{}).get("BonusTypeID")==89 and row.bonus.get("BonusApplicationTypeID")==0 and row.bonus.get("BonusApplicationTargetID")==0 and integer(row.bonus.get("Value")) and str(int(row.bonus.Value))==type_id:matches.append(type_id)
	return {"kind":"spell_material","spell_material_type_ids":matches,"standalone_effect_complete":false} if not matches.is_empty() else {}

static func material_owned(world: Node,uid: String) -> Dictionary:
	var owned: Dictionary=proof(world,uid)
	if not owned.is_empty():
		owned["inventory_key"]=str(owned.record.name);owned["ownership_kind"]="native";return owned
	var quest: Dictionary=QUEST_OWN.proof(world,uid)
	if not quest.get("ok",false) or quest.get("source_use_immediately",true) or quest.get("source_sha256")!=SOURCE.identity().get("source_sha256") or quest.source_item!=SOURCE.row("ItemClass",int(quest.item_class_id)):return {}
	var definition: Dictionary=D.definition_id(str(int(quest.item_class_id)));var record: Dictionary=D.variant_item(definition.get("native_record",{}),int(quest.bless_code_id))
	if supply_profile(record).is_empty():return {}
	return {"record":record,"remaining":int(quest.quantity),"receipt":world.item_instances[uid].quest_reward_receipt.duplicate(true),"inventory_key":str(quest.inventory_key),"ownership_kind":"quest"}

static func plan_spell_material(world: Node,skill: Dictionary,cost_key: String,quantity: int) -> Dictionary:
	if quantity<1 or not skill.get("source523",{}).get("applied",[]).has("materials") or world.original_skills==null:return {"handled":false}
	var adapter: Object=world.original_skills.catalog.source523
	var text: String=FileAccess.get_file_as_string("res://data/skills/player_skills523_bindings.json")
	var public: Variant=JSON.parse_string(text)
	if text.sha256_text()!="497a594e7312ce98dd966b737b1bfb4555072af3c0d5b63d61b8ee2c33075346" or not public is Dictionary or adapter.bindings!=public or not adapter.material_ready(public,cost_key):return _failure("원문 스킬 재료의 실제 공개 연결·전체 원문 정체 확인 필요")
	var ids: Array=[]
	for bridge: Variant in public.get("material_inventory_keys",{}).values():
		if bridge is Dictionary and bridge.get("inventory_key")==cost_key and bridge.get("native_item_id") not in ids:ids.append(bridge.get("native_item_id"))
	if ids.size()!=1:return {"handled":false}
	var remaining: int=quantity;var requests: Array=[];var physical_ids: Array=world.item_instances.keys();physical_ids.sort()
	# Deterministic host custody selection, not native material/odds semantics.
	# Every chosen ID is recorded with exact proof/remaining and consumed as quoted.
	for uid: String in physical_ids:
		var owned: Dictionary=material_owned(world,uid)
		if owned.is_empty() or owned.record.get("source_item_class_id")!=ids[0] or owned.record.get("source_bless_raw")!=1 or spell_material_profile(owned.record).is_empty():continue
		if world._item_locked(str(owned.inventory_key)) or world._item_locked(str(owned.inventory_key),uid):continue
		if not str(load("res://scripts/loot/patch523_item_use.gd").call("eligibility",world,owned.record)).is_empty():continue
		var amount: int=mini(remaining,int(owned.remaining))
		var request: Dictionary={"physical_id":uid,"quantity":amount,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-amount}
		request["quest_reward_receipt" if owned.ownership_kind=="quest" else RECEIPT]=owned.receipt.duplicate(true)
		requests.append(request);remaining-=amount
		if remaining==0:break
	if remaining>0:return _failure("정확한 원문 스킬 재료 소지 개체·잔량 부족 · 기존 비용 보존")
	return {"handled":true,"ok":true,"requests":requests,"native_item_id":ids[0],"cost_role":cost_key,"quantity":quantity,"selection_policy":"TWILIGHT_exact_proven_physical_id_order"}

static func stage_owned_debits(world: Node,requests: Array) -> Dictionary:
	var native_requests: Array=[];var quest_requests: Array=[];var seen: Dictionary={}
	for request: Variant in requests:
		if not request is Dictionary or request.size()!=5 or not request.get("physical_id") is String or seen.has(request.physical_id):return _failure("공동 스킬 재료 물리 요청·중복 정체 불일치")
		seen[request.physical_id]=true
		if request.has("quest_reward_receipt"):quest_requests.append(request)
		else:native_requests.append(request)
	var native: Dictionary=stage_debit(world,native_requests) if not native_requests.is_empty() else {}
	if not native_requests.is_empty() and not native.get("ok",false):return native
	var quest: Dictionary=QUEST_CONSUME.stage(world,quest_requests,str(SOURCE.identity().source_sha256)) if not quest_requests.is_empty() else {}
	if not quest_requests.is_empty() and not quest.get("ok",false):return _failure(str(quest.get("reason","공동 퀘스트 재료 차감 증명 불일치")))
	var bag: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true);var selected: Array=[]
	# Join only the exact selected physical edits. Never merge two full owner
	# inventory candidates over each other or consume an unquoted legacy object.
	for request: Dictionary in requests:
		var uid: String=request.physical_id;var name_value: String=str(world.item_instances[uid].name)
		if not integer(bag.get(name_value,0)) or int(bag[name_value])<int(request.quantity):return _failure("공동 재료 인벤토리 차감 수량 불일치")
		bag[name_value]=int(bag[name_value])-int(request.quantity)
		if bag[name_value]==0:bag.erase(name_value)
		var branch: Dictionary=quest if request.has("quest_reward_receipt") else native
		if branch.overrides.item_instances.has(uid):instances[uid]=branch.overrides.item_instances[uid].duplicate(true)
		else:instances.erase(uid)
	selected.append_array(native.get("selections",[]));selected.append_array(quest.get("selections",[]))
	var result: Dictionary={"inventory":bag,"item_instances":instances,"consumable_state":native.get("overrides",{}).get("consumable_state",world.consumable_service.export_state())}
	if not quest.is_empty():result["quest_state"]=quest.overrides.quest_state
	return {"ok":true,"overrides":result,"selections":selected,"quest_step":quest,"use_authorized":false}

static func spend_original_skill_materials(world: Node,skill: Dictionary,plan: Dictionary) -> Dictionary:
	var requests: Array=plan.get("physical_materials",[])
	if requests.is_empty():return {"handled":false}
	if world.original_skills==null or world.original_skills.material_plan(skill)!=plan:return _failure("현재 실제 스킬 재료 견적·소지 선택 변경")
	if not plan.get("physical_ammo",{}).is_empty():return _failure("스킬 탄약과 원문 재료 공동 비용은 탄약 소비 소유자로 전달해야 합니다")
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty() or world.hp<=0 or not world._patch523_item_allowed():return _failure("원문 스킬 재료 소비 저장 보호 중")
	var mp_cost: Variant=skill.get("mp",0);var hp_cost: Variant=skill.get("hp",0)
	if not integer(mp_cost) or not integer(hp_cost) or world.mp<int(mp_cost) or world.hp<=int(hp_cost):return _failure("기존 스킬 MP·HP 비용 미충족")
	var paid: Dictionary=stage_owned_debits(world,requests)
	if not paid.get("ok",false):return paid
	var payload: Dictionary=paid.overrides
	for key: String in plan.get("spent",{}):
		var amount: Variant=plan.spent[key]
		if not integer(amount) or int(amount)<1 or not integer(payload.inventory.get(key,0)) or int(payload.inventory.get(key,0))<int(amount) or world._item_locked(key):return _failure("기존 스킬 일반 재료 공동 비용 불일치")
		for physical: Variant in world.item_instances.values():
			if physical is Dictionary and physical.get("name")==key and (physical.has(RECEIPT) or physical.has("quest_reward_receipt")):return _failure("다른 물리 재료의 이름 기반 차감 금지")
		payload.inventory[key]=int(payload.inventory[key])-int(amount)
		if payload.inventory[key]==0:payload.inventory.erase(key)
	# No per-cast journal row: the debited physical quantities are the result.
	var state: Dictionary=payload.consumable_state;var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	state.erase(SKILL_MATERIAL_USES);payload["mp"]=int(world.mp)-int(mp_cost);payload["hp"]=int(world.hp)-int(hp_cost)
	if not paid.quest_step.is_empty() and not QUEST_CONSUME.matches_payload(world,paid.quest_step,payload):return _failure("스킬 원문 재료의 실제 잔량·퀘스트 사용 장부 공동 후보 불일치")
	busy=true;_candidate_kind="skill_material_use";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:
		world.patch523_owner_state_problem="원문 스킬 재료 저장 결과 미확정 · 정상 불러오기 전 재시전 중지";return _failure(world.patch523_owner_state_problem)
	if payload.has("quest_state") and not world.quest_service.import_state(payload.quest_state):
		world.patch523_owner_state_problem="원문 스킬 재료 저장 후 장부 채택 미확정 · 정상 불러오기 전 재시전 중지";return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.mp=int(payload.mp);world.hp=int(payload.hp);world.consumable_service.import_state(state);world.deferred_save.cancel()
	var consumed_units: int=0
	for input: Dictionary in paid.selections:consumed_units+=int(input.quantity)
	return {"handled":true,"ok":true,"saved":true,"consumed":consumed_units,"physical_input_count":paid.selections.size(),"selected_inputs":paid.selections.duplicate(true),"source_material_receipt_id":id}


# A post-confirmation data handoff, never an extra sprite/emission trigger.
# The existing one call site remains the sole dispatch owner until the visual
# owner publishes its exact compatible source-item API.
static func committed_use_context(result: Dictionary,record: Dictionary,sprite: int,dispatch_attempted: bool,dispatch_owner: String) -> Dictionary:
	if not result.get("ok",false) or not result.get("saved",false) or int(result.get("consumed",0))<1:return result
	result["source_use_context"]={"original_item":NATIVE_FIELDS.full(record).get("source_original_item",{}).duplicate(true),"source_definition_archive":SOURCE.identity(),"physical_id":str(result.get("physical_id","")),"remaining_quantity":result.get("remaining_quantity"),"effect_sprite_id":sprite,"commit_key":JSON.stringify([str(result.get("physical_id","")),result.get("remaining_quantity"),str(result.get("source_bag_receipt_id",""))]).sha256_text(),"visual_dispatch_owner":dispatch_owner,"visual_dispatch_attempted":dispatch_attempted,"render_observed":false}
	return result
