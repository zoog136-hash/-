extends SceneTree
## Compare production font validation, wrapping and drawing with prior routing.
## Uses the tracked FontFile; text/options are synthetic, not private CSB assets.
const TEXT=preload("res://scripts/ui/original_ui/source_text.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
var checks: int=0
var failures: Array[String]=[]
var pixel_comparisons: int=0
var samples: Array=[]
var font: FontFile=load("res://assets/fonts/NotoSansKR.ttf")
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_TEXT_COSTS_FAIL ",label)
func options(value: String,alignment: int=0) -> Dictionary:
	return {"text":value,"fontSize":20,"hAlignment":alignment,"vAlignment":0,"_type":"TextOptions","isCustomSize":true,"widgetOptions":{"ignoreSize":false,"nested":[{"value":7}]},"shadowEnabled":false,"shadowOffsetX":2,"shadowOffsetY":-2,"shadowColor":[180,20,40,80],"outlineEnabled":false,"outlineSize":2,"outlineColor":[255,120,40,20]}
func instrument(previous: bool) -> GDScript:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_text.gd")
	if previous:
		source=source.replace("original_options.duplicate()","original_options.duplicate(true)")
		var begin: int=source.find("\t\tvar x: float=0.0\n")
		var end: int=source.find("\t\tvar pos:=Vector2(x,y)",begin)
		check(begin>=0 and end>begin,"prior draw block located")
		source=source.left(begin)+"\t\tvar width: float=original_font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x\n\t\tvar x: float=0.0\n\t\tif int(original_options.hAlignment)==1:x=(original_size.x-width)/2.0\n\t\telif int(original_options.hAlignment)==2:x=original_size.x-width\n"+source.substr(end)
	source=source.replace("original_options.duplicate(true)","_test_copy(original_options,true)")
	source=source.replace("options.duplicate(true)","_test_copy(options,true)")
	source=source.replace("original_options.duplicate()","_test_copy(original_options,false)")
	source=source.replace("original_font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)","_test_width(text_value,font_size)")
	source+="\nvar deep_copies: int=0\nvar width_calls: int=0\nfunc _test_copy(value: Dictionary,deep: bool) -> Dictionary:\n\tif deep:deep_copies+=1\n\treturn value.duplicate(deep)\nfunc _test_width(value: String,font_size: int) -> Vector2:\n\twidth_calls+=1\n\treturn original_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)\n"
	var script:=GDScript.new();script.source_code=source
	check(script.reload()==OK,"instrumented renderer compiles")
	return script
func state(node: Node2D) -> Dictionary:
	return {"font":node.original_font,"options":node.original_options,"size":node.original_size,"lines":node.source_lines}
func headless(old: Script,current: Script) -> void:
	var a: Node2D=old.new();var b: Node2D=current.new()
	var input: Dictionary=options("Knight 가방")
	check(a.configure(font,input,Vector2(240,90))==b.configure(font,input,Vector2(240,90)),"initial configure equivalent")
	input.widgetOptions.nested[0].value=999
	check(b.original_options.widgetOptions.nested[0].value==7,"public configure retains detached nested snapshot")
	a.deep_copies=0;b.deep_copies=0
	for value: String in ["Knight","가방","12345","","Knight","가방","1","12","123","1234","12345","Knight"]:
		var old_snapshot: Dictionary=b.original_options
		var preserved: Dictionary=old_snapshot.duplicate(true)
		check(a.set_source_text(value)==b.set_source_text(value),"update result matches")
		check(state(a)==state(b),"font/options/line layout match")
		check(old_snapshot==preserved and not is_same(old_snapshot,b.original_options),"successful update replaces snapshot without mutating prior aliases")
		check(not is_same(old_snapshot.widgetOptions,b.original_options.widgetOptions),"nested output remains detached")
	check(a.deep_copies==24 and b.deep_copies==12,"12 updates halve deep copies without removing commit snapshot")
	samples.append({"updates":12,"old_deep_copies":a.deep_copies,"new_deep_copies":b.deep_copies})
	for scenario: String in ["missing_glyph","multiline_width","wrap_height","wrap_bad_contract","wrap_ok"]:
		var opts: Dictionary=options("Before")
		for node: Node2D in [a,b]:check(node.configure(font,opts,Vector2(200,80)).ok,"reset accepted")
		var text_value: String="A"+String.chr(0x10ffff)
		if scenario=="multiline_width":text_value="Knight Knight Knight Knight\nB"
		if scenario.begins_with("wrap"):
			for node: Node2D in [a,b]:node.original_options._cocos_wrap=true
			text_value="가방 가방 가방 가방 가방"
		if scenario=="wrap_height":
			for node: Node2D in [a,b]:node.original_size=Vector2(50,10)
		if scenario=="wrap_bad_contract":
			for node: Node2D in [a,b]:node.original_options.isCustomSize=false
		var before: Dictionary=state(b).duplicate(true)
		var reference: Dictionary=b.original_options
		var result: Dictionary=b.set_source_text(text_value)
		check(a.set_source_text(text_value)==result and state(a)==state(b),"validation and output match: "+scenario)
		if scenario!="wrap_ok":check(not result.ok and state(b)==before and is_same(reference,b.original_options),"failed update preserves previous owner: "+scenario)
		else:check(result.ok,"valid CJK wrap retained")
	# Even identical text rechecks live font/layout state.
	for node: Node2D in [a,b]:node.original_font=null
	var before: Dictionary=b.original_options
	check(a.set_source_text(str(a.original_options.text))==b.set_source_text(str(b.original_options.text)),"same text revalidates missing font")
	check(is_same(before,b.original_options),"font failure does not commit shallow candidate")
	check(HITCH._details.has("ui.text_update"),"inclusive update diagnostic emitted")
	a.free();b.free()
func viewport(script: Script) -> Dictionary:
	var vp:=SubViewport.new();vp.size=Vector2i(300,160);vp.transparent_bg=true;vp.disable_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var node: Node2D=script.new();node.position=Vector2(20,130);vp.add_child(node)
	return {"vp":vp,"node":node}
func pixels(old: Script,current: Script) -> void:
	var a: Dictionary=viewport(old);var b: Dictionary=viewport(current)
	for alignment: int in [0,1,2,7]:
		for variant: int in 7:
			var value: String="가방 Knight" if variant%2==0 else "가방\nKnight"
			var opts: Dictionary=options(value,alignment)
			opts.vAlignment=variant%3;opts.shadowEnabled=variant%2==1;opts.outlineEnabled=variant>=3;opts._line_spacing=2.0
			var extent:=Vector2(240,90 if variant!=5 else 25)
			if variant==6:opts._cocos_wrap=true;opts.text="가방 가방 가방 가방 가방";extent=Vector2(120,90)
			check(a.node.configure(font,opts,extent)==b.node.configure(font,opts,extent),"render configuration equivalent")
			await process_frame;await RenderingServer.frame_post_draw
			var before_a: int=a.node.width_calls;var before_b: int=b.node.width_calls
			a.node.queue_redraw();b.node.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			var count_a: int=a.node.width_calls-before_a;var count_b: int=b.node.width_calls-before_b
			check(count_a>0 and (count_b==count_a if alignment in [1,2] else count_b==0),"only center/right alignment measures draw width")
			if variant==0:samples.append({"alignment":alignment,"old_width_calls":count_a,"new_width_calls":count_b})
			var image_a: Image=a.vp.get_texture().get_image();var image_b: Image=b.vp.get_texture().get_image()
			check(image_a.get_data()==image_b.get_data(),"full RGBA identical across alignment/shadow/outline/height")
			if variant==0:check(not image_b.is_invisible(),"comparison contains actual font pixels")
			pixel_comparisons+=1
			check(a.node.set_source_text("Changed 가방")==b.node.set_source_text("Changed 가방"),"rendered update result equivalent")
			await process_frame;await RenderingServer.frame_post_draw
			check(a.vp.get_texture().get_image().get_data()==b.vp.get_texture().get_image().get_data(),"updated RGBA identical")
			pixel_comparisons+=1
	a.vp.free();b.vp.free()
func run() -> void:
	HITCH.reset_for_test("user://source_text_costs")
	var old: Script=instrument(true);var current: Script=instrument(false)
	headless(old,current)
	if "--render" in OS.get_cmdline_user_args():await pixels(old,current)
	print("SOURCE_TEXT_COSTS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"pixel_comparisons":pixel_comparisons,"android_measured":false}))
	quit(0 if failures.is_empty() else 1)
