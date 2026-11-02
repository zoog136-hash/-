extends SceneTree
const VIEW=preload("res://scripts/animation/original_source_preview.gd")
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
var canvas:SubViewport
var phase:Label
var views:Array=[]
func _initialize() -> void:call_deferred("run")
func label_at(text:String,point:Vector2,width:float,size:int=20) -> Label:
	var node:=Label.new();node.text=text;node.position=point;node.size=Vector2(width,65);node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font",load("res://assets/fonts/NotoSansKR.ttf"));node.add_theme_font_size_override("font_size",size);canvas.add_child(node);return node
func run() -> void:
	canvas=SubViewport.new();canvas.size=Vector2i(1920,840);canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(canvas)
	var bg:=ColorRect.new();bg.color=Color("17222d");bg.size=canvas.size;canvas.add_child(bg)
	label_at("할파스 무기 선택 수정 · 원본 무기별 몸체 동작 사용 / 새 무기 합성 없음",Vector2(0,8),1920,25)
	phase=label_at("",Vector2(0,46),1920,22)
	var records:Array=[{"body":28439,"option":0,"name":"기본 할파스 28439"},{"body":28514,"option":24,"name":"녹색 옵션 28514"},{"body":28519,"option":4,"name":"적색 옵션 28519"},{"body":28524,"option":14,"name":"청색 옵션 28524"}]
	var manifest:String=INSTALL.active_root().path_join("manifest.json")
	for i:int in range(4):
		var row:Dictionary=records[i];var x:float=12+i*475
		label_at(row.name,Vector2(x,90),455,21)
		label_at("수정 전 · 맨손용 동작 3/0/1",Vector2(x,126),455,17)
		label_at("수정 후 · 한손검(type1) 7/4/5",Vector2(x,425),455,17)
		for after:bool in [false,true]:
			for zoom:float in [1.0,2.0]:
				var view:=VIEW.new();view.playback_mode_override="compatible";canvas.add_child(view)
				view.position=Vector2(x+(70 if zoom==1.0 else 270),650 if after else 335);view.scale=Vector2.ONE*zoom
				var context:Dictionary={"source_weapon_type":1 if after else 0,"local_weapon_type":"한손검" if after else "이전 generic 선택","active_card_options":{"m508:1:24504":row.option}}
				if not view.configure("transform:m508:1:24504",manifest,context) or int(view._record.source_sprite_id)!=int(row.body) or (after and view.source_weapon_status.state!="selected_source_weapon_actions"):push_error("exact source option/weapon selection failed");quit(1);return
				view.advance_source(0.0,"idle",2,0,false);views.append(view)
		label_at("1×                       2×",Vector2(x,370),455,14);label_at("1×                       2×",Vector2(x,700),455,14)
	label_at("동일 정면 · 원본 픽셀/프레임/시간값 유지 · 호환 합성 / 원작 완전동등성 미검증",Vector2(0,753),1920,18)
	label_at("30FPS 엔진 프레임 출력 · 실시간/Android 아님 · 색상 옵션 sc/mu 미확보 상태는 그대로",Vector2(0,793),1920,17)
	for frame:int in range(180):
		var t:float=float(frame)/30.0;var role:String="idle" if t<2.0 else "walk" if t<4.0 else "attack"
		phase.text="대기" if role=="idle" else "이동 · 원본 walk" if role=="walk" else "공격 · 실제 게임 타격 시계는 변경하지 않음"
		var sequence:int=1+int(t-4.0) if role=="attack" else 0
		for view:Node2D in views:view.advance_source(1.0/30.0,role,2,sequence,role=="attack")
		await process_frame;await RenderingServer.frame_post_draw
		if canvas.get_texture().get_image().save_png("/tmp/halpas-weapon-review/frames/%04d.png"%frame)!=OK:push_error("frame write failed");quit(1);return
		if frame%60==0:print("HALPAS_WEAPON_BEFORE_AFTER ",frame,"/180")
	for view:Node2D in views:view.free()
	print("HALPAS_WEAPON_BEFORE_AFTER_DONE 180 frames");quit(0)
