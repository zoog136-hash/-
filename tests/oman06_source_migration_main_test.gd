extends SceneTree
const RUNTIME=preload("res://scripts/maps/source_map_runtime.gd")
const OLD=preload("res://scripts/maps/remake_registry.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var checks: int=0
var world: TwilightWorld
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("OMAN06_MIGRATION_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var child: bool="--reload-child" in OS.get_cmdline_user_args()
	world=load("res://Main.tscn").instantiate();world.active_map_id="source_77";root.add_child(world)
	world.set_process(false);world.save_timer=-100000;world.portal_cooldown=10000
	check(QA.enter_game(world),"real character confirmation")
	if child:
		check(world.active_map_id=="oman_06" and bool(world.field_map.get_meta("source_map84",false)),"restart follows pointer to migrated actual Oman field")
		check(world.gold==456789 and not world.source_save_blocked,"restart preserves progress and accepted layout")
		check(world.save_path()!=world.base_save_path(),"restart uses separate migrated file")
		await finish();return
	world.field_population.set_process(false)
	check(world._save_game(true)==OK,"current-schema baseline save")
	var original_path: String=world.save_path()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(original_path))
	var previous: RemakePlayableField=OLD.load_field("oman_06")
	var next: RemakePlayableField=RUNTIME.load_field("oman_06")
	check(previous!=null and next!=null,"both authenticated old layout and new selected360 layout")
	if previous==null or next==null:await finish();return
	var source_start:=Vector2(previous.definition.spawn_source[0],previous.definition.spawn_source[1]) if previous.definition.has("spawn_source") else Vector2(32672,32864)
	var blocked_source:=Vector2.INF
	for radius: int in range(1,30):
		for y: int in range(-radius,radius+1):
			for x: int in range(-radius,radius+1):
				var p: Vector2=source_start+Vector2(x,y)
				if previous.point_clear(previous.coordinates.to_world(p),4) and not next.point_clear(next.coordinates.to_world(p),4):blocked_source=p;break
			if blocked_source.is_finite():break
		if blocked_source.is_finite():break
	check(blocked_source.is_finite(),"genuine old clear cell now blocked in selected grid")
	var old_player: Vector2=previous.coordinates.to_world(blocked_source)
	var old_drop: Vector2=previous.coordinates.to_world(Vector2(32670,32864))
	fixture.map_id="oman_06";fixture.position=[old_player.x,old_player.y];fixture.map_layout_revision=2026101502
	fixture.original_position={"source_map_id":106,"grid_sha256":previous.definition.source_sha256,"source":previous.coordinates.source_components(old_player)}
	fixture.source_map84_layouts.erase("oman_06")
	fixture.gold=456789
	fixture.ground_drops=[{"id":"legacy-oman-drop","map_id":"oman_06","item_name":"HP 물약","quantity":3,"position":[old_drop.x,old_drop.y],"created_at":Time.get_unix_time_from_system(),"expires_at":Time.get_unix_time_from_system()+600,"state":"ground"}]
	fixture.monster_world.bosses["oman_06:불사의 머미 로드"]={"phase":"alive","hp":987,"ready_at":Time.get_unix_time_from_system()+5000,"layout_revision":2026101502,"position":[old_player.x,old_player.y],"home":[old_player.x,old_player.y]}
	var old_count: int=0
	for region: Dictionary in previous.data.monster_spawn:old_count+=int(region.max_count)
	var new_count: int=0
	for region: Dictionary in next.data.monster_spawn:new_count+=int(region.max_count)
	check(old_count==new_count and previous.data.monster_spawn.size()==next.data.monster_spawn.size(),"existing roster counts and region IDs preserved")
	check(previous.data.npc_spawn.size()==next.data.npc_spawn.size() and previous.data.portal.size()==next.data.portal.size(),"existing NPC and portal counts preserved")
	previous.close();next.close()
	check(WRITER.write(original_path,fixture)==OK,"isolated real legacy save fixture")
	var original_sha: String=FileAccess.get_sha256(original_path)
	var pack_path: String=OS.get_environment("TWILIGHT_SOURCE_MAP_PACK")
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",pack_path+"-missing");world.gold=17;world._load_game(true)
	check(world.source_save_blocked and world.gold==17 and FileAccess.get_sha256(original_path)==original_sha,"missing target pack rejects before progress changes")
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",pack_path)
	var diagnostic: Dictionary=RUNTIME.prepare_migrations(fixture,original_sha)
	print("OMAN06_PLAN_DIAGNOSTIC ",diagnostic.get("ok")," ",diagnostic.get("error","")," validation=",RUNTIME.validate_save(diagnostic.data) if diagnostic.get("ok",false) else "not prepared")
	world._load_game(true)
	print("OMAN06_LOAD_DIAGNOSTIC map=",world.active_map_id," blocked=",world.source_save_blocked," path=",world.save_path()," gold=",world.gold)
	check(world.active_map_id=="oman_06" and bool(world.field_map.get_meta("source_map84",false)) and world.gold==456789,"real World migrates to selected360 Oman06")
	check(world.player.global_position.distance_to(world._spawn_position())<.01,"blocked old player lands at verified entry")
	check(FileAccess.get_sha256(original_path)==original_sha,"original filename and exact bytes remain untouched")
	check(FileAccess.get_sha256(original_path+".pre-source-map-"+original_sha)==original_sha,"SHA-verified original backup exists")
	check(world.ground_loot.records.has("legacy-oman-drop") and int(world.ground_loot.records["legacy-oman-drop"].quantity)==3,"actual drop UUID and quantity survive migration")
	var boss_state: Dictionary=world.legacy_population.boss_director.states.get("oman_06:불사의 머미 로드",{})
	check(int(boss_state.get("hp",0))==987 and str(boss_state.get("phase",""))=="alive","existing boss life and HP survive migration")
	var target: String=world.save_path()
	check(target!=original_path and FileAccess.file_exists(target),"separate verified candidate selected in memory")
	if target==original_path:await finish();return
	var staged: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(target))
	check(staged.source_map_migrations.size()==1 and staged.source_map_migrations[0].player.position==fixture.position,"original spatial values retained for recovery")
	world._load_game(true)
	check(JSON.parse_string(FileAccess.get_file_as_string(world.save_path())).source_map_migrations.size()==1,"reload is idempotent; no repeated migration")
	check(world._save_game(true)==OK,"normal save activates separate candidate pointer")
	check(FileAccess.get_sha256(original_path)==original_sha and FileAccess.file_exists(original_path+".source-map-current.json"),"activation never overwrites original")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			world.field_population.set_process(false);world.portal_cooldown=10000
			world.field_renderer.refresh_visible();await process_frame;await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))==OK,"actual migrated Main capture")
	var output: Array=[]
	var exit_code: int=OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/oman06_source_migration_main_test.gd","--","--reload-child"]),output,true)
	check(exit_code==0,"fresh process loads activated migrated character")
	for line: Variant in output:print(line)
	await finish()
func finish() -> void:
	print("OMAN06_SOURCE_MIGRATION_", "OK" if failures.is_empty() else "FAILED"," checks=",checks)
	world.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
