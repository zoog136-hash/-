extends SceneTree
const DROP=preload("res://scripts/loot_drop.gd")
const REVIEW=preload("res://scripts/loot/source3_reviewed_drop.gd")
const EXTRA=preload("res://scripts/loot/source3_drop_extensions.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("DROP_EXTENSION_FAIL ",label)
func _initialize():
 var world=load("res://scripts/world.gd").new();world._load_data()
 var registry:Dictionary=EXTRA.registry();check(registry.size()==24 and registry.has("45651"),"exact reviewed new source identities and held grade")
 if registry.size()!=24 or not registry.has("45651"):
  printerr("DROP_EXTENSION_REGISTRY_INVALID: check pinned source3 item links and drop manifest")
  world.free();quit(1);return
 var seen:int=0;var by_id:Dictionary={}
 for row:Dictionary in world.monster_db:
  if row.has("source_npc_id"):by_id[str(row.source_npc_id)]=row
 for id:String in registry:
  check(by_id.has(id),"reviewed actor exists in runtime catalog "+id)
  if not by_id.has(id):continue
  var row:Dictionary=by_id[id];var identity:Dictionary=REVIEW.identity(row)
  check(identity==registry[id].identity,"actual active source catalog identity "+id)
  for field:String in identity:
   var bad:Dictionary=identity.duplicate(true);bad[field]="changed"
   check(EXTRA.candidates("희귀",world.loot_catalog.by_name,bad).is_empty(),"altered identity rejected "+id+field)
  var appearance:Dictionary=row.duplicate(true);appearance.appearance_status="HOLD_TEST"
  check(REVIEW.identity(appearance).is_empty(),"appearance hold cannot opt in")
  var legacy:Dictionary=row.duplicate(true);legacy.catalog_only=false
  check(REVIEW.identity(legacy).is_empty(),"legacy pool cannot inherit source drops")
  var grades:Dictionary={}
  for target:Dictionary in registry[id].drops:grades[str(target.grade)]=true;seen+=1
  for grade:String in grades:
   var candidates:Array[Dictionary]=EXTRA.candidates(grade,world.loot_catalog.by_name,identity)
   check(not candidates.is_empty(),"exact namespace and existing item type available")
   var observed:Dictionary={};var rng:=RandomNumberGenerator.new();rng.seed=123
   for repeat:int in range(100):
    var picked:Dictionary=DROP._pick_equipment_entry(grade,[],world.loot_catalog,rng,str(row.name),identity)
    check(picked.get("quantity")==1 and candidates.any(func(c):return c.item_name==picked.get("item_name")),"existing rarity picker uses only explicit source membership")
    observed[str(picked.get("item_name",""))]=true
   check(observed.size()==candidates.size(),"all reviewed same-grade members reachable")
   var old_catalog:Dictionary=world.loot_catalog.duplicate(true)
   var original:String=str(candidates[0].item_name)
   old_catalog.l1j_monster_drops[str(row.name)]=[{"item_name":original}]
   for repeat:int in range(3):check(DROP._pick_equipment_entry(grade,[],old_catalog,rng,str(row.name),identity).item_name==original,"existing nonempty pool retains precedence")
 check(seen==41,"exact new SQL rows; one existing Barode row remains separate")
 check(EXTRA.candidates("전설",world.loot_catalog.by_name,registry["45651"].identity).is_empty(),"unreachable ordinary-monster legendary grade stays held")
 check(DROP.NORMAL_EQUIPMENT_RATES=={"일반":0.001,"고급":0.001,"희귀":0.001,"영웅":0.00015},"normal grade probabilities unchanged")
 world.free();print("SOURCE3_DROP_EXTENSIONS_RESULT identities=24 rows=",seen," checks=",checks," errors=",errors);quit(0 if errors==0 else 1)
