extends SceneTree
## Original 523 오림의 흔적 level-up skill choice (source_main_orim_skill_window,
## Hud_TracesOrim_Skill). Synthetic (no original files): the window names the
## client CSB with its three cards and every OrimsTrailSpellType node, fails
## closed without the pack, reads owned levels the way the run stores them,
## and the Orim field panel hides its own cards only while the original choice
## is shown.
const ORIM=preload("res://scripts/ui/original_ui/source_main_orim_skill_window.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_ORIM_SKILL_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(ORIM.ROOT=="UI/Main/Hud_TracesOrim_Skill.csb" and ORIM.CARDS==["Panel_Orim_01","Panel_Orim_02","Panel_Orim_03"],"the choice is Hud_TracesOrim_Skill with its three cards")
	check(ORIM.TYPES.has("Attack") and ORIM.TYPES.has("Utility") and ORIM.TYPES.has("Reward") and ORIM.TYPES.has("Synergy"),"every OrimsTrailSpellType has its card node")
	var result: Dictionary=ORIM.new().configure(FakePack.new())
	check(not result.get("ok",true) and result.get("code")=="source_orim_skill_window_member_missing","the choice fails closed without its CSB")
	var info: Dictionary={"skills":[{"group":11,"level":2},{"group":12,"level":0}]}
	check(ORIM._owned_level(info,11)==2 and ORIM._owned_level(info,12)==0 and ORIM._owned_level(info,13)==-1,"owned levels (0 = first learn, -1 = a new card)")
	var window=ORIM.new()
	check(window.show(null,null).get("code")=="source_orim_skill_window_host_unavailable","no host, no window")
	var main_text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main_text.contains("func show_orim_skill_choice") and main_text.contains("func close_orim_skill_choice"),"the original UI controller shows and closes the choice")
	var orim_text: String=FileAccess.get_file_as_string("res://scripts/orim523/orim523_hud.gd")
	check(orim_text.contains("show_orim_skill_choice") and orim_text.contains("cards.visible = false"),"the Orim panel hides its own cards while the original choice is shown")
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_orim_skill_window.gd")
	check(text.contains("dungeon_play.choose_skill") and text.contains("dungeon_play.reroll"),"결 정 and 새로고침 run the existing run actions")
	check(not text.contains("Image.create") and not text.contains("draw_rect"),"no picture is drawn")
	print("ORIGINAL_UI_ORIM_SKILL_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
