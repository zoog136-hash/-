extends SceneTree
func _initialize():call_deferred('run')
func run():
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment('BASE508_ENTRY_CATALOG')))
 var results:Array=[]
 for row:Dictionary in catalog.maps:
  if row.status!='READY_FOR_GRAPH_REVIEW':continue
  var pack=load('res://scripts/maps/base508_pack.gd').new()
  var result:Dictionary={'land':row.land,'asset':row.asset,'status':'NO_COMPATIBLE_ENTRY','attempts':[]}
  if not pack.load_pack(OS.get_environment('BASE508_ASSETS')+'/base508_asset_'+str(row.asset)):
   result.status='PACK_REJECTED';results.append(result);continue
  for entry:Dictionary in row.entries:
   var evidence:Dictionary=row.duplicate(true);evidence.selected=entry
   var nav=load('res://scripts/maps/base508_source_navigation.gd').new()
   if not nav.configure(pack,OS.get_environment('BASE508_TABLES'),evidence):
    result.attempts.append({'entry':entry,'error':nav.error});continue
   var start:Vector2=nav.point(nav.arrival)
   if not nav.safe(start):result.attempts.append({'entry':entry,'error':'Foot clearance fails'});continue
   var visited:Dictionary={nav.ids[nav.arrival]:true};var queue:Array=[nav.ids[nav.arrival]]
   for id:int in queue:
    for neighbor:int in nav.graph.get_point_connections(id):
     if not visited.has(neighbor):visited[neighbor]=true;queue.append(neighbor)
   var passes:int=0
   for direction:Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
    var best:float=-INF;var target:int=-1
    for id:int in visited:
     var score:float=nav.graph.get_point_position(id).dot(direction)
     if score>best:best=score;target=id
    if not nav.route(start,nav.graph.get_point_position(target)).is_empty():passes+=1
   result.merge({'status':'GRAPH_REVIEW_PASSED' if passes==4 else 'FOOT_ROUTE_REJECTED','entry':entry,'component_cells':visited.size(),'graph_cells':nav.ids.size(),'routes':passes},true)
   break
  results.append(result)
  print('SOURCE_ENTRY_QUEUE ',JSON.stringify(result))
 var out=FileAccess.open(OS.get_environment('BASE508_ENTRY_RESULTS'),FileAccess.WRITE);out.store_string(JSON.stringify(results,'  '));out.close();quit()
