extends SceneTree
const QA=preload('res://tests/qa_class_selection.gd')
func _initialize():call_deferred('run')
func run():
 var w:TwilightWorld=load('res://Main.tscn').instantiate();w.active_map_id='source_64';root.add_child(w);w.set_process(false);QA.enter_game(w)
 var f=w.field_map;var id:String='local_castle_gate';var c:Vector2i=f.local_doors[id][0];var p:Vector2=f.cell_to_world(c)
 var spot:=Vector2.INF
 for dy:int in range(-3,4):
  for dx:int in range(-3,4):
   var q:Vector2=f.cell_to_world(c+Vector2i(dx,dy))
   if q.distance_to(p)>40 and q.distance_to(p)<120 and f.point_clear(q,4):spot=q
 if not spot.is_finite():printerr('TOUCH_DOOR_FAIL no safe interaction landing');quit(1);return
 w.player.global_position=spot;f.set_local_door(id,false)
 var touch:=InputEventScreenTouch.new();touch.pressed=true;touch.position=w.field_renderer.get_canvas_transform()*p
 w.field_renderer._unhandled_input(touch)
 var opened:bool=f.local_door_states[id]
 var mouse:=InputEventMouseButton.new();mouse.pressed=true;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=touch.position
 w.field_renderer._unhandled_input(mouse)
 var dedup:bool=f.local_door_states[id]
 w.field_renderer.last_door_input_usec=0;w.field_renderer._unhandled_input(touch)
 var closed:bool=not f.local_door_states[id]
 var ok:bool=opened and dedup and closed
 print('TOUCH_DOOR_DIAGNOSTIC ',opened,' ',dedup,' ',closed,' actor_distance=',spot.distance_to(p))
 print('SOURCE_MAP_TOUCH_DOOR_','OK' if ok else 'FAILED',' checks=3')
 w.queue_free();await process_frame;await process_frame;quit(0 if ok else 1)
