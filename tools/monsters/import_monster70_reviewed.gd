extends SceneTree
const DEC=preload("res://scripts/skills/source_spr_decoder.gd")
func digest(b:PackedByteArray)->String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(b);return h.finish().hex_encode()
func _initialize():
 var args:=OS.get_cmdline_user_args()
 if args.size()!=1:quit(1);return
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 for item:Dictionary in plan.species:
  var decoded:Dictionary={};var bounds:=Rect2i();var first:=true
  for r:Dictionary in item.records:
   var zip:=ZIPReader.new()
   if zip.open(r.archive_path)!=OK:quit(1);return
   var raw:=zip.read_file(r.package_blob);zip.close()
   if digest(raw)!=r.sha256:printerr("RAW_SHA ",r.record_key);quit(1);return
   for index:int in r.used_frames:
    var pose:Dictionary=DEC.decode(raw,index)
    if pose.is_empty():printerr("DECODE ",r.record_key," ",index);quit(1);return
    bounds=pose.bounds if first else bounds.merge(pose.bounds);first=false
    decoded[str(r.sha256)+":"+str(index)]=pose
  var directory:String=item.directory
  DirAccess.make_dir_recursive_absolute(directory)
  var ext:Array[String]=[];var subs:Array[String]=[];var animations:Array[String]=[];var frame_id:=0;var tracks:Dictionary={};var hashes:Dictionary={}
  for role:String in ["idle","walk","attack","hit","death"]:
   var count:int=item.tracks[role+"_0"].size()
   var atlas:=Image.create_empty(bounds.size.x*8,bounds.size.y*count,false,Image.FORMAT_RGBA8)
   for facing:int in range(8):
    var refs:Array=[];var poses:Array=[]
    for step:int in range(count):
     var ref:Dictionary=item.tracks[role+"_"+str(facing)][step].duplicate(true)
     var pose:Dictionary=decoded[str(ref.blob_sha256)+":"+str(int(ref.frame_index))]
     var image:=Image.create_empty(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
     image.blit_rect(pose.image,Rect2i(Vector2i.ZERO,pose.image.get_size()),pose.bounds.position-bounds.position)
     var region:=[facing*bounds.size.x,step*bounds.size.y,bounds.size.x,bounds.size.y]
     atlas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(region[0],region[1]))
     ref["rgba_sha256"]=digest(image.get_data());ref["texture_region"]=region;ref["texture_path"]=directory+"/"+role+".png";poses.append(ref)
     var key:="F"+str(frame_id);frame_id+=1
     subs.append('[sub_resource type="AtlasTexture" id="'+key+'"]\natlas = ExtResource("'+role+'")\nregion = Rect2('+', '.join(region.map(func(v):return str(v)))+')')
     refs.append('{"duration": 1.0, "texture": SubResource("'+key+'")}')
    tracks[role+"_"+str(facing)]=poses
    for animation_role:String in ([role,"run"] if role=="walk" else [role]):
     animations.append('{"name": &"'+animation_role+'_'+str(facing)+'", "speed": 8.0, "loop": '+str(animation_role in ["idle","walk","run"]).to_lower()+', "frames": ['+', '.join(refs)+']}')
   var path:=directory+"/"+role+".png"
   if atlas.save_png(path)!=OK:quit(1);return
   hashes[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
   for facing:int in range(8):
    for ref:Dictionary in tracks[role+"_"+str(facing)]:ref["texture_sha256"]=hashes[path.trim_prefix("res://")]
   ext.append('[ext_resource type="Texture2D" path="'+path+'" id="'+role+'"]')
  for facing:int in range(8):tracks["run_"+str(facing)]=tracks["walk_"+str(facing)]
  var tres:='[gd_resource type="SpriteFrames" load_steps='+str(frame_id+6)+' format=3]\n\n'+'\n\n'.join(ext)+'\n\n'+'\n\n'.join(subs)+'\n\n[resource]\nanimations = [\n'+',\n'.join(animations)+'\n]\n'
  var file:=FileAccess.open(directory+"/frames.tres",FileAccess.WRITE);file.store_string(tres);file.close()
  var portrait:Dictionary=decoded[str(tracks.idle_2[0].blob_sha256)+":"+str(int(tracks.idle_2[0].frame_index))]
  portrait.image.save_png(directory+"/portrait.png")
  for name:String in ["frames.tres","portrait.png"]:hashes[(directory+"/"+name).trim_prefix("res://")]=FileAccess.get_sha256(directory+"/"+name)
  item["output"]={"tracks":tracks,"canvas_original_grid":[bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y],"assets":hashes}
  print("MONSTER70_RENDER npc=",item.npc_id," poses=",frame_id," bounds=",bounds)
 var output:=FileAccess.open(args[0]+".rendered.json",FileAccess.WRITE);output.store_string(JSON.stringify(plan));output.close();quit()
