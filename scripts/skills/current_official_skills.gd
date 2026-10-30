extends RefCounted
## Current official supplement. Reference IDs cannot enter legacy combat defaults.
var records: Array[Dictionary] = []
var index: Dictionary = {}
var mode_audit: Dictionary = {}
var local_design: Dictionary = {}

func _init() -> void:
	local_design = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/local_design_missing12.json"))
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/current_official_specs.json"))
	var visual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/current_official_visuals.json"))
	for row: Dictionary in document.get("records", []):
		var spec: Dictionary = row.current_official
		var current_name := str(row.name)
		var id := "lmref_" + (str(row["class"]) + ":" + current_name).sha256_text().substr(0, 16)
		var mode := str(spec.get("mode", "unknown"))
		var activation := str(spec.get("activation", "unknown"))
		var toggle := mode == "toggle_proc"
		if toggle: activation = "toggle"
		elif mode in ["passive", "upgrade_passive", "on_attack_proc", "counter_proc"]: activation = "passive"
		var grade: Variant = spec.get("grade", row.get("grade"))
		var record: Dictionary = {"id":id,"name":current_name,"class":row["class"],"classes":[row["class"]],
			"grade":"미확인" if grade == null else str(grade),"activation":activation,"mode":"official_pending",
			"origin":"OFFICIAL_REFERENCE_20261029","runtime_blocked":true,"official_mode":mode,"toggle_classified":toggle,
			"minimum_level":spec.get("learning_level",spec.get("minimum_level")),"mp":spec.get("mp_cost",spec.get("mp")),
			"hp":spec.get("hp_cost",spec.get("hp")),"cooldown":spec.get("cooldown_seconds"),
			"duration":spec.get("duration_seconds",spec.get("duration")),"book_cost":null,"book_name":null,
			"historical_aliases":row.get("historical_aliases",[]),"official":spec.duplicate(true),"historical":row.historical.duplicate(true),
			"icon":str(visual.get("icons",{}).get(current_name,"")),"desc":str(spec.get("effect_summary",row.historical.get("effect_summary","")))}
		var design: Dictionary = local_design.get("records",{}).get(id,{})
		if not design.is_empty():
			record.merge(design.runtime.duplicate(true),true)
			record["design_provenance"] = design.fields.duplicate(true)
			record["implementation"] = "TWILIGHT_LOCAL_DESIGN"
		records.append(record)
		index[id] = record
		index[current_name] = record
		for alias: String in record.historical_aliases: index[alias] = record
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/current_mode_audit.json"))
	for issue: Dictionary in audit.get("official_other_issues", []): mode_audit[str(issue.our_id)] = issue

func record_for(key: String) -> Dictionary:
	return index.get(key, {})

static func mode_label(row: Dictionary) -> String:
	if bool(row.get("toggle_classified", false)):
		return "ON/OFF 패시브" if str(row.name) == "슈팅 스타" else "ON/OFF 토글"
	if str(row.activation) == "passive": return "패시브"
	if str(row.activation) == "mixed_active_passive": return "액티브 + 패시브"
	return "액티브" if str(row.activation) == "active" else "운용 방식 미확인"

static func value_text(value: Variant, suffix: String = "") -> String:
	return "미확인" if value == null else str(value) + suffix

static func blocked_reason(row: Dictionary) -> String:
	var missing := PackedStringArray(["습득 스킬북·입수/가격"])
	if row.cooldown == null and str(row.activation) != "passive": missing.append("재사용 시간")
	match str(row.name):
		"슈팅 스타": missing.append("분열 피해·발동 확률·MP 차감 시점")
		"아쿠아 애로우": missing.append("치유량·시전 방식·아군 PC 대상 연결")
		"엘리멘탈 가디언": missing.append("소환체 능력·정령 마법 계수")
		"엘리멘탈 웨폰": missing.append("방어 무시·근거리 효과 계수")
		"엘븐 윙 슈즈": missing.append("대시·윙 실드 조건/수치")
		"아쿠아 프리즌": missing.append("발동 확률·제어 지속·회피 감소 수치")
		"아쿠아 프리즌(스피릿)": missing.append("기본 스킬·강화 계수·HP 흡수량")
		"리포스트": missing.append("응수 확률·피해 경감/반격 계수")
		"프라이드": missing.append("이동/공격속도 증가·회피 무시 수치")
		"디그니티": missing.append("더블 스탭 확률·피해 계수")
		"블러디 크로우": missing.append("발동 확률·범위 피해·흡수량")
		"버서커스": missing.append("명중·피해·AC·INT 비례 계수")
	return "실행 보류: " + " / ".join(missing)

static func detail_text(row: Dictionary) -> String:
	var spec: Dictionary = row.official
	var material: Variant = spec.get("materials",spec.get("material"))
	var material_text := "미확인"
	if material is Array:
		var parts := PackedStringArray()
		for item: Dictionary in material: parts.append(str(item.name) + " " + str(item.count) + "개")
		material_text = " · ".join(parts)
	elif material != null: material_text = str(material)
	if spec.has("on_proc_materials"):
		material_text += "\n발동 재료: "
		for item: Dictionary in spec.on_proc_materials: material_text += str(item.name) + " " + str(item.count) + "개 "
	var aliases: Array = row.historical_aliases
	var duration: String = value_text(row.duration, "초") if row.duration is int or row.duration is float else value_text(row.duration)
	var weapons: Variant = spec.get("weapon_requirements")
	var weapon_text := "미확인" if weapons == null else " · ".join(weapons)
	var prerequisite := str(spec.get("requires_skill", "미확인"))
	return ("[font_size=20]%s[/font_size]\n%s · %s · %s\n2026 현재 공식 자료 · 실행 보류\n%s\n\n습득 레벨 %s\nMP %s / HP %s\n재료 %s\n지속 %s / 재사용 %s\n대상 %s\n이전 명칭 %s\n\n%s\n\n공식 출처: %s" % [str(row.name),str(row["class"]),str(row.grade) + (" (TWILIGHT)" if row.get("design_provenance",{}).get("grade",{}).get("status","")=="local_design" else ""),mode_label(row),str(row.desc),value_text(row.minimum_level),value_text(row.mp),value_text(row.hp),material_text,duration,value_text(row.cooldown,"초"),str(spec.get("target","미확인"))," · ".join(aliases) if not aliases.is_empty() else "없음",blocked_reason(row),str(spec.get("source_url",""))]) + "\n사용 무기 " + weapon_text + "\n선행 스킬 " + prerequisite

static func runtime_text(row: Dictionary) -> String:
	var source: Dictionary = row.official
	var official_mp: Variant = source.get("mp_cost",source.get("mp"))
	var official_duration: Variant = source.get("duration_seconds",source.get("duration"))
	var text := "[font_size=20]%s[/font_size]\n%s · %s · %s\n%s\n\n공식 공개: Lv.%s / MP %s / 지속 %s\n공식 대상: %s\n\nTWILIGHT 설계 · 원작 수치 아님\n" % [str(row.name),str(row["class"]),str(row.grade) + (" (TWILIGHT)" if row.get("design_provenance",{}).get("grade",{}).get("status","")=="local_design" else ""),mode_label(row),str(row.desc),value_text(row.minimum_level),value_text(official_mp),value_text(official_duration),str(source.get("target","미확인"))]
	var labels := {"cooldown":"재사용(초)","book_cost":"스킬북(아데나)","proc_chance":"발동 확률","proc_cooldown":"발동 간격(초)","power":"추가 피해","heal":"치유량","stats":"버프","passive_stats":"패시브","proc_mp":"발동 MP","wing_reduction":"윙 실드 경감","dash_distance":"대시 거리"}
	for key: String in labels:
		if row.has(key):
			var value: Variant = row[key]
			if key=="proc_chance": value = "%.0f%%" % (float(value)*100)
			elif value is Dictionary:
				var names := {"attackSpeed":"공격속도(%)","meleeHit":"근거리 명중","rangedHit":"원거리 명중","meleeDamage":"근거리 피해","def":"방어","speed":"이동 배율","attackRangeCells":"사거리(칸)"}
				var parts := PackedStringArray()
				for stat: String in value: parts.append(str(names.get(stat,stat))+" "+str(value[stat]))
				value = " · ".join(parts) if not parts.is_empty() else "해당 없음"
			text += str(labels[key])+": "+str(value)+"\n"
	for phase: String in ["items","proc_items"]:
		var materials := PackedStringArray()
		for item: String in row.get(phase,{}): materials.append(item+" "+str(row[phase][item])+"개")
		text += ("시전 재료: " if phase=="items" else "\n발동 재료: ") + (" · ".join(materials) if not materials.is_empty() else "없음 (TWILIGHT)")
	if str(row.mode)=="local_toggle":text += "\n토글 ON/발동 비용 시점은 TWILIGHT 설정"
	text += "\n무기: "+str(row.get("weapons",[]))+"\n이전 명칭: "+str(row.historical_aliases)
	return text
