extends "res://scripts/maps/field_renderer.gd"
## Original source art is projected into the unchanged legacy gameplay space.
var source_pack:RefCounted
var navigation:RefCounted
var source_sprites:Dictionary={}
var source_overview:Sprite2D

func configure(value:PlayableField,actor:Node2D) -> void:
	field=value;player=actor
	source_pack=value.get("source_pack");navigation=value.get("source_navigation")
	z_index=-50
	var art:Dictionary=source_pack.manifest.art
	if FileAccess.get_sha256(source_pack.safe_file(str(art.overview)))!=str(art.overview_sha256):return
	var image:=Image.load_from_file(source_pack.safe_file(str(art.overview)))
	if image==null:return
	source_overview=Sprite2D.new();source_overview.centered=false
	source_overview.texture=ImageTexture.create_from_image(image)
	source_overview.position=-navigation.translation/navigation.scale
	source_overview.scale=Vector2(art.size[0]/float(image.get_width()),art.size[1]/float(image.get_height()))/navigation.scale
	add_child(source_overview)
	for evidence:Dictionary in value.call("portal_evidence"):
		var portal:Dictionary=evidence.portal
		var source_pixel:Vector2=source_pack.COORDINATE_CONTRACT.grid_anchor(source_pack.manifest,Vector2(portal.SourceX,portal.SourceY))
		var marker:=Line2D.new();marker.width=2;marker.default_color=Color("4dffff")
		marker.position=(source_pixel-navigation.translation)/navigation.scale
		marker.points=PackedVector2Array([Vector2(-12,0),Vector2(0,-6),Vector2(12,0),Vector2(0,6),Vector2(-12,0)])
		add_child(marker)
		var title:=Label.new();title.position=marker.position+Vector2(12,-12);title.text="%d · 검토 표식" % int(portal.ID);add_child(title)
	refresh_visible()

func set_visual_mode(_mode:String) -> void:
	pass # Review source artwork has no synthetic visual replacement mode.

func _process(_delta:float) -> void:
	refresh_visible()

func refresh_visible() -> void:
	if source_pack==null or not is_instance_valid(player):return
	var camera:Camera2D=player.get_node_or_null("Camera2D")
	if camera==null:return
	var extent:Vector2=get_viewport_rect().size/camera.zoom
	var world_view:=Rect2(camera.get_screen_center_position()-extent*.5,extent)
	var source_view:=Rect2(navigation.to_render(world_view.position),world_view.size*navigation.scale)
	var wanted:Dictionary={}
	for row:Dictionary in source_pack.manifest.art.chunks:
		if Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1])).intersects(source_view):wanted[row.file]=row
	for key:String in source_sprites.keys():
		if not wanted.has(key):source_sprites[key].queue_free();source_sprites.erase(key)
	for key:String in wanted:
		if source_sprites.has(key):continue
		if source_sprites.size()>=8:break
		var row:Dictionary=wanted[key];var path:String=source_pack.safe_file(key)
		if FileAccess.get_sha256(path)!=str(row.sha256):continue
		var image:=Image.load_from_file(path)
		if image==null:continue
		var sprite:=Sprite2D.new();sprite.centered=false;sprite.texture=ImageTexture.create_from_image(image)
		sprite.position=(Vector2(row.position[0],row.position[1])-navigation.translation)/navigation.scale
		sprite.scale=Vector2.ONE/navigation.scale
		add_child(sprite);source_sprites[key]=sprite
		break # At most one bounded source chunk per frame.
