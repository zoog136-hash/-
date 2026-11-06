extends ScrollContainer
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var service
var column: VBoxContainer
var result: Label

func configure(value) -> void:
	service = value
	name = "Death523Recovery"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	refresh()

func label(text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(node)
	return node

func button(text: String, action: Callable, control_name: String) -> Button:
	var node := Button.new()
	node.text = text; node.name = control_name
	node.clip_text = true
	node.tooltip_text = text
	node.custom_minimum_size.y = 48
	column.add_child(node)
	node.pressed.connect(func() -> void:
		if service.world.hud.workspace.was_scroll_dragged(self): return
		action.call())
	service.world.hud.workspace.register_scroll_drag(self,node)
	return node

func _bind_item_icon(control: Button, source_id: String, role: String) -> void:
	control.icon = null
	for key: String in ["source523_image", "source523_image_provenance", "source523_image_status"]:
		if control.has_meta(key): control.remove_meta(key)
	if source_id.is_empty() or not source_id.is_valid_int() or not IMAGES.selected(): return
	# The loss receipt and certificate wallet preserve the ItemClass key
	# chosen by the recovery service. Currency and behavior IDs never enter here.
	var source_row: Dictionary = service.source.items.get(source_id, {})
	var source_info: Dictionary = IMAGES.describe_item_class_row(source_row) if not source_row.is_empty() else IMAGES.describe_item_class(int(source_id))
	control.icon = source_info.get("texture") as Texture2D
	control.expand_icon = true
	var evidence: Dictionary = source_info.duplicate(true)
	evidence.erase("texture")
	evidence["presentation_role"] = role
	control.set_meta("source523_image", evidence)
	control.set_meta("source523_image_provenance", source_info.get("provenance", {}).duplicate(true))
	control.set_meta("source523_image_status", str(source_info.get("source_status", source_info.get("reason", ""))))

func refresh() -> void:
	for child: Node in get_children(): remove_child(child); child.queue_free()
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	add_child(column)
	label("무료 경험치 복구: %d / 2회 · 매일 %02d시 (UTC%+d) 갱신\n아데나 %d · 다이아 %d" % [service.free_remaining(),int(service.policy.get("reset_hour",5)),int(service.policy.get("timezone_offset_seconds",32400))/3600,service.world.gold,int(service.world.inventory.get("다이아",0))])
	label(str(service.source.problem))
	var stats: Dictionary = service.death_stats()
	label("장착 죽음 속성 %d · 경험치 손실 %.1f%% / 장비 손실 추첨 %.1f%% 완화\n완화 계수와 상한은 TWILIGHT 자체 정책입니다. 사망 당시 적용값을 기록합니다." % [int(stats.value),float(stats.exp_reduction),float(stats.item_reduction)])
	label("TWILIGHT 원격 복구 · 원본 경험치 손실 비율을 현재 성장 곡선에 적용합니다. 레벨은 하락하지 않습니다.\n기본 24시간 · 이후 72시간까지 다이아 복구만 가능. 아이템 추첨·아이템 복구비·다이아 환산·연장 가산·부활 회복량은 조정 가능한 자체 정책입니다.")
	label("복구 슬롯 · 경험치 %d/%d · 아이템 %d/%d\n슬롯을 초과한 내역은 앞선 내역 복구 또는 확장 후 이용합니다. 보관 장비와 기록은 삭제하지 않습니다. 기본 슬롯과 확장 한도는 자체 정책입니다." % [service.active_losses("exp").size(),service.slot_capacity("exp"),service.active_losses("item").size(),service.slot_capacity("item")])
	for kind: String in ["exp","item"]:
		var offer: Dictionary = service.quote_slot(kind)
		var caption: String = ("경험치" if kind == "exp" else "아이템")+" 복구 슬롯 확장"
		caption += " · +%d칸 / 다이아 %d" % [int(offer.amount),int(offer.cost)] if offer.ok else " · "+str(offer.message)
		var action := button(caption,func() -> void: _confirm_slot(kind),"Death523Slot_"+kind)
		action.disabled = not offer.ok
	var certificate: Dictionary = service.certificate_wallet()
	label("구호증서 · 무료 2회 소진 후 24시간 이내 경험치 복구\n"+("사용 가능한 영구 증서가 없습니다" if certificate.is_empty() else "%s %d개 · 복구당 %d개 (자체 소모량)" % [certificate.name,int(service.world.inventory.get(certificate.name,0)),int(service.policy.get("certificate_per_recovery",1))]))
	button("원본523 규칙 ZIP 불러오기",_choose_pack,"Death523Install")
	result = label("")
	result.name = "Death523RecoveryResult"
	var count: int = 0
	var entries: Array = service.state.records.duplicate()
	entries.reverse()
	for entry: Dictionary in entries:
		var age: int = maxi(0,service.now()-int(entry.at))
		var item: Dictionary = entry.item
		var origin: String=service.source_location_text(entry)
		if origin.is_empty():origin=str(entry.map)
		var summary: String = "#%s · Lv.%d · %s\n경험치 %d %s · 아이템 %s\n%s" % [entry.id,int(entry.level),origin,int(entry.exp),"(복구 완료)" if entry.exp_claimed else "(미복구)","없음" if item.is_empty() else str(item.physical.name)+( " (복구 완료)" if entry.item_claimed else " (미복구)"),"기한 만료 · 기록 보존" if age >= 259200 else "남은 시간 %d분" % maxi(0,int((259200-age)/60))]
		var restarted: String=service.source_location_text(entry,"restart_source_location")
		if not restarted.is_empty():summary+="\n부활 위치: "+restarted+" · 기존 시작점 정책"
		label(summary)
		for kind: String in ["exp","item"]:
			if bool(entry[kind+"_claimed"]): continue
			count += 1
			for mode: String in (["free","certificate","adena","gem"] if kind == "exp" else ["adena","gem"]):
				var request: Dictionary = service.quote(str(entry.id),kind,mode)
				var caption: String = ("경험치" if kind == "exp" else "아이템")+" · "+{"free":"무료 복구","certificate":"구호증서 복구","adena":"아데나 복구","gem":"다이아 복구"}[mode]
				if request.ok: caption += " (%d)" % int(request.cost)
				else: caption += " · "+str(request.message)
				var action := button(caption,func() -> void: _confirm(str(entry.id),kind,mode),"Death523_%s_%s_%s" % [entry.id,kind,mode])
				if kind == "item":
					_bind_item_icon(action, str(item.get("source_id", "")), "death_recovery_item")
				elif mode == "certificate":
					_bind_item_icon(action, str(request.get("certificate", {}).get("source_id", "")), "death_recovery_certificate_cost")
				action.disabled = not request.ok
	if count == 0: label("복구 대기 중인 손실이 없습니다.")

func _confirm(id: String, kind: String, mode: String) -> void:
	var request: Dictionary = service.quote(id,kind,mode)
	if not request.ok: result.text = str(request.message); return
	var currency: String = {"free":"무료 횟수 1회","certificate":"%s %d개 (자체 소모량)" % [str(request.certificate.get("name","구호증서")),int(request.cost)],"adena":"%d 아데나" % int(request.cost),"gem":"%d 다이아" % int(request.cost)}[mode]
	var origin: String=service.source_location_text(service._entry(id))
	var where: String="" if origin.is_empty() else "\n사망 위치: "+origin
	service.world.hud.confirm_action("사망 복구 확인","#%s %s을 복구합니다.%s\n소모: %s\n%s" % [id,"경험치" if kind == "exp" else "원래 장비",where,currency,"자체 복구비/환산/소모 정책 적용" if kind == "item" or mode in ["gem","certificate"] or not service.source.ready else "원본 레벨별 비용 · 로컬 아데나 연결"],"복구",func(_amount: int) -> void:
		var response: Dictionary = service.recover(request)
		refresh()
		result.text = str(response.message)
		service.world.hud.show_message(str(response.message)))

func _confirm_slot(kind: String) -> void:
	var request: Dictionary = service.quote_slot(kind)
	if not request.ok: result.text = str(request.message); return
	service.world.hud.confirm_action("복구 슬롯 확장 확인","%s 복구 슬롯을 %d칸 확장합니다.\n소모: 다이아 %d개\n원본523 상품 가격 · 기본 슬롯/한도/보관 방식은 자체 정책" % ["경험치" if kind == "exp" else "아이템",int(request.amount),int(request.cost)],"확장",func(_amount: int) -> void:
		var response: Dictionary = service.expand_slot(request)
		refresh(); result.text = str(response.message)
		service.world.hud.show_message(str(response.message)))

func _choose_pack() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.zip ; 최신523 원본 규칙"])
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		var problem: String = service.source.install(path)
		refresh(); result.text = "설치 완료 · 다음 실행에도 유지됩니다" if problem.is_empty() else problem
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.8)
