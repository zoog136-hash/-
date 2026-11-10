extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## PR238's verified source HP dice/metadata, using the current host potion
## modifiers and NPC healing hooks. No flat/name-derived potion substitution.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
static func metadata(record: Dictionary) -> Dictionary:
	# The pinned233 row has an explicit AutoUseRegistrable=TrueFalse/1 join.
	# PR238's five-effect HP whitelist predates that input flag. Interpret it
	# as registration permission; never discard an unknown effect/condition.
	if int(record.get("source_item_class_id",0))!=233:return {"ok":false}
	var definition: Dictionary=D.item_definition(record)
	var original: Dictionary=definition.get("original_item",{})
	var category: Dictionary=definition.get("category",{})
	if original.is_empty() or original.get("TestItem",true) or int(original.get("TargettingTypeID",0))!=1 or not str(original.get("ServiceRegionCode","")).is_empty() or category.get("Name")!="Potion" or not category.get("IsConsumable",false):return {"ok":false}
	var allowed: Dictionary={"HPRestoration":"Value","HPRestorationDiceNumber":"Value","HPRestorationDiceSpotCount":"Value","ItemConsumeDelay":"MilliSeconds","ItemConsumeEffectSpriteID":"SpriteID","AutoUseRegistrable":"TrueFalse"}
	var seen: Dictionary={}
	var result: Dictionary={"ok":true,"can_use_when_invisible":bool(original.get("CanUseWhenInvisible",false)),"auto_use_registrable":false,"consume_effect_sprite_id":0}
	for row: Dictionary in definition.get("item_bonus",[]):
		var kind: String=str(row.get("bonus_type",{}).get("Name",""));var bonus: Dictionary=row.get("bonus",{})
		if not allowed.has(kind) or seen.has(kind) or row.get("IsPossession")!=false or int(bonus.get("BonusApplicationTypeID",-1))!=0 or int(bonus.get("BonusApplicationTargetID",-1))!=0 or row.get("unit",{}).get("Name")!=allowed[kind]:return {"ok":false}
		seen[kind]=true
		if kind=="AutoUseRegistrable":
			var flag: Variant=bonus.get("Value")
			if not (flag is int or flag is float) or not is_finite(float(flag)) or float(flag)!=floorf(float(flag)) or flag<0 or flag>1:return {"ok":false}
			result["auto_use_registrable"]=int(bonus.Value)==1
		if kind=="ItemConsumeDelay":result["source_consume_delay_ms"]=int(bonus.get("Value",-1))
		if kind=="ItemConsumeEffectSpriteID":result["consume_effect_sprite_id"]=int(bonus.get("Value",0))
	return result if seen.size()==6 and int(result.get("source_consume_delay_ms",-1))>=0 else {"ok":false}

static func use(world: Node, saved: Dictionary) -> bool:
	if int(saved.get("source_item_class_id",0))!=233:return false
	if world.quest_service.save_blocked:
		world.hud.show_message("저장 보호 중 · 정상 저장 불러오기 필요");return true
	var record: Dictionary=USE.canonical(saved)
	var problem: String=USE.eligibility(world,record)
	var details: Dictionary=metadata(record)
	if problem.is_empty():problem=D.deadline_problem(record,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
	if problem.is_empty() and not details.get("ok",false):problem="원본 회복제의 효과·사용·등록 조건 미지원 · 아이템 보존"
	if problem.is_empty() and not details.can_use_when_invisible and world.is_player_concealed():problem="원본 조건: 은신 중 사용할 수 없습니다"
	if not problem.is_empty():world.hud.show_message(problem);return true
	if not world._patch523_item_allowed():return true
	var key: String=str(record.name)
	if world._item_locked(key,"") or int(world.inventory.get(key,0))<1 or int(world.hp)<=0:
		world.hud.show_message("소지량·잠금·생존 조건 미충족 · 원본 회복제 보존");return true
	var maximum: int=world._effective_max_hp()
	if world.hp>=maximum:world.hud.show_message("HP가 가득 찼습니다");return true
	var parameters: Dictionary=world._source_hp_potion_parameters(0)
	if float(world.item_use_cooldowns.get(parameters.cooldown_key,0))>0:
		world.hud.show_message("HP 물약 재사용 대기");return true
	var before_rng: int=world.rng.state
	var rolled: int=D.healing_amount(record,world.rng,0)
	parameters=world._source_hp_potion_parameters(rolled)
	var healed: int=world.patch523_npc_spells.extensions.healing(int(parameters.heal_amount),true)
	var old_hp: int=int(world.hp)
	var hp: int=mini(maximum,old_hp+healed)
	var inventory: Dictionary=USE.debit(world,key)
	var cooldowns: Dictionary=world.item_use_cooldowns.duplicate(true)
	cooldowns[str(parameters.cooldown_key)]=float(parameters.cooldown_seconds)
	if world._save_game(true,{"inventory":inventory,"item_use_cooldowns":cooldowns,"hp":hp})!=OK:
		world.rng.state=before_rng
		world.hud.show_message("회복 저장 실패 · 원본 수량·HP·추첨 상태 보존");return true
	world.inventory=inventory;world.item_use_cooldowns=cooldowns;world.hp=hp
	world._source_hp_potion_committed(healed)
	world.hud.refresh_inventory(world.inventory);world._update_hud()
	world.hud.show_message("%s 사용 · HP %d 회복" % [str(NATIVE_FIELDS.field(record,"source_display_name")),hp-old_hp])
	var sprite: int=int(details.get("consume_effect_sprite_id",0))
	if sprite>0:world.option_awakening.combat.emit_sprite(sprite,world.player,D.item_definition(record).get("original_item",{}))
	return true
