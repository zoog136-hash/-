extends SceneTree
const CATALOG=preload("res://scripts/monsters/monster_catalog.gd")
const SOURCE=preload("res://scripts/monsters/source_identity_catalog.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("CATALOG_GAP_FAIL ",label)
func digest(bytes:PackedByteArray) -> String:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func _initialize():call_deferred("run")
func run():
 var original:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))["몬스터"]
 var all:Array=CATALOG.expand(original)
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--baseline-script="):
   var prior:Array=load(arg.trim_prefix("--baseline-script=")).expand(original)
   check(prior.size()==443 and all.slice(0,443)==prior,"all prior 443 identities, stats, AI, drops and animation definitions preserved")
 check(all.size()==456 and CATALOG.spawnable_records(all).size()==318,"twenty-five additions, original random pool retained")
 var new:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CATALOG.ADDITIONS_PATH))
 check(new.records.size()==25,"exact reviewed twenty-five, no bulk numeric-ID imports")
 var ids:Dictionary={}
 for record:Dictionary in all:
  var id:String=str(record.get("sourceId",record.name));check(not ids.has(id),"unique game identity");ids[id]=true
 for path:String in new.assets:check(FileAccess.file_exists("res://"+path) and FileAccess.get_sha256("res://"+path)==str(new.assets[path]),"real newly tracked asset "+path)
 for record:Dictionary in new.records:
  check(CATALOG.reviewed_record_allowed(record),"reviewed identity gate")
  var blocked:Dictionary=record.duplicate(true);blocked.source_npc_id="45025"
  check(not CATALOG.reviewed_record_allowed(blocked),"approval does not broaden to excluded identity")
  var entity:Dictionary=SOURCE.entity(SOURCE.NAMESPACE+str(record.source_npc_id))
  var reverse:Dictionary=SOURCE.for_game_record(record)
  check(reverse.status=="exact_source_identity" and reverse.source_candidates==[entity.key],"bidirectional exact source identity")
  check(entity.status=="active_source_identity" and entity.game_source_id==record.sourceId,"typed registry source identity")
  check(int(entity.gfx_id)==int(record.source_raw_fields.gfxid) and entity.nameid==record.source_raw_fields.nameid,"SQL ID/gfx/nameid tuple")
  check(not SOURCE.body_records(str(entity.key)).is_empty(),"original pack row locators preserved")
  var duplicate:Array=original.duplicate(true);duplicate.append(record.duplicate(true));check(CATALOG.expand(duplicate).size()==456,"repeated source identity cannot duplicate record")
  var frames:SpriteFrames=load(str(record.animation_profile.frames_path))
  check(frames!=null,"actual source SpriteFrames")
  if frames==null:quit(1);return
  for role:String in ["idle","walk","run","attack","hit","death"]:
   for facing:int in range(8):
    var name:String=role+"_"+str(facing);var refs:Array=record.source_animation.tracks[name]
    check(frames.has_animation(name) and frames.get_frame_count(name)==refs.size(),"literal sequence length")
    check(frames.get_animation_speed(name)==8.0,"declared presentation speed; no source unit guess")
    for i:int in range(refs.size()):
     var image:Image=frames.get_frame_texture(name,i).get_image();image.convert(Image.FORMAT_RGBA8)
     var pixels:PackedByteArray=image.get_data()
     # Godot fix_alpha_border pads RGB under alpha=0; visible source pixels remain exact.
     for offset:int in range(3,pixels.size(),4):
      if pixels[offset]==0:pixels[offset-3]=0;pixels[offset-2]=0;pixels[offset-1]=0
     check(digest(pixels)==str(refs[i].rgba_sha256),"every Godot pose preserves visible original RGBA "+str(record.name)+" "+name+" "+str(i))
     check(frames.get_frame_duration(name,i)==1.0,"unchanged game presentation frame weighting")
  check(record.drop.is_empty(),"no inherited or invented source loot")
 check(SOURCE.entity("45082").is_empty() and SOURCE.entity("source3:tw380:Taiwan:item:45082").is_empty(),"namespaces never guessed")
 var sum:int=0
 for count:Variant in SOURCE.counts().values():sum+=int(count)
 check(sum==1693,"exhaustive source SQL classification")
 print("REVIEWED_CATALOG_GAPS_RESULT checks=",checks," failures=",failures);quit(0 if failures==0 else 1)
