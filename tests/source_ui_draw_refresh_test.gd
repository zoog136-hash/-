extends SceneTree
## Actual draw-signal counts and full RGBA equivalence; synthetic source UI only.
const PANEL=preload("res://scripts/ui/original_ui/source_panel.gd")
const TEXT=preload("res://scripts/ui/original_ui/source_text.gd")
const BLEND=preload("res://scripts/ui/original_ui/source_blend.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const FONT=preload("res://assets/fonts/NotoSansKR.ttf")
var checks: int=0
var failures: Array[String]=[]
var pixel_comparisons: int=0
var redraw_counts: Array[int]=[0,0]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_UI_DRAW_REFRESH_FAIL ",label)
func old_panel() -> GDScript:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_panel.gd")
	var first: int=source.find("\t# Compare actual geometry state:")
	var last: int=source.find("\nstatic func layer_material",first)
	check(first>=0 and last>first,"old setter boundary located")
	source=source.left(first)+"\t_color.vertex_colors=PackedColorArray([start,start,start,start])\n"+source.substr(last)
	var script:=GDScript.new();script.source_code=source
	check(script.reload()==OK,"old actual renderer compiles")
	return script
func options(kind: int=1) -> Dictionary:
	return {"colorType":kind,"bgColorOpacity":173,"bgColor":[255,79,126,234],"backGroundImageData":{"path":""}}
func headless_checks() -> void:
	var p:=PANEL.new();check(p.configure(null,options(),Vector2(48,28)).ok,"color panel configures")
	p.set_source_display(Color(0.8,0.5,0.3,0.6))
	var expected: PackedColorArray=p._color.vertex_colors
	for i: int in 100:p.set_source_display(Color(0.8,0.5,0.3,0.6))
	check(p._color.vertex_colors==expected,"same display retains exact colors")
	for malformed: PackedColorArray in [PackedColorArray(),PackedColorArray([Color.RED]),PackedColorArray([Color.RED,Color.GREEN,Color.BLUE,Color.WHITE]),PackedColorArray([expected[0],expected[0],expected[0],expected[0],Color.RED])]:
		p._color.vertex_colors=malformed;p.set_source_display(Color(0.8,0.5,0.3,0.6))
		check(p._color.vertex_colors==expected,"external vertex shape/color mutation repaired")
	p._options.bgColor=[255,17,49,91];p.set_source_display(Color(0.8,0.5,0.3,0.6))
	check(p._color.vertex_colors!=expected,"live source option changes still applied")
	p.set_source_display(Color(1,1,1,0));check(not p._color.visible and not p._color_copy.visible,"zero alpha still hides geometry and copy")
	p.set_source_display(Color.WHITE);check(p._color.visible and p._color_copy.visible,"nonzero alpha restores geometry and copy")
	p.free()
	p=PANEL.new();check(p.configure(null,options(0),Vector2(20,20)).ok,"image-free colorless panel")
	p.set_source_display(Color.RED);check(p._color==null,"no invented color geometry");p.free()
func view(script: Script, transparent: bool) -> Dictionary:
	var vp:=SubViewport.new();vp.size=Vector2i(96,80);vp.transparent_bg=transparent;vp.disable_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg:=ColorRect.new();bg.size=Vector2(96,80);bg.color=Color(0.18,0.35,0.69,0.77);vp.add_child(bg)
	var panel: Node2D=script.new();panel.position=Vector2(17,61)
	check(panel.configure(null,options(),Vector2(56,38)).ok,"render panel configures");vp.add_child(panel)
	return {"vp":vp,"panel":panel,"draws":0}
func pixels(v: Dictionary) -> PackedByteArray:
	var img: Image=v.vp.get_texture().get_image();img.convert(Image.FORMAT_RGBA8);return img.get_data()
func draw_count(v: Dictionary) -> void:v.draws+=1
func frame_compare(a: Dictionary,b: Dictionary,label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	pixel_comparisons+=1
	check(pixels(a)==pixels(b),label+" full RGBA equivalence")
func render_checks() -> void:
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility":check(false,"--render requires Compatibility GL");return
	for screen_copy: bool in [false,true]:
		BLEND.screen_copy_available=screen_copy;PANEL._layer_material=null
		var old: Script=old_panel()
		for transparent: bool in [false,true]:
			var a: Dictionary=view(PANEL,transparent);var b: Dictionary=view(old,transparent)
			a.panel._color.draw.connect(draw_count.bind(a));b.panel._color.draw.connect(draw_count.bind(b))
			var color:=Color(0.81,0.63,0.94,0.72)
			for v: Dictionary in [a,b]:v.panel.set_source_display(color)
			await frame_compare(a,b,"initial")
			a.draws=0;b.draws=0
			for i: int in 12:
				for v: Dictionary in [a,b]:v.panel.set_source_display(color)
				await frame_compare(a,b,"stable %d"%i)
			check(a.draws==0 and b.draws==12,"stable geometry draw dispatch 12 to zero")
			redraw_counts[0]+=b.draws;redraw_counts[1]+=a.draws
			for phase: int in 5:
				for v: Dictionary in [a,b]:
					if phase==0:v.panel._color.vertex_colors=PackedColorArray([Color.RED])
					if phase==1:v.panel._options.bgColorOpacity=89
					if phase==2:color=Color(0.2,0.7,0.4,0)
					if phase==3:color=Color(0.2,0.7,0.4,0.8)
					if phase==4:v.panel._options.bgColor=[255,44,192,69]
					v.panel.set_source_display(color)
				await frame_compare(a,b,"changed %d"%phase)
			a.vp.free();b.vp.free()
	# Draw the actual source text component with the repository Noto fixture.
	# Record CPU submission without replacing font,
	# layout or clipping, then compare against the exact previous _draw body.
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_text.gd")
	source=source.replace("\tvar hitch_started: int=FRAME_HITCH.now()\n\tvar hitch_nested: int=FRAME_HITCH.nested()\n","").replace("\tFRAME_HITCH.add_self(\"ui_text_draw\",hitch_started,hitch_nested)\n","").replace("\tFRAME_HITCH.detail(\"ui.text_draw\",hitch_started)\n","")
	var old_text:=GDScript.new();old_text.source_code=source;check(old_text.reload()==OK,"old text draw compiles")
	var text_views: Array[Dictionary]=[]
	for script: Script in [TEXT,old_text]:
		var vp:=SubViewport.new();vp.size=Vector2i(256,128);vp.transparent_bg=true;vp.disable_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
		var label: Node2D=script.new();label.position=Vector2(7,110);vp.add_child(label)
		text_views.append({"vp":vp,"label":label})
	HITCH.reset_for_test("user://ui_draw_test")
	var opt: Dictionary={"text":"UI 비용\n123 ABC","fontSize":18,"widgetOptions":{"ignoreSize":true},"vAlignment":0,"hAlignment":0,"shadowEnabled":true,"shadowOffsetX":1,"shadowOffsetY":-1,"shadowColor":[160,31,51,71],"outlineEnabled":true,"outlineSize":1,"outlineColor":[255,211,123,17]}
	for align: int in 3:
		opt.hAlignment=align;opt.vAlignment=align
		for v: Dictionary in text_views:check(v.label.configure(FONT,opt,Vector2(220,100)).ok,"actual source text configures")
		await frame_compare(text_views[0],text_views[1],"source text %d"%align)
		check(HITCH._sections.has("ui_text_draw") and HITCH._sections.ui_text_draw>=0,"real text draw records CPU section")
		var detail: Array=HITCH._details.get("ui.text_draw",[])
		check(detail.size()==3 and detail[1]>=align+1 and detail[0]>=detail[2],"text draw keeps bounded total/calls/max detail")
	for v: Dictionary in text_views:v.vp.free()
func run() -> void:
	headless_checks()
	if "--render" in OS.get_cmdline_user_args():await render_checks()
	print("SOURCE_UI_DRAW_REFRESH_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pixel_comparisons":pixel_comparisons,"stable_geometry_redraws_old_new":redraw_counts,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
