extends VBoxContainer
## Optional, explicitly estimated playback of the installed, verified SP2 bytes.
## Stored group bits and record order do not establish client direction or timing.
const PLAYBACK = preload("res://scripts/resources/current523_playback.gd")
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const TEXTURE_CACHE_LIMIT: int = 8
## The picker shows at most this many file names; the search narrows the rest.
## 989 PopupMenu rows (plus a full re-list on every typed letter) is not a
## phone-sized list.
const PICKER_LIMIT: int = 120

signal playback_frame_changed(frame_index: int)

class EstimatedCanvas:
	extends Control
	var sprite: Sprite2D
	var pan := Vector2.ZERO
	var zoom: float = 1.0
	var native_offset := Vector2i.ZERO
	var _dragging: bool = false
	var _blend_material: CanvasItemMaterial

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite = Sprite2D.new()
		sprite.centered = false
		_blend_material = CanvasItemMaterial.new()
		sprite.material = _blend_material
		add_child(sprite)
		resized.connect(_place)
		_place()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.055,0.065,0.08))
		var origin: Vector2 = size * 0.5 + pan
		draw_line(origin - Vector2(10,0),origin + Vector2(10,0),Color(0.42,0.46,0.52))
		draw_line(origin - Vector2(0,10),origin + Vector2(0,10),Color(0.42,0.46,0.52))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			accept_event()
		elif event is InputEventMouseMotion and _dragging:
			pan += event.relative
			_place()
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
			_dragging = false

	func present(texture: Texture2D,offset: Vector2i,empty: bool,options: Dictionary) -> void:
		if not is_instance_valid(sprite): return
		sprite.texture = texture
		sprite.visible = not empty and bool(options.get("enabled",false))
		native_offset = offset
		zoom = float(options.get("zoom",1.0))
		sprite.modulate = Color(1,1,1,float(options.get("opacity",1.0)))
		match str(options.get("blend","mix")):
			"add": _blend_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			"multiply": _blend_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
			_: _blend_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
		_place()

	func clear() -> void:
		if is_instance_valid(sprite):
			sprite.texture = null
			sprite.visible = false
		queue_redraw()

	func reset_pan() -> void:
		pan = Vector2.ZERO
		_place()

	func _place() -> void:
		if is_instance_valid(sprite):
			sprite.position = size * 0.5 + pan + Vector2(native_offset) * zoom
			sprite.scale = Vector2.ONE * zoom
		queue_redraw()

var current_frame_index: int = 0
var frame_time: float = 0.0
var is_playing: bool = false
var member_picker: OptionButton
var group_picker: OptionButton
var member_search: LineEdit
var status: Label
var save_status: Label
var canvas: EstimatedCanvas
var frame_progress: HSlider
var play_button: Button
var enabled_toggle: CheckBox
var world_toggle: CheckBox
var fps_input: SpinBox
var alpha_picker: OptionButton
var rgb_picker: OptionButton
var blend_picker: OptionButton
var opacity_input: SpinBox
var zoom_input: SpinBox
var loop_toggle: CheckBox
var world_x_input: SpinBox
var world_y_input: SpinBox
var target_picker: OptionButton
var _previous_button: Button
var _next_button: Button
var _reset_button: Button
var _member_rows: Array[Dictionary] = []
var _options: Dictionary = {}
var _parsed: Dictionary = {}
var _group_index: int = -1
var _texture_cache: Dictionary = {}
var _cache_order: Array[String] = []
var _loading_controls: bool = false
var _load_error: String = ""
var _render_error: String = ""

func _ready() -> void:
	name = "Current523SP2Viewer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_options = PLAYBACK.options().duplicate(true)
	_loading_controls = true
	var title := Label.new()
	title.name = "Current523EstimatedTitle"
	title.text = "SP2 추정 재생 · 원본 표시 미검증"
	add_child(title)
	var explanation := Label.new()
	explanation.text = "저장된 프레임 순서 × 설정 FPS · 원본 속도·동작·방향 미검증"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(explanation)
	enabled_toggle = CheckBox.new()
	enabled_toggle.name = "EnableCurrent523Estimate"
	enabled_toggle.text = "추정 미리보기 사용 (직접 선택)"
	enabled_toggle.button_pressed = bool(_options.get("enabled",false))
	enabled_toggle.toggled.connect(_on_enabled_changed)
	add_child(enabled_toggle)
	var search_row := HBoxContainer.new()
	add_child(search_row)
	member_search = LineEdit.new()
	member_search.name = "Current523SP2Search"
	member_search.placeholder_text = "SP2 파일명 검색"
	member_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_search.text_changed.connect(func(_query: String) -> void: _refresh_member_picker())
	search_row.add_child(member_search)
	var refresh_button := Button.new()
	refresh_button.text = "목록 새로고침"
	refresh_button.pressed.connect(refresh_members)
	search_row.add_child(refresh_button)
	member_picker = OptionButton.new()
	member_picker.name = "Current523SP2Member"
	member_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_picker.item_selected.connect(_on_member_selected)
	add_child(member_picker)
	group_picker = OptionButton.new()
	group_picker.name = "Current523SP2StoredGroup"
	group_picker.item_selected.connect(_on_group_selected)
	add_child(group_picker)
	canvas = EstimatedCanvas.new()
	canvas.name = "Current523EstimatedCanvas"
	canvas.custom_minimum_size = Vector2(0,240)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.tooltip_text = "중앙 십자 = 원문 좌표 원점 · 마우스로 끌어 이동"
	add_child(canvas)
	var transport := HBoxContainer.new()
	add_child(transport)
	_previous_button = _button(transport,"이전 프레임",func() -> void: step_frame(-1))
	_previous_button.name = "PreviousCurrent523Frame"
	play_button = _button(transport,"재생",toggle_playback)
	play_button.name = "PlayCurrent523Estimate"
	_reset_button = _button(transport,"처음",reset_playback)
	_reset_button.name = "ResetCurrent523Estimate"
	_next_button = _button(transport,"다음 프레임",func() -> void: step_frame(1))
	_next_button.name = "NextCurrent523Frame"
	_button(transport,"화면 원점",func() -> void: canvas.reset_pan())
	frame_progress = HSlider.new()
	frame_progress.name = "Current523FrameProgress"
	frame_progress.min_value = 0
	frame_progress.step = 1
	frame_progress.value_changed.connect(_on_progress_changed)
	add_child(frame_progress)
	status = Label.new()
	status.name = "Current523EstimatedStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var controls := GridContainer.new()
	controls.columns = 2
	add_child(controls)
	fps_input = _number(controls,"추정 속도 (FPS)","Current523FPS",1,60,1,float(_options.get("fps",12.0)))
	fps_input.value_changed.connect(func(value: float) -> void: _options["fps"] = value; frame_time = 0.0; _update_status())
	alpha_picker = _choice(controls,"추정 투명도","Current523AlphaPolicy",["커버 샘플 불투명","색인 0 투명"],["opaque_samples","index0_transparent"],str(_options.get("alpha_policy","opaque_samples")))
	alpha_picker.item_selected.connect(func(index: int) -> void: _options["alpha_policy"] = alpha_picker.get_item_metadata(index); _show_current_frame())
	rgb_picker = _choice(controls,"추정 RGB 확장","Current523RGBPolicy",["비트 복제","선형 확장"],["bit_replication","linear"],str(_options.get("rgb_policy","bit_replication")))
	rgb_picker.item_selected.connect(func(index: int) -> void: _options["rgb_policy"] = rgb_picker.get_item_metadata(index); _show_current_frame())
	blend_picker = _choice(controls,"추정 합성","Current523Blend",["일반 (mix)","가산 (add)","곱하기 (multiply)"],["mix","add","multiply"],str(_options.get("blend","mix")))
	blend_picker.item_selected.connect(func(index: int) -> void: _options["blend"] = blend_picker.get_item_metadata(index); _show_current_frame())
	opacity_input = _number(controls,"추정 불투명도","Current523Opacity",0,1,0.05,float(_options.get("opacity",1.0)))
	opacity_input.value_changed.connect(func(value: float) -> void: _options["opacity"] = value; _show_current_frame())
	zoom_input = _number(controls,"확대","Current523Zoom",0.25,8,0.25,float(_options.get("zoom",1.0)))
	zoom_input.value_changed.connect(func(value: float) -> void: _options["zoom"] = value; _show_current_frame())
	loop_toggle = CheckBox.new()
	loop_toggle.name = "Current523Loop"
	loop_toggle.text = "반복 재생"
	loop_toggle.button_pressed = bool(_options.get("loop",true))
	loop_toggle.toggled.connect(func(value: bool) -> void: _options["loop"] = value; _update_status())
	add_child(loop_toggle)
	world_toggle = CheckBox.new()
	world_toggle.name = "EnableCurrent523WorldEstimate"
	world_toggle.text = "게임 안 추정 표시 (충돌·전투·저장 데이터 유지)"
	world_toggle.button_pressed = bool(_options.get("world_enabled",false))
	world_toggle.toggled.connect(func(value: bool) -> void: _options["world_enabled"] = value)
	add_child(world_toggle)
	var offsets := GridContainer.new()
	offsets.columns = 2
	add_child(offsets)
	target_picker = _choice(offsets,"추정 표시 대상","Current523WorldTarget",["플레이어 옆 샘플","플레이어 외형 직접 선택"],["sample","player"],str(_options.get("world_target","sample")))
	target_picker.item_selected.connect(func(index: int) -> void:
		_options["world_target"] = target_picker.get_item_metadata(index)
		if _options.world_target == "player":
			world_x_input.value = 0
			world_y_input.value = 0)
	world_x_input = _number(offsets,"플레이어 기준 X 이동 (추정)","Current523WorldX",-1024,1024,1,float(_options.get("world_x",96.0)))
	world_x_input.value_changed.connect(func(value: float) -> void: _options["world_x"] = value)
	world_y_input = _number(offsets,"플레이어 기준 Y 이동 (추정)","Current523WorldY",-1024,1024,1,float(_options.get("world_y",0.0)))
	world_y_input.value_changed.connect(func(value: float) -> void: _options["world_y"] = value)
	var save_button := Button.new()
	save_button.name = "SaveCurrent523Estimate"
	save_button.text = "추정 재생 설정 저장"
	save_button.pressed.connect(_apply)
	add_child(save_button)
	save_status = Label.new()
	save_status.name = "Current523EstimateSaveStatus"
	save_status.text = "미리보기는 즉시 반영 · 게임 안 표시는 저장 후 적용 · 동작·방향은 저장 순서 추정"
	if not PLAYBACK.settings_problem.is_empty():
		save_status.text = PLAYBACK.settings_problem
		save_status.modulate = Color(1.0,0.45,0.4)
	save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(save_status)
	_loading_controls = false
	refresh_members()
	is_playing = bool(_options.get("enabled",false)) and frame_count() > 0
	_update_status()

func _button(parent: Control,text: String,callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _number(parent: Control,text: String,node_name: String,minimum: float,maximum: float,increment: float,value: float) -> SpinBox:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var input := SpinBox.new()
	input.name = node_name
	input.min_value = minimum
	input.max_value = maximum
	input.step = increment
	input.value = value
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(input)
	return input

func _choice(parent: Control,text: String,node_name: String,labels: Array,values: Array,selected_value: String) -> OptionButton:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var picker := OptionButton.new()
	picker.name = node_name
	for index: int in range(values.size()):
		picker.add_item(str(labels[index]))
		picker.set_item_metadata(index,values[index])
		if str(values[index]) == selected_value: picker.select(index)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(picker)
	return picker

func refresh_members() -> void:
	_member_rows.clear()
	for row: Dictionary in PLAYBACK.members(): _member_rows.append(row)
	_refresh_member_picker()
	_load_selected_member()

func _refresh_member_picker() -> void:
	if not is_instance_valid(member_picker): return
	member_picker.clear()
	var selected_index: int = -1
	var query: String = member_search.text.strip_edges().to_lower()
	var hidden: int = 0
	for row: Dictionary in _member_rows:
		var member: String = str(row.get("member",""))
		if not query.is_empty() and not member.to_lower().contains(query): continue
		if member_picker.item_count >= PICKER_LIMIT and member != str(_options.get("member","")):
			hidden += 1
			continue
		var index: int = member_picker.item_count
		member_picker.add_item(member)
		member_picker.set_item_metadata(index,member)
		if member == str(_options.get("member","")): selected_index = index
	if hidden > 0:
		member_picker.add_item("… %d개 더 · 파일명 검색으로 좁히세요" % hidden)
		member_picker.set_item_disabled(member_picker.item_count - 1,true)
		member_picker.set_item_metadata(member_picker.item_count - 1,"")
	member_picker.disabled = member_picker.item_count == 0
	if member_picker.item_count == 0:
		member_picker.add_item("설치된 SP2 없음" if _member_rows.is_empty() else "검색 결과 없음")
	member_picker.select(selected_index)

func _on_member_selected(index: int) -> void:
	if _loading_controls or member_picker.disabled or index < 0: return
	select_member(str(member_picker.get_item_metadata(index)))

func select_member(member: String) -> Dictionary:
	var known: bool = false
	for row: Dictionary in _member_rows:
		if str(row.get("member","")) == member:
			known = true
			break
	if not known: return {"ok":false,"error":"설치된 원문 목록에 없는 SP2입니다."}
	_options["member"] = member
	_refresh_member_picker()
	return _load_selected_member()

func _load_selected_member() -> Dictionary:
	_parsed = {}
	_group_index = -1
	current_frame_index = 0
	frame_time = 0.0
	_texture_cache.clear()
	_cache_order.clear()
	_load_error = ""
	_render_error = ""
	group_picker.clear()
	canvas.clear()
	if _member_rows.is_empty():
		_load_error = "523 원문 팩 설치 후 목록을 새로고침하세요."
		_update_status()
		return {"ok":false,"error":_load_error}
	var loaded: Dictionary = PLAYBACK.load_member(str(_options.get("member","Sprite/85-0.sp2")))
	if not bool(loaded.get("ok",false)):
		_load_error = str(loaded.get("error","SP2 원문을 열 수 없습니다."))
		_update_status()
		return loaded
	_parsed = loaded.get("parsed",{})
	var groups: Array = _parsed.get("groups",[])
	for index: int in range(groups.size()):
		var group: Dictionary = groups[index]
		var bit: int = int(group.get("bit",-1))
		var frames: Array = group.get("frames",[])
		group_picker.add_item("저장 그룹 bit %d · %d 프레임" % [bit,frames.size()])
		group_picker.set_item_metadata(index,bit)
		if bit == int(_options.get("group_bit",0)): _group_index = index
	if _group_index < 0 and not groups.is_empty(): _group_index = 0
	group_picker.disabled = groups.is_empty()
	if _group_index >= 0:
		group_picker.select(_group_index)
		_options["group_bit"] = int(groups[_group_index].get("bit",0))
	_show_current_frame()
	return loaded

func _on_group_selected(index: int) -> void:
	if _loading_controls or index < 0: return
	select_group_bit(int(group_picker.get_item_metadata(index)))

func select_group_bit(bit: int) -> bool:
	var groups: Array = _parsed.get("groups",[])
	for index: int in range(groups.size()):
		if int(groups[index].get("bit",-1)) != bit: continue
		_group_index = index
		_options["group_bit"] = bit
		group_picker.select(index)
		current_frame_index = 0
		frame_time = 0.0
		_show_current_frame()
		return true
	return false

func frame_count() -> int:
	var groups: Array = _parsed.get("groups",[])
	if _group_index < 0 or _group_index >= groups.size(): return 0
	var frames: Array = groups[_group_index].get("frames",[])
	return frames.size()

func _on_enabled_changed(value: bool) -> void:
	if _loading_controls: return
	_options["enabled"] = value
	is_playing = value and frame_count() > 0
	frame_time = 0.0
	_show_current_frame()

func toggle_playback() -> void:
	if is_playing:
		pause()
		return
	play()

func play() -> void:
	if is_playing: return
	if not bool(_options.get("enabled",false)) or frame_count() == 0: return
	if current_frame_index == frame_count() - 1 and not bool(_options.get("loop",true)):
		current_frame_index = 0
		_show_current_frame()
	is_playing = true
	frame_time = 0.0
	_update_status()

func pause() -> void:
	is_playing = false
	frame_time = 0.0
	_update_status()

func reset_playback() -> void:
	current_frame_index = 0
	frame_time = 0.0
	_show_current_frame()

func step_frame(amount: int) -> void:
	var count: int = frame_count()
	if count == 0: return
	is_playing = false
	frame_time = 0.0
	current_frame_index = posmod(current_frame_index + amount,count) if bool(_options.get("loop",true)) else clampi(current_frame_index + amount,0,count - 1)
	_show_current_frame()

func _on_progress_changed(value: float) -> void:
	if _loading_controls or frame_count() == 0: return
	is_playing = false
	frame_time = 0.0
	current_frame_index = clampi(int(value),0,frame_count() - 1)
	_show_current_frame()

func _process(delta: float) -> void:
	if not is_playing or not bool(_options.get("enabled",false)) or not is_visible_in_tree(): return
	var count: int = frame_count()
	if count == 0: return
	var period: float = 1.0 / clampf(float(_options.get("fps",12.0)),1.0,60.0)
	frame_time += delta
	var steps: int = floori(frame_time / period)
	if steps <= 0: return
	frame_time -= float(steps) * period
	if bool(_options.get("loop",true)):
		current_frame_index = posmod(current_frame_index + steps,count)
	else:
		current_frame_index = mini(current_frame_index + steps,count - 1)
		if current_frame_index == count - 1:
			is_playing = false
			frame_time = 0.0
	_show_current_frame()

func _show_current_frame() -> void:
	if not is_instance_valid(canvas): return
	_render_error = ""
	if frame_count() == 0 or not bool(_options.get("enabled",false)):
		canvas.clear()
		_update_status()
		return
	current_frame_index = clampi(current_frame_index,0,frame_count() - 1)
	var key: String = "%d:%d:%s:%s" % [_group_index,current_frame_index,str(_options.get("alpha_policy","opaque_samples")),str(_options.get("rgb_policy","bit_replication"))]
	var entry: Dictionary
	if _texture_cache.has(key):
		entry = _texture_cache[key]
		_cache_order.erase(key)
	else:
		var rendered: Dictionary = DECODER.render(_parsed,_group_index,current_frame_index,_options)
		if not bool(rendered.get("ok",false)):
			_render_error = str(rendered.get("error","SP2 추정 표시 실패"))
			is_playing = false
			canvas.clear()
			_update_status()
			return
		var image: Image = rendered.get("image")
		entry = {"texture":ImageTexture.create_from_image(image),"offset":rendered.get("offset",Vector2i.ZERO),"empty":bool(rendered.get("empty",false)),"bounds":rendered.get("bounds",Rect2i())}
		_texture_cache[key] = entry
	_cache_order.append(key)
	while _cache_order.size() > TEXTURE_CACHE_LIMIT:
		_texture_cache.erase(_cache_order.pop_front())
	canvas.present(entry.texture,entry.offset,entry.empty,_options)
	_update_status()
	playback_frame_changed.emit(current_frame_index)

func _update_status() -> void:
	if not is_instance_valid(status): return
	var count: int = frame_count()
	var disabled: bool = not bool(_options.get("enabled",false)) or count == 0
	play_button.disabled = disabled
	_previous_button.disabled = disabled
	_next_button.disabled = disabled
	_reset_button.disabled = disabled
	frame_progress.editable = not disabled
	frame_progress.set_block_signals(true)
	frame_progress.max_value = maxi(0,count - 1)
	frame_progress.set_value_no_signal(current_frame_index)
	frame_progress.set_block_signals(false)
	play_button.text = "일시정지" if is_playing else "재생"
	if not _load_error.is_empty():
		status.text = "SP2 추정 재생 · " + _load_error
	elif not _render_error.is_empty():
		status.text = "SP2 추정 표시 실패 · " + _render_error
	elif count == 0:
		status.text = "선택한 저장 그룹에 프레임이 없습니다."
	else:
		status.text = "%s · 프레임 %d / %d · 추정 %s FPS" % ["재생 중" if is_playing else "일시정지",current_frame_index + 1,count,str(float(_options.get("fps",12.0)))]
		status.text += " · 반복" if bool(_options.get("loop",true)) else " · 1회 재생"
		if not bool(_options.get("enabled",false)): status.text += " · 사용 선택 전 표시 꺼짐"
		var groups: Array = _parsed.get("groups",[])
		var frame: Dictionary = groups[_group_index].get("frames",[])[current_frame_index]
		if bool(frame.get("empty",false)): status.text += " · 원문 빈 프레임"

func _apply() -> Dictionary:
	# The service validates and persists atomically. Do not reload controls on a
	# failed save: both the user's edits and the previously active settings survive.
	var result: Dictionary = PLAYBACK.save_options(_options.duplicate(true))
	if not bool(result.get("ok",false)):
		save_status.text = "저장 실패 · %s · 조작값 유지" % str(result.get("error","설정을 저장할 수 없습니다."))
		save_status.modulate = Color(1.0,0.45,0.4)
		return result
	save_status.text = "추정 재생 설정 저장 완료 · 원본 표시 미검증"
	save_status.modulate = Color(0.7,1.0,0.75)
	return result

func get_playback_state() -> Dictionary:
	return {"member":str(_options.get("member","")),"group_bit":int(_options.get("group_bit",0)),"frame_index":current_frame_index,"frame_count":frame_count(),"frame_time":frame_time,"playing":is_playing,"enabled":bool(_options.get("enabled",false)),"estimated":true,"cached_textures":_texture_cache.size()}
