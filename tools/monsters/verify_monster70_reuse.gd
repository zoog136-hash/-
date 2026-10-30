extends SceneTree
## Verify existing textures against exact same-namespace raw SPR bytes before
## reusing their complete animation profiles for a different SQL identity.
const DEC=preload("res://scripts/skills/source_spr_decoder.gd")
var errors:int=0
var checks:int=0
func check(ok:bool,note:String):
 checks+=1
 if not ok:errors+=1;printerr("REUSE_FAIL ",note)
func sha(b:PackedByteArray)->String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(b);return h.finish().hex_encode()
func rgba_sha(image:Image)->String:
 image.convert(Image.FORMAT_RGBA8)
 var pixels:=image.get_data()
 for at:int in range(3,pixels.size(),4):
  if pixels[at]==0:pixels[at-3]=0;pixels[at-2]=0;pixels[at-1]=0
 return sha(pixels)
func _initialize():
 var args:=OS.get_cmdline_user_args()
 if args.size()!=1:quit(1);return
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]));var output:Dictionary={}
 for item:Dictionary in plan.bases:
  var frames:SpriteFrames=load(str(item.frames_path))
  check(frames!=null,"existing SpriteFrames "+str(item.base_npc_id))
  if frames==null:quit(1);return
  var raw:Dictionary={};var poses:Dictionary={};var assets:Dictionary={};var tracks:Dictionary={}
  for row:Dictionary in item.records:
   var zip:=ZIPReader.new();check(zip.open(str(row.archive_path))==OK,"input archive")
   var bytes:=zip.read_file(str(row.package_blob));zip.close()
   check(sha(bytes)==str(row.sha256),"raw same-namespace SHA "+str(row.record_key));raw[str(row.sha256)]=bytes
  var c:Array=item.canvas_original_grid;var bounds:=Rect2i(int(c[0]),int(c[1]),int(c[2])-int(c[0]),int(c[3])-int(c[1]))
  var speeds:Dictionary={}
  for name:String in item.tracks:
   var refs:Array=item.tracks[name];check(frames.has_animation(name) and frames.get_frame_count(name)==refs.size(),"complete source sequence "+name)
   speeds[name]=frames.get_animation_speed(name);var normalized:Array=[]
   for index:int in range(refs.size()):
    var ref:Dictionary=refs[index].duplicate(true);var digest:String=str(ref.blob_sha256);var key:=digest+":"+str(int(ref.frame_index))
    check(raw.has(digest),"no numeric or cross-source fallback")
    if not raw.has(digest):quit(1);return
    if not poses.has(key):
     var decoded:Dictionary=DEC.decode(raw[digest],int(ref.frame_index));check(not decoded.is_empty(),"raw frame decode")
     if decoded.is_empty():quit(1);return
     var expected:=Image.create_empty(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
     check(bounds.encloses(decoded.bounds),"original canvas encloses raw pose")
     expected.blit_rect(decoded.image,Rect2i(Vector2i.ZERO,decoded.image.get_size()),decoded.bounds.position-bounds.position)
     poses[key]=rgba_sha(expected)
    var texture:AtlasTexture=frames.get_frame_texture(name,index) as AtlasTexture
    check(texture!=null,"existing atlas texture")
    if texture==null:quit(1);return
    var actual:=rgba_sha(texture.get_image());check(actual==poses[key],"source pixels equal existing pose "+str(item.base_npc_id)+" "+name+" "+str(index))
    var path:String=texture.atlas.resource_path
    if not assets.has(path.trim_prefix("res://")):assets[path.trim_prefix("res://")]=FileAccess.get_sha256(path)
    ref["rgba_sha256"]=actual;ref["texture_path"]=path;ref["texture_sha256"]=assets[path.trim_prefix("res://")]
    ref["texture_region"]=[int(texture.region.position.x),int(texture.region.position.y),int(texture.region.size.x),int(texture.region.size.y)]
    ref["presentation_weight"]=frames.get_frame_duration(name,index);normalized.append(ref)
   tracks[name]=normalized
  assets[str(item.frames_path).trim_prefix("res://")]=FileAccess.get_sha256(str(item.frames_path))
  assets[str(item.portrait_path).trim_prefix("res://")]=FileAccess.get_sha256(str(item.portrait_path))
  output[str(item.base_npc_id)]={"tracks":tracks,"assets":assets,"speeds":speeds,"unique_raw_poses":poses.size()}
  print("REUSE_VERIFIED base=",item.base_npc_id," raw_poses=",poses.size())
 print("MONSTER70_REUSE_RESULT checks=",checks," errors=",errors)
 if errors==0:
  var file:=FileAccess.open(args[0]+".verified.json",FileAccess.WRITE);file.store_string(JSON.stringify(output));file.close()
 quit(0 if errors==0 else 1)
