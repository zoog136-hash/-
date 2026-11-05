extends SceneTree
const DROPS=preload("res://scripts/loot/base508_monster_drops.gd")
const LOOT=preload("res://scripts/loot_drop.gd")
const TRANSFER=preload("res://scripts/loot/inventory_ground_transfer.gd")
var errors: Array=[]
class Host extends Node:
 var item_instances: Dictionary={}
 var next_item_instance_id: int=1
func check(value: bool,message: String) -> void:
 if not value: errors.append(message)
func item(id: String,name: String,grade: String,slot: String="weapon") -> Dictionary:
 return {"name":name,"source":"inven","sourceId":id,"sourceUrl":"https://lineagem.inven.co.kr/db/item/"+id,"type":"fixture","slot":slot,"grade":grade,"heal":100 if slot=="consumable" else 0}
func _initialize() -> void: call_deferred("run")
func run() -> void:
 # Numeric membership fixtures test contracts; they are not original resource evidence.
 var weapon: Dictionary=item("401","fixture weapon","유일")
 var potion: Dictionary=item("402","fixture potion","유일","consumable")
 var locked: Dictionary=item("403","fixture quest","희귀")
 var catalog: Dictionary={"by_name":{weapon.name:weapon,potion.name:potion,locked.name:locked},"potions":[potion.name]}
 var identity: Dictionary={"kind":"base508_npc_drop_identity","source_npc_id":10,"source_sprite_id":20}
 var document: Dictionary={"npcs":{"10":{"sprite_id":20}},"bindings":{},"drops":{"10":[]},"bless_codes":{"1":"Normal","2":"Blessed","3":"Cursed"}}
 for record: Dictionary in [weapon,potion,locked]:
  document.bindings[str(record.sourceId)]={"native_item_class_id":int(record.sourceId),"game_source_id":record.sourceId,"game_source":record.source,"game_source_url":record.sourceUrl,"game_name":record.name,"game_slot":record.slot,"game_type":record.type}
 document.drops["10"]=[{"ID":1,"NpcClassID":10,"ItemClassID":401,"Bless":2,"RequiredQuestID":0},{"ID":2,"NpcClassID":10,"ItemClassID":402,"Bless":1,"RequiredQuestID":0},{"ID":3,"NpcClassID":10,"ItemClassID":403,"Bless":1,"RequiredQuestID":90}]
 var groups: Dictionary=DROPS.resolve_candidates(document,identity,catalog)
 check(groups.size()==2,"Quest condition bypassed")
 var rng=RandomNumberGenerator.new();rng.seed=808
 var picked: Dictionary=DROPS.pick(groups,"equipment","유일",rng)
 check(not picked.is_empty() and picked.quantity==1 and picked.item_record.source_m_item_bless_raw==2,"Grade cap or Bless/quantity loss")
 check(DROPS.resolve_candidates(document,identity,catalog,{"90":true}).size()==3,"Explicit quest eligibility ignored")
 var duplicated: Dictionary=document.duplicate(true)
 for i: int in range(50): duplicated.drops["10"].append(document.drops["10"][0].duplicate(true))
 var duplicate_pool: Dictionary=DROPS.resolve_candidates(duplicated,identity,catalog)
 var rng_a=RandomNumberGenerator.new();var rng_b=RandomNumberGenerator.new();rng_a.seed=99;rng_b.seed=99
 for i: int in range(100):
  check(DROPS.pick(groups,"equipment","유일",rng_a)==DROPS.pick(duplicate_pool,"equipment","유일",rng_b),"Duplicate source row changed item chance or RNG")
 check(rng_a.state==rng_b.state,"Duplicate memberships added random rolls")
 var spoof: Dictionary=catalog.duplicate(true);spoof.by_name[weapon.name].sourceId="999"
 check(not DROPS.resolve_candidates(document,identity,spoof).has("401"),"Same name different ID granted")
 var foreign: Dictionary=catalog.duplicate(true);foreign.by_name[weapon.name].source="other_game"
 check(not DROPS.resolve_candidates(document,identity,foreign).has("401"),"Foreign namespace granted")
 var wrong_identity: Dictionary=identity.duplicate();wrong_identity.source_sprite_id=999
 check(DROPS.resolve_candidates(document,wrong_identity,catalog).is_empty(),"Foreign NPC sprite accepted")
 var potion_names: Array[String]=[str(potion.name)]
 check(LOOT._pick_potion(potion_names,false,catalog,rng)==potion.name,"Unique potion still hard-blocked")
 check(LOOT.NORMAL_EQUIPMENT_RATES=={"일반":0.001,"고급":0.001,"희귀":0.001,"영웅":0.00015},"Normal grade weights changed")
 check(LOOT.BOSS_EQUIPMENT_RATES=={"일반":0.001,"고급":0.001,"희귀":0.001,"영웅":0.01,"전설":0.002,"신화":0.00025,"유일":0.00001},"Boss grade weights changed")
 var metadata: Dictionary=DROPS.ground_metadata(picked,true)
 var ground: Dictionary=metadata.duplicate(true);ground.item_name=picked.item_name;ground.quantity=1
 var host=Host.new();root.add_child(host)
 check(TRANSFER.can_collect(host,ground),"Ground native item rejected")
 TRANSFER.restore_physical(host,ground)
 var physical: Dictionary=host.item_instances[ground.physical_item.id]
 check(physical.bless_state=="blessed" and physical.record.source_m_item_bless_raw==2,"Pickup lost native Bless variant")
 check(not TRANSFER.can_collect(host,ground),"Physical duplicate ownership accepted")
 var source: Dictionary=DROPS.data()
 var source_counts: Dictionary={}
 if not source.is_empty():
  source_counts=source.counts
  check(int(source.counts.rows)==46244 and int(source.counts.dangling_source_references)==0,"Private source index incomplete")
 var native_rolls: int=0;var native_equipment: int=0
 if not source.is_empty():
  var catalog_rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["아이템"]
  var actual_catalog: Dictionary=LOOT.build_catalog(catalog_rows)
  var chosen_identity: Dictionary={}
  var allowed_items: Dictionary={}
  for source_id: String in source.drops:
   var candidate_identity: Dictionary={"kind":"base508_npc_drop_identity","source_npc_id":int(source_id),"source_sprite_id":int(source.npcs[source_id].sprite_id)}
   var source_pool: Dictionary=DROPS.resolve_candidates(source,candidate_identity,actual_catalog)
   var supported: bool=false
   for group: Dictionary in source_pool.values():
    if group.kind=="equipment" and float(LOOT.BOSS_EQUIPMENT_RATES.get(str(group.item.get("grade","")),0.0))>0.0: supported=true
   if supported: chosen_identity=candidate_identity;allowed_items=source_pool;break
  check(not chosen_identity.is_empty(),"No live verified source item membership")
  var native_rng=RandomNumberGenerator.new();native_rng.seed=1701
  for attempt: int in range(2000):
   var entries: Array[Dictionary]=LOOT.roll_detailed([],true,actual_catalog,native_rng,"same-name legacy pools must not participate",chosen_identity)
   var per_kill_equipment: int=0
   for entry: Dictionary in entries:
    check(entry.has("source_m_drop_proof") and int(entry.quantity)==1 and allowed_items.has(str(int(entry.get("source_m_item_id",-1)))),"Actual native roll escaped ID/membership/quantity policy")
    if DROPS._equipment(entry.item_record):per_kill_equipment+=1;native_equipment+=1
   check(per_kill_equipment<=3,"Extra native equipment rolls")
   native_rolls+=1
  check(native_equipment>0,"Deterministic native equipment path never yielded an item")
 print("BASE508_DROP_TEST ",JSON.stringify({"errors":errors,"duplicates_checked":50,"deterministic_picks":100,"source_counts":source_counts,"native_rolls":native_rolls,"native_equipment_drops":native_equipment,"fixture_is_not_original_pixels":true}))
 host.queue_free();quit(0 if errors.is_empty() else 1)
