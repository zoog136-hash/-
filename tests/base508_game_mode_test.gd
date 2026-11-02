extends SceneTree
const MODE=preload("res://scripts/maps/base508_game_mode.gd")
func _initialize() -> void:
 assert(MODE.enabled())
 var maps:Array=[];var by_id:Dictionary={}
 var mid:String=MODE.register_test_map(maps,by_id)
 assert(mid=="base508_land_48962_review_albino_01",MODE.problem)
 assert(maps.size()==1 and by_id.size()==1)
 var field:PlayableField=MODE.field_for(mid)
 assert(field!=null and field.get_meta("base508_source_test",false))
 assert(field.data.monster_spawn.is_empty() and field.data.portal.is_empty())
 assert(MODE.field_for("aden_world")==null)
 assert(MODE.prepare()==field)
 assert(MODE.register_test_map(maps,by_id).is_empty())
 assert(maps.size()==1 and by_id.size()==1)
 print("BASE508_GAME_MODE_TEST_OK: explicit source flag, one validated host map, cached field, no default-map hijack or fabricated spawns/portals")
 quit()
