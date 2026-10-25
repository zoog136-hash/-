extends SceneTree
var failures := 0
var retained: Array[ImageTexture] = []
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 var role := OS.get_environment("PR122_DRAFT_ROLE")
 var anim := StringName(role+"_2")
 var looped := role in ["run","idle"]
 for id: String in OS.get_environment("PR122_DRAFT_IDS").split(","):
  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/remake/evidence/pr122-mythic-detailed/batch03/transform_"+id+"-S-"+role+"-draft-v01.json"))
  var path := "res://"+str(data.source)
  if FileAccess.get_sha256(path) != data.source_sha256: failures+=1;break
  var texture := ImageTexture.create_from_image(Image.load_from_file(path));retained.append(texture);texture.take_over_path(path)
  var frames := load(data.output_spriteframes) as SpriteFrames
  if frames==null or frames.get_animation_names().size()!=1 or not frames.has_animation(anim) or frames.get_frame_count(anim)!=6 or frames.get_animation_loop(anim)!=looped:
   failures+=1;break
  var sprite := AnimatedSprite2D.new();sprite.sprite_frames=frames;root.add_child(sprite);sprite.play(anim)
  var reached: Dictionary = {};var previous := 0;var wraps := 0
  var seconds := 6.0 / frames.get_animation_speed(anim)
  for tick: int in range(int(ceil(seconds*60.0*(2.0 if looped else 1.0)))+5):
   reached[sprite.frame]=true
   if previous>sprite.frame:wraps+=1
   previous=sprite.frame
   await process_frame
  if reached.size()!=6 or (looped and (wraps<1 or not sprite.is_playing())) or (not looped and (sprite.frame!=5 or sprite.is_playing())):failures+=1
  sprite.queue_free()
  print("DRAFT_MOTION_RESOURCE "+id+" "+role+" poses="+str(reached.size())+" wraps="+str(wraps)+" final_approval=HOLD Main_Player=NOT_RUN")
 print("PR122_FIRST_DRAFT_RESOURCE_RESULT failures="+str(failures))
 quit(0 if failures==0 else 1)
