extends SceneTree
const PACK=preload("res://scripts/maps/base508_pack.gd")
func _initialize() -> void:
 var pack=PACK.new()
 assert(pack.load_pack(OS.get_environment("TWILIGHT_BASE508_SHARED_CONTEXT_PACK"),12156),pack.error)
 assert(pack.source_map_key()=="base508_land_12156" and pack.manifest.land.AssetPath=="0/")
 assert(pack.geometry.size()==1)
 assert(pack.geographic_contract().land_id==12156)
 var geometry_sha:String=pack.manifest.geometry[0].source_sha256
 assert(pack.select_land_context(0))
 assert(pack.source_map_key()=="base508_land_0" and pack.manifest.geometry[0].source_sha256==geometry_sha)
 assert(not pack.select_land_context(48962))
 assert(pack.source_map_key()=="base508_land_0")
 print("BASE508_SHARED_LAND_CONTEXT_OK: Land12156 and Land0 share exact geometry, distinct portal/NPC context; unrelated Land rejected")
 quit()
