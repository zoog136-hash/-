extends VBoxContainer

# Existing quest snapshot; original AUTO and map actions; no invented rewards.
const UI = preload("res://scripts/ui/renewal_theme.gd")
var hud: Node
var counter: Label
var progress: ProgressBar
var status: RichTextLabel

func configure(controller: Node) -> void:
	hud = controller
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",16)
	scroll.add_child(stack)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel",UI.chrome_panel(Color("18171b"),UI.BRONZE,18))
	stack.add_child(banner)
	var head := HBoxContainer.new()
	banner.add_child(head)
	var emblem := TextureRect.new()
	emblem.texture = UI.icon("quest")
	emblem.custom_minimum_size = Vector2(60,72)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(emblem)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UI.section("메인 퀘스트",12))
	titles.add_child(UI.section("몬스터의 세력 다툼",22))
	titles.add_child(UI.section("지역의 몬스터를 처치하고 사냥 기록을 완성하세요.",12))
	stack.add_child(UI.section("진행 상황",16))
	counter = UI.section("",19)
	stack.add_child(counter)
	progress = ProgressBar.new()
	progress.name = "QuestProgress"
	progress.custom_minimum_size.y = 14
	progress.show_percentage = false
	stack.add_child(progress)
	status = UI.rich("")
	status.custom_minimum_size.y = 100
	stack.add_child(status)
	var actions := HBoxContainer.new()
	stack.add_child(actions)
	actions.add_child(UI.button("월드맵",func() -> void: hud._navigate("map"),Vector2(150,42)))
	actions.add_child(UI.button("AUTO 전환",func() -> void: hud.auto_pressed.emit(),Vector2(150,42)))
	refresh(hud.character_state)

func refresh(state: Dictionary) -> void:
	if progress == null: return
	var goal := maxi(1,int(state.get("quest_goal",9)))
	var current := maxi(0,int(state.get("quest_kills",0)))
	progress.max_value = float(goal)
	progress.value = float(mini(current,goal))
	counter.text = "몬스터 처치  %d / %d" % [current,goal]
	status.text = "[color=#8bc7a1]목표를 달성했습니다.[/color]" if current >= goal else "현재 사냥 진행률  %.1f%%\n\nAUTO를 켜면 주변의 몬스터를 탐색하고 자동으로 전투합니다." % (100.0*float(current)/float(goal))
