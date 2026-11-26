extends SceneTree
## Real Main route. CI runs the no-pack safety path; an explicitly mounted
## pin adds the original CSB, exact PNG and the original entry requirements.
const SRC=preload("res://scripts/resources/current523_definition_rows.gd")
const IMG=preload("res://scripts/ui/source523_image_assets.gd")
const COMP=preload("res://scripts/dungeons/competition_dungeon523.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const ART="Image/Mission/WorldDungeon_Escaros.png"
const PIN="d3a5740258f6f4d7a9f345a80f56bd7680488fadc1cf640d40e79890df65ef6a"
const PACK_PIN="db51444bcd65d89c8775b67f321db0c1aa6bcb801f5e4375f6d50a0de2d3cb1f"
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message);printerr("ESCAROS_ORIGINAL_CARD_FAIL ",message)
	return ok
func _initialize()->void:run.call_deferred()
func run()->void:
	var w:Node=load("res://Main.tscn").instantiate()
	root.add_child(w);w.set_process(false);w.save_timer=-100000
	ck(QA.enter_game(w),"Main entered")
	await process_frame;await process_frame
	w.field_population.set_process(false);w.player.set_physics_process(false)
	var h:Node=w.hud
	var defs:String=OS.get_environment("TWILIGHT_ESCAROS_DEFINITIONS")
	var pack:String=OS.get_environment("TWILIGHT_ESCAROS_IMAGES")
	if defs.is_empty() or pack.is_empty():
		h._navigate("content523")
		ck(h.active_section=="content523" and h.workspace.visible and h.find_child("Content523Panel",true,false)==null,"Escaros route never opens combined debug panel")
	else:
		OS.set_environment("TWILIGHT_PATCH523_CONTENT",defs);SRC.reset()
		ck(SRC.identity().get("source_sha256")==SRC.SOURCE_SHA,"pinned source definitions")
		ck(IMG.configure(pack,PACK_PIN).get("ok",false) and FileAccess.get_sha256(pack.path_join("originals").path_join(ART))==PIN,"pinned exact Escaros PNG")
		w.level=84;w.gold=100000
		h._navigate("content523")
		var controller:Node=h.original_main_ui_controller
		var native:RefCounted=controller.dungeon_window() if is_instance_valid(controller) else null
		var status:Dictionary=h.original_main_ui_status.get("dungeon_window",{})
		if ck(native!=null and status.get("handled",false) and not h.workspace.visible,"same menu route opens native Mission_Dungeon_All: "+str(status.get("code",""))):
			ck(native.tab=="world" and native.rows.size()==1 and int(native.rows[0].id)==314,"only exact Escaros original dungeon row is focused")
			var art:Dictionary=COMP.picture(COMP.entry(314))
			ck(art.get("texture") is Texture2D and art.texture.get_size()==Vector2(154,262),"source picture resolver decodes exact Escaros texture")
			ck(status.get("pictures",0)==1,"bound original picture exists on the visible native card")
			var low:Dictionary=native._competition_pressed(314)
			ck(str(low.get("blocked","")).contains("85레벨") and w.gold==100000,"real card at level 84 refuses without any fee")
			w.level=85;w.gold=99999
			var poor:Dictionary=native._competition_pressed(314)
			ck(str(poor.get("blocked","")).contains("100000") and w.gold==99999,"level 85 needs the exact original fee")
			w.gold=100000
			var quote:Dictionary=w.content523.escaros_entry_quote()
			ck(quote.get("ok",false) and quote.route.land_id==47954 and quote.route.min_level==85 and quote.route.cost==100000,"original gameplay owner retains verified destination and terms")
			ck(native._competition_pressed(314).get("confirming")=="에스카로스 · 입장" and w.gold==100000,"card opens the actual activity confirmation without charging prematurely")
			var confirmation:Node=h.find_child("TwilightConfirmation",true,false)
			if confirmation!=null:confirmation.queue_free()
			h._close_workspace();await process_frame
			ck(not native.is_open(),"native window closes through existing close owner")
	h._navigate("field_activities523");await process_frame
	var activities:Node=h.find_child("Content523Panel",true,false)
	ck(h.active_section=="field_activities523" and activities!=null,"Elf forest and territory activities remain accessible separately")
	if activities!=null:
		var hidden:bool=activities.find_child("Escaros523Enter",true,false)==null
		for label:Node in activities.find_children("*","Label",true,false):
			hidden=hidden and not str(label.text).contains("현재 Land") and not str(label.text).contains("Prob")
		ck(hidden,"outside Escaros no hidden coordinate or developer-data listing is exposed")
	IMG.clear_selection();w.queue_free();await process_frame
	print("ESCAROS_ORIGINAL_CARD_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
