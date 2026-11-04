extends VBoxContainer
## Map-screen inspection of source definitions and actual host generation state.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
const HOST_PORTALS = preload("res://scripts/maps/host_portal_navigation.gd")
const PORTAL_SOURCE = preload("res://scripts/maps/patch523_portal_source_evidence.gd")
const ARRIVAL = preload("res://scripts/maps/patch523_portal_arrival.gd")
var portal_source = PORTAL_SOURCE.new()
var inspect_arrival: Button
var last_arrival_check: Dictionary = {}
var world: Node
var links: RefCounted
var summary: Label
var mode: OptionButton
var search: LineEdit
var rows: ItemList
var detail: RichTextLabel
var action: Button
var navigate: Button
var entries: Array = []
var visible_entries: Array = []

static func open(hud: Node) -> void:
	hud._open_window("map_links", "포탈·출현 정보", "현재 게임 상태와 원본 자료를 확인합니다.")
	var panel = load("res://scripts/ui/patch523_world_panel.gd").new()
	panel.name = "WorldLinksPanel"
	hud.workspace.column().add_child(panel)
	panel.configure(hud.get_parent())

func configure(controller: Node) -> void:
	world = controller
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary = UI.label("", 14)
	summary.name = "LinkSummary"
	add_child(summary)
	var tools := HBoxContainer.new()
	add_child(tools)
	mode = OptionButton.new()
	mode.name = "LinkMode"
	for title: String in ["현재 게임의 생성 상태", "아덴 본토 · 출현 정의", "아덴 본토 · 포탈 정의", "현재 게임 이동석"]: mode.add_item(title)
	tools.add_child(mode)
	search = LineEdit.new()
	search.name = "LinkSearch"
	search.placeholder_text = "이름 또는 번호 검색"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(search)
	tools.add_child(UI.button("새로고침", refresh, Vector2(90,36)))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	rows = preload("res://scripts/ui/native_touch_list.gd").new()
	rows.name = "LinkRows"
	rows.custom_minimum_size = Vector2(300,280)
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(rows)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	detail = RichTextLabel.new()
	detail.name = "LinkDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size = Vector2(240,240)
	right.add_child(detail)
	action = UI.button("포탈 이동 보류", func() -> void: pass, Vector2(180,36))
	action.name = "SourcePortalTravel"
	action.disabled = true
	action.hide()
	right.add_child(action)
	inspect_arrival = UI.button("도착 계약 확인", check_arrival, Vector2(180,36))
	inspect_arrival.name = "InspectSourceArrival"
	inspect_arrival.hide()
	right.add_child(inspect_arrival)
	navigate = UI.button("이동석으로 이동", navigate_selected, Vector2(180,36))
	navigate.name = "NavigateHostPortal"
	navigate.hide()
	right.add_child(navigate)
	mode.item_selected.connect(func(_index: int) -> void: search.text = ""; refresh())
	search.text_changed.connect(func(_value: String) -> void: filter_rows())
	rows.item_selected.connect(show_entry)
	links = LINKS.new()
	var options: Dictionary = POLICY.settings()
	if options.enabled: links.load_land(str(options.root), 4, "Aden/", str(options.sha))
	var evidence_path: String = PORTAL_SOURCE.configured_path()
	if not evidence_path.is_empty(): portal_source.load_archive(evidence_path, links)
	mode.set_item_disabled(1, not links.loaded)
	mode.set_item_disabled(2, not links.loaded)
	refresh()

static func hold_text(reason: String) -> String:
	if reason == "patch523_is_spawn_0": return "원본 정의에서 생성 제외"
	if reason == "patch523_server_context_required": return "서버·서비스 지역 조건 확인 필요"
	if reason == "patch523_schedule_context_required": return "출현 기간·시간 조건 확인 필요"
	if reason == "patch523_original_pixels_not_ready": return "원본 몬스터 리소스 확인 필요"
	return "원본 연결 또는 조건 확인 필요"

static func targeting_text(category: Dictionary) -> String:
	if not category.get("IsAutoSelectable") is bool: return "자동 대상 선택 규칙 확인 필요"
	var text: String = "자동 대상 탐색 가능" if category.IsAutoSelectable else "자동 대상 탐색 제외"
	if category.get("IsSelectable") == true: text += " · 직접 선택 가능"
	elif category.get("IsSelectable") == false: text += " · 원본 직접 선택 제외"
	return text

func refresh() -> void:
	entries.clear()
	var active: String = str(world.active_map.get("name", world.active_map_id))
	summary.text = "현재 플레이 지역: %s\n" % active
	if links.loaded:
		summary.text += "아덴 본토 자료 · 포탈 %d · 출현 영역 연결 %d · 구성 확인 중 %d팩" % [links.shard.portals.size(), links.shard.spawn_relations.size(), links.shard.unresolved_class_view_packs.size()]
		if portal_source.loaded: summary.text += "\n원문 대조 50건 · 아덴 출발 %d건 · 이동 활성 근거 아님" % portal_source.aden_count()
		elif not portal_source.problem.is_empty(): summary.text += "\n원문 대조 자료 연결 보류: " + portal_source.problem
	else:
		summary.text += "원본 출현 자료를 사용할 수 없습니다. 자료 연결을 확인한 뒤 다시 실행하세요."
	if mode.selected == 0:
		for slot: Dictionary in world.field_population.slots:
			var actor: Variant = slot.get("monster")
			var title: String = " / ".join(slot.region.get("monster_types", []))
			var state: String = "대기"
			if slot.has("patch523_spawn_hold"): state = hold_text(str(slot.patch523_spawn_hold))
			elif is_instance_valid(actor): state = "생성됨" if not actor.dead else "재생성 대기"
			entries.append({"title": title + " · " + state, "kind": "live", "slot": slot})
	elif mode.selected == 1 and links.loaded:
		for entry: Dictionary in links.spawn_evidence():
			var title: String = "%s · 팩 %d" % [str(entry.territory.get("Name", "영역")), int(entry.relation.NpcSpawnPackID)]
			var query: String = title + " " + str(entry.territory.ID)
			for member: Dictionary in entry.classes: query += " " + str(member.npc_class.get("Name", "")) + " " + str(int(member.view.NpcClassID)) + " " + str(int(member.view.ID))
			entries.append({"title": title, "query": query, "kind": "spawn", "data": entry})
	elif mode.selected == 2 and links.loaded:
		for entry: Dictionary in links.portal_evidence():
			entries.append({"title": "포탈 %d → %s [%d]" % [int(entry.portal.ID), str(entry.target_land.get("Name", "목적 지역")), int(entry.target_land.ID)], "kind": "portal", "data": entry})
	elif mode.selected == 3 and world.field_map != null:
		for portal: Dictionary in world.field_map.data.get("portal", []):
			var target_id: String = world.NATIVE_PNG.canonical(str(portal.get("target_map", "")))
			var target: Dictionary = world.maps_by_id.get(target_id, {})
			entries.append({"title": "%s → %s" % [str(portal.get("name", portal.get("id", "이동석"))), str(target.get("name", target_id))], "kind": "host_portal", "receipt": HOST_PORTALS.capture(world, portal)})
	filter_rows()

func filter_rows() -> void:
	rows.clear(); visible_entries.clear()
	for entry: Dictionary in entries:
		if not search.text.is_empty() and not str(entry.get("query", entry.title)).containsn(search.text): continue
		visible_entries.append(entry)
		rows.add_item(str(entry.title))
	if not visible_entries.is_empty(): rows.select(0); show_entry(0)
	else:
		detail.text = "표시할 항목이 없습니다. 검색어 또는 현재 생성 상태를 확인하세요."
		action.hide()
		navigate.hide()
		inspect_arrival.hide()

func show_entry(index: int) -> void:
	if index < 0 or index >= visible_entries.size(): return
	var entry: Dictionary = visible_entries[index]
	var lines: Array[String] = [str(entry.title), ""]
	action.hide()
	navigate.hide()
	inspect_arrival.hide()
	last_arrival_check.clear()
	if entry.kind == "live":
		var slot: Dictionary = entry.slot
		lines.append("현재 게임에 이미 설정된 사냥터입니다.")
		lines.append("해당 영역의 설정 수량: %d" % int(slot.region.get("max_count", 0)))
		lines.append("위치·수량·재생성 주기는 기존 게임 설정을 유지합니다.")
		if slot.has("patch523_spawn_hold"): lines.append("생성 보류: " + hold_text(str(slot.patch523_spawn_hold)))
		var actor: Variant = slot.get("monster")
		if is_instance_valid(actor) and not actor.source_targeting.is_empty(): lines.append(targeting_text(actor.source_targeting))
		if is_instance_valid(actor) and not actor.get_meta("patch523_spawn_admission", {}).is_empty():
			lines.append("이 개체는 누적523의 명시적 출현 정의 검사를 통과했습니다.")
		else: lines.append("기존 게임 개체입니다. 리니지M 원본 배치로 판정하지 않습니다.")
	elif entry.kind == "spawn":
		var data: Dictionary = entry.data
		lines.append("원본 영역: (%d, %d) ~ (%d, %d)" % [int(data.territory.StartX), int(data.territory.StartY), int(data.territory.EndX), int(data.territory.EndY)])
		if data.classes.is_empty(): lines.append("이 팩의 몬스터 구성은 아직 연결되지 않았습니다.")
		for member: Dictionary in data.classes:
			var view: Dictionary = member.view
			var state: String = "출현 후보 · 실제 활성 미확인"
			if member.definition_state == "EXPLICIT_IS_SPAWN_0": state = "원본 정의에서 생성 제외"
			elif member.definition_state != "DEFINED_IS_SPAWN_1_ACTIVATION_UNKNOWN": state = "조건 확인 필요"
			lines.append("%s [NPC %d] · 레벨 %s\n%s · 서버 조건 %s" % [str(member.npc_class.get("Name", "NPC")), int(view.NpcClassID), str(view.NpcLevel), state, str(view.ServerLimitSetID)])
			for category: Dictionary in links.context_rows("NpcCategory"):
				if category.ID == member.npc_class.get("Category"): lines.append(targeting_text(category)); break
		var conditions: Dictionary = links.pack_conditions(int(data.relation.NpcSpawnPackID))
		if not conditions.NpcSpawnPackSchedulePeriod.is_empty() or not conditions.DaynightSpawnPack.is_empty() or not conditions.WorldBossRaidView.is_empty(): lines.append("기간·주야·보스 일정 조건이 있어 자동 생성을 보류합니다.")
		lines.append("\n이 영역을 생성 개체 수나 확정된 개별 위치로 사용하지 않습니다.")
	elif entry.kind == "host_portal":
		var state: Dictionary = HOST_PORTALS.inspect(world, entry.receipt)
		lines.append("현재 게임에 이미 연결된 이동석입니다.")
		lines.append("기존 통행 격자로 걸어가며, 도착하면 기존 포탈 규칙이 적용됩니다.")
		lines.append("리니지M 원본 포탈과 같은 연결이라고 추정하지 않습니다.")
		lines.append("\n" + str(state.reason))
		navigate.disabled = not state.ok
		navigate.show()
	else:
		var data: Dictionary = entry.data
		var target: Dictionary = data.target_territory
		lines.append("도착 지역: %s [지역 %d] · 영역 %d" % [str(data.target_land.get("Name", "지역")), int(data.target_land.ID), int(target.ID)])
		lines.append("원본 출발: (%d, %d)" % [int(data.portal.SourceX), int(data.portal.SourceY)])
		lines.append("원본 도착 영역: (%d, %d) ~ (%d, %d)" % [int(target.StartX), int(target.StartY), int(target.EndX), int(target.EndY)])
		lines.append_array(PORTAL_SOURCE.display_lines(portal_source.for_portal(int(data.portal.ID))))
		if data.arrival_selection == "EXACT_POINT": lines.append("원본 도착점은 확인됐지만, 포탈의 트리거·활성 조건이 미확인이라 이동을 보류합니다.")
		else: lines.append("도착 영역의 선택 규칙과 포탈의 트리거·활성 조건이 미확인이라 이동을 보류합니다.")
		lines.append("기존 게임의 이동석과 같은 경로라고 추정하지 않습니다.")
		action.show()
		inspect_arrival.show()
		action.tooltip_text = "원본 포탈의 트리거·활성 조건·도착 규칙 확인이 필요합니다."
	detail.text = "\n".join(lines)

func check_arrival() -> void:
	var selection: PackedInt32Array = rows.get_selected_items()
	if selection.is_empty() or selection[0] >= visible_entries.size(): return
	var entry: Dictionary = visible_entries[selection[0]]
	if entry.kind != "portal": return
	show_entry(selection[0])
	last_arrival_check = ARRIVAL.inspect(links, int(entry.data.portal.ID), world.field_map)
	var contract: Dictionary = last_arrival_check.contract
	if contract.is_empty(): return
	var context: Dictionary = contract.conditions
	var report: String = "도착 계약: %s\n도착 Land %d · AssetPath %s\n%s" % ["원본 명시점" if contract.arrival_kind == "EXACT_POINT" else "영역 · 선택 규칙 필요", int(contract.target_namespace.land_id), str(contract.target_namespace.asset_path), str(last_arrival_check.reason)]
	report += "\n도착 지역 속성 %d행 · 시간 제한 %d행 · 주간 연결 %d행" % [context.target_land_attributes.size(), context.land_time_limits.size(), context.land_weekly_links.size()]
	report += "\n별도 LandTeleport 경로 %d건 · 해당 비용·전제조건을 이 포탈에 적용하지 않습니다." % context.separate_land_teleport_routes.size()
	report += "\n포탈 비용·활성·트리거는 미확정입니다. 기존 PC 지형을 M 원본 좌표로 간주하지 않습니다."
	detail.text = report + "\n\n" + detail.text
	detail.scroll_to_line(0)

func navigate_selected() -> void:
	var selection: PackedInt32Array = rows.get_selected_items()
	if selection.is_empty() or selection[0] >= visible_entries.size(): return
	var entry: Dictionary = visible_entries[selection[0]]
	if entry.kind != "host_portal": return
	var result: Dictionary = HOST_PORTALS.walk_to(world, entry.receipt)
	world.hud.show_message(str(result.reason))
	if result.ok: world.hud._close_workspace()
	else:
		detail.text += "\n\n" + str(result.reason)
		navigate.disabled = true
