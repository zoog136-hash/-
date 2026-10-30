extends SceneTree
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
var failures:Array[String]=[]
var checks:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);printerr("VALIDATION_OWNER_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var field=RUN.load_field("source_77");check(field!=null,"real admitted geometry")
 if field==null:quit(1);return
 var p:Vector2=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
 var data:Dictionary={"map_id":"source_77","position":[p.x,p.y],"source_map84_layouts":RUN.saved_layouts(),"source_map84_doors":RUN.saved_doors(field),"original_position":{"source_map_id":77,"grid_sha256":field.definition.source_sha256,"source":field.coordinates.source_components(p)},"ground_drops":[]}
 check(RUN.validate_save(data,field).is_empty(),"save validates against actual live field")
 check(field.png_game_pack!=null and field.point_clear(p,4),"validation does not close live map")
 var bad:Dictionary=data.duplicate(true);bad.position=[-10000,-10000]
 check(not RUN.validate_save(bad,field).is_empty(),"invalid spatial state still rejected")
 check(field.png_game_pack!=null and field.point_clear(p,4),"rejected save retains live map")
 bad=data.duplicate(true);bad.source_map84_doors.source_77={"unknown_door":true}
 var before:Dictionary=field.local_door_states.duplicate(true)
 check(not RUN.validate_save(bad,field).is_empty() and field.local_door_states==before,"untrusted validation cannot mutate live doors")
 var root:String=OS.get_environment("TWILIGHT_SOURCE_MAP_PACK");OS.set_environment("TWILIGHT_SOURCE_MAP_PACK","/workspace/absent-source-pack-validation-test")
 check(not RUN.validate_save(data,field).is_empty(),"retained geometry cannot hide a missing pack")
 OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",root)
 check(RUN.validate_save(data,field).is_empty(),"verified restored pack remains usable")
 field.close();print("SOURCE_MAP_VALIDATION_OWNER_RESULT checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1)
