extends SceneTree
## The original 523 카드 뽑기 result window (source_main_card_gacha_window.gd,
## BMShop/BM_Gacha) for granted cards, with the grade light of
## source_main_card_grade_fx. Without arguments (no original files): the
## card set follows the count (1 / up to 5 / more, ten a page), the
## full-screen tap turns the page's cards, then pages and then closes, the HUD routes non-fusion
## reveals to it, 영웅 이상 are the lit grades and a pack without the light
## scenes leaves the cell as before. Real input: -- --pack=<private original
## main UI pack directory> (ui43 or later): BM_Gacha mounts each set with
## the client card prefabs and 영웅 이상 light up.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_card_gacha_window.gd")
const GRADE_FX=preload("res://scripts/ui/original_ui/source_main_card_grade_fx.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeHud extends Node:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:
		messages.append(text)

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

static func cards(count: int, grade: String="영웅") -> Array:
	var rows: Array=[]
	for index: int in count:rows.append({"name":"카드 %d" % index,"grade":grade})
	return rows

func _run() -> void:
	var window=WINDOW.new()
	window.results=cards(1)
	check(window._card_set()[0]=="Nd_CardSet_One","one card: Nd_CardSet_One")
	window.results=cards(5)
	check(window._card_set()[0]=="Nd_CardSet_Five","five cards: Nd_CardSet_Five")
	window.results=cards(6)
	check(window._card_set()[0]=="Nd_CardSet" and window.pages()==1,"six to ten cards: Nd_CardSet")
	window.results=cards(12)
	check(window.pages()==2 and window._card_set()[0]=="Nd_CardSet","more than ten: pages of ten")
	window.page=1
	check(window._card_set()[0]=="Nd_CardSet_Five","the last page (two cards) uses its own count: "+str(window._card_set()))
	var closed: Array=[]
	window.page=0
	window.on_closed=func() -> void:closed.append(true)
	window._next()
	check(window.page==0 and window.page_open() and closed.is_empty(),"the full-screen tap first turns the page's closed cards")
	window._next()
	check(window.page==1 and closed.is_empty(),"then turns the page")
	window.open_all()
	window._next()
	check(closed==[true],"the last tap closes and releases the reveal")
	check(GRADE_FX.lit("영웅") and GRADE_FX.lit("전설") and GRADE_FX.lit("신화") and not GRADE_FX.lit("희귀") and not GRADE_FX.lit("일반"),"영웅 이상 light up")
	var old_pack=FakePack.new()
	window._pack=old_pack
	var spec: Dictionary={}
	GRADE_FX.cell_spec(window,spec,"Nd_CardSet_One/Card_00/","전설")
	check(spec.get("Nd_CardSet_One/Card_00/Fx_Glow",{}).get("exclude",false) and spec.get("Nd_CardSet_One/Card_00/Fx_Result_Start",{}).get("exclude",false),"a pack without the light scenes leaves the cell as before")
	for member: String in GRADE_FX.members():old_pack.manifest.scenes[member]={}
	spec={}
	GRADE_FX.cell_spec(window,spec,"Nd_CardSet_One/Card_00/","전설")
	check(not spec.has("Nd_CardSet_One/Card_00/Fx_Glow") and spec.get("Nd_CardSet_One/Card_00/Fx_Glow/Fx_Greade",{}).get("exclude",false) and spec.get("Nd_CardSet_One/Card_00/Fx_Outline_Front",{}).get("visible",false),"with the scenes the glow stays and the light is mounted in place")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("_present_original_gacha(views,category,str(awarded.get(\"title\",\"\")))") and renewal.contains("\"card_gacha_result\""),"the HUD routes card acquisitions to the original window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_CARD_GACHA_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	if not pack.manifest.get("scenes",{}).has(WINDOW.ROOT):
		print("original_ui_card_gacha_window_test: pack without BM_Gacha (before ui43); not mounted")
		return
	var world:=Node.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures")
	var mixed: Array=[{"name":"영웅 카드","grade":"영웅"},{"name":"희귀 카드","grade":"희귀"},{"name":"신화 카드","grade":"신화"}]
	for case: Array in [[cards(1,"전설"),"Nd_CardSet_One",1],[mixed,"Nd_CardSet_Five",2],[cards(8,"일반"),"Nd_CardSet",0]]:
		var opened: Dictionary=window.open(parent,case[0],"변신","크리스터의 영웅 변신 카드 선택 상자")
		check(opened.get("handled",false) and opened.filled.set==case[1] and int(opened.filled.shown)==(case[0] as Array).size(),"BM_Gacha mounts %s: %s" % [case[1],str(opened).left(300)])
		check(int(opened.get("filled",{}).get("lights",-1))==0 and int(opened.get("filled",{}).get("backs",-1))==(case[0] as Array).size(),"%s: dealt face down: %s" % [case[1],str(opened.get("filled",{}))])
		var turned: Dictionary=window.open_all()
		check(int(turned.get("lit",-1))==int(case[2]),"%s: %d lit cards once turned: %s" % [case[1],int(case[2]),str(turned)])
		await process_frame
		window.close()
	await process_frame
	parent.queue_free()
	world.queue_free()
