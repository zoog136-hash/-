extends SceneTree
const CATALOG=preload("res://scripts/animation/animation_catalog.gd")
var checks:int=0
var errors:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:errors+=1;printerr("SOURCE201_RENDER_FAIL ",label)
func _initialize():call_deferred("run")
func run():
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1400,1300)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/source_transform_visuals.json"))
 var actors:Array[TwilightPlayer]=[];var empty_frames:Dictionary={}
 for card:Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
  var key:String="transform:"+str(card.sourceId);var spec:Dictionary=manifest.entries.get(key,{})
  if not spec.get("source201_selected_input",false):continue
  var actor:TwilightPlayer=load("res://scenes/Player.tscn").instantiate();root.add_child(actor)
  actor.set_process(false);actor.set_physics_process(false);actor.camera.enabled=false
  actor.position=Vector2(175+(actors.size()%4)*350,260+(actors.size()/4)*300)
  actor.set_transform_visual(str(card.image_path),1.0,CATALOG.for_record("transform",card))
  check(actor.transform_profile.frames_path==spec.frames_path,"actual Player selects reviewed appearance")
  empty_frames[key]=JSON.parse_string(FileAccess.get_file_as_string(spec.frames_path.get_base_dir()+"/provenance.json")).transparent_frames
  actors.append(actor)
 check(actors.size()==14,"all fourteen reviewed transformations")
 for facing:int in range(8):
  for role:String in ["idle","walk","attack","cast","hit","death"]:
   for actor:TwilightPlayer in actors:
    actor.motion.state=role;actor.motion.facing8=facing;actor.motion.facing4=facing/2;actor.motion.active=role in ["attack","cast"];actor.motion.dead=role=="death"
    actor.motion.state_clock=0.12;actor.motion.gait=1.0;actor.motion.move_ratio=1.0 if role=="walk" else 0.0;actor.motion.hit_clock=0.08 if role=="hit" else 0.0;actor.motion.death_clock=0.15;actor.motion.visual_progress=0.5;actor.motion.attack_duration=0.8;actor.motion.attack_elapsed=0.3
    actor.motion.apply(actor.transform_sprite,actor.transform_sprite.get_meta("base_scale"))
    check(actor.motion._resolved_key==role+"_"+str(facing),"real role/facing selection")
    check(not actor.transform_sprite.flip_h,"no mirrored source substitution")
   await process_frame;await RenderingServer.frame_post_draw
   var image:Image=root.get_texture().get_image()
   for actor:TwilightPlayer in actors:
    var texture:Texture2D=actor.transform_sprite.sprite_frames.get_frame_texture(actor.transform_sprite.animation,actor.transform_sprite.frame)
    if texture.get_image().get_used_rect().size==Vector2i.ZERO:
     var index:int=int(texture.get_meta("source_frame_index",-1))
     check(empty_frames[actor.transform_profile.profile_id].any(func(n):return int(n)==index),"only documented source-empty pose")
     continue
    var local_box:=Rect2(actor.transform_sprite.offset-texture.get_size()*0.5,texture.get_size());var box:Rect2=actor.transform_sprite.get_global_transform()*local_box
    var colors:Dictionary={}
    for y:int in range(maxi(0,floori(box.position.y)),mini(image.get_height(),ceili(box.end.y))):
     for x:int in range(maxi(0,floori(box.position.x)),mini(image.get_width(),ceili(box.end.x))):
      var c:Color=image.get_pixel(x,y)
      if maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b))>0.08:colors[c.to_rgba32()]=true
    check(colors.size()>8,"native source colors visible in actual viewport "+actor.transform_profile.profile_id+role)
   if facing==2 and role=="idle":
    var capture:String=OS.get_environment("TWILIGHT_SOURCE201_CAPTURE")
    if not capture.is_empty():check(image.save_png(capture)==OK,"one actual diagnostic viewport")
 for actor:TwilightPlayer in actors:actor.queue_free()
 await process_frame
 print("SOURCE201_RENDER_RESULT actors=",actors.size()," views=",actors.size()*48," checks=",checks," errors=",errors);quit(0 if errors==0 else 1)
