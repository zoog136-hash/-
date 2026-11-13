extends Node2D
## Original ParticleReader GROUPED particles; source plist and PNG only.
const STATE=preload("res://scripts/ui/original_ui/source_particle_state.gd")
const BLEND=preload("res://scripts/ui/original_ui/source_blend.gd")
const MATERIAL=preload("res://scripts/ui/original_ui/source_material.gd")
const DESTINATION_COPY=preload("res://scripts/ui/original_ui/source_destination_copy.gd")
var state=STATE.new()
var original_texture: Texture2D
var original_member: String=""
var texture_member: String=""
var blend_pair: String=""
var opacity_modify_rgb: bool=false
var _quads: Array[Sprite2D]=[]
var _copies: Array[BackBufferCopy]=[]
var _configured: bool=false

func configure(pack: RefCounted, options: Dictionary, source_random: Callable=Callable()) -> Dictionary:
	if _configured:return {"ok":false,"error":"particle_already_configured"}
	var data: Dictionary=pack.particle(options.get("fileNameData",{}))
	if not data.ok:return data
	var factors: Array=options.get("blendFunc",[])
	if factors.size()!=2:return {"ok":false,"error":"particle_blend_missing"}
	var requested_pair: String=str(int(factors[0]))+":"+str(int(factors[1]))
	if requested_pair not in BLEND.PAIRS:return {"ok":false,"error":"particle_blend_unsupported"}
	var result: Dictionary=state.configure(data.values,source_random)
	if not result.ok:return result
	original_texture=data.texture
	original_member=data.member
	texture_member=data.texture_member
	set_source_blend(requested_pair)
	_configured=true
	return {"ok":true,"member":original_member,"texture_member":texture_member}

func _process(delta: float) -> void:
	advance(delta)

func _enter_tree() -> void:
	# One draw hook per emitter, not one signal subscription per particle.
	if not RenderingServer.frame_pre_draw.is_connected(_sync_destination_copies):
		RenderingServer.frame_pre_draw.connect(_sync_destination_copies)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_destination_copies):
		RenderingServer.frame_pre_draw.disconnect(_sync_destination_copies)

func _sync_destination_copies() -> void:
	for copy: BackBufferCopy in _copies: copy.call("_sync_copy")

func advance(delta: float) -> void:
	if not _configured:return
	state.step(delta)
	_sync_quads()

func _sync_quads() -> void:
	if not is_visible_in_tree():return
	while _quads.size()<state.particles.size():
		var copy:=DESTINATION_COPY.new(false)
		add_child(copy);_copies.append(copy)
		var quad:=Sprite2D.new()
		quad.texture=original_texture
		quad.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		quad.material=BLEND.material(original_texture,blend_pair,true)
		add_child(quad);_quads.append(quad)
		copy.track(quad)
	for index: int in range(_quads.size()):
		var shown: bool=index<state.particles.size()
		_quads[index].visible=shown;_copies[index].visible=shown
		if not shown:continue
		var particle: Dictionary=state.particles[index]
		var quad: Sprite2D=_quads[index]
		quad.position=Vector2(particle.position.x,-particle.position.y)
		quad.rotation=deg_to_rad(float(particle.rotation))
		quad.scale=Vector2(float(particle.size)/original_texture.get_width(),float(particle.size)/original_texture.get_height())
		var color: Color=particle.color
		var rgb_alpha: float=color.a if opacity_modify_rgb else 1.0
		var vertex:=Color(float(int(color.r*rgb_alpha*255.0))/255.0,float(int(color.g*rgb_alpha*255.0))/255.0,float(int(color.b*rgb_alpha*255.0))/255.0,float(int(color.a*255.0))/255.0)
		MATERIAL.bind_display(quad,vertex)

func set_source_blend(pair: String) -> bool:
	if pair not in BLEND.PAIRS or original_texture==null:return false
	# Original ParticleSystem::updateBlendFunc adjusts the default blend
	# for non-PMA textures and only modifies RGB for the PMA default.
	var pma: bool=bool(original_texture.get_meta("cocos_premultiplied",false))
	var effective: String="770:771" if pair=="1:771" and not pma else pair
	if effective==blend_pair:return true
	blend_pair=effective
	opacity_modify_rgb=effective=="1:771" and pma
	for quad: Sprite2D in _quads:quad.material=BLEND.material(original_texture,blend_pair,true)
	_sync_quads()
	return true

func playback_status() -> Dictionary:
	return {"configured":_configured,"emitting":state.active,"particles":state.particles.size(),"elapsed":state.elapsed,"source":original_member,"texture":texture_member}
