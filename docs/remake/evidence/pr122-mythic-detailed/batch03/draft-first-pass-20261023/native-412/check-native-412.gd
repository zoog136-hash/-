extends SceneTree
var retained: Array[ImageTexture] = []
func _initialize():
 var tex0 = ImageTexture.create_from_image(Image.load_from_file("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/NE-idle.png"))
 retained.append(tex0)
 tex0.take_over_path("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/NE-idle.png")
 var tex1 = ImageTexture.create_from_image(Image.load_from_file("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/S-run.png"))
 retained.append(tex1)
 tex1.take_over_path("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/S-run.png")
 var tex2 = ImageTexture.create_from_image(Image.load_from_file("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/SE-hit.png"))
 retained.append(tex2)
 tex2.take_over_path("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/SE-hit.png")
 var tex3 = ImageTexture.create_from_image(Image.load_from_file("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/SE-idle.png"))
 retained.append(tex3)
 tex3.take_over_path("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/SE-idle.png")
 var tex4 = ImageTexture.create_from_image(Image.load_from_file("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/SW-idle.png"))
 retained.append(tex4)
 tex4.take_over_path("res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/SW-idle.png")
 var path = "res://assets/actors/eight_direction/native_locomotion_staging/transform_412/native001/SpriteFrames.tres"
 var frames = load(path) as SpriteFrames
 assert(frames != null)
 var count = 0
 for name in frames.get_animation_names():
  if name == "default": continue
  assert(frames.get_frame_count(name) == 6)
  assert(frames.get_animation_loop(name) == (str(name).begins_with("idle_") or str(name).begins_with("run_")))
  count += 1
 assert(count == 5)
 print("NATIVE_412_RESOURCE_PASS clips=5 poses=30 actual_Main_Player=NOT_RUN final_approval=0")
 quit()
