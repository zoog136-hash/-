extends SceneTree
## Optional synthetic GL observation, not a timing gate or Android claim.
## godot --path . --script res://tools/benchmarks/benchmark_original_ui_sprite_copy.gd
## Optional: -- --output=/absolute/path/result.json
## The full-copy baseline retains disabled helper callbacks. The measured
## updater interval brackets all actual production frame_pre_draw callbacks.
const COPY=preload("res://scripts/ui/original_ui/source_sprite_back_buffer.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
var rows:Array=[]
var pre_started:int=0
var callback_us:int=0
func pre_begin():pre_started=Time.get_ticks_usec()
func pre_end():callback_us=Time.get_ticks_usec()-pre_started
class FakePack extends RefCounted:
	var manifest:Dictionary={}
	var manifest_sha256:String="synthetic-only"
	var tree:Dictionary={}
	var pixel:Texture2D
	func scene(_member:String)->Dictionary:return tree.duplicate(true)
	func texture(_ref:Dictionary,_cocos:bool=false)->Texture2D:return pixel
func widget(name_value:String,position_value:Array)->Dictionary:
	return {"name":name_value,"actionTag":0,"rotationSkew":[0.0,0.0],"zOrder":0,"visible":1,"alpha":180,"position":position_value,"scale":[1.0,1.0],"anchorPoint":[0.0,0.0],"color":[255,200,225,170],"size":[24.0,24.0],"flipX":0,"flipY":0,"ignoreSize":0,"touchEnabled":0,"frameEvent":"","customProperty":"","callBackType":null,"callBackName":null}
func _initialize():run.call_deferred()
func make_pack()->RefCounted:
	var p:=FakePack.new()
	var image:=Image.create(24,24,false,Image.FORMAT_RGBA8)
	for y:int in 24:
		for x:int in 24:image.set_pixel(x,y,Color(float(x)/48.0,float(y)/48.0,0.25,0.5))
	p.pixel=ImageTexture.create_from_image(image);p.pixel.set_meta("cocos_premultiplied",true)
	var children:Array=[]
	for idx:int in 150:
		children.append({"_offset":1000+idx,"classname":"Sprite","children":[],"options":{"nodeOptions":widget("Sprite%d"%idx,[float(15+(idx%15)*34),-float(45+(idx/15)*34)]),"blendFunc":[1,771],"fileNameData":{"path":"synthetic.png","plist":"","type":0}}})
	p.tree={"nodeTree":{"_offset":1,"classname":"Node","children":children,"options":{"nodeOptions":widget("Root",[0.0,0.0])}}}
	return p
func median(values:Array)->float:
	var v:Array=values.duplicate();v.sort();return float(v[v.size()/2])
func run():
	if DisplayServer.get_name()=="headless" or not COPY.supports_runtime(Engine.get_version_info(),RenderingServer.get_current_rendering_method()):
		printerr("SPRITE_SCENE_BENCH_REQUIRES_VERIFIED_COMPATIBILITY_GL")
		quit(2);return
	var output_path:String=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var pack:RefCounted=make_pack()
	var vp:=SubViewport.new();vp.size=Vector2i(640,480);vp.disable_3d=true;vp.transparent_bg=false;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene:=SCENE.new();var configured:Dictionary=scene.configure(pack,"UI/Synthetic150.csb")
	if not configured.get("ok",false):print("SPRITE_SCENE_BENCH_ERROR ",configured);scene.free();quit(1);return
	RenderingServer.frame_pre_draw.connect(pre_begin)
	vp.add_child(scene)
	RenderingServer.frame_pre_draw.connect(pre_end)
	var entries:Array=[]
	for node:Node2D in scene.source_nodes.values():
		if not node.has_meta("source_sprite"):continue
		var sprite:Sprite2D=node.get_meta("source_sprite")
		for child:Node in sprite.get_parent().get_children():
			if child is BackBufferCopy:entries.append([sprite,child])
	if entries.size()!=150:print("SPRITE_SCENE_BENCH_ERROR count ",entries.size());quit(1);return
	var gpu_method:bool=RenderingServer.has_method("viewport_get_measured_render_time_gpu")
	var cpu_method:bool=RenderingServer.has_method("viewport_get_measured_render_time_cpu")
	var enable_method:bool=RenderingServer.has_method("viewport_set_measure_render_time")
	if enable_method:RenderingServer.call("viewport_set_measure_render_time",vp.get_viewport_rid(),true)
	for offscreen:bool in [false,true]:
		scene.position=Vector2(10000,0) if offscreen else Vector2.ZERO
		var baseline:PackedByteArray
		for run_index:int in 4:
			var use_rect:bool=run_index in [1,2]
			for entry:Array in entries:
				entry[1]._runtime_supported=use_rect
				entry[1].copy_mode=BackBufferCopy.COPY_MODE_RECT if use_rect else BackBufferCopy.COPY_MODE_VIEWPORT
			var elapsed:Array=[];var updater:Array=[];var cpu:Array=[];var gpu:Array=[]
			for frame:int in 34:
				var started:int=Time.get_ticks_usec()
				await process_frame
				await RenderingServer.frame_post_draw
				if frame>=10:
					elapsed.append(Time.get_ticks_usec()-started);updater.append(callback_us)
					if cpu_method:cpu.append(RenderingServer.call("viewport_get_measured_render_time_cpu",vp.get_viewport_rid()))
					if gpu_method:gpu.append(RenderingServer.call("viewport_get_measured_render_time_gpu",vp.get_viewport_rid()))
			var image:Image=vp.get_texture().get_image();image.convert(Image.FORMAT_RGBA8)
			if run_index==0:baseline=image.get_data()
			var row:Dictionary={"offscreen":offscreen,"run":run_index,"copy":"rect" if use_rect else "viewport","sprites":150,"viewport":[640,480],"samples":elapsed.size(),"median_frame_wall_us":median(elapsed),"median_updater_us":median(updater),"cpu_query_supported":cpu_method,"gpu_query_supported":gpu_method,"median_viewport_cpu_ms":median(cpu) if not cpu.is_empty() else null,"median_viewport_gpu_ms":median(gpu) if not gpu.is_empty() else null,"pixels_equal":baseline==image.get_data()}
			rows.append(row);print("SPRITE_SCENE_BENCH_ROW ",JSON.stringify(row))
	var result:Dictionary={"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"synthetic_only":true,"actual_sprite_scene":true,"actual_guarded_helper":true,"baseline_has_disabled_helper_callbacks":true,"rows":rows}
	if not output_path.is_empty():
		var file:=FileAccess.open(output_path,FileAccess.WRITE)
		if file==null:
			printerr("SPRITE_SCENE_BENCH_OUTPUT_FAILED ",output_path)
			quit(1);return
		file.store_string(JSON.stringify(result,"  "));file.close()
	print("SPRITE_SCENE_BENCH_RESULT ",JSON.stringify(result))
	var exact:bool=true
	for row:Dictionary in rows:exact=exact and row.pixels_equal
	quit(0 if exact else 1)
