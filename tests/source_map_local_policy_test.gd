extends SceneTree
const RUN=preload('res://scripts/maps/source_map_runtime.gd')
const LOCAL=preload('res://scripts/maps/source_map_local_policy.gd')
const ART=preload('res://scripts/maps/source_map_review_pack.gd')
var failures:Array[String]=[]
var checks:int=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);printerr('LOCAL_POLICY_FAIL ',label)
func _initialize():call_deferred('run')
func run():
 var catalog:Dictionary=LOCAL.index(RUN.root_path())
 check(catalog.maps.size()==25,'complete later-authorized local overlay')
 var ids:Dictionary={}
 for mid:String in RUN.policy():
  var p:Dictionary=RUN.policy()[mid]
  if not p.get('local_policy',false):continue
  var field=RUN.load_field(mid)
  check(field!=null,'load verified local field '+mid)
  if field==null:continue
  var entry:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
  check(field.point_clear(entry,4),'entry has exact foot clearance '+mid)
  if mid.begins_with('source_variant_'):
   check(field.definition.source_map_id>=910001 and not ids.has(field.definition.source_map_id),'own stable runtime ID '+mid);ids[field.definition.source_map_id]=true
   check(field.runtime_record.original_source_map_id==null and field.data.monster_spawn.all(func(r):return r.get("local_habitat",false)),'no guessed base identity or collision; only authored habitat rows '+mid)
  for id:String in field.local_doors:
   var cell:Vector2i=field.local_doors[id][0]
   check(id!='107','dangerous source door107 remains excluded')
   check(not field.set_local_door(id,false,[field.cell_to_world(cell)]),'closing cannot crush actor or drop '+mid+':'+id)
   check(field.set_local_door(id,false) and not field.raw_grid.contains(cell),'closed door blocks its footprint '+mid+':'+id)
   check(field.set_local_door(id,true) and field.raw_grid.contains(cell),'open door restores separately overlaid cells '+mid+':'+id)
  if mid in ['domination_summit','source_303']:
   var clipped:Dictionary=field.raw_grid.clipped_cells
   check(not clipped.is_empty(),'clipped glyph void is also blocked '+mid)
   check(field.runtime_record.get('local_policy',false),'original image remains separate from patch '+mid)
  field.close()
 check(ids.size()==5,'five isolated variant identities')
 check(ART.read_object('res://data/maps/source_map_runtime.json').pending.is_empty(),'no unhandled runtime admission remains')
 print('SOURCE_MAP_LOCAL_POLICY_','OK' if failures.is_empty() else 'FAILED',' checks=',checks)
 quit(0 if failures.is_empty() else 1)
