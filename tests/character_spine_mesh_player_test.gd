extends SceneTree
## Geometry/ownership fixtures only, not original source/render/layout acceptance.
const PLAYER = preload("res://scripts/characters/lobby_spine_mesh_player.gd")
const PAGE := "UI/Spine/fixture.png"
var checks := 0
var failures: Array[String] = []
var texture: Texture2D

func _initialize() -> void: run.call_deferred()
func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures.append(note)
		printerr("CHARACTER_SPINE_MESH_PLAYER_FAIL ",note)

func batch(offset: Vector2 = Vector2.ZERO, blend: String = "normal", alpha: float = 1.0) -> Dictionary:
	return {"page":PAGE,"blend":blend,"color":[1.0,0.6,0.2,alpha],"dark_color":[0.1,0.2,0.3,1.0],
		"positions":[offset.x,offset.y,offset.x+4.0,offset.y,offset.x+4.0,offset.y+3.0,offset.x,offset.y+3.0],
		"uvs":[0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0],"indices":[0,1,2,2,3,0]}

func fixture() -> Dictionary:
	return {"schema":PLAYER.SCHEMA,"coordinate_space":"godot_y_down","premultiplied_alpha":false,
		"source":{"json_sha256":"a".repeat(64),"atlas_sha256":"b".repeat(64),"spine_version":"3.6.52",
			"pages":{PAGE:{"sha256":"c".repeat(64),"bytes":40}}},
		"setup":{"batches":[batch()]},
		"clips":{"Exact_Case":{"duration":1.0,"fps":2.0,"frames":[
			{"time":0.0,"batches":[batch(Vector2(-4,-3),"normal",0.0)]},
			{"time":0.5,"batches":[batch(Vector2(10,20),"screen")]},
			{"time":1.0,"batches":[batch(Vector2(30,40),"multiply")]}]},
			"zero":{"duration":0.0,"fps":60.0,"frames":[{"time":0.0,"batches":[]}]}}}

func compact_fixture() -> Dictionary:
	var data: Dictionary=fixture()
	var inline_batch: Dictionary=data.setup.batches[0]
	data.geometries={"g0":{"page":PAGE,"uvs":inline_batch.uvs.duplicate(),"indices":inline_batch.indices.duplicate()}}
	var poses: Array=[data.setup]
	for clip: Dictionary in data.clips.values(): poses.append_array(clip.frames)
	for pose: Dictionary in poses:
		for item: Dictionary in pose.batches:
			item.erase("page");item.erase("uvs");item.erase("indices");item.geometry="g0"
	return data

func invalid_budget(total: int, unique: int, label: String) -> void:
	var player=PLAYER.new()
	root.add_child(player)
	player.geometry_value_budget=total
	player.unique_geometry_value_budget=unique
	var result: Dictionary=player.configure(compact_fixture(),pages())
	check(not result.get("ok",true),label+" rejected")
	check(not player.playback_status().configured and player.get_child_count()==0,label+" mounts no GPU nodes")
	player.free()

func compact_checks() -> void:
	var player=PLAYER.new()
	root.add_child(player)
	var data: Dictionary=compact_fixture()
	check(player.configure(data,pages()).get("ok",false),"shared geometry packet configures")
	var status: Dictionary=player.playback_status()
	check(status.geometry_templates==1 and status.unique_geometry_values==14 and status.geometry_values==46,"topology counted once while every position remains budgeted")
	check(player.get_preview_bounds()==Rect2(0,0,4,3),"shared geometry setup bounds preserved")
	var mesh_node: MeshInstance2D=player.get_child(0).get_child(1)
	var mesh: Mesh=mesh_node.mesh
	var arrays: Array=mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_TEX_UV]==PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]),"shared template UVs reach actual mesh")
	check(arrays[Mesh.ARRAY_INDEX]==PackedInt32Array([0,1,2,2,3,0]),"shared template indices reach actual mesh")
	check(player.play_source_animation("Exact_Case").get("ok",false),"shared source clip starts")
	check(player.get_preview_bounds()==Rect2(10,20,24,23),"shared geometry clip extent uses every visible actual pose")
	player.advance(0.5)
	check(mesh_node.mesh==mesh and player.playback_status().current_rendered_bounds==Rect2(10,20,4,3),"same shared topology reuses ArrayMesh with changing positions")
	data.geometries.g0.uvs[0]=999.0
	data.geometries.g0.indices[0]=999
	data.clips.Exact_Case.frames[2].batches[0].positions[0]=999999.0
	player.advance(0.5)
	check(mesh_node.mesh==mesh and player.playback_status().current_rendered_bounds==Rect2(30,40,4,3),"caller template and future position mutations do not alter private arrays")
	check(player._pool[0].uvs[0]==Vector2.ZERO and player._pool[0].indices[0]==0,"caller mutations cannot change packed shared topology")
	data=compact_fixture()
	data.geometries["alias"]=data.geometries.g0
	data.clips.Exact_Case.frames[2].batches[0].geometry="alias"
	var alias_result: Dictionary=player.configure(data,pages())
	check(alias_result.get("ok",false),"two IDs may alias identical caller template "+str(alias_result))
	if not alias_result.get("ok",false): player.free();return
	check(player.playback_status().geometry_templates==2 and player.playback_status().unique_geometry_values==28,"separate declared IDs budget their own normalized templates")
	player.play_source_animation("Exact_Case")
	mesh_node=player.get_child(0).get_child(1);mesh=mesh_node.mesh
	player.advance(1.0)
	check(mesh_node.mesh==mesh and player.playback_status().frame==2,"equivalent topology under another ID keeps valid dynamic mesh")
	data=compact_fixture()
	data.geometries["triangle"]={"page":PAGE,"uvs":[0,0,0.5,0,0,0.5],"indices":[0,1,2]}
	data.clips.Exact_Case.frames[1].batches[0].geometry="triangle"
	data.clips.Exact_Case.frames[1].batches[0].positions=[10,20,12,20,10,22]
	data.clips.Exact_Case.frames[2].batches[0]=batch(Vector2(30,40))
	check(player.configure(data,pages()).get("ok",false),"different shared topology transition fixture configures")
	player.play_source_animation("Exact_Case")
	mesh_node=player.get_child(0).get_child(1);mesh=mesh_node.mesh
	player.advance(0.5)
	arrays=mesh_node.mesh.surface_get_arrays(0)
	check(mesh_node.mesh!=mesh and arrays[Mesh.ARRAY_VERTEX].size()==3 and arrays[Mesh.ARRAY_INDEX]==PackedInt32Array([0,1,2]),"changed referenced topology rebuilds correct triangle mesh")
	check(arrays[Mesh.ARRAY_TEX_UV]==PackedVector2Array([Vector2.ZERO,Vector2(0.5,0),Vector2(0,0.5)]) and player.playback_status().current_rendered_bounds==Rect2(10,20,2,2),"changed referenced UVs and actual extent preserved")
	mesh=mesh_node.mesh;player.advance(0.5)
	arrays=mesh_node.mesh.surface_get_arrays(0)
	check(mesh_node.mesh!=mesh and arrays[Mesh.ARRAY_VERTEX].size()==4 and arrays[Mesh.ARRAY_INDEX]==PackedInt32Array([0,1,2,2,3,0]),"referenced to inline topology rebuilds exact quad")
	mesh=mesh_node.mesh;player.play_source_animation("Exact_Case")
	check(mesh_node.mesh==mesh and player._pool[0].geometry_key=="g0","inline to equivalent referenced topology safely reuses mesh")
	player.advance(0.5);mesh=mesh_node.mesh
	player.play_source_animation("Exact_Case")
	check(mesh_node.mesh!=mesh and player._pool[0].points.size()==4,"triangle reference back to original quad rebuilds mesh")
	data=compact_fixture();data.setup.batches.append(batch(Vector2(50,60)))
	check(player.configure(data,pages()).get("ok",false) and player.get_child_count()==2,"inline and referenced batches can coexist in a packet")
	check(player.get_preview_bounds()==Rect2(0,0,54,63),"mixed packet bounds include actual inline and referenced geometry")
	data=JSON.parse_string(JSON.stringify(compact_fixture()))
	check(data is Dictionary and player.configure(data,pages()).get("ok",false),"compact JSON round trip configures with JSON numeric indices")
	check(player.playback_status().geometry_values==46 and player.playback_status().unique_geometry_values==14,"JSON round trip retains accounting scope")
	player.geometry_value_budget=46;player.unique_geometry_value_budget=14
	check(player.configure(compact_fixture(),pages()).get("ok",false),"exact lowered resource boundaries accept valid shared packet")
	player.geometry_value_budget=PLAYER.MAX_GEOMETRY_VALUES;player.unique_geometry_value_budget=PLAYER.MAX_UNIQUE_GEOMETRY_VALUES
	data=fixture();data.geometries={}
	check(player.configure(data,pages()).get("ok",false) and player.playback_status().geometry_values==88 and player.playback_status().unique_geometry_values==0,"optional empty templates preserve inline V1 accounting")
	# Exercise the hard counter boundary without allocating a 64M-value fixture.
	player.clear()
	check(player._reserve_values(64000000) and player.playback_status().geometry_values==64000000,"64M global counter boundary accepted without allocation")
	check(not player._reserve_values(1) and player.playback_status().geometry_values==64000000,"64M global counter overflow fails before allocation")
	player.clear()
	check(player._reserve_values(16000000,true) and player.playback_status().unique_geometry_values==16000000,"16M unique counter boundary accepted without allocation")
	check(not player._reserve_values(1,true) and player.playback_status().unique_geometry_values==16000000,"unique counter overflow cannot mutate accounted total")
	player.free()
	for reference: Variant in ["unknown","",0,null,true]:
		data=compact_fixture();data.setup.batches[0].geometry=reference;invalid(data,"invalid shared reference "+str(reference))
	for field: String in ["page","uvs","indices"]:
		data=compact_fixture();data.setup.batches[0][field]=null;invalid(data,"single batch rejects shared plus inline "+field)
	for value: Variant in [null,[],"template"]:
		data=compact_fixture();data.geometries=value;invalid(data,"invalid template collection "+str(value))
	for key: Variant in ["",4,"x".repeat(257)]:
		data=compact_fixture();data.geometries[key]=data.geometries.g0;invalid(data,"invalid template ID "+str(key))
	data=compact_fixture();data.geometries.g0=[];invalid(data,"non-dictionary template")
	data=compact_fixture();data.geometries.g0.page="UI/unknown.png";invalid(data,"referenced template page absent")
	data=compact_fixture();data.geometries.g0.uvs[0]=NAN;invalid(data,"referenced template nonfinite UV")
	data=compact_fixture();data.geometries.g0.uvs[0]=-0.2;invalid(data,"referenced template UV outside texture")
	data=compact_fixture();data.geometries.g0.uvs.pop_back();invalid(data,"referenced template odd UV length")
	data=compact_fixture();data.geometries.g0.indices[0]=4;invalid(data,"referenced template bad index")
	data=compact_fixture();data.geometries.g0.indices[0]=1.5;invalid(data,"referenced template fractional index")
	data=compact_fixture();data.geometries.g0.indices.append(0);invalid(data,"referenced template nontriangle indices")
	data=compact_fixture();data.geometries["unused"]={"page":PAGE,"uvs":[0,0,1,0,0,1],"indices":[0,1,9]};invalid(data,"invalid unused template also fails closed")
	data=compact_fixture();data.setup.batches[0].positions.pop_back();invalid(data,"shared setup vertex count mismatch")
	data=compact_fixture();data.clips.Exact_Case.frames[2].batches[0].positions.append_array([0,0]);invalid(data,"shared future frame vertex count mismatch")
	data=compact_fixture();data.geometries={}
	for index: int in PLAYER.MAX_GEOMETRIES+1:data.geometries[str(index)]={}
	invalid(data,"template count cap")
	invalid_budget(45,14,"total positions plus unique topology lower budget")
	invalid_budget(46,13,"unique topology lower budget")
	for budget: int in [0,-1,64000001]:invalid_budget(budget,14,"invalid global host budget "+str(budget))
	for budget: int in [0,-1,16000001]:invalid_budget(46,budget,"invalid unique host budget "+str(budget))

func pages() -> Dictionary: return {PAGE:texture}
func invalid(data: Dictionary, label: String, supplied: Dictionary = {}) -> void:
	var player = PLAYER.new()
	root.add_child(player)
	var result: Dictionary = player.configure(data,pages() if supplied.is_empty() else supplied)
	check(not result.get("ok",true) and not str(result.get("error","")).is_empty(),label+" rejected")
	check(not player.playback_status().configured and player.get_child_count()==0,label+" mounts no GPU nodes")
	player.free()

func run() -> void:
	var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(image)
	var input: Dictionary = fixture()
	var player = PLAYER.new()
	root.add_child(player)
	var configured: Dictionary = player.configure(input,pages())
	check(configured.get("ok",false),"valid source mesh fixture configures")
	check(configured.get("autoplay_disabled")==true and configured.supported_major_minor=="3.6" and configured.source_sha256=="a".repeat(64),"factory source and no-autoplay contract")
	check(not player.is_processing() and not player.playback_status().playing,"setup never autoplays")
	check(player.get_preview_bounds()==Rect2(0,0,4,3),"setup bounds use actual indexed geometry")
	check(player.get_child_count()==1,"one setup batch owns one group")
	var group: Node = player.get_child(0)
	check(group.get_child(0) is BackBufferCopy and group.get_child(1) is MeshInstance2D,"framebuffer copy precedes actual mesh")
	var mesh_node: MeshInstance2D = group.get_child(1)
	check(mesh_node.texture==texture and mesh_node.mesh is ArrayMesh,"raw supplied texture assigned to indexed ArrayMesh")
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX] is PackedVector2Array and arrays[Mesh.ARRAY_VERTEX]==PackedVector2Array([Vector2.ZERO,Vector2(4,0),Vector2(4,3),Vector2(0,3)]),"two-dimensional vertices are exact")
	check(arrays[Mesh.ARRAY_INDEX]==PackedInt32Array([0,1,2,2,3,0]),"triangle topology preserved")
	check(arrays[Mesh.ARRAY_TEX_UV]==PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]),"atlas normalized UVs preserved")
	check(mesh_node.material is ShaderMaterial and mesh_node.material.get_shader_parameter("mesh_light")==Color(1.0,0.6,0.2,1.0),"light multiplier reaches shader")
	check(mesh_node.material.get_shader_parameter("mesh_dark")==Color(0.1,0.2,0.3,1.0),"two-color dark multiplier reaches shader")
	check(not player.play_source_animation("exact_case").get("ok",true),"clip names are exact case")
	check(player.play_source_animation("Exact_Case",false).get("ok",false),"declared source clip plays")
	check(player.playback_status().frame==0 and not mesh_node.visible,"initial transparent source pose stays transparent")
	check(player.get_preview_bounds()==Rect2(10,20,24,23) and player.playback_status().bounds_scope=="sampled_clip_extent","active extent includes delayed visible geometry without transparent origin")
	var updates: int = player.playback_status().draw_updates
	check(player.advance(0.25).get("ok",false) and player.playback_status().frame==0,"nearest earlier actual sample held")
	check(player.playback_status().draw_updates==updates,"unchanged sample avoids repeated mesh uploads")
	check(player.advance(0.25).get("ok",false) and player.playback_status().frame==1,"exact sample timestamp advances")
	check(mesh_node.visible and mesh_node.material.shader.code.contains("vec4(1.0)-source"),"screen blend uses actual destination and inverse source")
	check(player.playback_status().current_rendered_bounds==Rect2(10,20,4,3),"current geometry is separate from clip fit extent")
	check(player.advance(20.0).get("ok",false) and not player.playback_status().playing and player.playback_status().frame==2,"non-loop holds terminal source pose")
	check(mesh_node.material.shader.code.contains("source * destination"),"multiply blend uses destination factor")
	check(player.play_source_animation("Exact_Case",true).get("ok",false) and player.advance(1.5).get("ok",false),"explicit loop supported")
	check(player.playback_status().playing and is_equal_approx(player.playback_status().time,0.5) and player.playback_status().frame==1,"loop wraps duration without inferred autoplay")
	var snapshot: Dictionary = player.playback_status()
	check(not player.advance(-1.0).get("ok",true) and player.playback_status()==snapshot,"negative delta rejected without mutation")
	check(not player.advance(NAN).get("ok",true) and player.playback_status()==snapshot,"NaN delta rejected without mutation")
	player.stop()
	var frozen: Dictionary = player.playback_status()
	player.advance(2.0)
	check(player.playback_status()==frozen and not player.is_processing(),"stop freezes existing mesh and clock")
	check(player.play_source_animation("zero").get("ok",false) and not player.is_processing() and player.get_preview_bounds()==Rect2(),"zero-duration empty source frame valid")
	check(not mesh_node.visible,"smaller pose hides retired batch")
	check(not player.playback_status().original_render_verified and not player.playback_status().original_lobby_layout_verified,"fixture never certifies original rendering")
	# Input mutation after validation cannot change normalized owned meshes.
	check(player.configure(input,pages()).get("ok",false),"valid source reconfigures")
	input.setup.batches[0].positions[0]=999
	input.clips.Exact_Case.frames[1].batches[0].positions[0]=999
	player.play_source_animation("Exact_Case")
	player.advance(0.5)
	check(player.playback_status().current_rendered_bounds==Rect2(10,20,4,3),"caller mutations do not alter validated frame arrays")
	# Same topology gets a dynamic vertex update instead of new scene nodes.
	var dynamic: Dictionary=fixture()
	for frame: Dictionary in dynamic.clips.Exact_Case.frames: frame.batches=[batch(Vector2(frame.time*10,0))]
	check(player.configure(dynamic,pages()).get("ok",false),"dynamic topology fixture configures")
	player.play_source_animation("Exact_Case")
	var dynamic_group: Node=player.get_child(0)
	var dynamic_mesh: MeshInstance2D=dynamic_group.get_child(1)
	var original_mesh: Mesh=dynamic_mesh.mesh
	player.advance(0.5)
	check(player.get_child(0)==dynamic_group and dynamic_mesh.mesh==original_mesh,"constant topology reuses mesh and pool nodes")
	check(player.playback_status().current_rendered_bounds==Rect2(5,0,4,3),"dynamic vertex positions advance actual geometry")
	var unused: Dictionary=fixture()
	unused.setup.batches[0].positions.append_array([999999.0,-999999.0])
	unused.setup.batches[0].uvs.append_array([0.0,0.0])
	check(player.configure(unused,pages()).get("ok",false) and player.get_preview_bounds()==Rect2(0,0,4,3),"unreferenced vertices do not invent fit extent")
	var end_rounding: Dictionary=fixture()
	end_rounding.clips.Exact_Case.frames[2].time=1.00005
	check(player.configure(end_rounding,pages()).get("ok",false),"tiny endpoint serialization difference accepted")
	player.play_source_animation("Exact_Case")
	player.advance(1.0)
	check(player.playback_status().frame==2,"normalized endpoint remains reachable at actual clip duration")
	# All four blends and PMA are explicit. Dark alpha never selects PMA.
	var blends: Dictionary=fixture();blends.premultiplied_alpha=true;blends.setup.batches=[]
	for blend: String in PLAYER.BLENDS: blends.setup.batches.append(batch(Vector2.ZERO,blend))
	check(player.configure(blends,pages()).get("ok",false),"all declared blend modes and explicit PMA configure")
	check(player.playback_status().batch_nodes==4 and player.playback_status().premultiplied_alpha,"batch order and PMA status retained")
	for index: int in 4:
		var item: MeshInstance2D=player.get_child(index).get_child(1)
		check(item.material.get_shader_parameter("mesh_pma")==true,"explicit PMA reaches every blend "+str(index))
		check(item.material.shader.get_shader_uniform_list().size()>0,"blend shader parses "+str(index))
	player.clear()
	check(player.get_child_count()==0 and not player.playback_status().configured and player.get_preview_bounds()==Rect2(),"clear detaches all old groups and drops data ownership")
	# Invalid reconfiguration must fail closed, not retain a previous actor.
	player.configure(fixture(),pages())
	var bad: Dictionary=fixture();bad.schema="other"
	check(not player.configure(bad,pages()).get("ok",true) and player.get_child_count()==0 and not player.playback_status().configured,"invalid reconfigure clears previous actor")
	player.free()
	for property: String in ["schema","coordinate_space"]:
		bad=fixture();bad[property]="bad";invalid(bad,property)
	bad=fixture();bad.erase("premultiplied_alpha");invalid(bad,"missing alpha policy")
	bad=fixture();bad.premultiplied_alpha=1;invalid(bad,"integer alpha policy")
	for property: String in ["json_sha256","atlas_sha256"]:
		bad=fixture();bad.source[property]="a".repeat(63);invalid(bad,property)
	for version: String in ["4.3.0","3.60.1","3.5.52","3.6.","3.6.invalid","3.6.52.0",""]:
		bad=fixture();bad.source.spine_version=version;invalid(bad,"unsupported version "+version)
	bad=fixture();bad.source.pages[PAGE].bytes=0;invalid(bad,"zero page bytes")
	bad=fixture();bad.source.pages[PAGE].sha256="Z".repeat(64);invalid(bad,"uppercase nonhex page SHA")
	bad=fixture();bad.source.pages["UI/../escape.png"]=bad.source.pages[PAGE];bad.source.pages.erase(PAGE);invalid(bad,"unsafe page path",{"UI/../escape.png":texture})
	bad=fixture();invalid(bad,"missing texture",{PAGE:null})
	bad=fixture();invalid(bad,"extra undeclared texture",{PAGE:texture,"UI/extra.png":texture})
	for duration: Variant in [-1.0,NAN,INF,"1"]:
		bad=fixture();bad.clips.Exact_Case.duration=duration;invalid(bad,"bad duration "+str(duration))
	for fps: Variant in [0.0,-1.0,241.0,NAN,"60"]:
		bad=fixture();bad.clips.Exact_Case.fps=fps;invalid(bad,"bad fps "+str(fps))
	bad=fixture();bad.clips.Exact_Case.frames=[];invalid(bad,"empty frames")
	bad=fixture();bad.clips.Exact_Case.frames[0].time=0.1;invalid(bad,"missing time zero")
	bad=fixture();bad.clips.Exact_Case.frames[1].time=0.0;invalid(bad,"duplicate timestamp")
	bad=fixture();bad.clips.Exact_Case.frames[2].time=0.9;invalid(bad,"last frame not duration")
	bad=fixture();bad.clips.Exact_Case.frames[1].time=NAN;invalid(bad,"nonfinite timestamp")
	bad=fixture();bad.clips.Exact_Case.frames[1].time=1.0;bad.clips.Exact_Case.frames[2].time=1.00005;invalid(bad,"rounded duplicate endpoint")
	bad=fixture();bad.clips.Exact_Case.duration=0.00001;bad.clips.Exact_Case.frames=[{"time":0.0,"batches":[]}];invalid(bad,"nonzero duration requires endpoint pose")
	for property: String in ["positions","uvs","indices","color"]:
		bad=fixture();bad.setup.batches[0][property]=[];invalid(bad,"empty "+property)
	bad=fixture();bad.setup.batches[0].positions[0]=NAN;invalid(bad,"nonfinite vertex")
	bad=fixture();bad.setup.batches[0].positions[1]=PLAYER.MAX_COORDINATE+1.0;invalid(bad,"oversized vertex")
	bad=fixture();bad.setup.batches[0].uvs[0]=INF;invalid(bad,"nonfinite UV")
	bad=fixture();bad.setup.batches[0].uvs[0]=1.2;invalid(bad,"UV outside page")
	for index: Variant in [-1,4,1.5,"0",true]:
		bad=fixture();bad.setup.batches[0].indices[0]=index;invalid(bad,"invalid triangle index "+str(index))
	bad=fixture();bad.setup.batches[0].indices.append(0);invalid(bad,"non-triangle topology")
	bad=fixture();bad.setup.batches[0].page="UI/unknown.png";invalid(bad,"undeclared mesh page")
	bad=fixture();bad.setup.batches[0].blend="unknown";invalid(bad,"unknown blend")
	for property: String in ["color","dark_color"]:
		bad=fixture();bad.setup.batches[0][property][0]=1.1;invalid(bad,"invalid "+property)
		bad=fixture();bad.setup.batches[0][property][1]=NAN;invalid(bad,"nonfinite "+property)
	bad=fixture();bad.setup.batches.resize(PLAYER.MAX_BATCHES+1);invalid(bad,"batch allocation cap")
	compact_checks()
	print("CHARACTER_SPINE_MESH_PLAYER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"INLINE_AND_SHARED_GEOMETRY_OWNERSHIP_BUDGET_LIFETIME_AND_MATERIAL_FIXTURES_NOT_ORIGINAL_RENDER_OR_DEVICE_ACCEPTANCE"}))
	quit(0 if failures.is_empty() else 1)
