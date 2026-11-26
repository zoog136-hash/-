extends SceneTree
const BIND=preload("res://scripts/ui/original_ui/source_main_combat_bindings.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks:=0
var failures:Array[String]=[]
func ck(ok:bool,msg:String)->bool:
	checks+=1
	if not ok:failures.append(msg);printerr("AUTO_ORIGINAL_ACTION_ART_FAIL ",msg)
	return ok
func _initialize()->void:run.call_deferred()
func run()->void:
	var w:Node=load("res://Main.tscn").instantiate();root.add_child(w)
	w.set_process(false);w.player.set_physics_process(false);w.field_population.set_process(false)
	ck(QA.enter_game(w),"actual Main class selection")
	for _i:int in range(5):await process_frame
	var hud:Node=w.hud
	var original:bool=not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty()
	hud.toggle_menu()
	var tile:Button=hud.menu_page.find_child("MenuTile_auto",true,false)
	if ck(tile!=null,"actual Main full menu auto tile"):
		var art:=tile.get_node_or_null("SourceActionIcon") as TextureRect
		var source:Sprite2D=null
		if original:
			var controller:Node=hud.original_main_ui_controller
			if ck(is_instance_valid(controller) and is_instance_valid(controller._combat_scene),"admitted authored gameplay HUD"):
				var node:Variant=controller._combat_scene.source_nodes.get(29664)
				if ck(is_instance_valid(node) and node.get_meta("original_ui_source",{}).get("scene")==BIND.PAD,"exact original HUD Auto sibling sprite"):
					source=node.get_meta("source_sprite") as Sprite2D
			ck(is_instance_valid(source) and is_instance_valid(art) and art.texture==source.texture and art.material==source.material,"visible auto menu artwork uses the identical resident original asset")
		else:ck(art!=null and art.texture==null,"missing original has text, never handmade icon")
		tile.pressed.emit()
		var shown:TextureRect=hud.workspace.find_child("SourceAutoActionIcon",true,false)
		ck(hud.active_section=="auto" and shown!=null and shown.is_visible_in_tree(),"menu tile opens actual auto status banner")
		if shown!=null:
			ck(shown.texture==null if not original else (source!=null and shown.texture==source.texture and shown.material==source.material),"actual status view uses identical art or retains text")
		var action:Button=hud.workspace.find_child("AutoSettingToggle",true,false)
		if ck(action!=null,"existing gameplay action remains available"):
			var previous:bool=w.player.auto_enabled
			action.pressed.emit()
			ck(w.player.auto_enabled!=previous,"launch opens same real auto-hunting toggle, not a decorative replacement")
			w.player.set_auto_enabled(previous)
	w.queue_free();await process_frame
	print("AUTO_ORIGINAL_ACTION_ART_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
