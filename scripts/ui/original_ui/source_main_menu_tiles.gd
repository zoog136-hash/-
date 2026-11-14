extends RefCounted
## The original 523 메뉴 tiles (UI/CsbFile/MainMenu/MainMenu_*.csb: 70x67
## panel, Hud_Menu_* picture, caption) for the menu sections that have one.
## A tile is only a picture: the TWILIGHT menu button keeps the tap and the
## scroll drag, so every original touch node is made transparent to input.
## Sections without a client tile keep their TWILIGHT tile. Sp_New / Sp_Event /
## Sp_Buff / Img_Disabled have no rule here and stay hidden.
const NamedTree=preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
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
	"monsterbook523":"UI/CsbFile/MainMenu/MainMenu_MonsterBook.csb",
	"source_dungeons":"UI/CsbFile/MainMenu/MainMenu_Dungeon.csb",
	"exchange":"UI/CsbFile/MainMenu/MainMenu_Trade.csb",
	"crafting":"UI/CsbFile/MainMenu/MainMenu_Production.csb",
	"refine523":"UI/CsbFile/MainMenu/MainMenu_Alchemy.csb",
	"settings":"UI/CsbFile/MainMenu/MainMenu_Option.csb",
}
const HIDDEN: Array[String]=["Panel/Sp_New","Panel/Sp_Event","Panel/Sp_Buff","Panel/Img_Disabled"]
var _pack: RefCounted
var _tree: RefCounted

func configure(pack: RefCounted) -> Dictionary:
	if pack==null:return _fail("source_menu_tiles_pack_unavailable")
	_pack=pack
	_tree=NamedTree.new(pack)
	return {"ok":true}

static func member_of(section: String) -> String:
	return str(MEMBERS.get(section,""))

## The tile scene of `section` (centre of its 70x67 panel at the origin),
## or not ok when the section has no tile or the pack lacks it.
func tile(section: String) -> Dictionary:
	var member: String=member_of(section)
	if member.is_empty():return _fail("source_menu_tile_not_in_client")
	if _pack==null or not _pack.manifest.get("scenes",{}).has(member):return {"ok":false,"handled":false,"code":"source_menu_tile_member_missing","member":member}
	var spec: Dictionary={}
	for name: String in HIDDEN:spec[name]={"visible":false}
	var built: Dictionary=_tree.scene_of(member,spec,{})
	if not built.get("ok",false):return built
	var scene: Node2D=built.scene
	_ignore_input(scene)
	return {"ok":true,"scene":scene,"member":member}

static func _ignore_input(node: Node) -> void:
	if node is Control:(node as Control).mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():_ignore_input(child)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
