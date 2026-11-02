extends SceneTree
const PACK=preload("res://scripts/maps/base508_pack.gd")
const FIELD=preload("res://scripts/maps/base508_game_field.gd")
const MODE=preload("res://scripts/maps/base508_game_mode.gd")
func _initialize() -> void:
 var pack=PACK.new()
 assert(pack.load_pack(OS.get_environment("TWILIGHT_BASE508_PACK")))
 var field=FIELD.new()
 assert(field.configure_source(pack,OS.get_environment("TWILIGHT_BASE508_REGISTRATION"),OS.get_environment("TWILIGHT_LEGACY_ART_ROOT"),"albino_01"))
 assert(field is PlayableField and field is NativePngField)
 assert(field.data.portal.is_empty() and field.data.npc_spawn.is_empty() and field.data.monster_spawn.is_empty())
 assert(field.portal_evidence().size()==4)
 for portal:Dictionary in field.portal_evidence():assert(not portal.runtime_enabled)
 assert(field.data.map_id=="base508_land_48962_review_albino_01")
 var spawn:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
 assert(field.source_to_world(field.world_to_source(spawn)).is_equal_approx(spawn))
 assert(field.line_clear(spawn,spawn+Vector2(8,0)))
 assert(not field.line_clear(spawn,Vector2(3700,4350)))
 var actor:=Node2D.new()
 actor.position=spawn
 var before:Vector2=actor.position
 var record:Dictionary={"edition":"LineageM_base508","map_key":pack.source_map_key(),"land_id":48962,"asset_path":"13474/","coordinate_space":pack.COORDINATE_CONTRACT.SPACE}
 assert(not field.place_confirmed_source_actor(actor,record,Vector2i(32653,32909),2))
 assert(not field.place_confirmed_source_actor(actor,record,Vector2i(-1,-1),true))
 assert(actor.position==before)
 var source:Vector2=field.world_to_source(spawn)
 var placed:bool=false
 for y:int in range(floori(source.y)-2,floori(source.y)+3):
  for x:int in range(floori(source.x)-2,floori(source.x)+3):
   if field.place_confirmed_source_actor(actor,record,Vector2i(x,y),true):
    assert(field.world_to_source(actor.position).is_equal_approx(Vector2(x,y)))
    placed=true
 assert(placed,"At least one supplied, collision-checked source cell must accept a confirmed fixture placement")
 assert(field.actor_contract(actor).position_evidence=="PROJECTED_RUNTIME_REVIEW; NOT_AN_ORIGINAL_SPAWN_RECORD")
 assert(not MODE.enabled())
 var maps:Array=[];var by_id:Dictionary={}
 assert(MODE.register_test_map(maps,by_id).is_empty() and maps.is_empty() and by_id.is_empty())
 actor.free()
 print("BASE508_GAME_API_TEST_OK: field interface, source roundtrip, blocked route, no fabricated portal/NPC placement, default mode unchanged")
 quit()
