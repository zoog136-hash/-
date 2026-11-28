extends SceneTree
const CATALOG=preload("res://scripts/skills/skill_catalog.gd")
class CollectionFixture extends RefCounted:
 func source_server_context():return {}
class Owner extends Node:
 var job_class:String="기사"
 var level:int=90
 var equipped_items:Dictionary={}
 var equipped_catalog:Dictionary={}
 var card_draw_fusion:Dictionary={"owned":{}}
 var card_collections:=CollectionFixture.new()
 var inventory:Dictionary={}
 func _current_weapon_type():return ""
 func _inventory_total_weight():return 0
 func _carrying_capacity():return 100
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("ROSTER_REGISTRY_FAIL ",label)
func _initialize():
 var owner=Owner.new();root.add_child(owner)
 var catalog=CATALOG.new();catalog.configure(owner)
 check(catalog.records.size()==479,"147 existing and 332 publicly documented skills retain their IDs")
 var ids:Dictionary={};var public_profiles:int=0
 for row:Dictionary in catalog.records:
  check(not ids.has(row.id),"unique stable ID "+str(row.id));ids[row.id]=true
  if row.get("reference_approx523",false):
   public_profiles+=1
   check(not catalog.owned(row) and not catalog.enabled(row),"reference profile does not auto-grant ownership")
   check(not row.get("runtime_blocked",false) and row.desc.contains("TWILIGHT 근사"),"public approximation identifies local execution")
 check(public_profiles==332,"every reference is available in the off-pack catalog")
 for alias:String in ["디스인티그레이트","디스인티그레이트 (에이션트)","셋팅 업"]:
  var canonical:String={"디스인티그레이트":"디스인트그레이트","디스인티그레이트 (에이션트)":"디스인트그레이트(에이션트)","셋팅 업":"세팅 업"}[alias]
  check(catalog.record_for(alias).id==catalog.record_for(canonical).id,"alias preserves prior save identity")
 for values:Array in [["요정","엘리멘탈 스피드",1.25,25.0,12.5],["암흑기사","다크 러쉬",1.25,25.0,25.0],["사신","고스트 스텝",1.3,30.0,25.0]]:
  owner.job_class=values[0];var row:Dictionary=catalog.record_for(values[1]);catalog.learned[row.id]=1
  check(catalog.enabled(row),"published passive available for matching class")
  check(CATALOG.CURRENT.runtime_text(row).contains("(TWILIGHT)"),"unknown official grade is clearly labeled shared local policy")
  check(is_equal_approx(catalog.speed(),values[2]) and catalog.stat("attackSpeed")==values[3] and catalog.stat("castSpeed")==values[4],"exact published percentages enter shared runtime stats")
  owner.job_class="기사";check(not catalog.enabled(row) and catalog.stat("attackSpeed")==0,"no cross-class passive leakage")
 var roster:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/official_roster.json"))
 var extensions:Array=roster.observations.filter(func(r):return r.status=="existing_shared_class")
 check(extensions.size()==11,"all explicitly reviewed common-spell class extensions")
 for fact:Dictionary in extensions:
  var row:Dictionary=catalog.record_for(fact.runtime_name);var stable:String=row.id
  catalog.learned[stable]=1;owner.job_class=fact["class"];owner.level=int(fact.level_display)-1
  check(not catalog.enabled(row) and catalog.level_locked(row),"old shared learned save cannot bypass new class level")
  owner.level=int(fact.level_display)
  check(catalog.enabled(row),"published new-class permission enabled")
  var resolved:Dictionary=catalog.resolve(row)
  check(resolved.id==stable and int(resolved.mp)==int(fact.mp_display) and int(resolved.minimum_level)==owner.level,"one stable ID with published class-specific level/MP")
  owner.job_class="마법사";owner.level=90
  check(catalog.resolve(row).mp==row.mp and catalog.resolve(row).minimum_level==row.minimum_level,"original wizard balance unchanged after class switch")
 owner.queue_free()
 print("OFFICIAL_ROSTER_REGISTRY_RESULT checks=",checks," errors=",errors," playable=479 references=332")
 quit(0 if errors==0 else 1)
