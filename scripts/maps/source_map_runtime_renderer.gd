extends "res://scripts/maps/source_renderer.gd"
## Stream original full-resolution WebPs in the same source frame as physics.
var art: RefCounted
var record: Dictionary
var failure: String=""
var pixel_material: ShaderMaterial
var last_door_input_usec: int=0
const MAX_VISIBLE=12
const PREFETCH_BYTES: int=32*1024*1024
const TEXTURES=preload("res://scripts/maps/source_map_texture_store.gd")
var texture_store: Node
var held_keys: Dictionary={}
var initial_view: bool=true
var waiting_for_visible: bool=false

func configure(value: PlayableField, actor: Node2D) -> void:
	field=value;source=value as OriginalPlayableField;player=actor
	art=(value as RemakePlayableField).png_game_pack
	record=value.runtime_record
	y_sort_enabled=true
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_material=ShaderMaterial.new()
	pixel_material.shader=load("res://assets/maps/source_map_texel.gdshader")
	texture_store=TEXTURES.shared(self)
	refresh_visible()

func refresh_visible() -> void:
	if not is_instance_valid(player) or record.is_empty():return
	var rect: Rect2=get_viewport_rect()
	var inverse: Transform2D=get_canvas_transform().affine_inverse()
	var view:=Rect2(inverse*rect.position,Vector2.ZERO).expand(inverse*rect.end).grow(64)
	var needed: Dictionary={}
	for i: int in range(record.chunks.size()):
		var row: Dictionary=record.chunks[i]
		var box:=Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		if box.intersects(view):needed[i]=row
	if needed.size()>MAX_VISIBLE:
		failure="Original map view exceeds texture budget";push_error(failure);return
	for i: Variant in chunks.keys():
		if not needed.has(i):
			chunks[i].texture=null
			remove_child(chunks[i]);chunks[i].queue_free();chunks.erase(i)
	var next_keys: Dictionary={}
	waiting_for_visible=false
	for i: int in needed:
		if i>=4096:failure="Map exceeds safe ground draw-order range";push_error(failure);return
		var row: Dictionary=needed[i]
		var key: String=texture_store.request(art.root_path,row,self,initial_view)
		if key.is_empty():failure="Source chunk missing, changed or unsafe: "+str(row.file);push_error(failure);return
		next_keys[key]=true
		if chunks.has(i):continue
		var texture: Texture2D=texture_store.texture(key)
		if texture==null:
			failure=texture_store.problem(key)
			if not failure.is_empty():push_error(failure);return
			waiting_for_visible=true
			continue
		var sprite:=Sprite2D.new()
		sprite.centered=false;sprite.texture=texture;sprite.position=Vector2(row.position[0],row.position[1])
		sprite.material=pixel_material
		# Preserve the original chunk painter order, entirely below actor z=0.
		# Starting at -30 hid the player on maps with high chunk IDs.
		sprite.z_index=-4096+i
		add_child(sprite);chunks[i]=sprite
	# These ring requests only enqueue preparation. The shared store admits
	# bounded worker jobs and uploads their completed Images on the scene thread.
	var prefetched: int=0
	var prefetch_bytes: int=0
	for row: Dictionary in record.chunks:
		if prefetched>=2:break
		var box:=Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		if box.intersects(view) or not box.intersects(view.grow(768)):continue
		var estimate: int=int(row.size[0])*int(row.size[1])*4
		if prefetch_bytes+estimate>PREFETCH_BYTES:continue
		var key: String=texture_store.request(art.root_path,row,self)
		if key.is_empty():continue
		next_keys[key]=true;prefetched+=1;prefetch_bytes+=estimate
	for key: String in held_keys:
		if not next_keys.has(key):texture_store.release(key,self)
	held_keys=next_keys
	initial_view=false
	queue_redraw()
	_refresh_markers()
	if source is RemakePlayableField and is_instance_valid(source.collision_stream):source.collision_stream.refresh()

func _process(delta: float) -> void:
	stream_clock-=delta
	if stream_clock<=0 or waiting_for_visible:
		stream_clock=0.25
		refresh_visible()

func _exit_tree() -> void:
	for sprite: Sprite2D in chunks.values():sprite.texture=null
	if is_instance_valid(texture_store):texture_store.release_owner(self)
	held_keys.clear()

func set_visual_mode(_mode: String) -> void:pass

func _unhandled_input(event: InputEvent) -> void:
	var clicked: Vector2
	if event is InputEventScreenTouch:
		if not event.pressed:return
		clicked=get_canvas_transform().affine_inverse()*event.position
	elif event is InputEventMouseButton:
		if event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed:return
		clicked=get_canvas_transform().affine_inverse()*event.position
	else:return
	if last_door_input_usec>0 and Time.get_ticks_usec()-last_door_input_usec<100000:return
	var f=field
	for id: String in f.local_doors:
		var p: Vector2=f.cell_to_world(f.local_doors[id][0])
		if p.distance_to(clicked)>32 or player.global_position.distance_to(p)>140:continue
		var occupied: Array=[player.global_position]
		var world=get_parent()
		for row: Dictionary in f.data.npc_spawn:occupied.append(Vector2(row.position[0],row.position[1]))
		if world is TwilightWorld:
			for row: Dictionary in world.ground_loot.records.values():
				if row.map_id==world.active_map_id:occupied.append(Vector2(row.position[0],row.position[1]))
			for actor: Node2D in world.monsters_root.get_children():occupied.append(actor.global_position)
		f.set_local_door(id,not bool(f.local_door_states[id]),occupied)
		last_door_input_usec=Time.get_ticks_usec()
		queue_redraw();get_viewport().set_input_as_handled();return

func _draw() -> void:
	if field==null:return
	var f=field
	for id: String in f.local_doors:
		for cell: Vector2i in f.local_doors[id]:
			var p: Vector2=f.cell_to_world(cell)
			var color:=Color("69d8b1") if f.local_door_states[id] else Color("e06860")
			draw_line(p+Vector2(-14,0),p+Vector2(14,0),color,3)
			if player.global_position.distance_to(p)<140:draw_string(ThemeDB.fallback_font,p+Vector2(-25,-16),"문 닫기" if f.local_door_states[id] else "문 열기",HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
