extends SceneTree
var failures := 0
var retained: Array[ImageTexture] = []
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 for id: String in OS.get_environment("PR122_DRAFT_IDS").split(","):
  var key := "transform_"+id
  var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/remake/evidence/pr122-mythic-detailed/batch03/"+key+"-S-attack-draft-v01.json"))
  var path := "res://"+str(data.source)
  if FileAccess.get_sha256(path) != data.source_sha256: failures+=1; break
  var texture := ImageTexture.create_from_image(Image.load_from_file(path))
  retained.append(texture); texture.take_over_path(path)
  var frames := load(data.output_spriteframes) as SpriteFrames
  if frames == null or frames.get_animation_names().size()!=1 or not frames.has_animation(&"attack_2") or frames.get_frame_count(&"attack_2")!=6 or frames.get_animation_loop(&"attack_2"):
   failures+=1;break
  var sprite := AnimatedSprite2D.new();sprite.sprite_frames=frames;root.add_child(sprite);sprite.play(&"attack_2")
  var reached: Dictionary = {}
  for tick: int in range(45):
   reached[sprite.frame]=true
   await process_frame
  if reached.size()!=6 or sprite.frame!=5 or sprite.is_playing():failures+=1
  sprite.queue_free()
  print("DRAFT_ATTACK_RESOURCE "+id+" six_pose_once="+str(reached.size()==6 and failures==0)+" final_approval=HOLD Main_Player=NOT_RUN")
 print("PR122_FIRST_DRAFT_RESOURCE_RESULT failures="+str(failures))
 quit(0 if failures==0 else 1)
