extends SceneTree
var failures:int=0
func check(ok:bool,label:String):
 if not ok:failures+=1;printerr("MAIN_PRELOAD_FAIL ",label)
func _initialize():
 var packed:PackedScene=load("res://Main.tscn")
 check(packed!=null,"main scene loads")
 if packed!=null:
  var world:Node=packed.instantiate()
  var hud:Node=world.get_node("HUD")
  var script:Script=hud.get_script()
  check(script!=null and script.can_instantiate(),"production HUD and all static image/audio dependencies compile")
  check(script!=null and script.resource_path=="res://scripts/ui/renewal_hud.gd","current main UI preserved")
  world.free()
 print("MAIN_SCENE_PRELOAD_RESULT errors=",failures)
 quit(0 if failures==0 else 1)
