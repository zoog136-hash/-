extends SceneTree
## Append only the resolved independent source identities; retain every prior habitat verbatim.
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
const SAFE=preload("res://scripts/maps/source_map_spawns.gd")
const PATH="res://data/monsters/local_source_habitats.json"
var selected:Dictionary={}
func _initialize():call_deferred("run")
func run():
 if OS.get_cmdline_user_args().size()!=2:printerr("requires selection JSON and output JSON");quit(1);return
 selected=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
 var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 var additions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/reviewed_source_additions.json"))
 var new_rows:Array=[]
 for ident:String in selected:
  var record:Dictionary={}
  for r:Dictionary in additions.records:
   if str(r.source_npc_id)==ident:record=r;break
  if record.is_empty():quit(1);return
  var named:bool=bool(selected[ident].named)
  var mid:String=selected[ident].map_id;var field=RUN.load_field(mid)
  if field==null:printerr("IDENTITY_HABITAT_FIELD_FAILED ",mid);quit(1);return
  var entry:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1]);var origin:Vector2i=field.world_to_cell(entry)
  var rng:=RandomNumberGenerator.new();rng.seed=("resolved70:"+ident).hash()
  var point:=Vector2.INF
  for attempt:int in range(5000):
   var c:=origin+Vector2i(rng.randi_range(-80,80),rng.randi_range(-80,80));var p:Vector2=field.cell_to_world(c)
   if p.distance_to(entry)<700 or p.distance_to(entry)>float(selected[ident].get("search_max_distance",2200)) or not SAFE.floor_allowed(field,p):continue
   var free:=true
   for old:Dictionary in payload.rows+new_rows:
    if str(old.get("source_npc_id","")) in selected and not old in new_rows:continue
    if old.map_id!=mid:continue
    var a:Array=old.rect;var rect:=Rect2(a[0],a[1],a[2],a[3]).grow(float(selected[ident].get("habitat_clearance",160)))
    if rect.has_point(p):free=false;break
   if free and not field.path(entry,p).is_empty():point=p;break
  if not point.is_finite():printerr("MONSTER70_NO_FLOOR ",ident);quit(1);return
  var center:Vector2i=field.world_to_cell(point);var cells:Array=[];var minimum:=Vector2.INF;var maximum:Vector2=-Vector2.INF
  for y:int in range(-3,4):
   for x:int in range(-3,4):
    var c:=center+Vector2i(x,y);var p:Vector2=field.cell_to_world(c)
    if not SAFE.floor_allowed(field,p) or field.path(point,p).is_empty():continue
    cells.append(c.y*field.width+c.x);minimum=minimum.min(p);maximum=maximum.max(p)
  if cells.size()<12:printerr("MONSTER70_SMALL_FLOOR ",ident);quit(1);return

  var size:=maximum-minimum
  var row:Dictionary={"id":"twilight_habitat:"+ident,"map_id":mid,"grid_sha256":field.definition.source_sha256,"layout_revision":field.data.layout_revision,"local_habitat":true,"placement_provenance":"TWILIGHT_USER_AUTHORIZED_GAME_HABITAT_NOT_ORIGINAL_SOURCE_COORDINATE","placement_reason":"Exact SQL/DESC identity; retained level and body; local reachable habitat selected by current map theme. Not original source spawn coordinates.","source_center":[center.x+field.coordinates.origin.x,center.y+field.coordinates.origin.y],"monster_types":[record.name],"mode":"boss" if named else "normal","max_count":1 if named else int(selected[ident].get("max_count",2)),"respawn_time":900.0 if named else 60.0,"rect":[minimum.x-1,minimum.y-1,size.x+2,size.y+2],"min_spacing":64.0,"roaming_radius":float(selected[ident].get("roaming_radius",100)),"cells":cells,"expected_level":record.lv,"source_game_id":record.sourceId,"source_npc_id":ident}
  new_rows.append(row);print("IDENTITY_HABITAT ",ident," ",mid," source_center=",row.source_center," cells=",cells.size());field.close()
 var file:=FileAccess.open(OS.get_cmdline_user_args()[1],FileAccess.WRITE);file.store_string(JSON.stringify(new_rows,"  ")+"\n");file.close();quit()
