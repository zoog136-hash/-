extends VBoxContainer

# Restored 13-class picker. Only the existing HUD signal may change the
# authoritative job; this widget never rewrites saves, equipment or skills.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Stage = preload("res://scripts/ui/renewal_stage.gd")
const CLASS_NAMES: Array[String] = [
	"기사", "군주", "요정", "마법사", "다크엘프", "총사", "투사",
	"암흑기사", "신성검사", "광전사", "사신", "뇌신", "마검사"
]

var hud: Node
var first_character: bool = false
var selected_job: String = ""
var profiles: Dictionary = {}
var class_buttons: Dictionary = {}
var class_scroll: ScrollContainer
var class_grid: GridContainer
var portrait: TextureRect
var details: RichTextLabel
var confirm_button: Button

func configure(controller: Node, initial: bool = false) -> void:
	hud = controller
	first_character = initial
	name = "ClassSelectionScreen"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 7)
	var title := UI.label("새로운 모험의 시작 · 클래스 선택" if initial else "클래스 선택 · 변경",21,UI.GOLD)
	add_child(title)
	add_child(UI.label("원하는 직업을 선택하세요. 각 직업의 주무기와 전투 역할이 다릅니다.",12,UI.MUTED))
	class_scroll = ScrollContainer.new()
	class_scroll.name = "ClassListScroll"
	class_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	class_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	class_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	class_scroll.scroll_deadzone = 8
	add_child(class_scroll)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_scroll.add_child(stack)
	class_grid = GridContainer.new()
	class_grid.name = "ClassGrid"
	class_grid.columns = 3
	class_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_child(class_grid)
	for profile_value: Variant in hud.job_classes:
		if profile_value is Dictionary:
			var profile: Dictionary = profile_value
			profiles[str(profile.get("name",""))] = profile
	for job_name: String in CLASS_NAMES:
		# Classes without a mythic illustration must still remain playable.
		var profile: Dictionary = profiles.get(job_name,{})
		var button: Button = UI.button(job_name,func() -> void:
			if not hud.workspace.was_scroll_dragged(class_scroll):
				_choose(job_name),Vector2(155,46))
		button.name = "Class_" + job_name
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",13)
		button.tooltip_text = "주스탯: %s · 주무기: %s" % [profile.get("primary_stat",""),profile.get("weapon","")]
		var path: String = str(profile.get("image_path",""))
		if path != "" and ResourceLoader.exists(path):
			button.icon = load(path) as Texture2D
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width",40)
		class_grid.add_child(button)
		hud.workspace.register_scroll_drag(class_scroll,button)
		class_buttons[job_name] = button
	var summary := HBoxContainer.new()
	stack.add_child(summary)
	portrait = TextureRect.new()
	portrait.name = "ClassPortrait"
	portrait.custom_minimum_size = Vector2(170,165)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.add_child(portrait)
	details = UI.rich("")
	details.name = "ClassDescription"
	details.fit_content = false
	details.scroll_active = false
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.custom_minimum_size.y = 140
	summary.add_child(details)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel",UI.box(Color("11141b"),UI.BRONZE,8))
	stack.add_child(stage)
	stack.move_child(stage,0)
	summary.reparent(stage)
	confirm_button = UI.button("클래스를 선택하세요",_confirm,Vector2(0,54))
	confirm_button.name = "ClassConfirm"
	confirm_button.disabled = true
	add_child(confirm_button)
	add_child(UI.label("현재 저장 데이터, 아데나, 장비와 인벤토리는 삭제되지 않습니다." if not initial else "선택 후 캐릭터가 생성되며 자동 저장됩니다.",11,UI.MUTED))
	if not initial:
		var current: String = str(hud.character_state.get("job_class","기사"))
		if CLASS_NAMES.has(current):
			_choose(current)
	_reflow()
	class_scroll.resized.connect(_reflow)
	get_viewport().size_changed.connect(_reflow)

func _reflow() -> void:
	if class_grid == null:
		return
	var width: float = class_scroll.size.x if class_scroll.size.x > 0 else hud.workspace.content.size.x
	class_grid.columns = 4 if width >= 880.0 else (3 if width >= 620 else (2 if width >= 400 else 1))

func _choose(job_name: String) -> void:
	if not class_buttons.has(job_name):
		return
	selected_job = job_name
	var profile: Dictionary = profiles.get(job_name,{})
	for key: String in class_buttons:
		(class_buttons[key] as Button).button_pressed = key == job_name
	var image_path: String = str(profile.get("image_path",""))
	portrait.texture = load(image_path) as Texture2D if image_path != "" and ResourceLoader.exists(image_path) else null
	details.text = "[font_size=20][color=#d8b878]%s[/color][/font_size]\n역할: %s\n주무기: %s\n주스탯: %s\n대표 변신: %s" % [
		UI.safe(job_name), UI.safe(profile.get("role","직업 전투")),
		UI.safe(profile.get("weapon","직업 무기")), UI.safe(profile.get("primary_stat","직업별")),
		UI.safe(profile.get("transform_name","미설정"))
	]
	confirm_button.text = "%s 선택 확정" % job_name
	confirm_button.disabled = false

func _confirm() -> void:
	if selected_job == "" or not CLASS_NAMES.has(selected_job):
		return
	# World owns class rules, skillbar updates, equipment compatibility and saves.
	hud.job_class_selected.emit(selected_job)
	hud.complete_class_selection()
