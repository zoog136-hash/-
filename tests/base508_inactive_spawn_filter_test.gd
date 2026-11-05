extends SceneTree
## Metadata fixtures prove exact zero filtering; no original NPC is generated.
const REGIONS=preload("res://scripts/monsters/base508_geographic_regions.gd")
const CONTEXT=preload("res://scripts/monsters/base508_monster_context.gd")
class MapDouble extends RefCounted:
 var removed:Array=[]
 func unregister_npc_occupancy(id:String)->void:removed.append(id)
func _initialize()->void:call_deferred("run")
func run()->void:
 var errors:Array=[]
 if CONTEXT.activation_flag(0)!="inactive" or CONTEXT.activation_flag(1)!="active" or CONTEXT.activation_flag(2)!="unsupported" or CONTEXT.activation_flag(false)!="unsupported":errors.append("Unknown flag inferred inactive")
 var raw:Array=[{"is_spawn_raw":0,"id":1},{"is_spawn_raw":1,"id":2,"server_limit_set_id_raw":99},{"is_spawn_raw":2,"id":3},{"id":4},{"is_spawn_raw":false,"id":5}]
 var before:Array=raw.duplicate(true);var applied:Array=REGIONS.applied_rows(raw)
 if applied.size()!=4 or applied.has(raw[0])or not applied.has(raw[1])or not applied.has(raw[2])or raw!=before:errors.append("Exact zero filter changed active/unknown/original data")
 var old_data:Dictionary=CONTEXT._data;var old_indexes:Dictionary=CONTEXT._indexes
 CONTEXT._data={"fixture":true}
 CONTEXT._indexes={"NpcSpawnPackNpcClassView":{101:{"ID":101,"NpcClassID":11,"NpcSpawnPackID":501,"IsSpawn":0},102:{"ID":102,"NpcClassID":11,"NpcSpawnPackID":501,"IsSpawn":1},103:{"ID":103,"NpcClassID":11,"NpcSpawnPackID":501,"IsSpawn":2}},"NpcSpawnPackTerritory":{901:{"ID":901,"NpcSpawnPackID":501}}}
 var map=MapDouble.new();var dead=Node2D.new();var live=Node2D.new();var unknown=Node2D.new()
 var prefix:String="lineagem_base508:npc:11:spawn:"
 var instances:Array=[{"source_key":prefix+"101:territory:901","instance_id":"inactive","view":dead},{"source_key":prefix+"102:territory:901","instance_id":"active","view":live},{"source_key":prefix+"103:territory:901","instance_id":"unknown","view":unknown}]
 var refusal:Dictionary=REGIONS.create_confirmed_visual(map,prefix+"101:territory:901","blocked",Vector2i.ZERO,true,"source_grid_anchor")
 if refusal.get("reason","")!="source_spawn_inactive":errors.append("Inactive creation was not blocked before model/occupancy access")
 if REGIONS.prune_inactive_visuals(map,instances)!=1 or instances.size()!=2 or map.removed!=["inactive"]or is_instance_valid(dead)or not is_instance_valid(live)or not is_instance_valid(unknown):errors.append("Prune removed an active/unknown instance or retained inactive")
 if CONTEXT.explicitly_inactive(12,101,901)or CONTEXT.explicitly_inactive(11,101,999):errors.append("Mismatched identity treated as inactive")
 live.free();unknown.free();CONTEXT._data=old_data;CONTEXT._indexes=old_indexes
 print("BASE508_INACTIVE_SPAWN_FILTER ",JSON.stringify({"errors":errors,"fixture_inactive_removed":1,"fixture_active_unknown_preserved":2,"original_rows_unchanged":raw==before,"real_placed_instances":0}))
 quit(0 if errors.is_empty()else 1)
