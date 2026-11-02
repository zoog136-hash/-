extends SceneTree
## Deterministic 30FPS engine writer, not real-time gameplay or Android footage.
const VIEW = preload("res://scripts/animation/original_source_preview.gd")
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
var canvas: SubViewport
var actors: Array = []
var phase_label: Label
var records: Array = [
	{"card":19381,"body":23369,"name":"젠","label":"전설 · mu23372 미확보"},
	{"card":21582,"body":24967,"name":"아인하사드의 그림자","label":"전설 · mu24970 미확보"},
	{"card":24193,"body":27891,"name":"벨라","label":"전설 · mu27894 미확보"},
	{"card":24504,"body":28439,"name":"해방된 할파스 · 기본","label":"28439 · 실존 sc/mu 표시"},
	{"card":24504,"body":28514,"option":24,"name":"할파스 · 녹색 옵션","label":"28514 · sc28516/mu28517 미확보"},
	{"card":24504,"body":28519,"option":4,"name":"할파스 · 적색 옵션","label":"28519 · sc28521/mu28522 미확보"},
	{"card":24504,"body":28524,"option":14,"name":"할파스 · 청색 옵션","label":"28524 · sc28526/mu28527 미확보"}]
func _initialize() -> void: call_deferred("run")
func label_at(text: String, point: Vector2, width: float, font_size: int=18) -> Label:
	var label := Label.new();label.text=text;label.position=point;label.size=Vector2(width,80);label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"));label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;canvas.add_child(label);return label
func run() -> void:
	root.size=Vector2i(1920,720);DisplayServer.window_set_size(root.size)
	canvas=SubViewport.new();canvas.size=Vector2i(1920,720);canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(canvas)
	var bg:=ColorRect.new();bg.color=Color("17222d");bg.size=canvas.size;canvas.add_child(bg)
	label_at("현재 적용본 · 원본 재생기 / 호환 합성 · 원작 완전동등성 미검증",Vector2(0,10),1920,24)
	phase_label=label_at("",Vector2(0,52),1920,22)
	label_at("위: 게임 기본 배율 1×  /  아래: 확인용 2×  ·  원본 그림·순서·시간값 유지",Vector2(0,635),1920,18)
	label_at("30FPS 엔진 프레임 출력 · 실시간 녹화/Android 아님 · 미확보 sc/mu는 표시되지 않음",Vector2(0,672),1920,16)
	var manifest: String=INSTALL.active_root().path_join("manifest.json")
	for i: int in range(records.size()):
		var row: Dictionary=records[i];var x:float=20+i*270
		label_at(str(row.name),Vector2(x,98),260,18)
		label_at(str(row.label),Vector2(x,130),260,12)
		for zoom: float in [1.0,2.0]:
			var view:=VIEW.new();view.playback_mode_override="compatible";canvas.add_child(view)
			view.position=Vector2(x+100,280 if zoom==1.0 else 550);view.scale=Vector2.ONE*zoom
			var context: Dictionary={"active_card_options":{}}
			if row.has("option"):context.active_card_options["m508:1:24504"]=row.option
			if not view.configure("transform:m508:1:"+str(row.card),manifest,context) or int(view._record.get("source_sprite_id",-1))!=int(row.body):push_error("Exact source selection failed "+str(row));quit(1);return
			view.advance_source(0.0,"idle",2,0,false);actors.append(view)
		label_at("1×",Vector2(x,300),260,13);label_at("2×",Vector2(x,575),260,13)
	var receipt: Dictionary={"engine":Engine.get_version_info(),"frames":240,"fps":30,"clock":"fixed_delta_engine_writer_not_realtime","front_game_facing":2,"source_stored_direction":5,"cards":records,"manifest":manifest,"visual_equivalence":false}
	for frame: int in range(240):
		var t:float=float(frame)/30.0
		var role: String="idle" if t<2.0 or t>=7.0 else "walk" if t<4.0 else "attack"
		phase_label.text="대기" if role=="idle" else "이동 (원본 walk)" if role=="walk" else "공격 (기존 타격 판정과 독립된 시각 재생)"
		var sequence:int=1+int(t-4.0) if role=="attack" else 0
		for view: Node2D in actors:view.advance_source(1.0/30.0,role,2,sequence,role=="attack")
		await process_frame;await RenderingServer.frame_post_draw
		var error:int=canvas.get_texture().get_image().save_png("/tmp/native-four-review/v2-frames/%04d.png"%frame)
		if error!=OK:push_error("capture write failed");quit(1);return
		if frame%60==0:print("NATIVE_FOUR_CAPTURE ",frame,"/240")
	var f:=FileAccess.open("/tmp/native-four-review/capture.json",FileAccess.WRITE);f.store_string(JSON.stringify(receipt,"\t"));f.close()
	for view: Node2D in actors:view.free()
	print("NATIVE_FOUR_CAPTURE_DONE 240 frames");quit(0)
