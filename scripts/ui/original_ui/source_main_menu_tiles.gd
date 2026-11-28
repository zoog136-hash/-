extends RefCounted
## The original 523 메뉴 tiles (UI/CsbFile/MainMenu/MainMenu_*.csb: 70x67
## panel, Hud_Menu_* picture, caption) for the menu sections that have one.
## A tile is only a picture: the TWILIGHT menu button keeps the tap and the
## scroll drag, so every original touch node is made transparent to input.
## Sections without a client tile keep their TWILIGHT tile. The character
## tile can show its authored notice when stat points can be assigned.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const COMPLETE=preload("res://scripts/ui/original_ui/source_complete_ui_scope.gd")
const MEMORY_INDEX="res://data/ui/current523_memory_tile_index.json"
const MEMBERS: Dictionary={
	"character":"UI/CsbFile/MainMenu/MainMenu_CharacterInfo.csb",
	"변신":"UI/CsbFile/MainMenu/MainMenu_Change.csb",
	"마법인형":"UI/CsbFile/MainMenu/MainMenu_MagicDoll.csb",
	"성물":"UI/CsbFile/MainMenu/MainMenu_HolyStuff.csb",
	"equipment_collections":"UI/CsbFile/MainMenu/MainMenu_Collection.csb",
	"emblems":"UI/CsbFile/MainMenu/MainMenu_Symbol.csb",
	"clan523":"UI/CsbFile/MainMenu/MainMenu_Alliance.csb",
	"guardians":"UI/CsbFile/MainMenu/MainMenu_SkillTree.csb",
	"half_elixir":"UI/CsbFile/MainMenu/MainMenu_Elixir.csb",
	"titles":"UI/CsbFile/MainMenu/MainMenu_Title.csb",
	"totems":"UI/CsbFile/MainMenu/MainMenu_Totem.csb",
	"weapon_mastery":"UI/CsbFile/MainMenu/MainMenu_Mastery.csb",
	"skill_card523":"UI/CsbFile/MainMenu/MainMenu_SkillCard.csb",
	"monsterbook523":"UI/CsbFile/MainMenu/MainMenu_MonsterBook.csb",
	"source_dungeons":"UI/CsbFile/MainMenu/MainMenu_Dungeon.csb",
	"exchange":"UI/CsbFile/MainMenu/MainMenu_Trade.csb",
	"crafting":"UI/CsbFile/MainMenu/MainMenu_Production.csb",
	"refine523":"UI/CsbFile/MainMenu/MainMenu_Alchemy.csb",
	"memory_places":"UI/CsbFile/MainMenu/MainMenu_Memory.csb",
	"settings":"UI/CsbFile/MainMenu/MainMenu_Option.csb",
}
const HIDDEN: Array[String]=["Panel/Sp_New","Panel/Sp_Event","Panel/Sp_Buff","Panel/Img_Disabled"]
const NOTICE_ATLAS="UI/UI_Resource/Atlas_Hud.plist"
var _pack: RefCounted
var _tree: RefCounted
var _memory_tree: RefCounted
var _memory_checked: bool=false

func configure(pack: RefCounted) -> Dictionary:
	if pack==null:return _fail("source_menu_tiles_pack_unavailable")
	if _pack!=pack:
		_memory_tree=null
		_memory_checked=false
	_pack=pack
	_tree=NamedTree.new(pack)
	return {"ok":true}

static func member_of(section: String) -> String:
	return str(MEMBERS.get(section,""))

## The tile scene of `section` (centre of its 70x67 panel at the origin),
## or not ok when the section has no tile or the pack lacks it.
func tile(section: String, stat_points: int=0) -> Dictionary:
	var member: String=member_of(section)
	if member.is_empty():return _fail("source_menu_tile_not_in_client")
	var tree: RefCounted=_tree
	if _pack!=null and not _pack.manifest.get("scenes",{}).has(member):
		tree=_memory_tile_tree() if section=="memory_places" else null
	if tree==null:return {"ok":false,"handled":false,"code":"source_menu_tile_member_missing","member":member}
	var spec: Dictionary={}
	for name: String in HIDDEN:spec[name]={"visible":false}
	if section=="character" and stat_points>0 and _pack.manifest.get("atlases",{}).get(NOTICE_ATLAS,{}).get("frames",{}).has("Hud_IconNew.png"):
		spec["Panel/Sp_New"]={"visible":true}
	var built: Dictionary=tree.scene_of(member,spec,{})
	if not built.get("ok",false):return built
	var scene: Node2D=built.scene
	_ignore_input(scene)
	return {"ok":true,"scene":scene,"member":member}

func _memory_tile_tree() -> RefCounted:
	if not _memory_checked:
		_memory_checked=true
		var installed: RefCounted=COMPLETE.open_selected(MEMORY_INDEX)
		if installed!=null:_memory_tree=NamedTree.new(installed)
	return _memory_tree

static func _ignore_input(node: Node) -> void:
	if node is Control:(node as Control).mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():_ignore_input(child)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
