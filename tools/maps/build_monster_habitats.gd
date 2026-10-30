extends SceneTree
## Bake user-authorized game habitats only for species absent from actual fields.
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
const SAFE=preload("res://scripts/maps/source_map_spawns.gd")
const CATALOG=preload("res://scripts/monsters/monster_catalog.gd")
const DROP=preload("res://scripts/loot_drop.gd")
const OUTPUT="res://data/monsters/local_source_habitats.json"
var fields:Dictionary={}
var occupied:Dictionary={}
func _initialize():call_deferred("run")
func target(record:Dictionary) -> String:
 var id:String=str(record.get("source_npc_id",""));var name:String=str(record.name)
 var named:Dictionary={"45648":"source_492","45651":"source_244","45676":"source_494","45677":"source_493","45680":"source_64","45678":"source_64","45588":"source_490","45602":"source_493","45612":"source_494","45574":"source_496","45615":"source_495","45585":"source_491","45752":"source_602","45625":"source_522","45685":"source_524","45675":"source_603","45671":"source_523","45681":"source_70","45682":"source_37","45683":"source_65","45684":"source_67","45548":"source_480","45413":"source_440","46037":"source_608","81163":"source_608","97068":"source_82","45941":"source_244","45943":"source_244","45088":"source_77","45322":"source_78","45215":"source_80","45557":"source_303","45734":"source_65","45745":"source_65","45726":"source_480","46048":"source_303","81368":"source_303"}
 if name=="마계의 지배자":return "source_603"
 if name=="천상계의 지배자":return "source_variant_54_25"
 if name=="종말의 성역의 지배자":return "source_780"
 if id=="45955":return "source_494"
 if named.has(id):return named[id]
 if id.begins_with("4595") or id in ["45960","45961","45962"]:return ["source_490","source_491","source_492","source_493","source_494","source_495","source_496","source_495"][clampi(int(id)-45955,0,7)]
 if name.begins_with("티칼"):return "source_783"
 if name.begins_with("테베") or name.begins_with("테베라스"):return "source_782" if DROP.is_boss_record(record) else "source_781"
 for group:Array in [["말하는 섬","source_0"],["검은숲","source_440"],["글루디오","source_53"],["개미굴","source_54"],["기란 평원","source_440"],["에바 왕국","source_480"],["용의 계곡","source_35"],["화룡","source_67"],["풍룡","source_70"],["지룡","source_37"],["수룡","source_65"],["잊혀진 섬","source_70"],["라스타바드","source_490"],["아틀란티스","source_variant_4_0"],["마계","source_variant_614_7786"],["천상계","source_variant_614_7785"],["시간의 균열","source_variant_54_25"],["종말의 성역","source_variant_7002_7785"],["알비노","source_244"]]:
  if name.begins_with(group[0]):return group[1]
 if name.begins_with("오만의 탑"):return "oman_04"
 for word:String in ["상어","인어","해파리","말미잘","해마","가오리","실러캔스","불가사리","크러스트","일렉카돔"]:
  if name.contains(word):return "source_480"
 for word:String in ["그리폰","와이번","튜폰","거인","아울베어","바쿡"]:
  if name.contains(word):return "source_70"
 var lv:int=int(record.get("lv",1))
 if lv<=15:return "source_0"
 if lv<=30:return "source_53"
 if lv<=45:return "source_55"
 if lv<=60:return "source_81"
 if lv<=80:return "oman_08"
 if lv<=110:return "oman_09"
 return "source_variant_7002_7785"
func run():
 if not "--without-local-habitats" in OS.get_cmdline_user_args():printerr("builder requires --without-local-habitats");quit(1);return
 var audit_path:String=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--audit="):audit_path=arg.trim_prefix("--audit=")
 if audit_path.is_empty():printerr("requires --audit=<audit_monster_habitats.gd --without-local-habitats output>");quit(1);return
 var audit:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(audit_path))
 if audit.get("local_habitats_included",true) or audit.get("source_placement_sha256","")!=FileAccess.get_sha256("res://data/monsters/source3_map_spawns.json"):printerr("audit scope or source hash changed");quit(1);return
 if not audit.failed_maps.is_empty():quit(1);return
 var records:Array=CATALOG.expand(JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))["몬스터"])
 var rows:Array=[];var failures:Array=[]
 for record:Dictionary in records:
  if audit.linked.has(str(record.name)):continue
  var mid:String=target(record)
  if not RUN.supports(mid) or mid=="aden_world":failures.append(record.name);continue
  if not fields.has(mid):fields[mid]=RUN.load_field(mid);occupied[mid]=[]
  var field=fields[mid]
  if field==null:failures.append(record.name);continue
  var named:bool=DROP.is_boss_record(record) or (int(record.get("hp",0))>=4000 and int(record.get("lv",1))>=40)
  var rng:=RandomNumberGenerator.new();rng.seed=str(record.name).hash()
  var entry:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
  var origin:Vector2i=field.world_to_cell(entry);var point:Vector2=Vector2.INF
  for attempt:int in range(2500):
   var c:Vector2i=origin+Vector2i(rng.randi_range(-100,100),rng.randi_range(-100,100))
   var p:Vector2=field.cell_to_world(c);var distance:float=p.distance_to(entry)
   if distance<(1000.0 if named else 700.0) or distance>2400.0 or not SAFE.floor_allowed(field,p):continue
   var free:bool=true
   for old:Vector2 in occupied[mid]:
    if old.distance_to(p)<(300.0 if named else 160.0):free=false;break
   if not free or field.path(entry,p).is_empty():continue
   point=p;break
  if not point.is_finite():failures.append(record.name);continue
  occupied[mid].append(point)
  var center:Vector2i=field.world_to_cell(point);var cells:Array=[];var minimum:=Vector2.INF;var maximum:Vector2=-Vector2.INF
  for y:int in range(-3,4):
   for x:int in range(-3,4):
    var c:Vector2i=center+Vector2i(x,y);var p:Vector2=field.cell_to_world(c)
    if not SAFE.floor_allowed(field,p) or field.path(point,p).is_empty():continue
    cells.append(c.y*field.width+c.x);minimum=minimum.min(p);maximum=maximum.max(p)
  var size:Vector2=maximum-minimum
  var id:String="twilight_habitat:"+str(record.get("source_npc_id",str(record.name).sha256_text().substr(0,16)))
  var row:Dictionary={"id":id,"map_id":mid,"grid_sha256":field.definition.source_sha256,"layout_revision":field.data.layout_revision,"local_habitat":true,"placement_provenance":"TWILIGHT_USER_AUTHORIZED_GAME_HABITAT_NOT_ORIGINAL_SOURCE_COORDINATE","placement_reason":"previously unspawned species; name/theme and retained level; reachable floor outside entry/NPC/portal reservations","source_center":[center.x+field.coordinates.origin.x,center.y+field.coordinates.origin.y],"monster_types":[record.name],"mode":"boss" if named else "normal","max_count":1 if named else 2,"respawn_time":900.0 if named else 60.0,"rect":[minimum.x-1,minimum.y-1,size.x+2,size.y+2],"min_spacing":64.0,"roaming_radius":100.0,"cells":cells,"expected_level":record.get("lv",1)}
  if record.get("catalog_only",false):row["source_game_id"]=record.sourceId;row["source_npc_id"]=record.source_npc_id
  rows.append(row);print("HABITAT_BAKED ",mid," ",record.name," cells=",cells.size()," rare=",named)
 for field:Variant in fields.values():
  if field!=null:field.close()
 if not failures.is_empty():printerr("HABITAT_UNRESOLVED ",failures);quit(1);return
 var file=FileAccess.open(OUTPUT,FileAccess.WRITE)
 file.store_string(JSON.stringify({"schema":1,"source_placement_sha256":FileAccess.get_sha256("res://data/monsters/source3_map_spawns.json"),"scope":"Only species absent from actual current map rosters; protected maps untouched; game-designed positions and cooldowns, not source claims","rows":rows},"  ")+"\n");file.close()
 print("HABITAT_BUILD_RESULT species=",rows.size()," maps=",fields.size());quit(0)
