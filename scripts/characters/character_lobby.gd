extends Control
## Local account roster. No network account, deletion or class-change shortcut.
const CATALOG = preload("res://scripts/characters/class_catalog.gd")
const PORTRAIT_PATH := "res://scripts/ui/source523_class_images.gd"
const IMAGE_OWNER_PATH := "res://scripts/ui/source523_image_assets.gd"
const STYLE = preload("res://scripts/boot/boot_style.gd")
const PROFILE = preload("res://scripts/characters/save_profile.gd")
const PRESENTATION = preload("res://scripts/characters/lobby_source_presentation.gd")
# Native buttons suppress taps after a drag. Forward that drag to the roster
# scroll before the button marks it handled, so long lists work on touch too.
class ScrollButton extends "res://scripts/ui/native_touch_button.gd":
	var scroll_host: ScrollContainer
	func _input(event: InputEvent) -> void:
		if finger != -1 and event is InputEventScreenDrag and event.index == finger and scroll_host != null:
			scroll_host.scroll_vertical -= int(event.relative.y)
		super._input(event)
const MAIN := "res://Main.tscn"
const LOADING_SCREEN := "res://scripts/boot/loading_screen.gd"
var store: RefCounted
# Explicitly injected stores keep their caller-selected path. Only the normal
# boot route resolves the namespace and authoritative map-migration pointer.
var profile_resolver: Callable
var _managed_profile: bool = false
var _profile_problem: String = ""
var catalog: RefCounted
var snapshot: Dictionary = {}
var selected_id: String = ""
var selected_class: int = 0
var selected_gender: int = 0
var busy: bool = false
var content: VBoxContainer
var status: Label
var scroll: ScrollContainer
var name_input: LineEdit
var details: Label
var portrait: TextureRect
var source_presentation: Control
var source_animation_controls: VBoxContainer
var source_selection_revision: int = 0
var _pack_dialog: Window
var gender_row: HBoxContainer
var create_button: Button
var class_buttons: Dictionary = {}
var _touch_index: int = -1
var _touch_last: Vector2

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if store == null:
		_managed_profile = true
		store = load("res://scripts/characters/account_store.gd").new()
	if catalog == null:
		catalog = CATALOG.new()
		catalog.configure()
	var font := load("res://assets/fonts/NotoSansKR.ttf") as Font
	if font != null: add_theme_font_override("font",font)
	add_child(STYLE.backdrop())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var panel: PanelContainer = STYLE.panel()
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	column.add_child(STYLE.label("TWILIGHT · 캐릭터 선택",26,STYLE.GOLD))
	column.add_child(STYLE.label("최대 13명 · 창고 / 변신·인형·성물 보유 / 아이템 컬렉션 / 문양·수호성은 계정 공유",14,STYLE.MUTED))
	column.add_child(_button("원본 로비 리소스 팩 설치", _open_pack_installer, "InstallLobbyPack"))
	scroll = ScrollContainer.new()
	scroll.name = "RosterScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	scroll.add_child(content)
	status = STYLE.label("",16,STYLE.GOLD)
	status.name = "LobbyStatus"
	column.add_child(status)
	_show_roster()

func _clear() -> void:
	source_selection_revision += 1
	if is_instance_valid(source_presentation): source_presentation.clear_selection()
	source_presentation = null
	source_animation_controls = null
	portrait = null
	details = null
	gender_row = null
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	class_buttons.clear()
	name_input = null
	create_button = null
	scroll.scroll_vertical = 0

func _button(text: String, action: Callable, identifier: String = "") -> Button:
	var button: Button = ScrollButton.new()
	button.scroll_host = scroll
	button.text = text
	button.clip_text = true
	button.tooltip_text = text.replace("\n", " · ")
	if not identifier.is_empty(): button.name = identifier
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",18)
	button.add_theme_stylebox_override("normal",STYLE.box(7,Color("262134"),STYLE.GOLD,1))
	button.pressed.connect(func() -> void:
		if not busy: action.call())
	return button

func _show_roster() -> void:
	_clear()
	selected_id = ""
	snapshot = {}
	_profile_problem = ""
	if _managed_profile:
		var resolved: Variant = profile_resolver.call() if profile_resolver.is_valid() else PROFILE.resolve_current()
		if not resolved is Dictionary or resolved.get("ok") != true or not resolved.get("path") is String or str(resolved.path).is_empty():
			_profile_problem = str(resolved.get("problem", "저장 위치를 확인하지 못했습니다. 기존 저장을 보존합니다.")) if resolved is Dictionary else "저장 위치를 확인하지 못했습니다. 기존 저장을 보존합니다."
			if _profile_problem.is_empty(): _profile_problem = "저장 위치를 확인하지 못했습니다. 기존 저장을 보존합니다."
			snapshot = {"ok": false, "problem": _profile_problem}
			status.text = _profile_problem
			content.add_child(_button("저장 위치 다시 확인", _show_roster, "RetryRoster"))
			return
		store.path = resolved.path
	snapshot = store.open()
	if not snapshot.get("ok",false):
		status.text = str(snapshot.get("problem","저장 데이터를 열지 못했습니다. 기존 파일을 보존합니다."))
		content.add_child(_button("다시 확인",_show_roster,"RetryRoster"))
		return
	status.text = ""
	if snapshot.get("legacy",false):
		content.add_child(STYLE.label("기존 캐릭터 저장을 발견했습니다. 원본을 SHA-256으로 검증한 백업을 남긴 뒤 첫 슬롯으로 이전합니다. 기존 진행과 자산은 유지됩니다.",18))
		content.add_child(_button("기존 저장 백업 후\n캐릭터 목록으로 이전",_migrate,"MigrateLegacy"))
		return
	if snapshot.get("upgrade", false):
		content.add_child(STYLE.label("기존 계정 저장을 발견했습니다. 원본을 백업한 뒤 계정 공유 정보와 각 캐릭터의 진행을 안전하게 정리합니다.", 18))
		content.add_child(_button("계정 저장 구조 업그레이드\n원본 백업 후 진행", _upgrade, "UpgradeAccount"))
		return
	var characters: Array = snapshot.get("characters",[])
	selected_id = str(snapshot.get("selected",""))
	content.add_child(STYLE.label("내 캐릭터 %d / 13" % characters.size(),20,STYLE.GOLD))
	for entry: Dictionary in characters:
		var id: String = str(entry.get("id",""))
		var label: String = "%s\n%s" % [str(entry.get("name","캐릭터")),catalog.job_name(int(entry.get("class_id",0)))]
		var button := _button(label,func() -> void: _select(id),"Character_"+id)
		button.toggle_mode = true
		button.button_pressed = id == selected_id
		content.add_child(button)
		if int(entry.get("gender_id",0))==0 and str(catalog.problem).is_empty():
			content.add_child(STYLE.label("%s · 기존 저장에 없던 성별을 한 번 선택하세요. 직업과 진행은 유지됩니다."%str(entry.name),14,STYLE.MUTED))
			for gender: int in [1,2]:
				if catalog.profile(int(entry.class_id),gender).is_empty(): continue
				content.add_child(_button("%s · %s 선택"%[str(entry.name),"남성" if gender==1 else "여성"],func() -> void: _complete_gender(id,gender),"LegacyGender_%s_%d"%[id,gender]))
	var enter := _button("선택한 캐릭터로 접속",_enter,"EnterCharacter")
	enter.disabled = selected_id.is_empty()
	content.add_child(enter)
	var create := _button("새 캐릭터 생성",_show_creation,"NewCharacter")
	create.disabled = characters.size() >= 13 or not str(catalog.problem).is_empty()
	content.add_child(create)
	if not str(catalog.problem).is_empty(): content.add_child(STYLE.label(str(catalog.problem),16,STYLE.MUTED))
	content.add_child(STYLE.label("레벨·경험치·인벤토리·장비·스킬·위치와 전투 상태는 캐릭터별로 저장됩니다. 캐릭터 삭제는 지원하지 않습니다.",14,STYLE.MUTED))

func _roster_ready() -> bool:
	return _profile_problem.is_empty() and snapshot.get("ok", false) == true and not snapshot.get("legacy", false) and not snapshot.get("upgrade", false)

func _select(id: String) -> void:
	if busy or not _roster_ready(): return
	selected_id = id
	for node: Node in content.get_children():
		if node is Button and node.name.begins_with("Character_"): node.button_pressed = node.name == "Character_"+id
	var enter := content.get_node_or_null("EnterCharacter") as Button
	if enter != null: enter.disabled = false

func _complete_gender(id: String, gender: int) -> void:
	if busy or not _roster_ready(): return
	busy=true
	var result: Dictionary=store.complete_legacy_gender(id,gender,catalog)
	busy=false
	if result.get("ok",false): _show_roster()
	else: status.text=str(result.get("problem","성별 저장 실패"))

func _upgrade() -> void:
	if busy or not _profile_problem.is_empty() or not snapshot.get("ok", false) or not snapshot.get("upgrade", false): return
	busy = true
	var result: Dictionary = store.upgrade_account()
	busy = false
	if result.get("ok", false):
		_show_roster()
		var unresolved: int = int(result.get("unresolved_timers", 0))
		if unresolved > 0: status.text = "계정 저장을 정리했습니다. %d명의 추가 성물 소환 시간은 확인할 수 없어, 해당 캐릭터에서 소환 주문서를 다시 사용해야 합니다." % unresolved
	else: status.text = str(result.get("problem", "계정 저장 업그레이드 실패 · 기존 파일을 보존합니다."))

func _migrate() -> void:
	if busy or not _profile_problem.is_empty() or not snapshot.get("ok", false) or not snapshot.get("legacy", false) or snapshot.get("upgrade", false): return
	busy = true
	var result: Dictionary = store.migrate_legacy()
	busy = false
	if result.get("ok",false): _show_roster()
	else: status.text = str(result.get("problem","이전 실패 · 원본 저장을 유지합니다."))

func _show_creation() -> void:
	if busy or not _roster_ready() or snapshot.get("characters", []).size() >= 13 or not str(catalog.problem).is_empty(): return
	_clear()
	selected_class = 0
	selected_gender = 0
	content.add_child(STYLE.label("새 캐릭터 · 직업과 성별을 선택하세요",20,STYLE.GOLD))
	name_input = LineEdit.new()
	name_input.name = "CharacterName"
	name_input.placeholder_text = "이름 2~12자 · 계정 내 중복 불가"
	name_input.max_length = 12
	name_input.custom_minimum_size.y = 52
	name_input.text_changed.connect(func(_value: String) -> void: _refresh_create())
	content.add_child(name_input)
	var flow := HFlowContainer.new()
	flow.name = "ClassChoices"
	content.add_child(flow)
	for row: Dictionary in catalog.classes:
		var id: int = int(row.id)
		var button := _button(str(row.name),func() -> void: _choose_class(id),"Class_%d" % id)
		button.custom_minimum_size.x = 125
		button.toggle_mode = true
		flow.add_child(button)
		class_buttons[id] = button
	gender_row = HBoxContainer.new()
	gender_row.name = "GenderChoices"
	content.add_child(gender_row)
	portrait = TextureRect.new()
	portrait.name = "SourcePortrait"
	portrait.custom_minimum_size.y = 120
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)
	source_presentation = PRESENTATION.new()
	source_presentation.name = "SourceLobbyPresentation"
	source_presentation.custom_minimum_size.y = 240
	source_presentation.hide()
	content.add_child(source_presentation)
	source_animation_controls = VBoxContainer.new()
	source_animation_controls.name = "SourceAnimationControls"
	content.add_child(source_animation_controls)
	details = STYLE.label("원본 Class 초기 능력치와 ClassAssets 성별 연결을 사용합니다.",16)
	content.add_child(details)
	create_button = _button("캐릭터 생성",_create,"CreateCharacter")
	content.add_child(create_button)
	content.add_child(_button("취소 · 목록으로",_show_roster,"CancelCreation"))
	status.text = "생성 가능한 직업 수와 계정의 13개 슬롯은 별개입니다."
	_refresh_create()

func _choose_class(id: int) -> void:
	if busy or not is_instance_valid(portrait) or not is_instance_valid(name_input): return
	source_selection_revision += 1
	if is_instance_valid(source_presentation):
		source_presentation.clear_selection()
		source_presentation.hide()
	_clear_source_controls()
	portrait.texture = null
	details.text = "성별을 선택하세요."
	selected_class = id
	selected_gender = 0
	for key: int in class_buttons: class_buttons[key].button_pressed = key == id
	for child: Node in gender_row.get_children():
		gender_row.remove_child(child)
		child.queue_free()
	for row: Dictionary in catalog.classes:
		if int(row.id) != id: continue
		for gender: int in row.genders:
			var button := _button("남성" if gender == 1 else "여성",func() -> void: _choose_gender(gender),"Gender_%d" % gender)
			button.toggle_mode = true
			gender_row.add_child(button)
		if row.genders.size() == 1: _choose_gender(int(row.genders[0]))
	_refresh_create()

func _choose_gender(gender: int) -> void:
	if busy or not is_instance_valid(portrait) or not is_instance_valid(name_input): return
	source_selection_revision += 1
	var profile: Dictionary = catalog.profile(selected_class,gender)
	if profile.is_empty(): return
	selected_gender = gender
	for node: Node in gender_row.get_children(): node.button_pressed = node.name == "Gender_%d" % gender
	var source: Dictionary = _source_portrait({"class_id":selected_class,"gender_id":gender})
	portrait.texture = source.get("texture") as Texture2D
	var stats: Dictionary = profile.stats
	var presented: Dictionary = source_presentation.select_profile(selected_class,gender)
	source_presentation.visible = presented.get("has_layers",false)
	_source_controls(presented)
	details.text = "%s · STR %d / DEX %d / CON %d / INT %d / WIS %d / CHA %d\n%s%s" % [profile.name,stats.str,stats.dex,stats.con,stats.int,stats.wis,stats.cha,_source_note(presented),"\n원본 초상화 팩 미설치 · 대체 이미지는 표시하지 않습니다." if portrait.texture == null else ""]
	details.tooltip_text = _source_note(presented)
	portrait.visible = portrait.texture != null
	_refresh_create()

func _source_portrait(context: Dictionary) -> Dictionary:
	# An unselected optional image pack must not initialize its unrelated item,
	# card and monster-book dependencies on the account lobby's first launch.
	# Already loaded owners can retain an explicit programmatic selection.
	var requested: bool = ResourceLoader.has_cached(IMAGE_OWNER_PATH) or not OS.get_environment("TWILIGHT_SOURCE523_IMAGES").is_empty() or not OS.get_environment("TWILIGHT_SOURCE523_IMAGES_SHA256").is_empty()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source523-images=") or argument.begins_with("--source523-images-sha256="): requested = true
	if not requested: return {"ok":false,"texture":null,"status":"original_icon_not_installed","reason":"source523_image_pack_not_selected"}
	var resolver: Script = load(PORTRAIT_PATH)
	return resolver.resolve(context)

func _clear_source_controls() -> void:
	if not is_instance_valid(source_animation_controls): return
	for child: Node in source_animation_controls.get_children():
		source_animation_controls.remove_child(child)
		child.queue_free()

func _source_note(state: Dictionary) -> String:
	var body: Dictionary = state.get("layers",{}).get("spine",{})
	if body.get("status") == "missing_runtime": return "원본 Spine 재생기 미설치 · 사용 가능한 전후 효과만 미리보기합니다."
	if state.get("has_layers",false): return "원본 연출 미리보기 · 아래 클립을 선택해 재생할 수 있습니다."
	if not state.get("ok",false): return "원본 로비 연결을 확인하지 못했습니다. 캐릭터 생성은 가능합니다."
	return "원본 로비 연출 파일이 준비되지 않았습니다. 캐릭터 생성은 가능합니다."

func _source_controls(state: Dictionary) -> void:
	_clear_source_controls()
	for role: String in ["back_effect","spine","front_effect"]:
		var layer: Dictionary = state.get("layers",{}).get(role,{})
		if not layer.get("mounted",false): continue
		for source_clip: String in layer.get("clips",[]):
			var clip: String = source_clip
			var source_role: String = role
			var ticket: int = source_selection_revision
			var preview: Control = source_presentation
			var label: String = {"back_effect":"뒤 효과","spine":"캐릭터","front_effect":"앞 효과"}[role]
			var button: Button = _button("%s · %s · 1회 재생" % [label,clip],func() -> void:
				if ticket != source_selection_revision or not is_instance_valid(preview) or source_presentation != preview: return
				var played: Dictionary = source_presentation.play_layer(source_role,clip,false)
				if not played.get("ok",false): status.text = "원본 연출을 재생하지 못했습니다.")
			source_animation_controls.add_child(button)

func _refresh_create() -> void:
	if create_button == null: return
	var length: int = name_input.text.strip_edges().length()
	create_button.disabled = length < 2 or length > 12 or catalog.profile(selected_class,selected_gender).is_empty()

func _create() -> void:
	if busy or not _roster_ready() or create_button == null or create_button.disabled: return
	busy = true
	create_button.disabled = true
	var result: Dictionary = store.create_character(name_input.text,selected_class,selected_gender,catalog)
	busy = false
	if result.get("ok",false):
		_show_roster()
		_select(str(result.get("id","")))
		status.text = "캐릭터를 생성했습니다. 접속할 캐릭터를 확인하세요."
	else:
		_refresh_create()
		status.text = str(result.get("problem","캐릭터를 저장하지 못했습니다."))

func _enter() -> void:
	if busy or not _roster_ready() or selected_id.is_empty(): return
	for entry: Dictionary in snapshot.get("characters",[]):
		if entry.id==selected_id and int(entry.get("gender_id",0))==0 and str(catalog.problem).is_empty():
			status.text="기존 캐릭터의 성별을 먼저 선택하세요. 직업과 진행은 바뀌지 않습니다."
			return
	busy = true
	var result: Dictionary = store.select_character(selected_id)
	if not result.get("ok",false):
		busy = false
		status.text = str(result.get("problem","선택을 저장하지 못했습니다."))
		return
	status.text = "세계를 불러오는 중…"
	_enter_main.call_deferred()

func _enter_main() -> void:
	# The world loads behind the progress overlay (no title a second time); the
	# Main scene itself was already loaded by the first loading.
	var loader: Script = load(LOADING_SCREEN) as Script if ResourceLoader.exists(LOADING_SCREEN) else null
	if loader != null and loader.call("open", get_tree(), MAIN, false) != null: return
	var result: Error = get_tree().change_scene_to_file(MAIN)
	if result != OK:
		busy = false
		status.text = "게임 장면을 열지 못했습니다. 저장은 유지됩니다. 다시 접속해 주세요."

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and scroll.get_global_rect().has_point(event.position):
			_touch_index = event.index
			_touch_last = event.position
		elif event.index == _touch_index: _touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index:
		scroll.scroll_vertical -= int(event.position.y - _touch_last.y)
		_touch_last = event.position

func _open_pack_installer() -> void:
	if busy: return
	if is_instance_valid(_pack_dialog):
		_pack_dialog.grab_focus()
		return
	_pack_dialog = load("res://scripts/characters/lobby_pack_install_dialog.gd").new()
	add_child(_pack_dialog)
	_pack_dialog.installed.connect(func(_result: Dictionary) -> void:
		if selected_class > 0 and selected_gender > 0 and is_instance_valid(name_input):
			_choose_gender(selected_gender)
	)
	_pack_dialog.popup_centered()
