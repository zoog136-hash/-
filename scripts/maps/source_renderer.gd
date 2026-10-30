extends "res://scripts/maps/field_renderer.gd"
class_name OriginalSourceRenderer
const CHUNK=preload("res://scripts/maps/source_chunk.gd")
var source: OriginalPlayableField
var terrain_table: Dictionary={}
var terrain_packs: Dictionary={}
var tile_mapping: Dictionary={}
# Reuse recently visible atlas pages rather than evicting them by insertion order.
# This remains capped at the same 128 textures as the original implementation.
const SOURCE_TEXTURE_LIMIT: int = 128
var source_textures: Dictionary={}
var source_texture_recency: Array[String]=[]
var source_markers: Dictionary={}
var last_chunk:=Vector2i(-999,-999)
var loaded_terrain_chunks: int=0
var missing_object_markers: int=0
var authored_art_enabled: bool=false
var authored_material: ShaderMaterial
var authored_props: Array[AtlasTexture]=[]
func configure(value: PlayableField,actor: Node2D) -> void:
	field=value
	source=value as OriginalPlayableField
	player=actor
	y_sort_enabled=true
	# User authorized reference-based expansion. The 25 TWILIGHT maps receive
	# explicit profiles; source map art stays on the separately verified mainland.
	authored_art_enabled=str(source.definition.map_id)=="l1_4"
	if authored_art_enabled:
		authored_material=ShaderMaterial.new()
		authored_material.shader=load("res://assets/maps/authored_mainland_v1/terrain.gdshader")
		authored_material.set_shader_parameter("atlas",load("res://assets/maps/reference_expansion_v2/terrain.png"))
		authored_material.set_shader_parameter("atlas_grid",4.0)
		authored_material.set_shader_parameter("material_slots",Vector4(0,2,1,7))
		var prop_atlas: Texture2D=load("res://assets/maps/reference_expansion_v2/props.png")
		for i: int in range(16):
			authored_props.append(REFERENCE_VISUALS.cell(prop_atlas,i))
	for record: Dictionary in source.definition.terrain_chunks:
		var key:=Vector2i((int(record.origin[0])-source.coordinates.origin.x)>>6,(int(record.origin[1])-source.coordinates.origin.y)>>6)
		terrain_table[key]=record
	tile_mapping=JSON.parse_string(FileAccess.get_file_as_string("res://data/original_maps/TILE_IMAGE_MAPPING.json")).get("tiles",{})
	refresh_visible()
func set_visual_mode(_mode: String) -> void: pass
func tile_texture(tile: int,index: int) -> Texture2D:
	var key: String="%d:%d" % [tile,index]
	if source_textures.has(key):
		source_texture_recency.erase(key)
		source_texture_recency.append(key)
		return source_textures[key] as Texture2D
	var entry: Dictionary=tile_mapping.get(str(tile),{}).get("images",{}).get(str(index),{})
	var path: String=str(entry.get("path",""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var found: Texture2D=load(path) as Texture2D
	if found==null: return null
	if source_textures.size()>=SOURCE_TEXTURE_LIMIT:
		var oldest: String=source_texture_recency.pop_front()
		source_textures.erase(oldest)
	source_textures[key]=found
	source_texture_recency.append(key)
	return found
func _terrain(key: Vector2i) -> Dictionary:
	if not terrain_table.has(key): return {}
	var ref: Dictionary=terrain_table[key]
	var row: Array=ref.pack
	var shard: int=int(row[0])
	if not terrain_packs.has(shard): terrain_packs[shard]=FileAccess.open("res://data/original_maps/terrain-%02d.bin" % shard,FileAccess.READ)
	var pack: FileAccess=terrain_packs[shard]
	if pack==null: return {}
	pack.seek(int(row[1]))
	var raw: PackedByteArray=pack.get_buffer(int(row[2])).decompress_dynamic(16000000,FileAccess.COMPRESSION_DEFLATE)
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(raw)
	if hash.finish().hex_encode()!=str(row[3]): push_error("Original S32 integrity failure"); return {}
	var value: Variant=JSON.parse_string(raw.get_string_from_utf8())
	if not (value is Dictionary): return {}
	loaded_terrain_chunks+=1
	return value
func refresh_visible() -> void:
	if source==null or not is_instance_valid(player): return
	var cell: Vector2i=source.world_to_cell(player.global_position)
	var center:=Vector2i(cell.x>>6,cell.y>>6)
	var needed: Dictionary={}
	if center!=last_chunk:
		last_chunk=center
		for dy: int in range(-1,2):
			for dx: int in range(-1,2):
				var key: Vector2i=center+Vector2i(dx,dy)
				if key.x<0 or key.y<0 or key.x*64>=source.width or key.y*64>=source.height: continue
				needed[key]=true
				if chunks.has(key): continue
				var node: OriginalSourceChunk=CHUNK.new()
				add_child(node)
				node.configure(source,key,_terrain(key),self)
				chunks[key]=node
		for key: Vector2i in chunks.keys():
			if needed.has(key): continue
			var old: Node=chunks[key]
			remove_child(old)
			old.queue_free()
			chunks.erase(key)
	_refresh_markers()
	missing_object_markers=0
	for node: OriginalSourceChunk in chunks.values(): missing_object_markers+=node.object_markers
func _refresh_markers() -> void:
	var needed: Dictionary={}
	for entry: Array in [["npc_spawn",false],["portal",true]]:
		for record: Dictionary in source.data[str(entry[0])]:
			var p:=Vector2(float(record.position[0]),float(record.position[1]))
			if p.distance_squared_to(player.global_position)>1400*1400: continue
			var key: String=str(entry[0])+":"+str(record.id)
			needed[key]=true
			if source_markers.has(key): continue
			var node:=Node2D.new()
			node.position=p
			add_child(node)
			var ring:=Line2D.new()
			ring.width=2
			ring.default_color=Color("87d1c8") if bool(entry[1]) else Color("dec68e")
			for i: int in range(17): ring.add_point(Vector2(cos(TAU*i/16)*15,sin(TAU*i/16)*7))
			node.add_child(ring)
			if not bool(entry[1]):
				var npc:=Sprite2D.new()
				var part:=AtlasTexture.new()
				part.atlas=load(VISUAL_STYLE.npc_class_art(str(record.get("role","guide"))))
				part.region=Rect2(0,0,148,116)
				npc.texture=part
				npc.scale=Vector2.ONE*.55
				npc.offset=Vector2(0,-52)
				node.add_child(npc)
			var label:=Label.new()
			label.text=str(record.name)
			label.position=Vector2(-80,-78 if not bool(entry[1]) else -28)
			label.size=Vector2(160,22)
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size",12)
			label.mouse_filter=Control.MOUSE_FILTER_IGNORE
			node.add_child(label)
			source_markers[key]=node
	for key: String in source_markers.keys():
		if needed.has(key): continue
		var old: Node=source_markers[key]
		remove_child(old)
		old.queue_free()
		source_markers.erase(key)
func _process(delta: float) -> void:
	stream_clock-=delta
	if stream_clock<=0: stream_clock=0.25; refresh_visible()
func _notification(_what: int) -> void: pass
