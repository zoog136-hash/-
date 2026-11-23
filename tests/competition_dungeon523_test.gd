extends SceneTree
## Optional exact definition input: TWILIGHT_PATCH523_CONTENT.
## The real Main UI, wallet and writer are exercised with an arrival recorder
## when no verified complete map/provider pack is installed. No terrain claim.
const DUNGEON = preload("res://scripts/dungeons/competition_dungeon523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const PAYMENT = preload("res://scripts/maps/current523_map_travel_payment.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
const VILLAGE = preload("res://scripts/maps/current523_start_village.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var checks := 0
var failures: Array[String] = []
var physical := false
var image_count := 0

func check(ok: bool, label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);printerr("COMPETITION_DUNGEON523_FAIL ",label)
	return ok

class Recorder extends RefCounted:
	var owner: Node
	var active := true
	var source_owned := true
	var saving_prior_snapshot := true
	var problem := ""
	var last: Dictionary = {}
	var moves: Array = []
	var here: Dictionary = {"land_id":4,"cell":[33426,32817]}
	var missing: bool = false
	var fail_landing: bool = false
	func source_land_ready(_land: int) -> String: return "설치된 리소스 팩에 지도 없음" if missing else ""
	func current_source_land() -> Dictionary: return here.duplicate(true)
	func last_source_transition() -> Dictionary: return last.duplicate(true)
	func enter_source_land(land: int, bounds: Array, policies: Array, changes: Dictionary) -> bool:
		moves.append([land,bounds,policies,changes.duplicate(true)])
		last={}
		if fail_landing:problem="fixture missing landing";return false
		last=PAYMENT.commit(owner,changes)
		problem=str(last.get("reason",""))
		if not last.get("ok",false):return false
		owner.gold=changes.gold
		here={"land_id":land,"cell":bounds.slice(0,2)}
		return true
	func return_to_aden(changes: Dictionary, _waive: Array) -> Dictionary:
		last=PAYMENT.commit(owner,changes)
		if last.get("ok",false):here={"land_id":4,"cell":[33426,32817]}
		return last

func _initialize() -> void:
	_run.call_deferred()

func _tables() -> void:
	var world_rows: Array=DUNGEON.entries(DUNGEON.WORLD)
	var master_rows: Array=DUNGEON.entries(DUNGEON.MASTER)
	check(world_rows.size()==23 and master_rows.size()==4 and DUNGEON.entries(DUNGEON.GLOBAL_MASTER).size()==1,"original world23/master4/global1, no season/siege substitution")
	check(DUNGEON.title("world")=="월드 던전" and DUNGEON.title("master")=="마스터 던전","exact original menu captions")
	for row: Dictionary in world_rows+master_rows+DUNGEON.entries(DUNGEON.GLOBAL_MASTER):
		var direct: Dictionary=SOURCE.row("Land",int(row.arrival.get("land_id",-1)))
		check(not direct.is_empty() and direct.get("AssetPath")==row.arrival.get("asset_path"),"explicit arrival Land and path #%d" % int(row.id))
		check(row.asset_id>0 and int(row.asset_type)==11 and not str(row.asset_path).is_empty(),"exact EntranceAssetId and original UI_Mission file #%d" % int(row.id))
	var enabled: Array=world_rows.filter(func(row: Dictionary)->bool:return str(row.local_block).is_empty()).map(func(row: Dictionary)->int:return int(row.id))
	enabled.sort()
	check(enabled==DUNGEON.LOCAL_LOBBIES,"only five approved offline physical lobbies: "+str(enabled))
	var escaros: Dictionary=DUNGEON.entry(314)
	check(escaros.arrival.territory_id==201094 and escaros.arrival.land_id==47954 and escaros.arrival.asset_path=="13410/" and escaros.levels.min==85 and escaros.asset_id==256534 and escaros.asset_path=="Image/Mission/WorldDungeon_Escaros.png","exact Escaros destination, minimum level, and typed literal entrance image")
	check(DUNGEON.lobby(47954,"13410/").get("links",[])==[1314,2042] and DUNGEON.lobby(47954,"13411/").is_empty(),"bound exact physical lobby membership only, including same-lobby variant")
	check(DUNGEON.lobby(47964).is_empty() and DUNGEON.lobby(47233).is_empty(),"combat Land and unapproved Master Land not authorized")
	for row: Dictionary in master_rows:check(str(row.local_block).contains("서버 조건"),"Master stays visible, server condition held #%d" % int(row.id))
	check(str(DUNGEON.entry(472).local_block).contains("미공개") and str(DUNGEON.entry(501).local_block).contains("재화") and str(DUNGEON.entry(82).local_block).contains("주간"),"global, fishing and normal weekly gates stay separate")
	var missing: Dictionary=DUNGEON.picture(escaros)
	check(missing.get("texture")==null or missing.get("ok",false),"no placeholder if original art cannot load")

func _images(root_path: String) -> void:
	var configured: Dictionary=IMAGES.configure(root_path,"b743a3f192ff5c4196bcd5d1775935068fe22a10a108334080be2e2fc8a1e58c")
	if not check(configured.get("ok",false),"production source image loader opens the exact pack: "+str(configured.get("status",""))+" "+str(configured.get("error",""))):return
	var checked: Dictionary={}
	for row: Dictionary in DUNGEON.entries(DUNGEON.WORLD)+DUNGEON.entries(DUNGEON.MASTER):
		if checked.has(row.asset_id):continue
		checked[row.asset_id]=true
		var visual: Dictionary=DUNGEON.picture(row)
		if check(visual.get("ok",false) and visual.get("texture") is Texture2D and visual.get("provenance",{}).get("path")==row.asset_path,"original loader decodes exact path for "+str(row.asset_id)+": "+str(visual.get("status",""))):
			image_count+=1
	check(image_count==21,"all 21 distinct world/master original PNG roles decoded")

func _confirm_escaros_menu(world: Node) -> bool:
	world.hud.open_source_dungeons()
	var view: Node=world.hud.workspace.find_child("SourceDungeonView",true,false)
	if not check(is_instance_valid(view) and view.family.item_count==8,"normal dungeon menu shows new categories"):return false
	view.family.select(7);view._refresh()
	check(view.rows.size()==4 and str(view.details.text).contains("서버 조건"),"master details surface the concrete lock")
	view.family.select(6);view._refresh()
	for i: int in range(view.rows.size()):
		if view.rows[i].id==314:view._select(i);break
	check(view.rows.size()==23 and view.condition_button.text=="원본 입구 이동","world row offers original local entry")
	if image_count>0:
		check(view.listing.get_item_icon(view.selected) is Texture2D and view.listing.get_item_metadata(view.selected).get("source_art_status","")!="","real selected Escaros row consumes the original image")
	view.condition_button.pressed.emit()
	var dialog: Node=world.hud.find_child("TwilightConfirmation",true,false)
	if not check(is_instance_valid(dialog) and dialog.confirm_button.text=="입구 이동","normal row opens the actual confirmation"):return false
	dialog.confirm_button.pressed.emit()
	return true

func _main() -> void:
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false);world.save_timer=-100000.0
	if not check(QA.enter_game(world),"real Main class entry"):
		world.queue_free();await process_frame;return
	world.level=85; world.gold=400000
	if not check(world._save_game(true)==OK,"real initial save"):
		world.queue_free();await process_frame;return
	var hash_before: String=FileAccess.get_sha256(world.save_path())
	var no_map: Dictionary=world.competition523_quote(314)
	check(not no_map.get("ok",false) and str(no_map.reason).contains("원본 지도"),"actual Main without source map refuses")
	var real: RefCounted=world._aden_play_controller()
	var recorder:=Recorder.new()
	recorder.owner=world
	world._current523_aden_play_controller=recorder
	world.current523_aden_play_active=true
	check(not world.competition523_quote(233).ok and recorder.moves.is_empty(),"master never reaches travel receiver")
	world.level=84
	check(str(world.competition523_quote(314).reason).contains("85레벨"),"minimum rechecked")
	world.level=85
	recorder.missing=true
	check(not world.competition523_quote(314).ok and recorder.moves.is_empty(),"missing target held")
	recorder.missing=false
	var q: Dictionary=world.competition523_quote(314)
	if check(q.get("ok",false),"real World quote for selected source entrance: "+str(q.get("reason",""))):
		var fake_ticket: Dictionary=q.ticket.duplicate(true);fake_ticket.arrival.land_id=123
		check(not world.competition523_enter(314,fake_ticket).ok and recorder.moves.is_empty(),"stale or changed selection rejected")
		recorder.fail_landing=true
		check(not world.competition523_enter(314,q.ticket).ok and world.gold==400000 and FileAccess.get_sha256(world.save_path())==hash_before,"no debit or write on failed landing")
		recorder.fail_landing=false
		world.equipment_collections.test_save_writer=func(_path: String,_value: Dictionary)->Error:return ERR_FILE_CANT_WRITE
		var failed: Dictionary=world.competition523_enter(314,q.ticket)
		world.equipment_collections.test_save_writer=Callable()
		check(not failed.ok and not failed.uncertain and recorder.here.land_id==4 and world.gold==400000 and FileAccess.get_sha256(world.save_path())==hash_before,"real writer refusal preserves old location, wallet and byte-identical save")
		var menu_confirmed: bool=_confirm_escaros_menu(world)
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		check(menu_confirmed and recorder.here.land_id==47954 and world.gold==300000 and int(saved.get("gold",-1))==300000,"menu-confirmed entry charges exact fee once with real writer")
		check(recorder.moves[-1]==[47954,[32731,32784,32755,32810],[DUNGEON.POLICY],{"gold":300000}],"movement receiver gets exact location and scoped geographic policy")
		check(not world.competition523_enter(314,q.ticket).ok and world.gold==300000,"repeat inside lobby cannot charge")
		check(world.competition523_return().ok and recorder.here.land_id==4 and world.gold==300000,"confirmed return uses the save owner with no charge")
	world.current523_aden_play_active=false
	world._current523_aden_play_controller=real
	recorder.owner=null
	world.queue_free()
	await process_frame

func _terrain(base: String) -> void:
	# Both manifests belong to the installed original 523 maps. A bounded test
	# may use only exact original Giran/Escaros cells and their necessary tiles.
	var options: Dictionary={"enabled":true,"navigation_profile":OPTIONS.GENERIC,
		"raw_root":base.path_join("source523"),"tile_root":base.path_join("tiles523"),
		"source_manifest_sha256":"6b71f4adb533b7acae6a7327e83af1b1322001a0f67c417bb3fae1bec35d96ca",
		"tile_manifest_sha256":"8a954372eed28e360dc3c7c77f361fba1e0fcc7ee1daa7ffa204f6a679e28482",
		"native_land_id":4,"source_position":VILLAGE.source_position()}
	check(OPTIONS.write(options)==OK,"save the explicit QA-only original pack selection")
	HOST.refresh()
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.save_timer=-100000.0
	if not check(QA.enter_game(world),"real Main class confirmation"):
		world.queue_free();await process_frame;return
	for frame: int in 400:
		if world.current523_aden_source_active():break
		await process_frame
	if not check(world.current523_aden_source_active(),"original Giran starts: "+str(world.current523_aden_play_problem)+" / "+HOST.problem):
		world.queue_free();await process_frame;return
	world.set_process(false);world.player.set_physics_process(false)
	world.level=85;world.gold=400000
	check(world._save_game(true)==OK,"real Giran save before Escaros")
	var before: String=FileAccess.get_sha256(world.save_path())
	var old: Dictionary=world.orim_current_land()
	var q: Dictionary=world.competition523_quote(314)
	if check(q.get("ok",false),"real Escaros route is available in the original pack: "+str(q.get("reason",""))):
		world.equipment_collections.test_save_writer=func(_path: String,_value: Dictionary)->Error:return ERR_FILE_CANT_WRITE
		var failure: Dictionary=world.competition523_enter(314,q.ticket)
		world.equipment_collections.test_save_writer=Callable()
		check(not failure.ok and not failure.uncertain and world.orim_current_land()==old and world.gold==400000 and FileAccess.get_sha256(world.save_path())==before,"actual geometry and save failure roll back")
		var menu_confirmed: bool=_confirm_escaros_menu(world)
		await process_frame
		physical=menu_confirmed and int(world.orim_current_land().get("land_id",-1))==47954
		if check(physical,"menu confirmation uses actual controller to enter original Escaros: "+str(world.hud.message_label.text)):
			var c: Dictionary=world.orim_current_land()
			check(c.land_id==47954 and c.cell[0]>=32731 and c.cell[0]<=32755 and c.cell[1]>=32784 and c.cell[1]<=32810 and world.field_map.walkable(world.player.global_position),"live actor stands inside original entry box on clear S32")
			check(world.gold==300000 and FileAccess.get_sha256(world.save_path())!=before,"fee and arrival committed together")
			world._load_game(true)
			# _set_map defers source play restore until Main has applied its saved state.
			for frame: int in 400:
				if world.orim_current_land()==c:break
				await process_frame
			check(world.orim_current_land()==c and world.gold==300000,"source cursor reload returns to the lobby without a repeated fee: "+str(world.orim_current_land())+" / "+str(world.current523_aden_play_problem))
			world.portal_cooldown=0.0
			var returned: Dictionary=world.competition523_return()
			check(returned.get("ok",false) and int(world.orim_current_land().get("land_id",-1))==4 and world.gold==300000,"actual Giran return without debit: "+str(returned.get("reason","")))
	world.queue_free()
	await process_frame

func _run() -> void:
	var exact: bool=SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA
	if exact:
		_tables()
		var terrain: String=""
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--competition-terrain="):terrain=arg.trim_prefix("--competition-terrain=")
			if arg.begins_with("--competition-images="):_images(arg.trim_prefix("--competition-images="))
		if not terrain.is_empty():await _terrain(terrain)
		elif "--tables-only" not in OS.get_cmdline_user_args():await _main()
	else:
		check(not OS.has_environment("TWILIGHT_PATCH523_CONTENT"),"an explicit invalid archive must not masquerade as a no-pack run")
		check(DUNGEON.entries(DUNGEON.WORLD).is_empty() and DUNGEON.entries(DUNGEON.MASTER).is_empty(),"absent source cannot invent a dungeon")
	print("COMPETITION_DUNGEON523_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"exact_definitions":exact,"physical_terrain_tested":physical,"original_images_decoded_by_runtime":image_count,"original_ui_art_render_tested":false}))
	quit(0 if failures.is_empty() else 1)
