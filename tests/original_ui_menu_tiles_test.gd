extends SceneTree
## Original 523 menu tiles (source_main_menu_tiles). Synthetic (no original
## files): every mapped section is a menu section and names a client
## MainMenu_* member, a tile fails closed without its member, the mounted tile
## takes no input (the TWILIGHT tile keeps tap and scroll drag) and the menu
## mounts it in place of the TWILIGHT picture and caption.
const TILES=preload("res://scripts/ui/original_ui/source_main_menu_tiles.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_MENU_TILES_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var hud_text: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	for section: String in TILES.MEMBERS:
		var member: String=TILES.member_of(section)
		check(member.begins_with("UI/CsbFile/MainMenu/MainMenu_") and member.ends_with(".csb"),section+" names a client MainMenu tile")
		check(hud_text.contains("[\""+section+"\","),section+" is a menu section")
	check(TILES.member_of("settings")=="UI/CsbFile/MainMenu/MainMenu_Option.csb" and TILES.member_of("guardians")=="UI/CsbFile/MainMenu/MainMenu_SkillTree.csb","설정 → MainMenu_Option, 수호성 → MainMenu_SkillTree (the tile captions)")
	check(TILES.member_of("inventory").is_empty() and not TILES.MEMBERS.has("domination_stone"),"sections without a client tile (and the separately mounted 지배석) are not mapped")
	check(not TILES.new().configure(null).get("ok",true),"no pack -> no tiles")
	var tiles=TILES.new()
	check(tiles.configure(FakePack.new()).get("ok",false),"a pack configures the tiles")
	var missing: Dictionary=tiles.tile("settings")
	check(not missing.get("ok",true) and missing.get("code")=="source_menu_tile_member_missing" and missing.get("member")==TILES.member_of("settings"),"a tile fails closed without its member")
	check(tiles.tile("inventory").get("code")=="source_menu_tile_not_in_client","an unmapped section has no tile")
	var root:=Node2D.new()
	var area:=Control.new()
	area.mouse_filter=Control.MOUSE_FILTER_STOP
	var inner:=Node2D.new()
	var deep:=Control.new()
	root.add_child(inner);inner.add_child(area);area.add_child(deep)
	TILES._ignore_input(root)
	check(area.mouse_filter==Control.MOUSE_FILTER_IGNORE and deep.mouse_filter==Control.MOUSE_FILTER_IGNORE,"every control of a tile ignores input")
	root.free()
	check(hud_text.contains("else: _mount_original_menu_tile(section_id,button,artwork,caption)"),"the menu mounts the original tile")
	check(hud_text.contains("artwork.texture = null") and hud_text.contains("caption.hide()"),"the original tile replaces the TWILIGHT picture and caption")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main_text.contains("func menu_tile(section: String)"),"the original UI controller exposes menu_tile")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_menu_tiles.gd")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
	print("ORIGINAL_UI_MENU_TILES_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
