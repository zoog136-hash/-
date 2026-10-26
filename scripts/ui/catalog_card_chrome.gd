extends Node

const UI=preload("res://scripts/ui/renewal_theme.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const ATLAS=preload("res://assets/ui/card_frame_atlas.png")
const METAL=preload("res://assets/effects/catalog_card_metal.gdshader")
const AURA=preload("res://assets/effects/catalog_card_aura.gdshader")
const AURA_ART=preload("res://assets/ui/card_aura_wisps.png")
const GRADES: Array[String]=["일반","고급","희귀","영웅","전설","신화","유일"]
# Presentation tuning, shared by all three catalogs and their details.
# Original-game RGB/timing measurements are not implied by these profiles.
const AURA_PROFILES: Array[Dictionary]=[
	{"spread":.48,"light_strength":.025,"veil_strength":0.0,"flow_speed":0.0},
	{"spread":.55,"light_strength":.065,"veil_strength":0.0,"flow_speed":0.0},
	{"spread":.64,"light_strength":.18,"veil_strength":.08,"flow_speed":.20},
	{"spread":.74,"light_strength":.27,"veil_strength":.15,"flow_speed":.36},
	{"spread":.83,"light_strength":.36,"veil_strength":.25,"flow_speed":.50},
	{"spread":.92,"light_strength":.44,"veil_strength":.32,"flow_speed":.62},
	{"spread":1.0,"light_strength":.52,"veil_strength":.42,"flow_speed":.78}
]
# Inspected game screens, used for structure/color hierarchy, not extracted assets:
# https://www.inven.co.kr/webzine/news/?news=286630&site=lineagem
# https://www.inven.co.kr/board/lineagem/5019/488524
# https://www.inven.co.kr/board/lineagem/5056/20468
# Original imagegen atlas, three painted metal variants; transparent centres.
const REGIONS: Array[Rect2]=[Rect2(48,52,534,715),Rect2(675,9,537,758),Rect2(1302,4,549,774)]
static var textures: Array[AtlasTexture]=[]
static var materials: Dictionary={}
var hud: Node
var active: bool=false
var slots: Control
var frame_layers: Array[Control]=[]
var aura_layers: Array[Control]=[]
var preview: Control
var preview_frame: Control
var preview_aura: Control
var visible_cards: Array[Dictionary]=[]
var selected_rank: int=0
var pending_layout: bool=false
var layout_generation: int=-1
var layout_size:=Vector2(-1,-1)
var layout_icon_size:=Vector2i(-1,-1)

static func texture_for(rank: int) -> AtlasTexture:
	if textures.is_empty():
		for region: Rect2 in REGIONS:
			var texture:=AtlasTexture.new()
			texture.atlas=ATLAS
			texture.region=region
			texture.filter_clip=true
			textures.append(texture)
	return textures[0 if rank<2 else 1 if rank<4 else 2]

static func material_for(rank: int, aura: bool, detail: bool=false, reduced: bool=false, low: bool=false) -> ShaderMaterial:
	var key: String=str([rank,aura,detail if aura else false,reduced,low])
	if not materials.has(key):
		var material:=ShaderMaterial.new()
		material.shader=AURA if aura else METAL
		material.set_shader_parameter("grade_color",UI.grade(GRADES[rank]))
		material.set_shader_parameter("rank",float(rank))
		material.set_shader_parameter("motion",0.0 if reduced or low else 1.0)
		if aura:
			material.set_shader_parameter("aura_texture",AURA_ART)
			var variant: int=0 if rank<3 else 1 if rank<5 else 2
			material.set_shader_parameter("aura_region",Vector4(variant/3.0,0,1.0/3.0,1))
			material.set_shader_parameter("detail_view",detail)
			material.set_shader_parameter("intensity",0.65 if low else 1.0)
			for field: String in AURA_PROFILES[rank]:material.set_shader_parameter(field,AURA_PROFILES[rank][field])
			if low:material.set_shader_parameter("veil_strength",0.0)
		materials[key]=material
	return materials[key]

func configure(controller: Node) -> void:
	hud=controller
	name="CatalogCardChrome"
	slots=_layer(hud.catalog_list,"CardBordersAndAuras")
	slots.clip_contents=true
	for rank: int in range(GRADES.size()):
		var aura: Control=_layer(slots,"CardAura"+GRADES[rank])
		aura.draw.connect(_draw_rank.bind(aura,rank,true))
		aura_layers.append(aura)
		var frame: Control=_layer(slots,"CardBorder"+GRADES[rank])
		frame.draw.connect(_draw_rank.bind(frame,rank,false))
		frame_layers.append(frame)
	preview=_layer(hud.catalog_preview,"SelectedCardBorder")
	preview_aura=_layer(hud.catalog_preview,"SelectedCardAura")
	# Some existing PNGs have an opaque backdrop. Keep the centre clear and
	# composite the peripheral aura above them, below the painted metal.
	hud.catalog_preview.move_child(preview_aura,0)
	preview_aura.draw.connect(_draw_preview_aura)
	preview_frame=_layer(preview,"SelectedCardMetal")
	preview_frame.draw.connect(_draw_preview_frame)
	hud.catalog_list.resized.connect(refresh)
	hud.catalog_preview.resized.connect(refresh)
	hud.catalog_list.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:refresh())
	deactivate()

func _layer(parent: Node, label: String) -> Control:
	var layer:=Control.new()
	layer.name=label
	layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return layer

func activate() -> void:
	active=Cards.CATEGORIES.has(hud.catalog_category)
	slots.visible=active
	preview.visible=active
	preview_aura.visible=active
	if active:refresh()

func deactivate() -> void:
	active=false
	if is_instance_valid(slots):slots.hide()
	if is_instance_valid(preview):preview.hide()
	if is_instance_valid(preview_aura):preview_aura.hide()

func refresh() -> void:
	if not active or pending_layout:return
	pending_layout=true
	call_deferred("_refresh_layout")

func _refresh_layout() -> void:
	pending_layout=false
	if not active:return
	var settings: Dictionary=hud.get_parent().presentation_settings
	var reduced: bool=bool(settings.get("reduced_motion",false))
	var low: bool=str(settings.get("effect_detail","full"))=="low"
	for rank: int in range(GRADES.size()):
		frame_layers[rank].material=material_for(rank,false,false,reduced,low)
		aura_layers[rank].material=material_for(rank,true,false,reduced,low)
	visible_cards.clear()
	var listing: ItemList=hud.catalog_list
	# Reflow after content/size changes, never for an ordinary scroll or selection.
	if layout_generation!=hud.catalog_icon_generation or layout_size!=listing.size or layout_icon_size!=listing.fixed_icon_size:
		listing.force_update_list_size()
		layout_generation=hud.catalog_icon_generation
		layout_size=listing.size
		layout_icon_size=listing.fixed_icon_size
	var bounds:=Rect2(Vector2.ZERO,listing.size)
	for index: int in range(mini(listing.item_count,hud.catalog_results.size())):
		# Expanded hit rectangles can stretch a row's last cell across empty space.
		var cell: Rect2=listing.get_item_rect(index,false)
		cell.position.y-=listing.get_v_scroll_bar().value
		if not bounds.intersects(cell):continue
		var record: Dictionary=hud.catalog_results[index]
		var rank: int=maxi(0,GRADES.find(str(record.get("grade","일반"))))
		var rect: Rect2=cell.grow(-1)
		# Native names/quantity remain outside the illustrated rim and aura.
		if hud.catalog_category!="성물":rect.size.y=minf(rect.size.y,float(listing.fixed_icon_size.y)+8.0)
		visible_cards.append({"index":index,"rect":rect,"rank":rank})
	for rank: int in range(GRADES.size()):
		var used: bool=visible_cards.any(func(card: Dictionary) -> bool:return card.rank==rank)
		frame_layers[rank].visible=used
		aura_layers[rank].visible=used
		frame_layers[rank].queue_redraw()
		aura_layers[rank].queue_redraw()
	selected_rank=maxi(0,GRADES.find(str(hud.selected_catalog_record.get("grade","일반"))))
	preview.visible=not hud.selected_catalog_record.is_empty()
	preview_aura.visible=preview.visible
	preview_frame.material=material_for(selected_rank,false,true,reduced,low)
	preview_aura.material=material_for(selected_rank,true,true,reduced,low)
	preview_frame.queue_redraw()
	preview_aura.queue_redraw()
	# Relic quantity labels are the last foreground layer, above the painted rim.
	if is_instance_valid(hud.relic_reference_view) and hud.relic_reference_view.active:
		listing.move_child(hud.relic_reference_view.card_frames,listing.get_child_count()-1)

func _draw_rank(layer: Control, rank: int, aura: bool) -> void:
	for card: Dictionary in visible_cards:
		if card.rank!=rank:continue
		if aura:layer.draw_rect(card.rect,Color.WHITE)
		else:layer.draw_texture_rect(texture_for(rank),card.rect,false)

func _preview_rect() -> Rect2:
	var extent: Vector2=hud.catalog_preview.size
	var width: float=minf(extent.x,maxf(0,extent.y)*.74)
	var size:=Vector2(width,width/.74)
	return Rect2((extent-size)*.5,size).grow(-1)

func _draw_preview_frame() -> void:
	if active and not hud.selected_catalog_record.is_empty():preview_frame.draw_texture_rect(texture_for(selected_rank),_preview_rect(),false)

func _draw_preview_aura() -> void:
	if active and not hud.selected_catalog_record.is_empty():preview_aura.draw_rect(_preview_rect(),Color.WHITE)
