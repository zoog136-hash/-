extends SceneTree
const RUN=preload("res://scripts/maps/source_map_runtime.gd")
const RENDERER=preload("res://scripts/maps/source_map_runtime_renderer.gd")
const STORE=preload("res://scripts/maps/source_map_texture_store.gd")
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);printerr("SOURCE84_RENDERER_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func settle(renderer: Node) -> int:
	for frame: int in range(240):
		await process_frame
		if not renderer.waiting_for_visible and int(renderer.texture_store.stats().pending)==0:return frame+1
	check(false,"stream completed before fixture deadline")
	return 240
func run() -> void:
	root.size=Vector2i(1152,648)
	var field=RUN.load_field("source_77")
	check(field!=null,"actual source77 field loaded with verified collision and art")
	if field==null:quit(1);return
	var entry:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	check(field.point_clear(entry,4),"actual entry clearance")
	var physical: PackedByteArray=field.raw_grid.bytes.duplicate()
	var collision_spec: String=JSON.stringify(field.runtime_record.collision)
	var stage:=Node2D.new();root.add_child(stage)
	var actor:=Node2D.new();stage.add_child(actor);actor.position=entry
	var camera:=Camera2D.new();actor.add_child(camera);camera.enabled=true
	await process_frame;camera.force_update_scroll()
	var renderer=RENDERER.new();stage.add_child(renderer);renderer.configure(field,actor)
	check(renderer.failure.is_empty() and not renderer.chunks.is_empty() and not renderer.waiting_for_visible,"initial required chunks present before configure returns")
	var initial_count: int=renderer.chunks.size()
	var initial_stats: Dictionary=renderer.texture_store.stats()
	for index: int in renderer.chunks:
		var row: Dictionary=field.runtime_record.chunks[index]
		var holder: Node2D=renderer.chunks[index]
		check(holder.position==Vector2(row.position[0],row.position[1]) and holder.z_index==-4096+index,"placement and painter order "+str(index))
		# Reassemble the streamed tiles and require the exact original pixels.
		var original: Texture2D=field.png_game_pack.load_texture(row)
		var rebuilt:=Image.create(int(row.size[0]),int(row.size[1]),false,Image.FORMAT_RGBA8)
		var covered: int=0
		for tile: Node in holder.get_children():
			var sprite:=tile as Sprite2D
			check(sprite!=null and not sprite.centered and sprite.texture.get_width()<=STORE.TILE_SIZE and sprite.texture.get_height()<=STORE.TILE_SIZE,"bounded tile "+str(index))
			var piece: Image=sprite.texture.get_image();piece.convert(Image.FORMAT_RGBA8)
			rebuilt.blit_rect(piece,Rect2i(Vector2i.ZERO,piece.get_size()),Vector2i(sprite.position))
			covered+=piece.get_width()*piece.get_height()
		var expected: Image=original.get_image() if original!=null else null
		if expected!=null:expected.convert(Image.FORMAT_RGBA8)
		check(expected!=null and covered==int(row.size[0])*int(row.size[1]) and expected.get_data()==rebuilt.get_data(),"original pixels "+str(index))
	await settle(renderer)
	var first: Dictionary=field.runtime_record.chunks[0]
	actor.position=Vector2(first.position[0],first.position[1])+Vector2(first.size[0],first.size[1])*0.5
	camera.force_update_scroll();renderer.refresh_visible()
	await settle(renderer)
	var last: Dictionary=field.runtime_record.chunks[-1]
	actor.position=Vector2(last.position[0],last.position[1])+Vector2(last.size[0],last.size[1])*0.5
	camera.force_update_scroll();renderer.refresh_visible()
	await settle(renderer)
	var store: Node=renderer.texture_store
	check(store.max_frame_uploads<=1 and store.max_frame_tile_uploads<=STORE.TILE_UPLOADS_PER_FRAME,"scroll GPU upload admission bounded per frame")
	var decoded: int=store.decodes
	store.idle_budget=0;store.prune();renderer.refresh_visible()
	check(store.decodes==decoded and not renderer.chunks.is_empty(),"active textures survived idle lookup eviction without reload")
	store.idle_budget=64*1024*1024
	renderer.free()
	check(int(store.stats().active_bytes)==0 and int(store.stats().idle_bytes)<=store.idle_budget,"map exit releases active leases and bounds idle bytes")
	var field_b=RUN.load_field("source_78")
	check(field_b!=null,"actual return-trip destination source78 loaded")
	if field_b==null:quit(1);return
	actor.position=Vector2(field_b.data.spawn_position[0],field_b.data.spawn_position[1]);camera.force_update_scroll()
	var other=RENDERER.new();stage.add_child(other);other.configure(field_b,actor)
	await settle(other)
	check(other.failure.is_empty() and not other.chunks.is_empty(),"source78 initial display complete")
	var other_stats: Dictionary=store.stats()
	other.free()
	check(int(store.stats().idle_bytes)<=store.idle_budget,"two-map idle residency stayed within byte budget")
	var before_return: int=store.decodes
	actor.position=entry;camera.force_update_scroll()
	var returned=RENDERER.new();stage.add_child(returned);returned.configure(field,actor)
	await settle(returned)
	check(returned.failure.is_empty() and not returned.chunks.is_empty(),"map return initial display restored")
	check(field.point_clear(entry,4) and field.raw_grid.bytes==physical and JSON.stringify(field.runtime_record.collision)==collision_spec,"collision specification unchanged by rendering")
	var returned_stats: Dictionary=store.stats()
	var return_decodes: int=store.decodes-before_return
	returned.free();store.idle_budget=0;store.prune();store.idle_budget=64*1024*1024
	# Wide spacing isolates scroll admission while retaining the actual source
	# WebP bytes and dimensions. This is a renderer fixture, not map geometry.
	var fixture=preload("res://scripts/maps/source_map_runtime_field.gd").new()
	fixture.png_game_pack=field.png_game_pack
	fixture.data={"npc_spawn":[],"portal":[]}
	fixture.runtime_record={"chunks":field.runtime_record.chunks.duplicate(true)}
	for index: int in range(fixture.runtime_record.chunks.size()):fixture.runtime_record.chunks[index].position=[0 if index==0 else 6000,0]
	actor.position=Vector2(first.size[0],first.size[1])*0.5;camera.force_update_scroll()
	var scrolling=RENDERER.new();stage.add_child(scrolling);scrolling.configure(fixture,actor)
	check(scrolling.chunks.size()==1,"scroll fixture initial display complete")
	var before_scroll: int=store.uploads
	var before_scroll_usec: int=store.upload_usec
	var second: Dictionary=fixture.runtime_record.chunks[1]
	actor.position=Vector2(second.position[0],second.position[1])+Vector2(second.size[0],second.size[1])*0.5
	camera.force_update_scroll()
	var refresh_begun: int=Time.get_ticks_usec()
	scrolling.refresh_visible()
	var refresh_usec: int=Time.get_ticks_usec()-refresh_begun
	check(scrolling.waiting_for_visible and store.uploads==before_scroll,"scroll refresh queues CPU work without synchronous upload")
	var scroll_frames: int=await settle(scrolling)
	check(store.uploads==before_scroll+3 and scrolling.chunks.has(1) and scrolling.chunks.has(2) and scrolling.chunks.has(3) and store.max_frame_tile_uploads<=STORE.TILE_UPLOADS_PER_FRAME and scroll_frames>3,"three actual WebPs spread over main-thread frames as bounded tiles")
	print("SOURCE84_RENDERER_STREAM_RESULT ",JSON.stringify({"failures":failures,"initial_visible":initial_count,"initial":initial_stats,"other_map":other_stats,"after_round_trip":returned_stats,"return_new_decodes":return_decodes,"scroll_uploads":store.uploads-before_scroll,"scroll_upload_usec":store.upload_usec-before_scroll_usec,"scroll_refresh_usec":refresh_usec,"scroll_frames":scroll_frames,"max_frame_uploads":store.max_frame_uploads,"max_frame_tile_uploads":store.max_frame_tile_uploads,"tile_uploads":store.tile_uploads,"renderer":RenderingServer.get_video_adapter_name()}))
	scrolling.free();stage.queue_free();field.close();field_b.close();fixture.close()
	await process_frame
	quit(0 if failures.is_empty() else 1)
