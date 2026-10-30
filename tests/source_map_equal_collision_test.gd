extends SceneTree
const EQ=preload('res://scripts/maps/source_map_equal_collision.gd')
const ART=preload('res://scripts/maps/source_map_review_pack.gd')
const RUN=preload('res://scripts/maps/source_map_runtime.gd')
const SELECTED=[0,4,25,26,27,28,30,31,32,33,34,35,36,37,53,54,55,56,77,78,79,80,81,82,106,244,303,480,495,601,783]
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);printerr('EQUAL_COLLISION_FAIL ',label)
func _initialize():call_deferred('run')
func run():
 var root_path:String=RUN.root_path()
 var index:Dictionary=ART.read_object(root_path+'/equal-collision-v1/index.json')
 check(index.maps.size()==35,'exact audited identical set, excluding thirteen single-source candidates and five variants')
 for sid:String in index.maps:
  var spec:Dictionary=EQ.spec(root_path,int(sid))
  check(not spec.is_empty() and spec.archive_version_label=='351' and not int(sid) in SELECTED,'only identical non-selected archive representatives')
  var path:String=root_path+'/'+str(spec.file)
  var bytes:PackedByteArray=FileAccess.get_file_as_bytes(path).decompress_dynamic(16000000,FileAccess.COMPRESSION_GZIP)
  var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
  check(FileAccess.get_sha256(path)==spec.sha256 and hash.finish().hex_encode()==spec.raw_sha256 and bytes.size()==int(spec.width)*int(spec.height),'actual immutable compressed and raw grid bytes: '+sid)
 for mid:String in RUN.policy():
  var p:Dictionary=RUN.policy()[mid]
  check((int(p.source_map_id) in SELECTED and p.get('collision_archive_version','360')=='360') or (not int(p.source_map_id) in SELECTED and p.get('collision_archive_version')=='351' and p.get('collision_basis')=='identical_archive_representative') or (p.get('local_policy',false) and p.get('collision_archive_version') in ['360','local_authored']),'explicit per-map choice without blanket360: '+mid)
 for mid:String in ['source_639','source_1930','source_1931','source_2042','source_2043','source_2044','albino_03','source_variant_54']:
  check(not RUN.supports(mid),'retired and nonexistent IDs remain unavailable: '+mid)
 var art=ART.new();check(art.open_pack(root_path),'original 84-map review index still matches original SHA')
 check(art.load_map('source_602').collision==null,'immutable historical unselected manifest is not rewritten')
 var field:RemakePlayableField=RUN.load_field('source_602')
 check(field!=null and field.data.map_id=='source_602' and field.definition.source_map_id==602,'source Balrog room retains independent ID instead of guessing existing temple alias')
 if field!=null:
  check(field.data.monster_spawn.all(func(r):return r.get("local_habitat",false)) and field.runtime_record.doors.is_empty(),'only explicit local habitats; no dynamic doors silently imported');field.close()
 var temp:String='user://equal-collision-bad-'+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(temp+'/equal-collision-v1')
 check(EQ.spec(temp,602).is_empty(),'missing supplement has no candidate fallback')
 var file:=FileAccess.open(temp+'/equal-collision-v1/index.json',FileAccess.WRITE);file.store_string('{}');file.close()
 check(EQ.spec(temp,602).is_empty(),'wrong supplement manifest fails closed')
 print('SOURCE_MAP_EQUAL_COLLISION_','OK' if failures.is_empty() else 'FAILED',' checks=',checks)
 quit(0 if failures.is_empty() else 1)
