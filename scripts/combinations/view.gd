extends VBoxContainer
const UI=preload("res://scripts/ui/renewal_theme.gd")
var hud: Node
var runtime: RefCounted
var entries: ItemList
var detail: Label
var status: Label
var apply_button: Button
var release_button: Button
var chosen: int=0
var _snapshot: Array=[]
var _refresh_elapsed: float=0
var _ownership_signature: int=0
func _process(delta: float) -> void:
	_refresh_elapsed+=delta
	if _refresh_elapsed<.5:return
	_refresh_elapsed=0
	var world: Node=hud.get_parent()
	var signature: int=hash([world.card_draw_fusion.owned,world.inventory,world.item_instances,runtime.context(),runtime.progress])
	if signature!=_ownership_signature:
		_ownership_signature=signature;runtime.invalidate();refresh()
func _touch_button(label: String,callback: Callable,minimum: Vector2) -> Button:
	var button: Button=UI.button(label,callback,minimum)
	button.set_script(preload("res://scripts/growth/growth_touch_button.gd"))
	button.scroll_host=hud.workspace;button.scroll_area=get_parent() as ScrollContainer
	return button
func configure(controller: Node) -> void:
	hud=controller;runtime=hud.get_parent().combinations
	name="CombinationSelectionView";size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	var help: Label=UI.label("영구 보유 변신·인형과 인벤토리 장비로 한 조합을 선택합니다. 강화는 요구값 이상이며 카드·장비를 소모하지 않습니다.",13,UI.MUTED)
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(help)
	var install: Button=_touch_button("최신523 원본 자료 설치",_choose_source,Vector2(0,44));install.name="CombinationInstallSource";add_child(install)
	status=UI.label("",13,UI.GOLD);status.name="CombinationStatus";status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(status)
	entries=preload("res://scripts/ui/native_touch_list.gd").new();entries.name="CombinationList"
	entries.custom_minimum_size=Vector2(240,184);entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;entries.add_theme_constant_override("v_separation",28)
	entries.item_selected.connect(_select);add_child(entries)
	detail=UI.label("",13);detail.name="CombinationRequirements";detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(detail)
	var actions:=HBoxContainer.new();add_child(actions)
	apply_button=_touch_button("선택 적용",_confirm_selection,Vector2(140,44));apply_button.name="CombinationApply";actions.add_child(apply_button)
	release_button=_touch_button("조합 해제",_confirm_release,Vector2(140,44));release_button.name="CombinationRelease";actions.add_child(release_button)
	refresh()
func refresh() -> void:
	_snapshot=runtime.snapshot();entries.clear()
	status.text=runtime.problem if not runtime.problem.is_empty() else "선택은 하나만 적용됩니다. 기본 수수료 0 아데나는 TWILIGHT 설정입니다."
	if runtime.save_blocked:status.text="조합 저장 보호 중 · 원본 저장을 보존합니다."
	var selected_index: int=-1
	for row: Dictionary in _snapshot:
		var text: String=str(row.name)+(" · 적용 중" if row.active else " · 선택됨 / 조건 미충족" if row.selected else " · 선택 가능" if row.status.ok else " · 미충족")
		var index: int=entries.add_item(text);entries.set_item_metadata(index,int(row.id))
		if int(row.id)==chosen:selected_index=index
	if selected_index<0 and not _snapshot.is_empty():selected_index=0
	if selected_index>=0:entries.select(selected_index);_select(selected_index)
	else:detail.text="원본 자료 설치 후 조합 목록을 확인할 수 있습니다.";apply_button.disabled=true
	release_button.disabled=int(runtime.progress.selected_id)==0 or runtime.save_blocked
func _select(index: int) -> void:
	if index<0 or index>=_snapshot.size():return
	var row: Dictionary=_snapshot[index];chosen=int(row.id)
	var lines: PackedStringArray=[str(row.name)]
	for slot_index: int in range(row.slots.size()):
		var slot: Dictionary=row.slots[slot_index];var state: Dictionary=row.status.get("slots",[])[slot_index] if row.status.has("slots") else {}
		var alternatives: PackedStringArray=[]
		for req: Dictionary in slot.candidates:alternatives.append(str(req.name)+(" +"+str(int(req.min_enchant))+" 이상" if int(req.kind)==24 else " 영구 보유"))
		lines.append(("✓ " if bool(state.get("ok",false)) else "· ")+" 또는 ".join(alternatives))
	lines.append("선택 효과")
	for effect: Dictionary in row.effects:
		var label: String=str(effect.label)+" "+str(effect.value)
		if effect.unit in ["Percentage","ValuePercent"]:label+="%"
		if int(effect.target)>0:label+=" · 적용 대상 "+str(int(effect.target))
		lines.append(label)
	if not row.status.ok:lines.append(str(row.status.get("error","조건 확인 필요")))
	var fee: int=int(runtime.policy.get("selection_fee_adena",0))
	lines.append("선택 비용: "+UI.number_text(fee)+" 아데나 · 카드·장비 소모 없음")
	detail.text="\n".join(lines)
	apply_button.disabled=not bool(row.status.ok) or bool(row.selected) or runtime.save_blocked
func _confirm_selection() -> void:_confirm(chosen)
func _confirm_release() -> void:_confirm(0)
func _confirm(id: int) -> void:
	var quote: Dictionary=runtime.quote(id)
	if not quote.ok:status.text=str(quote.error);return
	var label: String="조합 해제" if id==0 else str(runtime.rows[id].name)
	var dialog: Control=hud.confirm_action(label,"선택 비용 "+UI.number_text(int(quote.fee))+" 아데나\n카드와 장비는 소모하지 않습니다. 기존 조합 효과는 교체됩니다.","해제" if id==0 else "적용",func(_count: int) -> void:
		var result: Dictionary=runtime.request_selection(id,int(quote.revision),str(Time.get_ticks_usec())+":"+str(int(quote.revision)),quote.signature)
		if not is_instance_valid(self):return
		refresh();status.text="조합 선택을 저장했습니다." if result.ok else str(result.error)
		if hud.has_method("show_message"):hud.show_message(status.text))
	for button: Button in [dialog.confirm_button,dialog.cancel_button]:
		button.set_script(preload("res://scripts/ui/native_touch_button.gd"))
func _choose_source() -> void:
	var chooser:=FileDialog.new();chooser.name="CombinationSourceChooser";chooser.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	chooser.access=FileDialog.ACCESS_FILESYSTEM;chooser.filters=PackedStringArray(["*.zip ; 최신523 Content 원본"])
	add_child(chooser);chooser.file_selected.connect(func(path: String) -> void:
		var result: Dictionary=runtime.install_source(path);refresh()
		if not result.ok:status.text=str(result.error)
		chooser.queue_free())
	chooser.canceled.connect(chooser.queue_free);chooser.popup_centered_ratio(.8)
