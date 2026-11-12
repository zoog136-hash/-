extends SceneTree
const ACCOUNT=preload("res://scripts/characters/account_store.gd")
const PROFILE=preload("res://scripts/characters/save_profile.gd")
const MIGRATION=preload("res://scripts/maps/source_map_save_migration.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
var checks:int=0
var failures:Array[String]=[]
var base:String=""
var before_files:PackedStringArray
class Catalog extends RefCounted:
	var problem:String=""
	func profile(id:int,gender:int)->Dictionary:
		return {"name":ACCOUNT.JOBS[id],"stats":{"str":16,"dex":13,"con":16,"int":8,"wis":7,"cha":8},"source":{"ID":id}} if ACCOUNT.JOBS.has(id) and gender in [1,2] else {}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);printerr("CHARACTER_ROUTE_MAIN_FAIL ",label)
	return ok
func world()->Node:
	var value=load("res://Main.tscn").instantiate();root.add_child(value)
	value.set_process(false);value.player.set_physics_process(false);value.save_timer=-100000
	return value
func finish()->void:
	ACCOUNT.session.clear()
	if not base.is_empty():
		var directory:String=ProjectSettings.globalize_path(base).get_base_dir()
		for name:String in DirAccess.get_files_at(directory):
			if name.begins_with(base.get_file()) and name not in before_files:DirAccess.remove_absolute(directory.path_join(name))
	print("CHARACTER_ACCOUNT_ROUTE_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual Main plus production path resolver/account and migration pointers; source definitions absent, no original art claim"}))
	quit(0 if failures.is_empty() else 1)
func run()->void:
	base=PROFILE.current_base_path()
	before_files=DirAccess.get_files_at(ProjectSettings.globalize_path(base).get_base_dir())
	if FileAccess.file_exists(base) or FileAccess.file_exists(base+".source-map-current.json"):
		printerr("CHARACTER_ROUTE_MAIN_FAIL fresh isolated profile required; existing save untouched");base="";quit(2);return
	ACCOUNT.session.clear()
	var w:Node=world()
	if not check(w._save_game(true)==OK,"actual Main seeds current valid legacy save"):w.queue_free();await process_frame;finish();return
	w.queue_free();await process_frame;await process_frame
	var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base))
	original.gold=111;original.character_name="이전기사";original.source_visual_context.gender_id=1
	check(WRITER.write(base,original)==OK,"isolated legacy progress seeded")
	var base_sha:String=FileAccess.get_sha256(base)
	var latest:Dictionary=original.duplicate(true);latest.gold=456
	var migration:Dictionary=MIGRATION.stage(base,latest,base_sha)
	if not check(migration.get("ok",false),"newer legacy save candidate staged"):finish();return
	check(MIGRATION.activate(base,migration)==OK,"newer candidate pointer activated")
	var route:Dictionary=PROFILE.resolve_current()
	check(route.get("ok",false) and route.get("path")==migration.target_path,"lobby resolves newest candidate")
	var store=ACCOUNT.new();store.path=route.path
	if not check(store.open().get("legacy",false),"newest legacy selected for account migration"):finish();return
	var moved:Dictionary=store.migrate_legacy()
	if not check(moved.get("ok",false),"newest legacy safely becomes account"):finish();return
	var state:Dictionary=store.open()
	var first:String=state.characters[0].id
	check(store.select_character(first).ok,"select migrated A")
	w=world()
	check(w.save_path()==store.path and w.gold==456,"actual Main loads newest selected A progress")
	check(w.character_display_name=="이전기사" and w.hud.character_state.get("character_name")=="이전기사","selected name reaches actual HUD state")
	check(w._save_game(true)==OK,"selected A saves to same account file")
	w.queue_free();await process_frame;await process_frame
	store.open()
	var second:Dictionary=store.create_character("새요정",2,2,Catalog.new())
	if not check(second.get("ok",false) and store.select_character(second.id).ok,"create and select B on resolved account"):finish();return
	w=world()
	check(w.save_path()==store.path and w.job_class=="요정" and w.gold!=456,"actual Main loads independent B from same account")
	w.gold=789
	check(w._save_game(true)==OK,"B private progress commits")
	w.queue_free();await process_frame;await process_frame
	check(store.open().ok and store.select_character(first).ok,"return A after B")
	w=world()
	check(w.gold==456 and w.job_class=="기사","A private progress survives B and pointer routing")
	check(w._save_game(true)==OK,"A re-saves through canonical account")
	w.queue_free();await process_frame;await process_frame
	check(FileAccess.get_sha256(base)==base_sha,"obsolete base bytes never overwritten")
	var target_sha:String=FileAccess.get_sha256(store.path)
	check(WRITER.write_text(base+".source-map-current.json","{broken")==OK,"seed damaged pointer")
	ACCOUNT.session.clear()
	w=world()
	check(w.source_save_blocked and w._save_game(true)!=OK,"actual Main blocks damaged-pointer load and write")
	w.queue_free();await process_frame;await process_frame
	check(FileAccess.get_sha256(base)==base_sha and FileAccess.get_sha256(store.path)==target_sha,"damaged pointer preserves base and latest account bytes")
	finish()
