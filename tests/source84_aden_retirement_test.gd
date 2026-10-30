extends SceneTree
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
const NATIVE=preload("res://scripts/maps/native_png_registry.gd")
const OLD=preload("res://scripts/maps/remake_registry.gd")
var errors:int=0
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;failures.append(label);printerr("ADEN_RETIREMENT_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 check(not FileAccess.file_exists("res://data/maps/aden_field.json"),"retired authored geometry removed")
 check(not NATIVE.supports("aden_world") and NATIVE.load_field("aden_world")==null,"old native loader refuses Aden")
 check(not OLD.installed("aden_world") and OLD.load_field("aden_world")==null,"old remake loader refuses Aden")
 var field=RUN.load_field("aden_world")
 check(field!=null,"replacement loads without legacy Aden resources")
 if field!=null:
  var frozen:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_source84_gameplay.json")).gameplay
  var original:Array=field.data.monster_spawn.filter(func(row):return not row.has("source_key") and not row.get("local_habitat",false))
  check(original.size()==17 and original==frozen.monster_spawn and field.data.portal.size()==38 and field.data.portal==frozen.portal,"all original encounter rows and portals preserved exactly alongside approved added habitats")
  check(field.data.npc_spawn.size()==5,"five reviewed Aden NPCs remain")
  check(field.point_clear(Vector2(field.data.spawn_position[0],field.data.spawn_position[1]),4),"entry remains clear")
  for p:Dictionary in field.data.portal:
   check(field.point_clear(Vector2(p.position[0],p.position[1]),4),"portal floor "+str(p.id))
  field.close()
 for id:String in ["faith_01","faith_02","faith_03","faith_04"]:
  var kept=NATIVE.load_field(id)
  check(kept!=null,"shared Faith resources preserved "+id)
  kept=null
 var previous:String=OS.get_environment("TWILIGHT_SOURCE_MAP_PACK")
 OS.set_environment("TWILIGHT_SOURCE_MAP_PACK","/workspace/scratch/absent-retired-aden-proof")
 check(RUN.load_field("aden_world")==null,"missing new pack refuses fallback")
 OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",previous)
 print("ADEN_RETIREMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"errors":errors}))
 quit(0 if errors==0 else 1)
