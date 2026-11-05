extends RefCounted
## Exact source geometry handshake; activation rules are not in Portal rows.
static func inspect_pair(source:RefCounted,target:RefCounted,portal_id:int)->Dictionary:
 var matches:Array=[]
 for portal:Dictionary in source.source_pack.portals:
  if int(portal.ID)==portal_id:matches.append(portal)
 if matches.size()!=1:return {'status':'MISSING_OR_AMBIGUOUS_PORTAL'}
 var portal:Dictionary=matches[0];var territory:Dictionary=portal.TargetTerritory
 if int(portal.SourceLandID)!=int(source.source_pack.manifest.land.ID) or int(territory.LandID)!=int(target.source_pack.manifest.land.ID):return {'status':'LAND_MISMATCH'}
 if int(territory.StartX)!=int(territory.EndX) or int(territory.StartY)!=int(territory.EndY):return {'status':'REGION_REQUIRES_ORIGINAL_ARRIVAL_POLICY','portal':portal.duplicate(true)}
 var start:=Vector2i(portal.SourceX,portal.SourceY);var finish:=Vector2i(territory.StartX,territory.StartY)
 var from_world:Vector2=source.source_to_world(Vector2(start));var to_world:Vector2=target.source_to_world(Vector2(finish))
 if not source.walkable(from_world) or not target.walkable(to_world):return {'status':'SOURCE_OR_DESTINATION_FOOT_UNVERIFIED','portal':portal.duplicate(true)}
 return {'status':'POINT_GEOMETRY_REVIEWED','portal':portal.duplicate(true),'source_map':source.source_pack.source_map_key(),'target_map':target.source_pack.source_map_key(),'source_cell':start,'target_cell':finish,'source_world':from_world,'target_world':to_world,'automatic_activation_supported':false,'missing_native_rules':['trigger_geometry','activation_predicate'],'scope':'SOURCE_REVIEW_COMPATIBILITY_NOT_NATIVE_M'}
