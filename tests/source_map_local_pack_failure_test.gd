extends SceneTree
const RUN=preload('res://scripts/maps/source_map_runtime.gd')
var failures:Array[String]=[]
var checks:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);printerr('LOCAL_PACK_FAILURE ',label)
func _initialize():call_deferred('run')
func run():
 var original:String=OS.get_environment('TWILIGHT_SOURCE_MAP_PACK')
 OS.set_environment('TWILIGHT_SOURCE_MAP_PACK','/workspace/map-main-tests/local-missing-pack')
 check(RUN.load_field('aden_world')==null,'missing local supplement cannot silently load old native Aden')
 var unaffected=RUN.load_field('source_77');check(unaffected!=null,'previous59 art and raw grids stay independently valid');if unaffected!=null:unaffected.close()
 var world:TwilightWorld=load('res://Main.tscn').instantiate();root.add_child(world)
 world.set_process(false)
 check(world.field_map==null and world.source_save_blocked and world.map_bootstrap_blocked,'ordinary fresh bootstrap fails explicitly before exposing old background')
 check(world._save_game(true)!=OK,'missing supplement cannot create or overwrite a character save')
 OS.set_environment('TWILIGHT_SOURCE_MAP_PACK',original)
 world._set_map('source_77',false)
 check(world.field_map!=null and not world.map_bootstrap_blocked,'restored verified pack supports a safe retry')
 world.queue_free();await process_frame;await process_frame
 print('SOURCE_MAP_LOCAL_PACK_FAILURE_','OK' if failures.is_empty() else 'FAILED',' checks=',checks);quit(0 if failures.is_empty() else 1)
