extends SceneTree
## Original 523 지도 area tab (source_main_map_area_tab): synthetic, no
## original files. The tab needs the whole Map_Tab_Area and the 지역 정보
## members (UI pack ui43); an older pack keeps the map as it was. The map
## bindings mount the area list, filters, title and 텔레포트 panel inside the
## area project, Map_All's 지역 정보 button opens MapInfoScene, and a map tap
## selects the area at that cell.
const TAB=preload("res://scripts/ui/original_ui/source_main_map_area_tab.gd")
const AREAS=preload("res://scripts/maps/current523_map_areas.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{},"node_scopes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_MAP_AREA_TAB_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var pack:=FakePack.new()
	check(not TAB.available(null) and not TAB.available(pack),"no pack, no area tab")
	for member: String in [TAB.AREA,TAB.ROW,TAB.INFO,TAB.POPUP,TAB.MONSTER_ROW,TAB.INFO_ROW,TAB.DROP_ROW]:pack.manifest.scenes[member]={}
	pack.manifest.node_scopes[TAB.AREA]=[44440,37316]
	check(not TAB.available(pack),"a ui42 pack (Map_Tab_Area scoped to the picture and world row) keeps the old map")
	pack.manifest.node_scopes[TAB.AREA]=[44440,37316]+TAB.ROOTS+[10648,9196,3728]
	check(TAB.available(pack),"a pack with the whole area tab and 지역 정보 enables the tab")
	pack.manifest.scenes.erase(TAB.POPUP)
	check(not TAB.available(pack),"without Map_Popup_AreaInfo the tab stays off")
	check(TAB.ROOTS==[37984,37560,11324,9140,3672],"the tab mounts the list frame, ListView_Button, CheckBox_Land, Teleport_Enabled and Nd_Title")
	check(AREAS.filter_of(5)=="field" and AREAS.filter_of(4)=="dungeon" and AREAS.filter_of(3)=="village" and AREAS.filter_of(8)=="base" and AREAS.filter_of(0)=="","UIMapAreaType 5/4/3/8 are the 필드/던전/마을/거점 tabs")
	check(AREAS._npc_of("lineagem_base508:npc:45:spawn:3:territory:9")==45 and AREAS._npc_of("x")==-1,"a spawn region's NpcClass comes from its source key")
	check(TAB._number(25000)=="25,000","the fee is grouped like the client's amount text")
	check(TAB._type_text({"boss":true})=="보스형" and TAB._type_text({"aggressive":true})=="선공형" and TAB._type_text({})=="","monster type label")
	var holder:=Node2D.new()
	var button:=Node2D.new()
	holder.set_meta("source_button",button)
	TAB.forward_drags(holder,Callable(self,"check"))
	check(button.get_meta("source_drag_forward",Callable())==Callable(self,"check"),"an area row's buttons hand their drag to the list")
	button.free();holder.free()
	_sources()
	print("ORIGINAL_UI_MAP_AREA_TAB_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _sources() -> void:
	var bindings: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_map_bindings.gd")
	check(bindings.contains("area_tab.bind(field_map,offered_world_id,world_label)") and bindings.contains("area_bindings[AREA_AUTHORED_ROW][\"visible\"]=false"),"the area project mounts the tab and hides the single world row")
	check(bindings.contains("all_bindings[AREA_INFO_SCOPE[0]]=area_tab.area_info_binding()"),"Map_All 지역 정보 opens the popup")
	var view: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_world_map.gd")
	check(view.contains("tab.presented(child.player,mount)") and view.contains("_tab_router.route("),"the presenter fills the tab and routes its buttons (row drags reach the list)")
	var input: String=FileAccess.get_file_as_string("res://scripts/maps/current523_world_map_input.gd")
	check(input.contains("ui.call(\"select_area_at_cell\""),"a map tap selects the tapped area")
	var tab: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_map_area_tab.gd")
	check(tab.contains("MAP_TELEPORT.quote(world,str(area.destination_id))") and tab.contains("world.call(\"current523_map_teleport\""),"이동하기 uses the original map teleport quote and move")
	check(not tab.contains("Image.create") and not tab.contains("draw_rect"),"no picture is drawn")
