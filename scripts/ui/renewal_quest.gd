extends VBoxContainer

# Local quest journal; progress is read from the existing world snapshot.
const UI = preload("res://scripts/ui/renewal_theme.gd")
var hud: Node
var counter: Label
var progress: ProgressBar
var status: RichTextLabel

func configure(controller: Node) -> void:
	hud = controller
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UI.label("메인 퀘스트",25,UI.GOLD))
	add_child(UI.label("몬스터의 세력 다툼",19))
	add_child(UI.label("지역의 몬스터를 처치하고 사냥 기록을 완성하세요.",13,UI.MUTED))
	add_child(HSeparator.new())
	counter = UI.label("",21,UI.GOLD)
	add_child(counter)
	progress = ProgressBar.new()
	progress.name = "QuestProgress"
	progress.custom_minimum_size.y = 20
	progress.show_percentage = false
	add_child(progress)
	status = UI.rich("")
	status.custom_minimum_size.y = 110
	add_child(status)
	var actions := HBoxContainer.new()
	add_child(actions)
	actions.add_child(UI.button("월드맵 열기",func() -> void: hud._navigate("map"),Vector2(178,48)))
	actions.add_child(UI.button("AUTO 전환",func() -> void: hud.auto_pressed.emit(),Vector2(178,48)))
	add_child(UI.label("퀘스트 보상 수령 기능은 현재 게임 로직에 없어 제공하지 않습니다.",12,UI.MUTED))
	refresh(hud.character_state)

func refresh(state: Dictionary) -> void:
	if progress == null: return
	var goal := maxi(1,int(state.get("quest_goal",9)))
	var current := maxi(0,int(state.get("quest_kills",0)))
	progress.max_value = float(goal)
	progress.value = float(mini(current,goal))
	counter.text = "몬스터 처치  %d / %d" % [current,goal]
	status.text = "목표를 달성했습니다. 진행도는 기존 게임 저장 규칙에 따라 유지됩니다." if current >= goal else "현재 사냥 진행률  %.1f%%\n\n자동사냥은 AUTO로 켜거나 끌 수 있습니다. 대상 처치 수가 변경되면 이 화면에도 반영됩니다." % (100.0*float(current)/float(goal))
