extends SceneTree
func _initialize():
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment('BASE508_ENTRY_CATALOG')))
 var fields:Dictionary={}
 for row:Dictionary in catalog.maps:
  if str(row.asset) not in ['13233','13234']:continue
  var pack=load('res://scripts/maps/base508_pack.gd').new();assert(pack.load_pack(OS.get_environment('BASE508_ASSETS')+'/base508_asset_'+str(row.asset),int(row.land)))
  var field=load('res://scripts/maps/base508_source_edge_field.gd').new();var evidence:Dictionary=row.duplicate(true);evidence.selected=row.entries[0]
  assert(field.configure_edges(pack,OS.get_environment('BASE508_TABLES'),evidence));fields[int(row.land)]=field
 var passed:int=0
 for land:int in fields:
  var source=fields[land];var target=fields[45324 if land==45304 else 45304]
  for portal:Dictionary in source.source_pack.portals:
   if int(portal.TargetTerritory.LandID)!=int(target.source_pack.manifest.land.ID):continue
   var contract:Dictionary=load('res://scripts/maps/base508_portal_contract.gd').inspect_pair(source,target,int(portal.ID))
   assert(contract.status=='POINT_GEOMETRY_REVIEWED',JSON.stringify(contract))
   assert(not contract.automatic_activation_supported)
   assert(contract.target_cell==Vector2i(portal.TargetTerritory.StartX,portal.TargetTerritory.StartY));passed+=1
 assert(passed>0)
 assert(load('res://scripts/maps/base508_portal_contract.gd').inspect_pair(fields[45304],fields[45304],-1).status=='MISSING_OR_AMBIGUOUS_PORTAL')
 print('SOURCE_PORTAL_CONTRACT_OK ',passed,' exact point links; automatic triggers unavailable');quit()
