extends RefCounted
## Source numeric invokes on equipped physical IDs. No spell/recursive attacks.
const ENHANCE=preload("res://scripts/crafting/patch523_enhancement.gd")
static var fired: Array[Dictionary]=[]
static var weapon_fired: Array[Dictionary]=[]
static var spell_fired: Array[Dictionary]=[]
static var counter_fired: Array[Dictionary]=[]

static func valid(effect: Dictionary) -> bool:
	if not effect.get("option") is Dictionary or typeof(effect.get("probability")) not in [TYPE_INT,TYPE_FLOAT]:return false
	if typeof(effect.get("row_id")) not in [TYPE_INT,TYPE_FLOAT] or float(effect.row_id)!=floor(float(effect.row_id)) or float(effect.row_id)<1 or float(effect.row_id)>1000000000:return false
	var weight: float=float(effect.probability)
	if weight!=floor(weight) or weight<0 or weight>1000000:return false
	var option: Dictionary=effect.option
	for key: String in ["ID","Param1"]:
		if typeof(option.get(key)) not in [TYPE_INT,TYPE_FLOAT] or float(option[key])!=floor(float(option[key])):return false
	if float(option.ID)<1 or float(option.ID)>1000000000 or typeof(option.get("BySpellAttack"))!=TYPE_BOOL:return false
	var kind: int=int(option.get("InvokeOptionTypeID",0))
	if kind not in [1,3,5,6,61] or int(option.get("AttackTypeID",-1)) not in [0,1,2,3]:return false
	if kind==6 and (option.BySpellAttack or int(option.AttackTypeID) not in [0,1,2] or int(option.Param1)<1000000):return false
	for key: String in (["Param5","Param6"] if kind==61 else ["Param2","Param3","Param4","Param5","Param6"])+["MaterialTypeID","MaterialAmount","IsAmmoAttack","WeaponGroupID","ShieldTypeID","SuccessedInvokeOptionID","TargetKind","SiegeTargetKind"]:
		if int(option.get(key,-1))!=0:return false
	if kind==61 and (int(option.get("Param1",-1))<0 or int(option.get("Param1",-1))>1000000 or int(option.get("Param2",-1))<0 or int(option.get("Param2",-1))>1000000 or int(option.get("Param3",-1))<0 or int(option.get("Param3",-1))>1000000 or typeof(option.get("Param4"))!=TYPE_BOOL):return false
	return int(option.get("Param1",-1))>=0 and int(option.get("Param1",-1))<=1000000000 and effect.get("kind")=={1:"attack_source_spell",61:"defence_fixed_counter",3:"attack_fixed_damage",5:"defence_flat_reduction",6:"attack_weapon_scale"}[kind]

static func level_effects(record: Dictionary,level: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var levels: Variant=record.get("patch523_invoke_options",{})
	if not levels is Dictionary:return result
	var rows: Variant=levels.get(str(level),[])
	if not rows is Array:return result
	for row: Variant in rows:
		if row is Dictionary and valid(row):result.append(row)
	return result

static func active(world: Node,kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var strongest: Dictionary={}
	var visited: Dictionary={}
	var settings: Dictionary=ENHANCE.policy()
	var duplicate_mode: String=str(settings.get("duplicate_invoke_policy","strongest_probability_per_option"))
	if duplicate_mode not in ["strongest_probability_per_option","independent_physical_items"]:return result
	if kind!="attack_weapon_scale" and settings.get("invoke_order")!="after_existing_damage_resolution":return result
	for slot: String in world.EQUIPMENT_SLOT_ORDER:
		var worn: Dictionary=world.equipped_items.get(slot,{})
		var id: String=str(worn.get("instance_id",""))
		if id.is_empty() or visited.has(id):continue
		visited[id]=true
		var physical: Dictionary=world.item_instances.get(id,{})
		if physical.is_empty() or physical.get("name")!=worn.get("name") or world.patch523_equipment.bless_code(physical) not in [1,2]:continue
		var record: Dictionary=world._physical_enhancement_record(worn)
		var source_id: String=ENHANCE.item_id(record)
		if source_id.is_empty() or record.get("patch523_effect_basis",{}).get("selection")!="source_exact_level":continue
		if physical.has("sourceId") and str(physical.sourceId)!=str(record.get("sourceId","")):continue
		if world.patch523_equipment.data.get("items",{}).has(source_id) and not world.patch523_equipment.catalog_identity_matches(record,source_id):continue
		for effect: Dictionary in level_effects(record,int(physical.get("level",0))):
			if effect.get("kind")!=kind or not valid(effect):continue
			var selected: Dictionary=effect.duplicate(true)
			selected["instance_id"]=id;selected["item_name"]=str(worn.name);selected["source_item_id"]=source_id
			var key: String=str(int(effect.option.ID))
			if duplicate_mode=="strongest_probability_per_option":
				if not strongest.has(key) or int(selected.probability)>int(strongest[key].probability):strongest[key]=selected
			else:result.append(selected)
	for selected: Dictionary in strongest.values():result.append(selected)
	return result

static func roll(world: Node,weight: int) -> bool:
	if weight<=0:return false
	if weight>=1000000:return true
	return world.rng.randi_range(0,999999)<weight

static func attack_matches(option: Dictionary,kind: String) -> bool:
	var required: int=int(option.get("AttackTypeID",-1))
	return required==0 or required==int({"melee":1,"ranged":2,"magic":3}.get(kind,-2))

static func emit(world: Node,effect: Dictionary,target: Node2D) -> void:
	# Reuse the existing private source compositor; no fallback is called original.
	var sprite: int=int(effect.option.get("TargetEffectSpriteID",0))
	if sprite>0 and world.option_awakening!=null:world.option_awakening.combat.emit_sprite(sprite,target)

static func on_hit(world: Node,target: Node,attack_kind: String,main_target: bool,by_spell: bool) -> void:
	fired.clear();spell_fired.clear()
	if not is_instance_valid(target) or bool(target.get("dead")):return
	for effect: Dictionary in active(world,"attack_fixed_damage"):
		var option: Dictionary=effect.option
		if not attack_matches(option,attack_kind):continue
		if bool(option.BySpellAttack)!=by_spell or (bool(option.Param4) and not main_target):continue
		if not roll(world,int(effect.probability)):continue
		var amount: int=int(option.Param1)
		target.take_damage(amount,false,attack_kind)
		fired.append(effect)
		world.hud.append_log("원본 장비 발동 · %s · 추가 피해 %d · %.4f%%" % [str(effect.item_name),amount,float(effect.probability)/10000.0])
		emit(world,effect,target)
		if bool(target.get("dead")):break
	if world.original_skills==null or world.original_skills.equipment_source_depth>0:return
	for effect: Dictionary in active(world,"attack_source_spell"):
		var result: Dictionary=try_source_spell(world,effect,target,attack_kind,main_target,by_spell)
		if result.get("ok",false) and result.get("activated",false):spell_fired.append({"effect":effect,"result":result})

static func try_source_spell(world: Node,effect: Dictionary,target: Node,attack_kind: String,main_target: bool,by_spell: bool) -> Dictionary:
	if not valid(effect) or effect.get("kind")!="attack_source_spell" or world.original_skills==null or world.original_skills.equipment_source_depth>0:return {}
	var option: Dictionary=effect.option
	if not attack_matches(option,attack_kind) or bool(option.BySpellAttack)!=by_spell or not is_instance_valid(target) or bool(target.get("dead")):return {}
	var profile: Dictionary=world.patch523_equipment.data.get("equipment_spell_profiles",{}).get(str(int(option.Param1)),{})
	var context: Dictionary={"source":"patch523_equipment","source_sha256":world.patch523_equipment.digest,"instance_id":effect.instance_id,"source_item_id":effect.source_item_id,"row_id":int(effect.row_id),"option_id":int(option.ID)}
	var life: int=int(target.get("life_id"))
	if not preload("res://scripts/crafting/patch523_equipment_spells.gd").eligible(world,profile,target,life,context) or not roll(world,int(effect.probability)):return {}
	var result: Dictionary=world.original_skills.execute_equipment_source_spell(profile,target,life,context)
	result["activated"]=result.get("ok",false)
	return result

static func source_integer(world: Node,key: String) -> int:
	# Read this new field only from a current exact source derivation. An opaque
	# same-named base/save field is not authority to grant a new numeric effect.
	if key not in ["source_melee_flat_reduction_ignore","source_ranged_flat_reduction_ignore","source_magic_flat_reduction_ignore","source_pvp_flat_reduction_ignore","source_pvp_status_success_level","source_fear_flat_reduction_ignore"]:return 0
	var total: int=0;var visited: Dictionary={}
	for slot: String in world.EQUIPMENT_SLOT_ORDER:
		var worn: Dictionary=world.equipped_items.get(slot,{})
		var physical_id: String=str(worn.get("instance_id",""))
		if physical_id.is_empty() or visited.has(physical_id):continue
		visited[physical_id]=true
		var physical: Dictionary=world.item_instances.get(physical_id,{})
		if physical.is_empty() or physical.get("name")!=worn.get("name"):continue
		var blessing: int=world.patch523_equipment.bless_code(physical)
		if blessing not in [1,2]:continue
		var record: Dictionary=world._physical_enhancement_record(worn)
		var basis: Dictionary=record.get("patch523_effect_basis",{})
		var id: String=ENHANCE.item_id(record)
		if basis.get("selection")!="source_exact_level" or basis.get("sha256")!=world.patch523_equipment.digest or not world.patch523_equipment.catalog_identity_matches(record,id):continue
		if physical.has("sourceId") and physical.sourceId!=record.get("sourceId"):continue
		var rank: String=str(int(physical.get("level",0)))
		var expected: Variant=world.patch523_equipment.equipment_runtime_of(id).get("extra_options",{}).get(str(blessing),{}).get(rank,{}).get(key)
		var actual: Variant=record.get("enhancement_extra_options",{}).get(rank,{}).get(key)
		if typeof(expected) not in [TYPE_INT,TYPE_FLOAT] or typeof(actual) not in [TYPE_INT,TYPE_FLOAT] or actual!=expected or not is_finite(float(expected)) or float(expected)!=float(int(expected)) or int(expected)<0:continue
		total+=int(expected)
	return total

static func typed_flat_ignore(world: Node,attack_kind: String) -> int:
	if attack_kind not in ["melee","ranged","magic"]:return 0
	return source_integer(world,"source_"+attack_kind+"_flat_reduction_ignore")

static func pvp_flat_ignore(world: Node,attack_kind: String) -> int:
	if attack_kind not in ["melee","ranged","magic"] or ENHANCE.policy().get("source_pvp_flat_ignore_consumer")!="existing_singleplayer_flat_damage_projection":return 0
	return source_integer(world,"source_pvp_flat_reduction_ignore")

static func status_caster_level(world: Node,base_level: int) -> int:
	if ENHANCE.policy().get("source_pvp_status_level_consumer")!="existing_singleplayer_status_virtual_level":return base_level
	# Only the existing legacy status-chance input, never player.level or XP.
	return base_level+source_integer(world,"source_pvp_status_success_level")

static func fear_flat_ignore(world: Node,target: Node,by_spell: bool) -> int:
	var settings: Dictionary=ENHANCE.policy()
	if settings.get("source_fear_flat_ignore_consumer")!="existing_flat_damage_projection":return 0
	var scope: String=str(settings.get("source_fear_flat_ignore_scope","disabled"))
	if scope!="all_successful_hits" and not (scope=="normal_only" and not by_spell) and not (scope=="spell_hits_only" and by_spell):return 0
	var subject: Node
	match settings.get("source_fear_condition_subject","disabled"):
		"target_status":subject=target
		"self_status":subject=world.player
		_:return 0
	if not is_instance_valid(subject) or not subject.has_method("is_feared") or not subject.call("is_feared"):return 0
	return source_integer(world,"source_fear_flat_reduction_ignore")

static func weapon_scale(world: Node,amount: int,attack_kind: String,target: Node) -> int:
	weapon_fired.clear()
	var settings: Dictionary=ENHANCE.policy()
	if amount<=0 or settings.get("source_weapon_scale_scope")!="normal_weapon_roll_only" or settings.get("source_weapon_scale_stack")!="strongest_success_multiplier" or not is_instance_valid(target) or bool(target.get("dead")):return amount
	var multiplier: int=1000000
	for effect: Dictionary in active(world,"attack_weapon_scale"):
		var option: Dictionary=effect.option
		if option.BySpellAttack or not attack_matches(option,attack_kind):continue
		if not roll(world,int(effect.probability)):continue
		multiplier=maxi(multiplier,int(option.Param1))
		weapon_fired.append(effect)
		emit(world,effect,target)
	if weapon_fired.is_empty():return amount
	var scaled: float=float(amount)*float(multiplier)/1000000.0
	var result: int=maxi(0,int(floor(scaled)) if settings.get("source_weapon_scale_rounding")=="floor" else int(round(scaled)))
	world.hud.append_log("원본 무기 발동 · 기본 무기 피해 %d → %d · %s" % [amount,result,str(settings.get("source_weapon_scale_origin","TWILIGHT 처리 설정"))])
	return result

static func fixed_counter(world: Node,attacker: Node,attack_kind: String,amount: int,missed: bool=false) -> int:
	counter_fired.clear()
	if attack_kind not in ["melee","ranged","magic"] or ENHANCE.policy().get("source_counter_rounding") not in ["nearest","floor"] or ENHANCE.policy().get("source_counter_consumer")!="fixed_param3_times_param1" or world.source_save_blocked or not world.patch523_owner_state_problem.is_empty() or world.hp<=0 or not is_instance_valid(attacker) or bool(attacker.get("dead")):return amount
	var result: int=amount
	for effect: Dictionary in active(world,"defence_fixed_counter"):
		var option: Dictionary=effect.option
		if not attack_matches(option,attack_kind) or bool(option.BySpellAttack)!=(attack_kind=="magic") or (missed and not bool(option.Param4)):continue
		var physical: Dictionary=world.item_instances.get(str(effect.instance_id),{})
		if not preload("res://scripts/crafting/patch523_equipment_spells.gd").item_reason(world,physical.get("record",{}),str(effect.source_item_id)).is_empty():continue
		if not roll(world,int(effect.probability)):continue
		var reflected: float=float(option.Param3)*float(option.Param1)/1000000.0
		var remaining: float=float(result)*(1.0-float(option.Param2)/1000000.0)
		var nearest: bool=ENHANCE.policy().get("source_counter_rounding")=="nearest"
		result=maxi(0,int(round(remaining)) if nearest else int(floor(remaining)))
		var counter: int=maxi(0,int(round(reflected)) if nearest else int(floor(reflected)))
		counter_fired.append(effect)
		# Direct reflection cannot emit another normal-hit/proc/counter chain.
		attacker.take_damage(counter,false,"equipment_counter")
		emit(world,effect,world.player)
		world.hud.append_log("원본 장비 반격 · %s · 피해 %d · 피격 감소 %.2f%% · TWILIGHT 처리 순서" % [str(effect.item_name),counter,float(option.Param2)/10000.0])
		if bool(attacker.get("dead")):break
	return result

static func incoming(world: Node,attacker: Node,attack_kind: String,amount: int) -> int:
	fired.clear()
	if amount<=0 or not is_instance_valid(attacker) or bool(attacker.get("dead")):return amount
	var result: int=amount
	for effect: Dictionary in active(world,"defence_flat_reduction"):
		var option: Dictionary=effect.option
		if not attack_matches(option,attack_kind):continue
		if ENHANCE.policy().get("defence_invoke_spell_scope","")=="match_by_spell" and bool(option.BySpellAttack)!=(attack_kind=="magic"):continue
		if not roll(world,int(effect.probability)):continue
		result=maxi(0,result-int(option.Param1))
		fired.append(effect)
		world.hud.append_log("원본 장비 발동 · %s · 피격 리덕션 %d · %.4f%%" % [str(effect.item_name),int(option.Param1),float(effect.probability)/10000.0])
		emit(world,effect,world.player)
	return fixed_counter(world,attacker,attack_kind,result)

static func summary(record: Dictionary,level: int) -> String:
	var result: PackedStringArray=[]
	var settings: Dictionary=ENHANCE.policy()
	var extras: Dictionary=record.get("enhancement_extra_options",{}).get(str(clampi(level,0,21)),{})
	for key: String in ["source_melee_flat_reduction_ignore","source_ranged_flat_reduction_ignore","source_magic_flat_reduction_ignore"]:
		if extras.has(key):result.append("유형별 무시 처리: %s · 원본 수치와 TWILIGHT 추가 피해 투영 구분" % str(settings.get("source_typed_flat_ignore_consumer","disabled")));break
	if extras.has("source_pvp_flat_reduction_ignore"):result.append("PVP 원본 → 싱글플레이어 추가 피해: %s/TWILIGHT 설정" % str(settings.get("source_pvp_flat_ignore_consumer","disabled")))
	if extras.has("source_pvp_status_success_level"):result.append("스킬 성공 가상 레벨: %s/TWILIGHT 설정 · 실제 레벨/XP 불변" % str(settings.get("source_pvp_status_level_consumer","disabled")))
	if extras.has("source_fear_flat_reduction_ignore"):result.append("공포8 조건 리덕션 무시: %s · 주체 %s · 범위 %s/TWILIGHT 설정" % [str(settings.get("source_fear_flat_ignore_consumer","disabled")),str(settings.get("source_fear_condition_subject","disabled")),str(settings.get("source_fear_flat_ignore_scope","disabled"))])
	for effect: Dictionary in level_effects(record,level):
		if not valid(effect):continue
		var scope: String=str({0:"",1:"근거리 ",2:"원거리 ",3:"마법 "}.get(int(effect.option.AttackTypeID),""))
		if effect.kind=="attack_source_spell":result.append("원본 주문 #%d %s · 발동 %.4f%% · 타깃/소유/기간 재검사 · 계산 TWILIGHT 설정" % [int(effect.option.Param1),str(effect.get("spell_name","")),float(effect.probability)/10000.0])
		elif effect.kind=="defence_fixed_counter":result.append("고정 반격 %d ×%.2f · 피격 감소 %.2f%% · 회피 시 %s · 발동 %.4f%% · TWILIGHT 순서" % [int(effect.option.Param3),float(effect.option.Param1)/1000000.0,float(effect.option.Param2)/10000.0,str(effect.option.Param4),float(effect.probability)/10000.0])
		elif effect.kind=="attack_weapon_scale":result.append("%s무기 기본 피해 ×%.2f · 발동 %.4f%% · 현재 범위 %s/TWILIGHT 설정" % [scope,float(effect.option.Param1)/1000000.0,float(effect.probability)/10000.0,str(settings.get("source_weapon_scale_scope","disabled"))])
		else:result.append("%s%s %d · 발동 %.4f%%" % [scope,"적중 추가 피해" if effect.kind=="attack_fixed_damage" else "피격 리덕션",int(effect.option.Param1),float(effect.probability)/10000.0])
	if result.is_empty():return ""
	return " · ".join(result)+" · 처리 순서/중복 발동: TWILIGHT 설정"
