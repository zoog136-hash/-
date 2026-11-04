extends VBoxContainer
const UI=preload("res://scripts/ui/renewal_theme.gd")
var runtime: RefCounted
var balance: Label
var result: Label
var action: Button
func configure(service: RefCounted) -> void:
	runtime=service;name="NativeCardCraftView"
	add_theme_constant_override("separation",12)
	add_child(UI.section("네메시스 마법인형 카드 제작",20))
	var description: Label=UI.label("원본 마법인형 제작 코인 3,000,000개로 카드권 1개를 확정 제작합니다. 카드권은 인벤토리에서 사용하면 네메시스를 획득합니다.",15)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(description)
	var source_note: Label=UI.label("재료는 원본이 확인된 제작 코인 개체로 선택됩니다. 기존 일반 제작 코인 잔액은 보존됩니다.",12,UI.MUTED)
	source_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(source_note)
	balance=UI.label("",15,UI.GOLD);add_child(balance)
	action=UI.button("카드권 1개 제작",_execute,Vector2(0,48));action.set_script(preload("res://scripts/ui/native_touch_button.gd"));action.name="CraftNemesisTicket";add_child(action)
	result=UI.label("",14);result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(result)
	var bag: Button=UI.button("인벤토리 열기",func() -> void:runtime.world.hud.toggle_inventory(),Vector2(0,44));bag.set_script(preload("res://scripts/ui/native_touch_button.gd"));add_child(bag)
	refresh()
func refresh() -> void:
	var snapshot: Dictionary=runtime.nemesis_craft_view()
	balance.text="사용 가능한 원본 제작 코인: %d / %d" % [snapshot.available_coins,snapshot.required_coins]
	action.disabled=not bool(snapshot.can_craft)
	if snapshot.save_blocked:result.text="저장 보호 중 · 제작 재료 보존"
	elif not snapshot.conditions_verified:result.text="원본 제작 조건 확인 필요"
func _execute() -> void:
	action.disabled=true
	var outcome: Dictionary=runtime.craft_nemesis()
	result.text="네메시스 카드권 1개 제작 완료 · 인벤토리에서 사용할 수 있습니다" if outcome.ok else str(outcome.error)
	if outcome.ok:
		runtime.world._update_hud();runtime.world.hud.refresh_inventory(runtime.world.inventory)
	refresh()
