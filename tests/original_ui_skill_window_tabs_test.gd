extends SceneTree
## The original 523 skill window's tabs, buttons and slot labels
## (source_main_skill_window): 전체 / 정령 (요정) / 특수 (card-bound skills)
## / 착용 (equipment skills), 스킬 카드 / 속성 변경 (요정) / 디버프 (마법사)
## routing, the live cooldown and count labels and no fixed 160-skill cap.
## Without arguments (no original files): the tab rules and texts. Real
## input: -- --pack=<private original main UI pack directory>: Skill_All
## mounts the tab strip, every tab's list and a 200-skill class whose last
## skill scrolls into view and is selectable.
const SKILL=preload("res://scripts/ui/original_ui/source_main_skill_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeCatalog extends RefCounted:
	var source523=null
	func source_learning_status(_record: Dictionary) -> Dictionary:
		return {}
	func owned(record: Dictionary) -> bool:
		return not str(record.get("id","")).ends_with("_new")
	func resolve(record: Dictionary) -> Dictionary:
		return record

class FakeSkills extends RefCounted:
	var catalog:=FakeCatalog.new()

class FakeBase extends RefCounted:
	func source_class_id(_job: String) -> int:
		return 0

class FakeConversion extends RefCounted:
	var problem: String=""

class FakeWorld extends Node:
	var original_skills:=FakeSkills.new()
	var BASE508:=FakeBase.new()
	var skill_cooldowns: Dictionary={}
	var inventory: Dictionary={"정령옥":7}
	var spell_group_conversion:=FakeConversion.new()

class FakeHud extends Node:
	var character_state: Dictionary={"job_class":"요정"}
	var job_skills: Array=[]
	var routed: Array[String]=[]
	var messages: Array[String]=[]
	func _navigate(section: String) -> void:
		routed.append(section)
	func show_message(text: String) -> void:
		messages.append(text)
	func open_skills_workspace(_focus: String="") -> void:
		pass

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("ORIGINAL_UI_SKILL_WINDOW_TABS_FAIL: ",label)

func _initialize() -> void:
	_run.call_deferred()

static func _records(count: int) -> Array:
	var rows: Array=[]
	for index: int in range(count):
		rows.append({"id":"s%03d" % index,"name":"스킬%03d" % index,"class":"요정","classes":["요정"],"grade":"일반"})
	rows.append({"id":"water1","name":"물 정령","class":"요정","classes":["요정"],"grade":"고급","school":"water","items":{"정령옥":2}})
	rows.append({"id":"card1","name":"[신화] 카드 스킬","class":"요정","classes":["요정"],"grade":"신화","approx_required_card":11152})
	rows.append({"id":"eqspell523_1","name":"장비 스킬 (장비)","class":"장비","classes":["요정"],"grade":"일반","equipment_spell523":1})
	return rows

func _host() -> Dictionary:
	var world:=FakeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	hud.job_skills=_records(200)
	return {"world":world,"hud":hud}

func _run() -> void:
	var text: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_skill_window.gd")
	check(not text.contains("MAX_SLOTS") and not text.contains("list.resize("),"no fixed 160-skill cap (C05): rows are virtualized")
	check(SKILL.tabs_for("요정")==["all","spirit","myth","equip"] and SKILL.tabs_for("기사")==["all","myth","equip"],"정령 is the 요정's tab; 전체 / 특수 / 착용 for every job")
	check(SKILL.group_button("요정")=="Btn_Property" and SKILL.group_button("마법사")=="Btn_MagicMaster" and SKILL.group_button("기사")=="","속성 변경 for 요정, 디버프 for 마법사")
	var rows: Array=_records(0)
	check(SKILL.in_tab(rows[0],"spirit") and not SKILL.in_tab(rows[1],"spirit") and SKILL.in_tab(rows[1],"myth") and SKILL.in_tab(rows[2],"equip") and not SKILL.in_tab(rows[0],"equip"),"tab membership: school / LimitBuffCardID / EquipSpellClassID")
	check(SKILL.cooldown_text(0.0)=="" and SKILL.cooldown_text(3.24)=="3.2" and SKILL.cooldown_text(42.1)=="43","cooldown label text")
	var host: Dictionary=_host()
	var window=SKILL.new()
	window._hud=weakref(host.hud)
	check(window._skills(host.hud).size()==203,"전체 lists all 203 skills (over 160)")
	window.tab="spirit"
	check(window._skills(host.hud).map(func(r: Dictionary) -> String: return str(r.id))==["water1"],"정령 lists the elemental school skill")
	window.tab="all"
	check(window.uses_of(rows[0])==3 and window.uses_of({"name":"x"})==-1,"the count is how many casts the bag's materials allow")
	host.world.skill_cooldowns["물 정령"]=2.5
	check(is_equal_approx(window.cooldown_of(rows[0]),2.5),"the cooldown follows world.skill_cooldowns")
	check(window._skill_cards_requested().get("routed","")=="skill_card523" and host.hud.routed==["skill_card523"],"스킬 카드 opens the 스킬 카드 window")
	check(window._group_requested().get("routed","")=="spell_groups","속성 변경 opens the 스킬 계열 전환 screen")
	host.world.spell_group_conversion.problem="원본 없음"
	var refused: Dictionary=window._group_requested()
	check(not refused.get("ok",true) and host.hud.messages==["원본 없음"],"계열 전환 unavailable: its reason is shown")
	host.world.queue_free()
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_SKILL_WINDOW_TABS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host: Dictionary=_host()
	host.world.skill_cooldowns["스킬000"]=5.0
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=SKILL.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent)
	check(opened.get("handled",false) and int(opened.skills)==203 and int(opened.tab_scenes)==4 and str(opened.group_button)=="","Skill_All mounts 203 skills and the four 요정 tabs, 속성 변경 hidden (스킬 계열 전환 retired 2026-11-21): "+str(opened).left(300))
	check(int(opened.built_slots)<60,"only the rows near the view are built: "+str(opened.built_slots))
	var first: Dictionary=window._slots.get(0,{})
	check(first.has("cooldown") and str(first.cooldown.text)=="5.0","a cooling skill shows its Label_CoolTime")
	host.world.skill_cooldowns["스킬000"]=0.0
	check(window.refresh_times()>=1 and str(window._slots[0].cooldown.text)=="","the cooldown label clears when ready")
	# Scroll to the bottom: the last skill exists and can be selected.
	var drag:=InputEventScreenDrag.new()
	drag.relative=Vector2(0.0,-100000.0)
	window._list_input(drag)
	check(window._slots.has(202),"the last (203rd) skill is built after scrolling")
	window._moved=0.0
	window._slot_pressed(str(window._records[202].id))
	check(window.selected()==str(window._records[202].id),"the last skill is selectable")
	for name: String in ["spirit","myth","equip"]:
		var shown: Dictionary=window._tab_requested(name)
		check(shown.get("handled",false) and int(shown.skills)==1 and str(shown.tab)==name,name+" tab lists its one skill: "+str(shown).left(200))
	var equip_slot: Dictionary=window._slots.get(0,{})
	check(not equip_slot.is_empty(),"the 착용 skill slot is built")
	host.hud.job_skills=_records(3).filter(func(r: Dictionary) -> bool: return not r.has("equipment_spell523"))
	var empty: Dictionary=window._stage()
	check(empty.get("handled",false) and int(empty.skills)==0,"착용 with no equipment skill mounts empty with its notice")
	host.hud.character_state.job_class="기사"
	var knight: Dictionary=window._stage()
	check(knight.get("handled",false) and str(knight.tab)=="equip" and int(knight.tab_scenes)==3 and str(knight.group_button)=="","기사: three tabs, no 계열 button")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
