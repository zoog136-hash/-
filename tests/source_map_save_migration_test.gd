extends SceneTree
const MIGRATE=preload("res://scripts/maps/source_map_save_migration.gd")
const RUNTIME=preload("res://scripts/maps/source_map_runtime.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("MAP_MIGRATION_FAIL ",label)
func _initialize() -> void:
	var field: RemakePlayableField=RUNTIME.load_field("source_77")
	check(field!=null,"actual admitted art and directional grid")
	if field==null:quit(1);return
	var old=preload("res://scripts/maps/source_coordinates.gd").new()
	old.configure([32704,32768],[128,128],{"basis_x":[24,-12],"basis_y":[24,12],"translation":[0,2304]})
	var blocked: Vector2=old.to_world(Vector2(32768,32838))
	var open: Vector2=old.to_world(Vector2(32762,32842))
	var legacy={"origin":[32704,32768],"dimensions":[128,128],"coordinate_mapping":{"basis_x":[24,-12],"basis_y":[24,12],"translation":[0,2304]},"source_map_id":77,"grid_sha256":field.definition.source_sha256,"layout_revision":2026101502}
	var data: Dictionary={"map_id":"source_77","map_layout_revision":2026101502,"position":[blocked.x,blocked.y],
		"gold":777,"full_precision_deadline":1234567.123456789,"inventory":{"HP 물약":19},"item_instances":{"991":{"id":"991","enchant":7}},
		"original_position":{"source_map_id":77,"grid_sha256":field.definition.source_sha256,"source":[32768.5,32838.5]},
		"ground_drops":[{"id":"drop-physical-1","map_id":"source_77","position":[open.x,open.y],"quantity":3,"physical_item":{"id":"6001","enchant":9}},
		{"id":"drop-physical-2","map_id":"source_77","position":[blocked.x,blocked.y],"quantity":5}],
		"monster_world":{"bosses":{"source_77:old_boss":{"phase":"alive","hp":987,"ready_at":1234567,"position":[blocked.x,blocked.y],"home":[open.x,open.y]},"faith_01:boss":{"phase":"cooldown","ready_at":999999,"position":[],"home":[]}}}}
	var unchanged: Dictionary=data.duplicate(true)
	var folder: String="user://source-map-migration-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var original: String=folder+"/original.json"
	check(WRITER.write(original,data)==OK,"isolated original saved")
	var sha: String=FileAccess.get_sha256(original)
	var plan: Dictionary=MIGRATE.plan(data,"source_77",field,{"legacy_frame":legacy},sha)
	check(plan.ok,"all spatial fields planned against real collision")
	if not plan.ok:printerr(plan);field.close();quit(1);return
	var migrated: Dictionary=plan.data
	check(data==unchanged,"planning never mutates original input")
	var entry:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	check(Vector2(migrated.position[0],migrated.position[1]).distance_to(entry)<.01,"blocked player moves to verified entry")
	check(migrated.gold==777 and migrated.inventory==data.inventory and migrated.item_instances==data.item_instances,"all gold, inventory, physical equipment IDs and enchant values retained")
	check(migrated.ground_drops[0].id=="drop-physical-1" and migrated.ground_drops[0].physical_item.id=="6001" and migrated.ground_drops[0].physical_item.enchant==9 and migrated.ground_drops[0].quantity==3,"physical drop metadata and quantities retained")
	check(Vector2(migrated.ground_drops[0].position[0],migrated.ground_drops[0].position[1]).distance_to(field.coordinates.to_world(Vector2(32762,32842)))<.01,"valid known-frame drop preserves geographic source position")
	check(Vector2(migrated.ground_drops[0].position[0],migrated.ground_drops[0].position[1]).distance_to(Vector2(migrated.ground_drops[1].position[0],migrated.ground_drops[1].position[1]))>=36,"fallback drops have distinct reachable landings")
	check(migrated.monster_world.bosses["source_77:old_boss"].hp==987 and migrated.monster_world.bosses["source_77:old_boss"].phase=="alive" and migrated.monster_world.bosses["source_77:old_boss"].ready_at==1234567,"monster life, HP and cooldown preserved")
	check(migrated.monster_world.bosses["faith_01:boss"]==data.monster_world.bosses["faith_01:boss"],"unrelated protected monster state unchanged")
	check(migrated.source_map_migrations[0].ground_drops==data.ground_drops,"all original drop coordinates recoverable in archive")
	var staged: Dictionary=MIGRATE.stage(original,migrated,sha)
	check(staged.ok and FileAccess.get_sha256(original)==sha,"stage never overwrites original filename")
	check(FileAccess.get_sha256(staged.backup_path)==sha,"immutable backup byte SHA equals original")
	check(MIGRATE.resolve(original).path==original,"staging alone does not change active save")
	check(MIGRATE.activate(original,staged)==OK and MIGRATE.resolve(original).path==staged.target_path,"explicit activation selects separate migrated save")
	var retry: Dictionary=MIGRATE.stage(original,migrated,sha)
	check(retry.ok and retry.target_path!=staged.target_path and FileAccess.file_exists(staged.target_path),"retry preserves earlier candidate and original")
	check(not MIGRATE.stage(original,migrated,"bad-hash").ok and FileAccess.get_sha256(original)==sha,"source-change failure cannot write or activate")
	DirAccess.remove_absolute(staged.target_path)
	check(not MIGRATE.resolve(original).ok and FileAccess.get_sha256(original)==sha,"missing active candidate fails explicitly without fallback overwrite")
	field.close()
	print("SOURCE_MAP_SAVE_MIGRATION_", "OK" if failures.is_empty() else "FAILED"," checks=",checks)
	quit(0 if failures.is_empty() else 1)
