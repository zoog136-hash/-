extends SceneTree
## Production mesh/pose/shader fixture. Synthetic texels are tests, never game art.
## --render checks fixed-function RGB on a real GPU; not Android/native acceptance.
const PLAYER = preload("res://scripts/characters/lobby_spine_mesh_player.gd")
const POLICY = preload("res://scripts/ui/original_ui/source_blend.gd")
const PAGE = "UI/Spine/fixture.png"
var checks := 0
var failures: Array[String] = []
var render_checks := 0
var texel := Color(0.3,0.2,0.1,0.5)
var light := Color(0.8,0.6,0.4,0.7)
var dark := Color(0.1,0.2,0.15,1.0)
var background := Color(0.18,0.26,0.34,1.0)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures.append(note)

func fixture(blend: String, pma: bool) -> Dictionary:
	var batch := {"page":PAGE,"blend":blend,"color":[light.r,light.g,light.b,light.a],"dark_color":[dark.r,dark.g,dark.b,dark.a],"positions":[0,0,16,0,16,16,0,16],"uvs":[0,0,1,0,1,1,0,1],"indices":[0,1,2,2,3,0]}
	return {"schema":PLAYER.SCHEMA,"coordinate_space":"godot_y_down","premultiplied_alpha":pma,"source":{"json_sha256":"a".repeat(64),"atlas_sha256":"b".repeat(64),"spine_version":"3.6.52","pages":{PAGE:{"sha256":"c".repeat(64),"bytes":16}}},"setup":{"batches":[batch]},"clips":{"hold":{"duration":0.0,"fps":60.0,"frames":[{"time":0.0,"batches":[batch.duplicate(true)]}]}}}

func expected(blend: String, pma: bool) -> Vector3:
	var t := Vector3(texel.r,texel.g,texel.b)
	var l := Vector3(light.r,light.g,light.b)
	var d := Vector3(dark.r,dark.g,dark.b)
	if pma: l *= light.a; d *= light.a
	var s: Vector3 = (Vector3.ONE * ((texel.a-1.0) * (1.0 if pma else 0.0) + 1.0)-t)*d+t*l
	var a: float = texel.a*light.a
	var dest := Vector3(background.r,background.g,background.b)
	if blend == "multiply": return dest * (s+Vector3.ONE*(1.0-a)).clamp(Vector3.ZERO,Vector3.ONE)
	if blend == "screen": return (dest+s).clamp(Vector3.ZERO,Vector3.ONE)
	if blend == "additive": return (dest+s*(1.0 if pma else a)).clamp(Vector3.ZERO,Vector3.ONE)
	return s*(1.0 if pma else a)+dest*(1.0-a)

func run() -> void:
	var previous: bool = POLICY.screen_copy_available
	var render: bool = "--render" in OS.get_cmdline_user_args()
	if render and DisplayServer.get_name()=="headless":
		check(false,"--render requires an actual renderer")
		render = false
	var viewport := SubViewport.new()
	viewport.size=Vector2i(32,32)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var fill := ColorRect.new()
	fill.size=Vector2(32,32);fill.color=background
	viewport.add_child(fill)
	var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(texel)
	texel=image.get_pixel(0,0) # Match actual byte quantization in the source sampler.
	var texture := ImageTexture.create_from_image(image)
	var player = PLAYER.new()
	viewport.add_child(player)
	player.position=Vector2(8,8)
	for pma: bool in [false,true]:
		for blend: String in PLAYER.BLENDS:
			POLICY.screen_copy_available=false
			var configured: Dictionary=player.configure(fixture(blend,pma),{PAGE:texture})
			check(configured.get("ok",false),"production pose configures "+blend+str(pma)+": "+str(configured))
			if configured.get("ok",false):
				check(player.play_source_animation("hold").get("ok",false) and not player.is_processing(),"explicit zero-duration source pose holds")
			if player._pool.is_empty(): continue
			var entry: Dictionary=player._pool[0]
			var item: MeshInstance2D=entry.item
			var mesh: Mesh=item.mesh
			var original: PackedByteArray=texture.get_image().get_data()
			var fixed: Shader=item.material.shader
			check(not fixed.code.contains("hint_screen_texture") and not fixed.code.contains("SCREEN_UV"),"fixed shader never samples destination "+blend)
			check(entry.copy.copy_mode==BackBufferCopy.COPY_MODE_DISABLED,"fixed pose disables copy "+blend)
			check(item.material.get_shader_parameter("mesh_light")==light and item.material.get_shader_parameter("mesh_dark")==dark and item.material.get_shader_parameter("mesh_pma")==pma,"two-color and PMA uniforms preserved")
			check(fixed.get_shader_uniform_list().size()>0,"fixed shader parses "+blend)
			if render:
				await process_frame
				await RenderingServer.frame_post_draw
				var observed: Color=viewport.get_texture().get_image().get_pixel(12,12)
				var wanted: Vector3=expected(blend,pma)
				render_checks+=1
				check(Vector3(observed.r,observed.g,observed.b).distance_to(wanted)<0.025,"fixed RGB "+blend+str(pma)+": "+str(observed)+" expected "+str(wanted))
			POLICY.screen_copy_available=true
			player._refresh_blend_policy()
			check(item.material.shader.code.contains("hint_screen_texture") and item.material.shader.code.contains("blend_disabled"),"desktop shader restored on stopped pose")
			check(entry.copy.copy_mode!=BackBufferCopy.COPY_MODE_DISABLED,"desktop copy resumes")
			POLICY.screen_copy_available=false
			player._refresh_blend_policy()
			check(item.material.shader==fixed and entry.copy.copy_mode==BackBufferCopy.COPY_MODE_DISABLED,"fixed cache and disabled copy restored")
			check(item.mesh==mesh and item.texture==texture and texture.get_image().get_data()==original and item.visible,"policy preserves geometry, texture pixels and visibility")
	player.free();viewport.free()
	POLICY.screen_copy_available=previous
	print("LOBBY_SPINE_ANDROID_BLEND "+JSON.stringify({"checks":checks,"render_checks":render_checks,"failures":failures,"screen_fallback":"fixed_add_host_approximation","scope":"production_pose_shader_synthetic_fixture_not_android_or_original_equivalence"}))
	quit(0 if failures.is_empty() else 1)
