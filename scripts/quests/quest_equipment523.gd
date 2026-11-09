extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Selected quest ownership -> staged physical gear/equip -> one durable save.
## Exact base AC/HP/MP/MR/STR and compiled rank0 XP; other positive effects stay held.
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const GRANTS=preload("res://scripts/loot/patch523_item_inventory.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
const SOURCE="d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const PIN="38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const RULE_SHA="5e6ffac68fab01ba6de84226c1407f3076320aa8681fb83573116a2f822cb8d6"
const VIEW_SHA="7b023b445056cfdd79861f4327bbe6ef1a61884956682c46cefe93ac662aba30"
const IDS=[240,248,249,305,349,383,427,587,691,829,917,926,929,1129,1197,2772,2802,2832,2862,2872,3042,4851,4871,4921,4951,4971,5021,9091,30213,85643]
const REGEN_GEAR=[4851,4871,4921,4951,85643]
const EFFECTS={"ArmorClass":"def","HPPlus":"hpFlat","MagicResist":"mr","MPPlus":"mpFlat","Strength":"strFlat","WeaponSmallDamage":"small_damage","WeaponLargeDamage":"large_damage","WeaponHitBonus":"hit"}
static var cached: Dictionary={}
var data: Dictionary={}
var quotes: Dictionary={}
var saving_payload: Dictionary={}
var last_magic_hit: Dictionary={}
var problem: String="검증된 장비 수치 입력 미설치"
class SupplyView extends Node:
 var inventory: Dictionary
 var item_instances: Dictionary
 var gold: int
 var host: Node
 func _catalog_item_from_source_id(id: String)->Dictionary:return host._catalog_item_from_source_id(id)
func configure(world: Node)->void:
 var path: String="";var sha: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--quest-equipment-view="):path=arg.trim_prefix("--quest-equipment-view=")
  if arg.begins_with("--quest-equipment-view-sha256="):sha=arg.trim_prefix("--quest-equipment-view-sha256=")
 if path.is_empty() and sha.is_empty():return
 if sha!=VIEW_SHA or not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=sha:problem="정확한 장비 규칙 SHA 필요";return
 if cached.is_empty():
  var file:=FileAccess.open(path,FileAccess.READ)
  if file==null or file.get_length()!=36196:problem="장비 규칙 크기 불일치";return
  var parsed: Variant=JSON.parse_string(file.get_as_text())
  if not parsed is Dictionary or parsed.get("schema")!="twilight-quest-equipment-view-v1" or parsed.get("source_rules_sha256")!=RULE_SHA or parsed.get("snapshot")!="patch523" or parsed.get("catalog_sha256")!=FileAccess.get_sha256("res://data/catalog_v19.json") or parsed.get("source_files",{}).size()!=38:problem="장비 규칙 원본·카탈로그 불일치";return
  cached=parsed
 data=cached;problem=""
 # Definitions only; no grant, ownership conversion or monster-pool expansion.
 if D.pack_identity().get("sha256")!=PIN:return
 for id: int in IDS+[226318]:
  var record: Dictionary=profile(id,1)
  if record.is_empty():continue
  var previous: Dictionary=world._catalog_item_from_source_id(str(record.sourceId))
  if previous.is_empty():world.catalog_db["아이템"].append(effect_record(record))
 world._index_catalog_item_sources();world._index_item_weights()
func profile(id: int,bless: int)->Dictionary:
 if data.is_empty() or D.pack_identity().get("sha256")!=PIN or id not in IDS+[226318] or bless!=1:return {}
 var definition: Dictionary=D.definition_id(str(id));var bound: Dictionary=data.get("items",{}).get(str(id),{})
 if definition.is_empty() or definition.get("original_item")!=bound.get("item_class") or definition.original_item.get("TestItem",true) or not str(definition.original_item.get("ServiceRegionCode","")).is_empty() or not D.equipment(definition.get("native_record",{})) or not data.get("equipment_runtime",{}).has(str(id)):return {}
 var record: Dictionary=D.variant_item(definition.native_record,bless);var sums: Dictionary={}
 for row: Dictionary in definition.get("item_bonus",[]):
  var name: String=str(row.bonus_type.Name)
  if row.get("IsPossession",false) or int(row.bonus.BonusApplicationTypeID)!=0 or int(row.bonus.BonusApplicationTargetID)!=0:return {}
  if name in ["EnchantEquipGroupID","EnchantBonusGroupID"]:continue
  if name in ["RegenHP","RegenMP"]:
   if id not in REGEN_GEAR or row.unit.Name!="Value" or int(row.bonus.Value)<1:return {}
   continue
  if name=="MagicDamageReductionPercent":
   if id!=30213 or row.unit.Name!="Percentage" or row.bonus.Value!=30000:return {}
   continue
  if name=="WeaponErodeProof":
   # Existing TWILIGHT policy has no durability/erosion consuming action.
   # Preserve the exact immunity flag; do not invent repair or make it an
   # enhancement-destruction exemption. Integration must retain this rule.
   if id!=248 or row.unit.Name!="TrueFalse" or row.bonus.Value!=1:return {}
   continue
  if name=="WeaponType":
   if row.unit.Name!="WeaponTypeID" or int(row.bonus.Value) not in [1,6] or int(record.get("source_weapon_type_id",0))!=int(row.bonus.Value):return {}
   continue
  if not EFFECTS.has(name) or row.unit.Name!="Value":return {}
  sums[name]=int(sums.get(name,0))+int(row.bonus.Value)
 for name: String in sums:
  if int(record.get(EFFECTS[name],0))!=int(sums[name]):return {}
 var runtime: Dictionary=data.equipment_runtime[str(id)]
 if not runtime.get("extra_options",{}).get("1",{}).get("0",{}).is_empty() or not runtime.get("invokes",{}).get("1",{}).get("0",[]).is_empty():return {}
 for key: String in runtime.get("options",{}).get("1",{}).get("0",{}):
  if key!="xp_pct":return {}
 for row: Dictionary in bound.get("enchant_effects",[]):
  if int(row.EnchantLevel)==0 and int(row.BlessCode) in [0,1] and runtime.get("unconnected_effect_row_ids",[]).has(int(row.ID)):return {}
 return record
func effect_record(record: Dictionary)->Dictionary:
 var result: Dictionary=record.duplicate(true)
 var option: Variant=data.get("equipment_runtime",{}).get(str(int(record.source_item_class_id)),{}).get("options",{}).get("1",{}).get("0",{}).get("xp_pct",null)
 if option!=null:
  result["xp"]=float(option.get("total",0))/100.0 if option is Dictionary else float(record.get("xp",0))+float(option)/100.0
 if int(record.source_item_class_id)==248:result["quest_source_weapon_erosion"]={"original_bonus_id":7213,"original_value":1,"current_host_policy":"durability_and_erosion_disabled","enhancement_destruction_exemption":false}
 if int(record.source_item_class_id)==30213:result["quest_source_magic_reduction"]={"raw":30000,"scale":1000000,"source_percent":3,"host_stage":"after_critical_before_element_and_other_existing_defenses","host_rounding":"existing_round_nearest_min1","native_order_and_rounding_verified":false}
 var recovery: Dictionary=source_regeneration(record)
 if not recovery.is_empty():result["quest_source_regeneration"]={"amounts":recovery,"cadence":"TWILIGHT_existing_gear_recovery30s","source_interval_verified":false}
 result["quest_equipment_effect_basis"]={"rules_sha256":RULE_SHA,"item_pack_sha256":PIN,"level":0,"scope":"source_unconditional_AC_HP_MP_MR_STR_weapon_bounds_hit_and_rank0_XP_only"}
 return result
static func fail(reason: String)->Dictionary:return {"ok":false,"saved":false,"consumed":0,"reason":reason}
static func recognizes(world: Node,id: String)->bool:
 var p: Dictionary=world.item_instances.get(id,{});var r: Dictionary=p.get("record",{})
 return (r.get("source_pending_use",false) and IDS.has(int(r.get("source_item_class_id",0)))) or p.has("quest_source_input_receipt") or p.has("quest_equipment_lineage")
static func requires_selected(world: Node,name: String)->bool:
 for id: String in world.item_instances:
  if world.item_instances[id].get("name")==name and recognizes(world,id):return true
 return false
static func stamp(world: Node)->String:
 return JSON.stringify([OWN.stamp(world),world.equipped_items,world.ui_preferences.get("item_locks",{}),world.job_class,world.level,world.hp,world.mp,world.rng.state,world._carrying_capacity(),world.consumable_service.export_state(),world.equipped_catalog,world.active_skill_buffs,world.active_item_buffs,world._effective_max_hp(),world._effective_max_mp()]).sha256_text()
func _input(world: Node,receipt: Dictionary)->Dictionary:
 var qid: String=str(receipt.get("quest_id",""));var reward_id: int=OWN.positive(receipt.get("reward_id"))
 if receipt.get("schema")!=1 or receipt.get("source_sha256")!=SOURCE or world.quest_service.claimed.get(qid)!=true:return {}
 var q: Dictionary=world.quest_service.index.get(qid,{})
 if world.quest_service.has_method("full"):q=world.quest_service.full(q)
 if q.is_empty() or not q.get("blockers",[]).is_empty() or not q.get("excluded_reasons",[]).is_empty():return {}
 var matches: Array=[]
 for row: Dictionary in q.source_rewards:
  if int(row.ID)==reward_id:matches.append(row)
 if matches.size()!=1:return {}
 var row: Dictionary=matches[0]
 if row.type_name!="Item" or row.ClanOnly or int(row.RewardEnhancementTypeID)!=1 or row.UseImmediately or int(row.Amount)!=OWN.positive(receipt.get("quantity")) or int(row.RewardClassID)!=OWN.positive(receipt.get("item_class_id")) or int(row.ItemBlessCodeID)!=OWN.positive(receipt.get("bless_code_id")) or row.source_item.get("TestItem",true):return {}
 var used: Dictionary={}
 for r: Dictionary in world.quest_service.item_grants.get(qid,[]):
  if int(r.reward_id)==reward_id:
   if not used.is_empty():return {}
   used=r
 if used.get("origin")!="held_use" or used.get("source_sha256")!=SOURCE or used.get("pack_sha256")!=PIN or int(used.get("item_class_id",0))!=int(row.RewardClassID) or int(used.get("quantity",0))!=int(row.Amount) or int(used.get("used_quantity",0))<1 or int(used.get("used_quantity",0))>int(row.Amount) or int(used.get("bless_raw",0))!=int(row.ItemBlessCodeID):return {}
 if used.get("inventory_key")!="[원본 보상] "+str(row.source_item.get("Name","")):return {}
 if row.source_item!=D.definition_id(str(int(row.RewardClassID))).get("original_item"):return {}
 return {"source":row,"used":used}
func _reward_proof_matches(world: Node,id: String,physical: Dictionary)->bool:
 var receipt: Variant=physical.get("quest_source_input_receipt");var proof: Variant=physical.get("source_m_reward_proof")
 if not receipt is Dictionary or not proof is Dictionary or id.length()!=32 or not id.is_valid_hex_number(false):return false
 var input: Dictionary=_input(world,receipt)
 if input.is_empty() or str(physical.get("quest_source_input_physical_id","")).is_empty() or proof.get("source_snapshot")!="patch523" or OWN.positive(proof.get("bless"))!=OWN.positive(receipt.get("bless_code_id")) or proof.get("enchant")!=0:return false
 var output: int=OWN.positive(physical.get("record",{}).get("source_item_class_id"));var input_id: int=OWN.positive(receipt.get("item_class_id"))
 if input_id==369002:
  for key: String in proof:
   if key not in ["source_snapshot","item_class_id","source_item_class_id","lucky_bag_class_id","select_reward_id","entity_id","bless","enchant","initial_enchant_origin","original_initial_enchant"]:return false
  if output!=226318 or OWN.positive(proof.get("item_class_id"))!=369002 or OWN.positive(proof.get("source_item_class_id"))!=226318 or OWN.positive(proof.get("select_reward_id"))!=12522 or OWN.positive(proof.get("entity_id"))!=59062 or proof.get("lucky_bag_class_id")!=0 or int(receipt.quantity)!=1:return false
  var spec: Dictionary=NATIVE_FIELDS.full(D.definition_id("369002").native_record).get("source_use_spec",{});var choices: Array=[]
  for row: Dictionary in spec.get("rewards",[]):
   if int(row.source_entity_id)==59062:choices.append(row)
  if choices.size()!=1 or int(spec.get("select_reward_id",0))!=12522 or int(choices[0].item_class_id)!=output or int(choices[0].amount)!=1 or int(choices[0].bless_raw)!=1:return false
  if choices[0].get("enchant")!=null or proof.get("original_initial_enchant")!=null or proof.get("initial_enchant_origin")!="twilight_configured_default_zero":return false
  var copies: int=0
  for p: Dictionary in world.item_instances.values():
   if p.get("quest_source_input_receipt")==receipt and p.get("quest_source_input_physical_id")==physical.quest_source_input_physical_id:copies+=1
  return copies==1
 if not IDS.has(input_id) or output!=input_id or OWN.positive(proof.get("item_class_id"))!=output or OWN.positive(proof.get("source_item_class_id"))!=output:return false
 var supplier: Dictionary=proof.get("supplier",{});var lineage: Dictionary=physical.get("quest_equipment_lineage",{})
 if supplier.get("kind")!="quest_equipment_current523" or supplier.get("source_sha256")!=SOURCE or supplier.get("item_pack_sha256")!=PIN or supplier.get("input_receipt")!=receipt or supplier.get("input_physical_id")!=physical.quest_source_input_physical_id or int(supplier.get("quantity",0))!=1:return false
 var remaining: int=OWN.positive(supplier.get("remaining_before"))
 if OWN.positive(supplier.get("original_quantity"))!=OWN.positive(receipt.get("quantity")) or remaining<1 or remaining>int(receipt.quantity) or supplier.get("quantity")!=1:return false
 var sequence: int=OWN.positive(lineage.get("use_sequence"))
 if sequence!=int(receipt.quantity)-remaining+1:return false
 if lineage.get("schema")!=1 or lineage.get("kind")!="selected_quest_unit" or sequence<1 or sequence>int(input.used.used_quantity):return false
 var input_physical: String=str(physical.quest_source_input_physical_id)
 if world.item_instances.has(input_physical):
  var current_input: Dictionary=OWN.proof(world,input_physical)
  if not current_input.get("ok",false) or world.item_instances[input_physical].quest_reward_receipt!=receipt or int(current_input.quantity)!=int(receipt.quantity)-int(input.used.used_quantity):return false
 elif int(input.used.used_quantity)!=int(receipt.quantity):return false
 var copies: int=0
 for p: Dictionary in world.item_instances.values():
  if p.get("quest_source_input_receipt")==receipt and p.get("quest_equipment_lineage",{}).get("use_sequence")==sequence:copies+=1
 return copies==1
func _state_matches(world: Node,id: String)->Dictionary:
 var p: Dictionary=world.item_instances.get(id,{})
 if not _reward_proof_matches(world,id,p):return fail("장비 입력/출력 계보·원본 영수증 불일치")
 var same_name: int=0
 for physical: Dictionary in world.item_instances.values():
  if physical.get("name")==p.get("name"):same_name+=1
 if OWN.positive(world.inventory.get(str(p.get("name",""))))!=same_name:return fail("장비 수량·개체 합계 불일치")
 var r: Dictionary=p.get("record",{});var canonical: Dictionary=profile(int(r.get("source_item_class_id",0)),int(p.source_m_reward_proof.bless))
 if canonical.is_empty():return fail("현재 검증된 +0 능력·경험치 이외 원본 장비 효과 연결 대기")
 var expected: Dictionary=canonical.duplicate(true)
 if r.has("bless_state"):expected["bless_state"]="normal"
 var root_record: Dictionary=D.variant_item(D.data().get("item_definitions",{}).get(str(int(canonical.source_item_class_id)),{}).get("native_record",{}),1)
 if r.has("bless_state"):root_record["bless_state"]="normal"
 var normalized: Variant=JSON.parse_string(JSON.stringify(r))
 var exact_record: bool=normalized==JSON.parse_string(JSON.stringify(expected)) or normalized==JSON.parse_string(JSON.stringify(root_record))
 if not exact_record or p.get("name")!=canonical.name or p.get("level")!=0 or str(p.get("element",""))!="" or p.get("element_level",0)!=0 or p.get("bless_state")!="normal":return fail("장비 현재 축복·강화·원본 상태 미지원")
 for key: String in p:
  if key not in ["name","record","level","element","element_level","bless_state","source_m_reward_proof","quest_source_input_receipt","quest_source_input_physical_id","quest_equipment_lineage"]:return fail("알 수 없는 장비 상태 보존")
 return {"ok":true,"record":canonical,"physical":p.duplicate(true)}
func quote(world: Node,id: String,target: String="",remove: bool=false)->Dictionary:
 if world.hp<=0:return fail("생존 상태에서 장비를 조작할 수 있습니다")
 if data.is_empty() or D.pack_identity().get("sha256")!=PIN:return fail(problem if not problem.is_empty() else "검증된 원본 아이템 입력 필요")
 if world.quest_service.save_blocked or not world._patch523_item_allowed() or world._option_awakening_busy():return fail("현재 저장·행동 보호")
 var p: Dictionary=world.item_instances.get(id,{})
 if p.is_empty():return fail("선택 개체 없음")
 var payload: Dictionary={"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true),"equipped_items":world.equipped_items.duplicate(true)}
 var record: Dictionary={};var output_id: String=id;var owned: Dictionary={};var consumed: int=0
 if p.get("record",{}).get("source_pending_use",false):
  if remove:return fail("보관 장비는 장착 상태가 아닙니다")
  var prepared: Dictionary=OWN.prepare_debit(world,id,1)
  if not prepared.get("ok",false):return prepared
  owned=prepared.ownership;record=profile(int(owned.item_class_id),int(owned.bless_code_id))
  if record.is_empty():return fail("현재 검증된 +0 능력·경험치 이외 원본 장비 효과 연결 대기")
  if world._is_instance_equipped(id):return fail("보관 입력 장착 상태 오류")
  var usage: Dictionary=OWN.use_state(world,prepared,PIN)
  if not usage.ok:return usage
  var supplier: Dictionary={"kind":"quest_equipment_current523","source_sha256":SOURCE,"item_pack_sha256":PIN,"input_physical_id":id,"input_receipt":p.quest_reward_receipt.duplicate(true),"quantity":1,"remaining_before":int(owned.quantity),"original_quantity":int(owned.original_quantity)}
  var view:=SupplyView.new();view.host=world;view.inventory=prepared.override.inventory;view.item_instances=prepared.override.item_instances;view.gold=world.gold
  var supplied: Dictionary=GRANTS.stage(view,[{"item_class_id":int(owned.item_class_id),"amount":1,"bless_raw":1,"enchant":0}],supplier);view.free()
  if not supplied.get("ok",false):return fail(str(supplied.get("error","장비 공급 실패")))
  var added: Array=[]
  for uid: String in supplied.overrides.item_instances:
   if not prepared.override.item_instances.has(uid):added.append(uid)
  if added.size()!=1:return fail("선택 입력에 대한 출력 개체가 유일하지 않음")
  output_id=added[0];payload=prepared.override.duplicate(true);payload.merge(supplied.overrides,true);payload["quest_state"]=usage.state;payload["equipped_items"]=world.equipped_items.duplicate(true)
  var output: Dictionary=payload.item_instances[output_id];output["record"]=record.duplicate(true);output.record["bless_state"]="normal";output["quest_source_input_receipt"]=p.quest_reward_receipt.duplicate(true);output["quest_source_input_physical_id"]=id
  var seq: int=int(owned.original_quantity)-int(owned.quantity)+1
  output["quest_equipment_lineage"]={"schema":1,"kind":"selected_quest_unit","use_sequence":seq};consumed=1
 else:
  var checked: Dictionary=_state_matches(world,id)
  if not checked.ok:return checked
  record=checked.record
 if world._item_locked(str(p.name),id) or world._item_locked(str(p.name),"") or world._item_locked(str(record.name),""):return fail("잠긴 선택 장비 보존")
 var eligibility: String="" if remove else D.equipment_error(record,world.job_class,world.level,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
 if not eligibility.is_empty():return fail(eligibility)
 eligibility="" if remove else USE.eligibility(world,record)
 if not eligibility.is_empty():return fail(eligibility)
 if not remove and record.slot=="weapon":
  if not world._weapon_allowed_for_job(record,world.job_class):return fail("기존 직업별 무기 조건 미충족")
  var offhand: Dictionary=world.equipped_items.get("offhand",{})
  if not offhand.is_empty() and world._offhand_kind(offhand)=="shield" and not world._weapon_supports_shield(record):return fail("선택 무기·방패 공동 교체 소유자 연결 필요")
 var slot: String=world._equipment_slot_for_record(record)
 if not target.is_empty():
  if target!=slot and not (["ring1","ring2"].has(target) and ["ring1","ring2"].has(slot)):return fail("선택 장착 부위 불일치")
  slot=target
 if not world.EQUIPMENT_SLOT_ORDER.has(slot):return fail("현재 장착 부위 소유자 없음")
 if remove:
  slot=""
  for key: String in payload.equipped_items:
   if payload.equipped_items[key].get("instance_id")==id:slot=key;break
  if slot.is_empty():return fail("선택 장비가 장착되어 있지 않음")
 elif world._is_instance_equipped(output_id):return fail("이미 장착한 선택 개체")
 if not remove and record.slot=="offhand" and not world._can_equip_offhand(record):return fail("기존 무기·방패 호환 조건 미충족")
 var old: Dictionary=payload.equipped_items.get(slot,{})
 if not old.is_empty() and (world._item_locked(str(old.get("name","")),str(old.get("instance_id",""))) or world._item_locked(str(old.get("name","")),"")):return fail("잠긴 기존 장착 개체 보존")
 if not old.is_empty():
  var prior: Dictionary=world._source_catalog_record("아이템",old)
  if world.ITEM_OPTIONS.attribute(prior,"CON")!=0 or int(prior.get("weightBonus",0))!=0 or float(prior.get("hpPct",0))!=0 or float(prior.get("mpPct",0))!=0 or world._equipment_enhancement_level(slot)!=0 or world.item_instances.get(str(old.get("instance_id","")),{}).get("bless_state","normal")!="normal":return fail("기존 복합 용량·최대HP·강화 교체 거래 소유자 연결 필요")
 var worn: Dictionary=effect_record(record);worn["instance_id"]=output_id
 payload.equipped_items[slot]={} if remove else worn
 var weight: int=0
 for key: String in payload.inventory:
  if key.begins_with("[원본 보상] "):continue
  weight+=int(payload.inventory[key])*maxi(0,int(world.item_weight_index.get(key,0 if key=="아데나" else 3)))
 if consumed>0 and weight>world._carrying_capacity():return fail("원본 장비 반영 후 기존 소지 한도 초과")
 var slot_kind: String="weapon" if slot=="weapon" else ("armor" if world.ARMOR_EQUIPMENT_SLOTS.has(slot) else "accessory")
 var prior_enchant: Dictionary=world.ENCHANT.stats(slot_kind,world._equipment_enhancement_level(slot),world._physical_enhancement_record(old)) if not old.is_empty() else {}
 var next_enchant: Dictionary={} if remove else world.ENCHANT.stats(slot_kind,0,world._physical_enhancement_record(worn))
 var hp_delta: int=((-int(old.get("hpFlat",0))) if remove else int(record.get("hpFlat",0))-int(old.get("hpFlat",0)))+int(next_enchant.get("hp",0))-int(prior_enchant.get("hp",0))
 var mastery_type: int=world._mastery_actual_weapon_type()
 if slot=="weapon":
  var next_weapon: Dictionary=payload.equipped_items.get("weapon",{})
  mastery_type=preload("res://scripts/animation/source_weapon_banks.gd").local_type(world._normalized_weapon_type(str(next_weapon.get("type",""))))
 var flat: float=float(hp_delta)+float(world.weapon_mastery.catalog_bonus("hpFlat",mastery_type));var percent: float=world.original_skills.stat("hpPct") if world.original_skills!=null else 0.0
 for entry: Dictionary in world._all_equipped_records():flat+=float(entry.get("hpFlat",0));percent+=float(entry.get("hpPct",0))
 flat+=float(world._enhancement_stat_for_slots(world.EQUIPMENT_SLOT_ORDER,"hp"))+float(world._equipment_attribute_bonus("CON")*10)+float(world._active_skill_buff_total("hp"))+float(world._passive_skill_total("hpFlat"))+float(world._active_item_buff_total("hp_flat"))+float(world._equipped_bless_bonus("hp"))
 var next_max: int=maxi(1,int(round((world.max_hp+flat)*(1.0+percent))))
 var max_delta: int=next_max-world._effective_max_hp()
 payload["hp"]=mini(world.hp+maxi(0,max_delta),next_max)
 var added_mp: int=world._catalog_stat_sum("mpFlat")+world._active_item_buff_total("mp_flat")
 for current: Dictionary in world._all_equipped_records():
  if str(current.get("slot",""))!="":added_mp+=mp_contribution(world,current)
 added_mp+=(0 if remove else mp_contribution(world,record))-mp_contribution(world,old)
 var flat_mp: int=world.max_mp+added_mp+int(next_enchant.get("mp",0))-int(prior_enchant.get("mp",0))+world._enhancement_stat_for_slots(world.EQUIPMENT_SLOT_ORDER,"mp")+int(world.original_skills.stat("mp") if world.original_skills!=null else 0)
 var skill_mp_percent: float=world.original_skills.stat("mpPct") if world.original_skills!=null else 0.0
 var next_max_mp: int=maxi(1,int(round(float(flat_mp)*(1.0+world._equipped_numeric_sum("mpPct")+skill_mp_percent))))
 payload["mp"]=mini(world.mp,next_max_mp)
 var state: Dictionary=world.consumable_service.export_state();var log: Variant=state.get("source_quest_equipment_receipts",[])
 if not log is Array or log.size()>=10000:return fail("장비 거래 영수증 형식·보관 한도 확인 필요")
 log=log.duplicate(true);log.append({"schema":1,"action":"unequip" if remove else "equip","source_sha256":SOURCE,"item_pack_sha256":PIN,"rules_sha256":RULE_SHA,"selected_input_id":id,"physical_id":output_id,"item_class_id":int(record.source_item_class_id),"slot":slot,"consumed":consumed,"input":owned.duplicate(true)})
 state["source_quest_equipment_receipts"]=log;payload["consumable_state"]=state
 var candidate: Dictionary={"ok":true,"kind":"quest_equipment_candidate.v1","base_stamp":stamp(world),"payload":payload,"input_id":id,"output_id":output_id,"target_slot":slot,"remove":remove,"consumed":consumed,"record":record}
 var token: String=Crypto.new().generate_random_bytes(16).hex_encode();candidate["token"]=token
 if quotes.size()>=64:quotes.erase(quotes.keys()[0])
 quotes[token]=candidate.duplicate(true)
 return candidate.duplicate(true)
func cancel(token: String)->void:quotes.erase(token)
func commit(world: Node,quoted: Dictionary)->Dictionary:
 if not quoted.get("ok",false):return quoted
 var token: String=str(quoted.get("token",""))
 if not quotes.has(token) or quotes[token]!=quoted:return fail("장비 후보 증명 불일치")
 quoted=quotes[token].duplicate(true);quotes.erase(token)
 if quoted.get("kind")!="quest_equipment_candidate.v1" or quoted.get("base_stamp")!=stamp(world):return fail("장비 선택 후보 변경 · 다시 선택 필요")
 var fresh: Dictionary=quote(world,str(quoted.input_id),str(quoted.target_slot),bool(quoted.remove))
 # A fresh materialization deliberately has a different random UUID; validate
 # the selected proof/state stamp, never silently switch the selected input.
 if not fresh.get("ok",false):return fresh
 cancel(str(fresh.token))
 var payload: Dictionary=quoted.payload;var previous: String=FileAccess.get_sha256(world.save_path())
 saving_payload=payload.duplicate(true)
 var error: Error=world._save_game(true,payload)
 saving_payload.clear()
 if error!=OK:
  if world.get("patch523_owner_state_problem") is String and not world.patch523_owner_state_problem.is_empty():
   world.quest_service.save_blocked=true;return fail("공동 장비 저장 결과 미확정 · 재사용 중지")
  var parser:=JSON.new();var parsed: Error=parser.parse(FileAccess.get_file_as_string(world.save_path()))
  var disk: Variant=parser.data if parsed==OK else null;var expected: Dictionary=JSON.parse_string(JSON.stringify(payload,"",true,true));var confirmed: bool=disk is Dictionary
  if confirmed:
   for key: String in expected:
    if disk.get(key)!=expected[key]:confirmed=false;break
  if not confirmed:
   if FileAccess.get_sha256(world.save_path())!=previous:world.quest_service.save_blocked=true
   return fail("장비 원자 저장 실패·결과 확인 필요")
  if not world.equipment_collections.accept_load(disk):world.quest_service.save_blocked=true;return fail("장비 저장 재확인 필요")
 world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.equipped_items=payload.equipped_items;world.hp=payload.hp;world.mp=payload.mp
 if payload.has("quest_state"):world.quest_service.import_state(payload.quest_state)
 world.consumable_service.import_state(payload.consumable_state);world.deferred_save.cancel();world._invalidate_equipment_static();world._refresh_speed_modifiers();world.quest_auto.refresh_context(world);world.hud.refresh_inventory(world.inventory);world._update_hud()
 return {"ok":true,"saved":true,"consumed":int(quoted.consumed),"physical_id":str(quoted.output_id),"slot":str(quoted.target_slot),"source_effect_scope":"verified +0 base AC/HP/MP/MR/STR, weapon bounds/hit and rank0 XP; enhancement/proc/other effects not activated"}
static func mp_contribution(world: Node,record: Dictionary)->int:
 var typed: int=int(record.get("mpFlat",record.get("max_mp_bonus",0)))
 var total: int=typed
 if typed==0:
  for fragment: String in str(record.get("desc","")).split("·"):
   var segment: String=fragment.strip_edges()
   if segment.begins_with("MP ") or segment.begins_with("Max MP "):total+=maxi(0,world.ITEM_OPTIONS._signed_integer(segment.substr(3 if segment.begins_with("MP ") else 7)))
 return total
func authorizes_save(payload: Dictionary)->bool:return not saving_payload.is_empty() and saving_payload==payload
func activate(world: Node,id: String,target: String="",remove: bool=false)->bool:
 if not recognizes(world,id):return false
 var result: Dictionary=commit(world,quote(world,id,target,remove))
 world.hud.show_message("원본 +0 장비 "+("해제" if remove else "장착")+" 저장 완료" if result.get("ok",false) else str(result.get("reason",problem)))
 return true

func source_regeneration(record: Dictionary)->Dictionary:
 var item: int=int(record.get("source_item_class_id",0));var result: Dictionary={}
 if item not in REGEN_GEAR:return result
 for row: Dictionary in D.definition_id(str(item)).get("item_bonus",[]):
  if row.bonus_type.Name in ["RegenHP","RegenMP"]:
   result["hp" if row.bonus_type.Name=="RegenHP" else "mp"]=int(row.bonus.Value)
 return result
func recovery_for_worn(world: Node,record: Dictionary)->Dictionary:
 if not world.ui_preferences.get("quest523_source_gear_regen_enabled",true):return {}
 var iid: int=int(record.get("source_item_class_id",0));var uid: String=str(record.get("instance_id",""))
 if iid not in REGEN_GEAR or uid.is_empty() or not world._is_instance_equipped(uid):return {}
 var owned: Dictionary=_state_matches(world,uid)
 if not owned.get("ok",false) or owned.record.get("sourceId")!=record.get("sourceId"):return {}
 return source_regeneration(owned.record)

func reduce_hit(world: Node,damage: int,kind: String)->int:
 last_magic_hit={}
 # Exact source30213 normal+0 only. Source percentage is not configurable;
 # ordering and integer rounding reuse the existing host damage pipeline.
 if kind!="magic" or not world.ui_preferences.get("quest523_source_magic_reduction_enabled",true) or data.is_empty() or D.pack_identity().get("sha256")!=PIN:return damage
 var worn: Dictionary=world.equipped_items.get("gaiters",{})
 if int(worn.get("source_item_class_id",0))!=30213:return damage
 var id: String=str(worn.get("instance_id",""))
 if id.is_empty() or not world._is_instance_equipped(id):return damage
 var verified: Dictionary=_state_matches(world,id)
 if not verified.get("ok",false) or int(verified.record.get("source_item_class_id",0))!=30213 or verified.record.get("sourceId")!=worn.get("sourceId"):return damage
 var result: int=maxi(1,int(round(float(damage)*970000.0/1000000.0)))
 last_magic_hit={"physical_id":id,"item_class_id":30213,"raw_percent":30000,"damage_before":damage,"damage_after":result,"native_order_and_rounding_verified":false}
 return result
