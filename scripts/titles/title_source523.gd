extends RefCounted
## Reads an owner-held source ZIP. No source tables or original art are embedded.
const SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const INSTALLED = "user://title523/source.zip"
var stages: Array[Dictionary] = []
var quests: Dictionary = {}
var trial_npcs: Dictionary = {}
var result_messages: Dictionary = {}
var letters: Array[Dictionary]=[]
var upgrade_descriptions: Array[Dictionary]=[]
var personal: Dictionary = {}:
	set(value):
		personal = value.duplicate(true)
		# Preserve the consumer shape while ignoring legacy cached word lists.
		personal["banned_word_filter_enabled"] = false
		personal["banned_types"] = []
		personal["selected_banned_types"] = []
		personal["banned_counts"] = {}
		personal["banned_words"] = []
var effects: Dictionary = {}
var powder_record: Dictionary = {}
var powder_drop_rows: Array[Dictionary] = []
var powder_npcs: Dictionary = {}
var minimum_level: int = 85
var daily_limit: int = 10
var input_selected: bool = false
var problem: String = "작위 원본을 설치해 주세요."

static func rows(zip: ZIPReader, name: String) -> Array:
	var parser := JSON.new()
	if parser.parse(zip.read_file("content/"+name+".json").get_string_from_utf8()) != OK: return []
	if not parser.data is Dictionary or not parser.data.get("rows") is Array: return []
	return parser.data.rows

const COMMON = preload("res://scripts/resources/current523_definition_rows.gd")
var _shared: bool = false
## index() of a table, or (shared) its name for _at()/_get_or() lookups.
func _index_of(zip: ZIPReader, name: String) -> Variant:
	return name if _shared else index(rows(zip,name))

## index()[id] (the last row with that ID).
static func _at(table: Variant, id: int) -> Dictionary:
	if table is Dictionary: return table[id]
	var matches: Array[Dictionary] = COMMON.related(str(table),"ID",id)
	return matches[-1] if not matches.is_empty() else {}

static func _get_or(table: Variant, id: int) -> Dictionary:
	if table is Dictionary: return table.get(id,{})
	return _at(table,id)

static func index(values: Array, key: String = "ID") -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in values: result[int(row[key])] = row
	return result

static func sequence(definitions: Dictionary, links: Array, previous: String, following: String) -> Array[int]:
	var edges: Dictionary = {}
	var incoming: Dictionary = {}
	for link: Dictionary in links:
		var a := int(link[previous]); var b := int(link[following])
		if not definitions.has(a) or not definitions.has(b) or edges.has(a) or incoming.has(b): return []
		edges[a] = b; incoming[b] = true
	var starts: Array = []
	for id: int in definitions:
		if not incoming.has(id): starts.append(id)
	if starts.size() != 1: return []
	var result: Array[int] = []
	var current: int = starts[0]
	while not result.has(current):
		result.append(current)
		if not edges.has(current): break
		current = edges[current]
	return result if result.size() == definitions.size() else []

func load_zip(path: String) -> String:
	# Remember an attempted explicit input even when its existing guards reject it.
	input_selected = true
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SHA: return "작위 원본523 SHA 불일치·누락"
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return "작위 원본 ZIP 열기 실패"
	# Same verified bytes as the common reader: its large tables are looked up
	# there instead of parsed and indexed whole again.
	_shared = COMMON.identity().get("source_sha256") == SHA
	var subs := index(rows(zip,"SubTitle"))
	var mains := index(rows(zip,"MainTitle"))
	var order := sequence(subs,rows(zip,"SubTitleSequence"),"PrevSubTitleID","NextSubTitleID")
	if order.size() != 25 or sequence(mains,rows(zip,"MainTitleSequence"),"PrevMainTitleID","NextMainTitleID").size() != 6:
		zip.close(); return "작위 연결표 오류"
	var descriptions: Variant = _index_of(zip,"DescData_Korean")
	var letter_rows: Array[Dictionary]=[]
	var upgrade_rows: Array[Dictionary]=[]
	for row: Dictionary in rows(zip,"TitleLetterMessage"):
		var entry:=row.duplicate(true); entry.text=str(_at(descriptions,int(row.DescID)).Description); letter_rows.append(entry)
	for row: Dictionary in rows(zip,"TitleUpgradeDesc"):
		var entry:=row.duplicate(true); entry.text=str(_at(descriptions,int(row.DescID)).Description); upgrade_rows.append(entry)
	var personal_data: Dictionary={"title_limit":0,"max_names":0,"activation_delay_raw":0,"colors":[]}
	var color_table:=index(rows(zip,"ColorTable"))
	var appellations:=index(rows(zip,"Appellation"))
	var title_displays:=index(rows(zip,"AppellationTitle"))
	for row: Dictionary in rows(zip,"PersonalAppellationColor"):
		var color: Dictionary=color_table[int(row.ColorID)]
		if int(color.Type)!=1 or str(color.Value).length()!=6 or not Color.html_is_valid("#"+str(color.Value)):
			zip.close(); return "개인 호칭 색상 원문 오류"
		personal_data.colors.append({"id":int(row.ID),"color_table_id":int(row.ColorID),"stage":int(row.PrerequisiteSubTitleID),"hex":str(color.Value)})
	var messages: Dictionary={}
	for row: Dictionary in rows(zip,"TitleResultMessage"):
		var stage_id:=int(row.SubTitleID)
		if not messages.has(stage_id): messages[stage_id]={}
		messages[stage_id][int(row.ResultType)]=str(_at(descriptions,int(row.DescID)).Description)
	var item: Dictionary=_at(_index_of(zip,"ItemClass"),117544)
	var category: Dictionary=index(rows(zip,"ItemCategory"))[int(item.CategoryID)]
	var powder_name:=str(_at(descriptions,int(item.IdentifiedDescID)).Description)
	var material: Dictionary={"name":powder_name+" · 원본#117544","source_display_name":powder_name,"source":"lineagem_patch523","source_snapshot":"patch523","source_item_class_id":117544,"sourceId":"m523:item:117544","source_m_native_item":true,"source_category_name":str(category.Name),"source_bless_raw":1,"source_test_item":bool(item.TestItem),"source_is_stackable":bool(category.IsStackable),"slot":"material","type":"재료","grade":"일반","crafting_material":true,"droppable":bool(item.IsDroppable),"storable":bool(item.IsStorable),"tradable":bool(item.IsTradable),"source_weight":int(item.Weight),"source_item_row":item.duplicate(true)}
	var supplier_rows: Array[Dictionary]=[]
	var supplier_npcs: Dictionary={}
	var npcs: Variant=_index_of(zip,"NpcClass")
	for drop: Dictionary in (COMMON.rows_matching("NpcItemDropView","ItemClassID",{117544:true}) if _shared else rows(zip,"NpcItemDropView")):
		if int(drop.ItemClassID)!=117544: continue
		supplier_rows.append(drop.duplicate(true))
		if int(drop.RequiredQuestID)==0 and int(drop.Bless)==1:
			supplier_npcs[int(drop.NpcClassID)]=_at(npcs,int(drop.NpcClassID)).duplicate(true)
	var donations := index(rows(zip,"SubTitleDonation"),"SubTitleID")
	var rates := index(rows(zip,"SubTitleDonationProbability"),"SubTitleDonationID")
	var bonuses: Variant = _index_of(zip,"Bonus")
	var types := index(rows(zip,"BonusType"))
	var resistance_types:=index(rows(zip,"SpecialResistanceType"))
	var units := index(rows(zip,"UIUnit"),"UnitID")
	var selected_effects: Dictionary = {}
	var main_links := rows(zip,"MainTitleBonus")
	var sub_links := rows(zip,"SubTitleBonus")
	for link: Dictionary in main_links + sub_links:
		var bonus: Dictionary = _at(bonuses,int(link.BonusID)).duplicate(true)
		var type: Dictionary = types[int(bonus.BonusTypeID)]
		bonus["type"] = str(type.Name)
		bonus["label"] = str(_get_or(descriptions,int(type.DescID)).get("Description",type.Name))
		if int(bonus.BonusApplicationTypeID)==2:
			var resistance: Dictionary=resistance_types.get(int(bonus.BonusApplicationTargetID),{})
			bonus.label=str(bonus.label).replace("{0}",str(_get_or(descriptions,int(resistance.get("DescID",0))).get("Description","스턴")))
		bonus["denominator"] = maxi(1,int(units.get(int(type.UnitID),{}).get("Denominator",0)))
		bonus["value"] = float(bonus.Value) / float(bonus.denominator)
		if bonus.type == "ArmorClass": bonus.value = -bonus.value
		selected_effects[int(bonus.ID)] = bonus
	var staged: Array[Dictionary] = []
	for id: int in order:
		var sub: Dictionary = subs[id]
		var donation: Dictionary = donations[id]
		if int(donation.CurrencyID) != 1682: zip.close(); return "기부 통화 변경"
		var appellation: Dictionary=appellations[int(sub.AppellationID)]
		var title_display: Dictionary=title_displays[int(appellation.TitleID)]
		var title_color: Dictionary=color_table[int(title_display.ColorTableID)]
		var entry := {"id":id,"main":int(sub.MainTitleID),"name":str(_at(descriptions,int(sub.DescID)).Description),"quest_amount_raw":int(sub.QuestAmount),"cost":int(donation.Cost),"probability_raw":int(rates[int(donation.ID)].Probability),"main_effects":[],"sub_effects":[],"quests":[],"display_name":str(_at(descriptions,int(title_display.DescID)).Description),"display_color":str(title_color.Value).trim_prefix("#"),"appellation":appellation.duplicate(true),"title_display":title_display.duplicate(true)}
		for link: Dictionary in main_links:
			if int(link.MainTitleID) == entry.main: entry.main_effects.append(int(link.BonusID))
		for link: Dictionary in sub_links:
			if int(link.SubTitleID) == id: entry.sub_effects.append(int(link.BonusID))
		staged.append(entry)
	var views := index(rows(zip,"QuestView"))
	var date_definitions:=index(rows(zip,"DateTimes_Korean"))
	var server_definitions: Dictionary={}
	for server: Dictionary in rows(zip,"ServerLimit"):
		var set_id:=int(server.ServerLimitSetID)
		if not server_definitions.has(set_id): server_definitions[set_id]=[]
		server_definitions[set_id].append(server.duplicate(true))
	var goals := index(rows(zip,"Goal"))
	var links := index(rows(zip,"QuestGoal"),"QuestID")
	var groups: Dictionary = {}
	for member: Dictionary in rows(zip,"NpcClassForNpcGroup"):
		var group := int(member.NpcGroupID)
		if not groups.has(group): groups[group] = []
		groups[group].append(int(member.NpcClassID))
	var selected_quests: Dictionary = {}
	var selected_trial_npcs: Dictionary = {}
	var prerequisites := index(rows(zip,"Prerequisite"))
	var prerequisite_links := index(rows(zip,"QuestPrerequisite"),"QuestID")
	for link: Dictionary in rows(zip,"SubTitleQuest"):
		var id := int(link.QuestID)
		var view: Dictionary = views[id]
		var goal: Dictionary = goals[int(links[id].GoalID)]
		var kind := int(goal.GoalTypeID)
		var prerequisite: Dictionary = prerequisites[int(prerequisite_links[id].PrerequisiteID)]
		if int(prerequisite.PrerequisiteTypeID) != 1 or int(prerequisite.Value) != 85: zip.close(); return "작위 수락 조건 변경"
		if kind not in [261,574] or not bool(view.CannotReveal) or int(view.LimitHours) != 24: zip.close(); return "심사 목표 계약 변경"
		var targets: Array = [int(goal.GoalClassID)] if kind == 261 else groups[int(goal.GoalClassID)].duplicate()
		for target: int in targets: selected_trial_npcs[target]=_at(npcs,target).duplicate(true)
		selected_quests[id] = {"id":id,"stage":int(link.SubTitleID),"name":str(_at(descriptions,int(view.TitleDescID)).Description),"description":str(_at(descriptions,int(goal.DescID)).Description),"goal_type":kind,"amount":int(goal.Amount),"targets":targets,"limit_seconds":int(view.LimitHours)*3600,"source_quest_row":view.duplicate(true),"calendar_start":date_definitions[int(view.StartTime)].duplicate(true),"calendar_end":date_definitions[int(view.EndTime)].duplicate(true),"server_limit_set":int(view.ServerLimitSetID),"server_memberships":server_definitions.get(int(view.ServerLimitSetID),[]).duplicate(true)}
		for stage: Dictionary in staged:
			if stage.id == int(link.SubTitleID): stage.quests.append(id)
	var currency := index(rows(zip,"CurrencyUnitClass"))
	# The exact source is immutable; still check the resource relationship.
	var currency_ok := false
	for row: Dictionary in currency.values():
		if int(row.get("CurrencyID",-1)) == 1682 and int(row.get("UnitID",-1)) == 4 and int(row.get("ClassID",-1)) == 117544: currency_ok = true
	if selected_quests.size() != 128 or selected_effects.size() != 41 or not currency_ok: zip.close(); return "작위 원본 연결 수 불일치"
	for constant: Dictionary in rows(zip,"ConstantData"):
		if constant.Name == "TitleLevelLimit": minimum_level = int(constant.Value)
		if constant.Name == "TitleUpgradeByQuestPerDay": daily_limit = int(constant.Value)
		if constant.Name == "PersonalAppellationTitleLimit": personal_data.title_limit=int(constant.Value)
		if constant.Name == "PersonalAppellationMaxCount": personal_data.max_names=int(constant.Value)
		if constant.Name == "PersonalAppellationActivationDelay": personal_data.activation_delay_raw=int(constant.Value)
	if personal_data.title_limit!=278 or personal_data.max_names!=5 or personal_data.colors.size()!=8:
		zip.close(); return "개인 호칭 조건 원문 오류"
	zip.close()
	stages = staged; quests = selected_quests; effects = selected_effects; problem = ""
	powder_record=material; powder_drop_rows=supplier_rows; powder_npcs=supplier_npcs
	trial_npcs=selected_trial_npcs
	result_messages=messages
	letters=letter_rows; upgrade_descriptions=upgrade_rows
	personal=personal_data
	return ""

func result_text(stage_id: int, success: bool, variant: int) -> String:
	var stage: Dictionary={}
	for candidate: Dictionary in stages:
		if int(candidate.id)==stage_id: stage=candidate; break
	if stage.is_empty(): return ""
	var kind:=1 if success else 0
	var message:=str(result_messages.get(stage_id,{}).get(kind,"")).replace("{0}",str(stage.name))
	var letter_options: Array[Dictionary]=[]
	var upgrade_options: Array[Dictionary]=[]
	for row: Dictionary in letters:
		if int(row.ResultType)==kind: letter_options.append(row)
	for row: Dictionary in upgrade_descriptions:
		if int(row.MainTitleID)==int(stage.main) and int(row.Result)==kind: upgrade_options.append(row)
	# Pure display policy: rotate variants independently of gameplay RNG.
	# MessageProb is retained in the source row, never a success probability.
	if not letter_options.is_empty(): message=str(letter_options[posmod(variant,letter_options.size())].text).replace("{0}","모험가")+"\n"+message
	if not upgrade_options.is_empty(): message+="\n"+str(upgrade_options[posmod(variant,upgrade_options.size())].text).replace("{0}",str(stage.name))
	return message

func install(path: String) -> String:
	var candidate = get_script().new()
	var error: String = candidate.load_zip(path)
	if not error.is_empty(): return error
	var destination := ProjectSettings.globalize_path(INSTALLED)
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK: return "작위 원본 폴더 생성 실패"
	if DirAccess.copy_absolute(path,destination+".tmp") != OK: return "작위 원본 설치 실패"
	if FileAccess.get_sha256(destination+".tmp") != SHA: return "작위 원본 복사 검증 실패"
	if DirAccess.rename_absolute(destination+".tmp",destination) != OK: return "작위 원본 보존 실패"
	return load_zip(destination)
