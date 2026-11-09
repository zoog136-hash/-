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
## Original Gender table IDs; the 523 character picture is per class and gender.
const GENDERS := {1:"남성", 2:"여성"}
var gender_buttons: Dictionary = {}
var selected_gender: int = 0
var current_gender: int = 0
var current_job: String = ""

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
	var gender_row := HBoxContainer.new()
	gender_row.name = "GenderRow"
	gender_row.add_theme_constant_override("separation", 8)
	gender_row.add_child(UI.label("성별",14,UI.GOLD))
	for gender_id: int in GENDERS:
		var gender_button: Button = UI.button(GENDERS[gender_id],func() -> void: _choose_gender(gender_id),Vector2(120,44))
		gender_button.name = "Gender_%d" % gender_id
		gender_button.toggle_mode = true
		gender_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gender_row.add_child(gender_button)
		gender_buttons[gender_id] = gender_button
	stack.add_child(gender_row)
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
	current_gender = int(hud.character_state.get("source_gender_id", 0))
	if current_gender in GENDERS: _choose_gender(current_gender)
	if not initial:
		var current: String = str(hud.character_state.get("job_class","기사"))
		current_job = current
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
	# A class the original client draws for one gender only offers that one.
	var allowed: Array = _allowed_genders(job_name)
	for key: int in gender_buttons:
		(gender_buttons[key] as Button).disabled = not key in allowed
	if selected_gender != 0 and not selected_gender in allowed:
		selected_gender = 0
		for key: int in gender_buttons: (gender_buttons[key] as Button).button_pressed = false
	if selected_gender == 0 and allowed.size() == 1: _choose_gender(int(allowed[0]))
	_refresh_confirm()

func _allowed_genders(job_name: String) -> Array:
	var world: Node = hud.get_parent() if hud != null else null
	if world != null and world.has_method("source_class_genders"): return world.call("source_class_genders", job_name)
	return [1, 2]

func _choose_gender(gender_id: int) -> void:
	if not GENDERS.has(gender_id): return
	if selected_job != "" and not gender_id in _allowed_genders(selected_job): return
	selected_gender = gender_id
	for key: int in gender_buttons:
		(gender_buttons[key] as Button).button_pressed = key == gender_id
	_refresh_confirm()

func _refresh_confirm() -> void:
	if confirm_button == null: return
	confirm_button.disabled = selected_job == "" or not GENDERS.has(selected_gender)
	if selected_job == "": confirm_button.text = "클래스를 선택하세요"
	elif not GENDERS.has(selected_gender): confirm_button.text = "성별을 선택하세요"
	else: confirm_button.text = "%s · %s 선택 확정" % [selected_job, GENDERS[selected_gender]]

func _confirm() -> void:
	if selected_job == "" or not CLASS_NAMES.has(selected_job) or not GENDERS.has(selected_gender):
		return
	# World owns class rules, skillbar updates, equipment compatibility and saves.
	if selected_gender != current_gender and hud.has_signal("source_gender_selected"):
		hud.source_gender_selected.emit(selected_gender)
	# Confirming only a gender keeps the current class and its equipped cards.
	if first_character or selected_job != current_job:
		hud.job_class_selected.emit(selected_job)
	hud.complete_class_selection()
