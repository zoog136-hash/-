extends SceneTree
## Exercise the actual menu tile and the Change_WinTotal doll list's actual
## authored tab binding. Private original pack / catalogue are optional in CI.
const QA=preload("res://tests/qa_class_selection.gd")
const ChangeWindow=preload("res://scripts/ui/original_ui/source_main_change_window.gd")
const Explore=preload("res://scripts/ui/original_ui/source_main_doll_explore_window.gd")
var checks:=0
var errors:Array[String]=[]
func ck(ok:bool,why:String)->bool:
	checks+=1
	if not ok:errors.append(why);printerr("DOLL_EXPLORE_ROUTES_FAIL ",why)
	return ok
func _initialize()->void:run.call_deferred()
func run()->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w);w.set_process(false)
	ck(QA.enter_game(w),"Main entered")
	await process_frame;await process_frame
	var h:Node=w.hud
	h.toggle_menu()
	var tile:Button=h.menu_page.find_child("MenuTile_expedition",true,false)
	var exact:=not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty()
	if ck(is_instance_valid(tile),"actual player menu tile"):
		tile.pressed.emit()
	if exact:
		var c:Node=h.original_main_ui_controller
		if is_instance_valid(c):
			for section:String in ["inventory","skills","quests"]:
				var tile_owner:Node=h.menu_page.find_child("MenuTile_"+section,true,false)
				var art:=tile_owner.get_node_or_null("SourceActionIcon") as TextureRect
				var exact_art:Dictionary=c.menu_action_art(section)
				ck(art!=null and art.texture!=null and art.texture==exact_art.get("texture") and art.material==exact_art.get("material"),"actual "+section+" menu art is same Texture2D/material as actionable original HUD control")
		if ck(is_instance_valid(c),"installed source UI bound") and ck(h.active_section=="doll_explore" and c.feature_window_is_open("doll_explore"),"menu opens source feature: "+str(h.original_main_ui_status.get("doll_explore_window",{}))):
			var original:RefCounted=c.feature_window("doll_explore")
			ck(original.get_script()==Explore and original._tab()=="explore" and original.deck==2 and original._spots().size()>0,"source explore tab, original deck-two spots")
			h._go_back()
			ck(h.active_section=="menu","back from menu entrance returns to menu")
			h._navigate("마법인형")
			if ck(c.change_window_is_open(),"actual original doll category list"):
				var tab:Variant=c._change_window._scene.source_nodes.get(ChangeWindow.EXPLORE_OFF)
				if ck(is_instance_valid(tab) and tab.visible,"visible source explore-tab button"):
					var result:Dictionary=tab.get_meta("source_button")._dispatch_activation()
					ck(result.get("handled",false) and h.active_section=="doll_explore" and c.feature_window_is_open("doll_explore") and c.feature_window("doll_explore")==original and not c.change_window_is_open(),"real doll button -> exact same owner, former tab closed")
					h._go_back()
					ck(h.active_section=="마법인형" and c.change_window_is_open() and not c.feature_window_is_open("doll_explore"),"back returns to real doll list, no duplicate window")
	else:
		for section:String in ["inventory","skills","quests"]:
			var art:TextureRect=h.menu_page.find_child("MenuTile_"+section,true,false).get_node("SourceActionIcon")
			ck(art.texture==null,"no invented "+section+" art when original absent")
		ck(h.active_section=="menu" and h.workspace.visible,"missing UI keeps menu; no unrelated combined screen")
		var page:=ChangeWindow.new();page._hud=weakref(h)
		var refused:Dictionary=page._explore_requested()
		ck(not refused.get("ok",true) and h.active_section=="menu","real doll tab callback also declines missing original")
	w.queue_free();await process_frame
	print("DOLL_EXPLORE_ROUTES_RESULT ",JSON.stringify({"checks":checks,"failures":errors,"private_source_ui":exact}))
	quit(0 if errors.is_empty() else 1)
