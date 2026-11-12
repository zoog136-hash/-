extends RefCounted
## Native equipment identity/target binding; execution stays in SkillService.
const ENHANCE=preload("res://scripts/crafting/patch523_enhancement.gd")
const DAMAGE_NAMES=["SpellDamageBase","SpellDamageDiceNumber","SpellDamageDiceSpotCount"]
const FLAGS=["FixedMagicDamage","IgnoreMagicResistance","IgnoreDamageReductionCalculation"]
static func values(profile: Dictionary) -> Dictionary:
 if profile.get("schema")!="patch523-equipment-damage-spell-v1" or not profile.get("source_spell") is Dictionary or not profile.get("effects") is Array:return {}
 var raw: Dictionary=profile.source_spell
 if raw.get("TestSpell")!=false or raw.get("TargettingTypeID")!=2 or raw.get("TargetKindID")!=11 or raw.get("TargetAreaRadius")!=0:return {}
 if profile.get("source_target_kind")!={"ID":11,"Name":"AllButMe","RootTargetKindNodeID":41}:
  # JSON numbers deserialize as floats; compare semantic integer fields explicitly.
  var target: Dictionary=profile.get("source_target_kind",{})
  if int(target.get("ID",-1))!=11 or target.get("Name")!="AllButMe" or int(target.get("RootTargetKindNodeID",-1))!=41:return {}
 for key: String in ["SiegeTargetKindID","HPCost","MPCost","VPCost","SpellMaterialTypeID","SpellMaterialItemAmount","SpellCompositionNode","CopySpellClassID","IsChargeSpell","CastingWeaponType","AlignmentChangeAmount","TargetLimitCount","BackwardPathCount"]:
  if not raw.has(key) or float(raw[key])!=0:return {}
 var out: Dictionary={}
 for effect: Variant in profile.effects:
  if not effect is Dictionary:return {}
  var type: Dictionary=effect.get("type",{});var bonus: Dictionary=effect.get("bonus",{});var link: Dictionary=effect.get("link",{})
  var name: String=str(type.get("Name",""))
  if (name not in DAMAGE_NAMES and name not in FLAGS) or out.has(name) or int(link.get("MinSpellLevel",-1))!=0 or int(link.get("SpellClassID",-1))!=int(raw.get("ID",-2)) or int(bonus.get("BonusApplicationTypeID",-1))!=0 or int(bonus.get("BonusApplicationTargetID",-1))!=0:return {}
  if int(type.get("UnitID",-1))!=(20 if name in ["FixedMagicDamage","IgnoreMagicResistance"] else 1):return {}
  var number: Variant=bonus.get("Value")
  if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) or float(number)!=floor(float(number)) or float(number)<0 or float(number)>1000000:return {}
  out[name]=int(number)
 if out.is_empty() or int(raw.get("ElementalTypeID",-1)) not in [0,1,2,3,4]:return {}
 var flags: int=0
 for key: String in FLAGS:
  if out.has(key):
   flags+=1
   if int(out[key])!=1:return {}
 if flags not in [0,3] or profile.get("mode")!=("fixed_ignore_mr_dr" if flags==3 else "source_dice_magic"):return {}
 if int(out.get("SpellDamageDiceNumber",0))>100 or (int(out.get("SpellDamageDiceNumber",0))>0 and int(out.get("SpellDamageDiceSpotCount",0))<1):return {}
 if not out.has("SpellDamageBase") and not out.has("SpellDamageDiceNumber"):return {}
 if int(out.get("SpellDamageBase",0))+int(out.get("SpellDamageDiceNumber",0))*int(out.get("SpellDamageDiceSpotCount",0))<=0:return {}
 return out

static func item_reason(world: Node,record: Dictionary,id: String) -> String:
 var raw: Dictionary=world.patch523_equipment.item_entry(id).get("item_class",{})
 if raw.is_empty() or raw.get("TestItem")!=false or not str(raw.get("ServiceRegionCode","")).is_empty():return "원본 테스트/서비스 지역 조건"
 var source: Dictionary=load("res://scripts/crafting/current523_equipment_spell_profiles.gd").item_constraint(world.patch523_equipment,record,id)
 if source.get("schema")!="patch523-equipment-spell-item-v1":return "원본 장비 발동 자격 입력 필요"
 if not str(source.get("blocked_reason","")).is_empty():return str(source.blocked_reason)
 var offset: Variant=ENHANCE.policy().get("source_item_datetime_offset_minutes")
 if typeof(offset) not in [TYPE_INT,TYPE_FLOAT] or float(offset)!=floor(float(offset)) or absf(float(offset))>840:return "원본 기간의 TWILIGHT 시간대 설정 확인 필요"
 for deadline: Dictionary in source.get("delete_times",[]):
  if float(Time.get_unix_time_from_system())>=float(deadline.get("local_unix",0))-float(offset)*60:return "원본 장비 사용 기간 만료 · 소유 보존"
 return world.PATCH523_ITEM_USE.reason(record,world.level,world.BASE508.source_class_id(world.job_class))

static func eligible(world: Node,profile: Dictionary,target: Node,life: int,context: Dictionary) -> bool:
 if ENHANCE.policy().get("source_equipment_spell_consumer")!="existing_skill_service_source_damage":return false
 if profile.get("mode")=="source_buff_modifiers":
  if ENHANCE.policy().get("source_equipment_buff_consumer")!="existing_life_scoped_status_service":return false
 else:
  if ENHANCE.policy().get("source_equipment_spell_formula")!="existing_magic_hit_element_flat_target_reduction":return false
 if world.source_save_blocked or not world.patch523_owner_state_problem.is_empty() or world.hp<=0 or not is_instance_valid(target) or bool(target.get("dead")) or int(target.get("life_id"))!=life:return false
 if not target is TwilightMonster or (buff_values(profile).is_empty() if profile.get("mode")=="source_buff_modifiers" else values(profile).is_empty()) or context.get("source")!="patch523_equipment" or context.get("source_sha256")!=world.patch523_equipment.digest:return false
 var physical_id: String=str(context.get("instance_id",""));var physical: Dictionary=world.item_instances.get(physical_id,{})
 if physical_id.is_empty() or not world._is_instance_equipped(physical_id) or physical.is_empty():return false
 var record: Dictionary=physical.get("record",{});var id: String=world.patch523_equipment.identity(physical)
 if id!=str(context.get("source_item_id","")) or not world.patch523_equipment.catalog_identity_matches(record,id) or not item_reason(world,record,id).is_empty():return false
 var raw: Dictionary=profile.source_spell
 if profile!=load("res://scripts/crafting/current523_equipment_spell_profiles.gd").of(world.patch523_equipment,int(raw.ID)):return false
 var linked: bool=false
 for effect: Dictionary in world.PATCH523_EQUIPMENT_COMBAT.active(world,"attack_source_spell"):
  if str(effect.instance_id)==physical_id and int(effect.row_id)==int(context.get("row_id",-1)) and int(effect.option.ID)==int(context.get("option_id",-1)) and int(effect.option.Param1)==int(raw.ID):linked=true;break
 if not linked:return false
 var cooldown: String="equipment523|"+physical_id+"|"+str(int(raw.ID))
 if float(world.skill_cooldowns.get(cooldown,0))>0:return false
 var distance: int=world._weapon_cell_distance(target)
 if distance<int(raw.get("MinCastRange",0)) or distance>int(raw.get("CastRange",0)) or not world._has_line_of_sight_world(world.player.global_position,target.global_position):return false
 if raw.get("CanCastOnInvisible")!=true and world.is_player_concealed():return false
 return true

const BUFF_FIELDS={
 "ArmorClassBonus":["ac",1,-1.0],"MagicResist":["mr",1,1.0],"DamageReduction":["reduction",1,1.0],"PVPDamageReduction":["reduction",1,1.0],
 "RangeDamageReduction":["source_ranged_reduction",1,1.0],"MeleeHit":["source_melee_hit",1,1.0],"RangeHit":["source_ranged_hit",1,1.0],
 "MeleeDamage":["source_melee_damage",1,1.0],"RangeDamage":["source_ranged_damage",1,1.0],"MeleeEvasion":["source_melee_evasion",1,1.0],"RangeEvasion":["source_ranged_evasion",1,1.0],
 "AttackSpeedBonus":["source_attack_speed_pct",3,.0001],"HPHealDecreasePercent":["source_hp_heal_decrease_raw",3,1.0],"HPPotionDecreasePercent":["source_potion_heal_decrease_raw",3,1.0],
 "MeleeDamageReductionPercent":["source_melee_reduction_pct",3,.0001],"RangeDamageReductionPercent":["source_ranged_reduction_pct",3,.0001],"MagicDamageReductionPercent":["source_magic_reduction_pct",3,.0001]}
const BUFF_SPELL_FIELDS={"BuffClassID":16,"SpellDebuffMinDuration":17,"SpellDebuffMaxDuration":17,"SpellHitProbabilityBase":3,"SpellHitProbabilityMin":3,"SpellHitProbabilityMax":3,"SpellHitProbabilityMultiplier":1,"SpellHitProbabilityByLevel":20}
static func buff_values(profile: Dictionary) -> Dictionary:
 if profile.get("schema")!="patch523-equipment-damage-spell-v1" or profile.get("mode")!="source_buff_modifiers":return {}
 var raw: Dictionary=profile.get("source_spell",{});var buff: Dictionary=profile.get("buff",{});var br: Dictionary=buff.get("source_buff",{})
 if raw.get("TestSpell")!=false or raw.get("TargettingTypeID")!=2 or int(raw.get("TargetKindID",-1)) not in [10,11,422] or raw.get("TargetAreaRadius")!=0:return {}
 for key: String in ["SiegeTargetKindID","HPCost","MPCost","VPCost","SpellMaterialTypeID","SpellMaterialItemAmount","SpellCompositionNode","CopySpellClassID","IsChargeSpell","CastingWeaponType","AlignmentChangeAmount","TargetLimitCount","BackwardPathCount"]:
  if not raw.has(key) or float(raw[key])!=0:return {}
 if br.get("IsEraseOnTimeEnd")!=true or int(br.get("MaxStackCount",-1))!=0 or br.get("IsBuffGroup")!=false or br.get("IsAbsoluteTimeBuff")!=false:return {}
 for key: String in br:
  if key.begins_with("IsEraseOn") and key!="IsEraseOnTimeEnd" and bool(br[key]):return {}
 var out: Dictionary={};var modifiers: Dictionary={}
 for e: Dictionary in profile.get("effects",[]):
  var t: Dictionary=e.get("type",{});var b: Dictionary=e.get("bonus",{});var link: Dictionary=e.get("link",{});var name: String=str(t.get("Name",""))
  if not BUFF_SPELL_FIELDS.has(name) or out.has(name) or int(t.get("UnitID",-1))!=int(BUFF_SPELL_FIELDS[name]) or int(link.get("MinSpellLevel",-1))!=0 or int(link.get("SpellClassID",-1))!=int(raw.get("ID",-2)) or int(b.get("BonusApplicationTypeID",-1))!=0 or int(b.get("BonusApplicationTargetID",-1))!=0:return {}
  var number: Variant=b.get("Value")
  if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) or float(number)!=floor(float(number)) or float(number)<0 or float(number)>1000000000:return {}
  out[name]=int(number)
 if not out.has("BuffClassID") or int(br.get("ID",-1))!=int(out.BuffClassID) or float(out.get("SpellDebuffMinDuration",0))<=0 or float(out.get("SpellDebuffMaxDuration",0))<float(out.SpellDebuffMinDuration) or float(out.SpellDebuffMaxDuration)>86400:return {}
 if out.has("SpellHitProbabilityMultiplier") and (not out.has("SpellHitProbabilityBase") or not out.has("SpellHitProbabilityMax")):return {}
 for e: Dictionary in buff.get("effects",[]):
  var t: Dictionary=e.get("type",{});var b: Dictionary=e.get("bonus",{});var link: Dictionary=e.get("link",{});var name: String=str(t.get("Name",""))
  if int(link.get("BuffClassID",-1))!=int(br.ID):return {}
  for key: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
   if int(link.get(key,-1))!=0:return {}
  var value: Variant=b.get("Value")
  if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floor(float(value)) or absf(float(value))>1000000000:return {}
  var key: String;var amount: float
  if name=="SpecialResistance" and int(t.get("UnitID",-1))==3 and int(b.get("BonusApplicationTypeID",-1))==2 and int(b.get("BonusApplicationTargetID",-1))==6:key="source_stun_resistance";amount=float(value)*.0001
  elif BUFF_FIELDS.has(name) and int(t.get("UnitID",-1))==int(BUFF_FIELDS[name][1]) and int(b.get("BonusApplicationTypeID",-1))==0 and int(b.get("BonusApplicationTargetID",-1))==0:key=str(BUFF_FIELDS[name][0]);amount=float(value)*float(BUFF_FIELDS[name][2])
  elif name=="CannotMove" and int(t.get("UnitID",-1))==20 and int(value)==1 and int(b.get("BonusApplicationTypeID",-1))==0 and int(b.get("BonusApplicationTargetID",-1))==0:key="source_hold";amount=1
  else:return {}
  modifiers[key]=float(modifiers.get(key,0))+amount
 if modifiers.is_empty() or modifiers!=profile.get("modifiers",{}):return {}
 out["modifiers"]=modifiers
 return out

static func buff_chance_raw(world: Node,profile: Dictionary,target: Node) -> int:
 var data: Dictionary=buff_values(profile)
 if data.is_empty():return 0
 if not data.has("SpellHitProbabilityBase"):return 1000000
 var settings: Dictionary=ENHANCE.policy()
 if settings.get("source_equipment_buff_probability")!="base_minus_mr_coefficient":return 0
 var unit: float=float(settings.get("source_equipment_buff_mr_coefficient_unit_raw",-1));var step: float=float(settings.get("source_equipment_buff_level_step_raw",-1))
 if unit<0 or unit>1000000 or step<0 or step>1000000:return 0
 var mr: float=maxf(0,float(target.get("magic_resistance"))+world.original_skills.status.modifier(target,"mr"))
 var chance: float=float(data.SpellHitProbabilityBase)-mr*float(data.get("SpellHitProbabilityMultiplier",0))*unit
 if int(data.get("SpellHitProbabilityByLevel",0))==1:chance+=float(world.level-int(target.get("monster_level")))*step
 var low: float=clampf(float(data.get("SpellHitProbabilityMin",0)),0,1000000);var high: float=clampf(float(data.get("SpellHitProbabilityMax",1000000)),low,1000000)
 return clampi(int(round(chance)),int(low),int(high))
