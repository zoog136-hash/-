extends SceneTree
## Exercise the gameplay entry points through Main with a local synthetic
## special-dungeon projection. The original map pack is not required here.
const QA = preload("res://tests/qa_class_selection.gd")
const DUNGEON = preload("res://scripts/dungeons/dungeon_play_service.gd")
var checks: int=0
var failures: Array[String]=[]

class FixtureRules extends RefCounted:
	var special_by_id: Dictionary={41:{"destinations":[{"place":{"time_groups":[{"row":{"ID":61}}]}}]}}
	var time_by_id: Dictionary={}

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("DUNGEON_DURABLE_MAIN_FAIL ",label)
func stored(path: String) -> Dictionary:
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func run() -> void:
	for name: String in DirAccess.get_files_at("user://"):
		if name.begins_with("twilight_v20_save"):
			printerr("DUNGEON_DURABLE_MAIN_FAIL use an isolated user-data directory")
			quit(1)
			return
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world),"actual Main class entry")
	world.field_population.set_process(false);world.player.set_physics_process(false);world.player.auto_enabled=false
	world.deferred_save_enabled=true
	var play=world.dungeon_play
	play.rules=FixtureRules.new()
	var now: int=1800000000
	play.state=DUNGEON.empty_state()
	play.state.active={"kind":"special","status":"active","id":"durable-dungeon:1","land":22701,"map_id":"aden_world","stage_id":41,"started":now,"last":now,"groups":[61],"duration":0,"seed":1,"cursor":0,"remaining_count":0,"buffs":{},"events":{},"rewards":[],"issued":{}}
	play.state.pools={"61":{"period":now,"base":3,"bonus":120}}
	check(world._save_game(true)==OK,"durable gameplay seed")
	var path: String=world.save_path()
	var file_sha: String=FileAccess.get_sha256(path)
	check(not file_sha.is_empty(),"main writer created file")
	check(play.account_special(now+9).get("ok",false) and FileAccess.get_sha256(path)==file_sha,"pre-checkpoint tick doesn't write")
	world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_CANT_CREATE
	check(not play.account_special(now+10).get("ok",true) and int(play.state.pools["61"].base)==3 and FileAccess.get_sha256(path)==file_sha,"failed due checkpoint cannot publish debit")
	world.equipment_collections.test_save_writer=Callable()
	check(play.account_special(now+10).get("ok",false),"due checkpoint retry")
	var data:=stored(path)
	check(not world.equipment_collections._last_payload_snapshot_valid and int(data.get("source_dungeon_play",{}).get("pools",{}).get("61",{}).get("bonus",-1))==113,"exact due checkpoint durable without retaining typed payload")
	check(int(play.state.pools["61"].base)==0 and int(play.state.pools["61"].bonus)==113,"live publish after durable checkpoint")
	check(play.stop(now+12,false).get("ok",false),"actual stop method uses durable save")
	data=stored(path)
	var ledger: Dictionary=data.get("source_dungeon_play",{})
	check(ledger.get("active",{1:1}).is_empty() and int(ledger.get("pools",{}).get("61",{}).get("bonus",-1))==111,"stop closes and charges the remainder exactly once")
	check(world._save_game(true,{"gold":int(world.gold)+7})==OK and world.equipment_collections._last_payload_snapshot_valid,"economic write remains on normal durable policy")
	world.queue_free();await process_frame
	print("DUNGEON_DURABLE_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
