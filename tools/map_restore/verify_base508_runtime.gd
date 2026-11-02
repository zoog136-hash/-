extends SceneTree
## Standalone pack validation; never instantiates world/UI or reads a save.
const PACK=preload("res://scripts/maps/base508_pack.gd")
func _initialize() -> void:
 var path:String=OS.get_environment("TWILIGHT_BASE508_PACK")
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--pack="):path=arg.trim_prefix("--pack=")
 var pack=PACK.new()
 assert(pack.load_pack(path),pack.error)
 assert(pack.geometry.size()==pack.manifest.geometry.size(),"Duplicate canonical geometry origin")
 assert(pack.manifest.art.status in ["S32_TI2_RENDERABLE","EMPTY_ORIGINAL_SOURCE_RASTER"])
 for row:Dictionary in pack.manifest.geometry:
  var cell:=Vector2i(int(row.origin[0]),int(row.origin[1]))
  assert(pack.raw_attribute(cell.x*2,cell.y)>=0)
  assert(not pack.can_enter(cell),"Unverified M terrain must remain blocked")
 for portal:Dictionary in pack.portals:assert(int(portal.SourceLandID)==int(pack.manifest.land.ID))
 print("BASE508_GENERIC_RUNTIME_OK ",JSON.stringify({"land_id":pack.manifest.land.ID,"asset_path":pack.manifest.land.AssetPath,"geometry_chunks":pack.geometry.size(),"art_status":pack.manifest.art.status,"source_portals_preserved":pack.portals.size(),"terrain_collision":"UNKNOWN_BLOCKED","saves_accessed":false}))
 quit()
