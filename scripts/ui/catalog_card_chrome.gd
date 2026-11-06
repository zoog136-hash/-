extends Node

const UI=preload("res://scripts/ui/renewal_theme.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Ownership=preload("res://scripts/ui/catalog_card_ownership.gd")
const SourceSurfaces=preload("res://scripts/ui/original_card_surfaces.gd")
const GRADES: Array[String]=["일반","고급","희귀","영웅","전설","신화","유일"]
# Original frame pixels require the UI owner's exact selected-pack node role.
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
var quantities: Control
static var quantity_font: FontVariation

static func texture_for(_rank: int, record: Dictionary={}) -> Texture2D:
	# Grade rank is a display label, not an original asset identity. Only the
	# UI owner's exact source-grade/node binding can supply a frame.
	var original: Dictionary=SourceSurfaces.resolve("grade_frame",record)
	return original.get("texture") as Texture2D

static func material_for(_rank: int, _aura: bool, _detail: bool=false, _reduced: bool=false, _low: bool=false) -> ShaderMaterial:
	# Keep original pixels unmodified; retired generated metal/aura shaders
	# are not an original decoration or a substitute for a missing source role.
	return null

func configure(controller: Node) -> void:
	if quantity_font==null:
		quantity_font=FontVariation.new();quantity_font.base_font=UI.FONT
		quantity_font.variation_opentype={2003265652:650.0}
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
	quantities=_layer(slots,"CompanionCardQuantities")
	quantities.draw.connect(_draw_card_quantities)
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
	var owned: Dictionary=hud.card_collection_state.get("owned",{}).get(hud.catalog_category,{})
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
		visible_cards.append({"index":index,"rect":rect,"rank":rank,"owned":owned.has(Cards.card_id(record)),"native":preload("res://scripts/ui/source_card_presentation.gd").native(record)})
	for rank: int in range(GRADES.size()):
		var used: bool=visible_cards.any(func(card: Dictionary) -> bool:return card.rank==rank)
		frame_layers[rank].visible=used
		aura_layers[rank].visible=false
		frame_layers[rank].queue_redraw()
		aura_layers[rank].queue_redraw()
	quantities.visible=hud.catalog_category in ["변신","마법인형"] or visible_cards.any(func(card: Dictionary) -> bool:return card.native)
	quantities.queue_redraw()
	selected_rank=maxi(0,GRADES.find(str(hud.selected_catalog_record.get("grade","일반"))))
	preview.visible=not hud.selected_catalog_record.is_empty()
	preview_aura.visible=false
	preview_frame.material=material_for(selected_rank,false,true,reduced,low)
	preview_aura.material=material_for(selected_rank,true,true,reduced,low)
	preview_frame.queue_redraw()
	preview_aura.queue_redraw()
	# Relic quantity labels are the last foreground layer, above the painted rim.
	if is_instance_valid(hud.relic_reference_view) and hud.relic_reference_view.active:
		listing.move_child(hud.relic_reference_view.card_frames,listing.get_child_count()-1)

func _draw_rank(layer: Control, rank: int, aura: bool) -> void:
	if not active or layout_generation != hud.catalog_icon_generation:return
	if aura:return
	for card: Dictionary in visible_cards:
		if card.rank!=rank or card.index<0 or card.index>=hud.catalog_results.size():continue
		var original: Texture2D=texture_for(rank,hud.catalog_results[card.index])
		if original!=null:layer.draw_texture_rect(original,card.rect,false,Color.WHITE if card.owned else Ownership.UNOWNED_FRAME_TINT)

func _draw_card_quantities() -> void:
	# A filter/page change replaces catalog_results synchronously, while this
	# drawing cache is refreshed on the next deferred layout. Do not render old
	# indices or quantities against the new page during that intervening frame.
	if not active or layout_generation != hud.catalog_icon_generation:return
	var spare: Dictionary=hud.card_collection_state.get("spare",{}).get(hud.catalog_category,{})
	for card: Dictionary in visible_cards:
		if int(card.index)<0 or int(card.index)>=hud.catalog_results.size() or int(card.index)>=hud.catalog_list.item_count:continue
		var record: Dictionary=hud.catalog_results[card.index]
		var rect: Rect2=card.rect
		if card.native and hud.catalog_list.get_item_icon(card.index)==null:
			quantities.draw_multiline_string(UI.FONT,rect.position+Vector2(4,rect.size.y*.45),"원본 이미지\n미설치",HORIZONTAL_ALIGNMENT_CENTER,maxf(1,rect.size.x-8),12,-1,UI.MUTED)
		if hud.catalog_category=="성물":continue
		var duplicates: int=int(spare.get(Cards.card_id(record),0))
		if card.native and card.owned:duplicates+=1
		if duplicates>0:
			var at:=Vector2(rect.position.x+4,rect.end.y-5)
			quantities.draw_string_outline(quantity_font,at,str(duplicates),HORIZONTAL_ALIGNMENT_RIGHT,rect.size.x-9,13,2,Color.BLACK)
			quantities.draw_string(quantity_font,at,str(duplicates),HORIZONTAL_ALIGNMENT_RIGHT,rect.size.x-9,13,UI.TEXT)
		if bool(hud._option_awakening_card_state(hud.catalog_category,record).get("awakened",false)):
			var at:=rect.position+Vector2(4,14)
			quantities.draw_string_outline(UI.FONT,at,"각성",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-8,10,2,Color.BLACK)
			quantities.draw_string(UI.FONT,at,"각성",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-8,10,UI.GOLD)

func _preview_rect() -> Rect2:
	var extent: Vector2=hud.catalog_preview.size
	var width: float=minf(extent.x,maxf(0,extent.y)*.74)
	var size:=Vector2(width,width/.74)
	return Rect2((extent-size)*.5,size).grow(-1)

func _draw_preview_frame() -> void:
	if active and not hud.selected_catalog_record.is_empty():
		var original: Texture2D=texture_for(selected_rank,hud.selected_catalog_record)
		if original!=null:preview_frame.draw_texture_rect(original,_preview_rect(),false)

func _draw_preview_aura() -> void:
	# No authoritative original aura-role input has been delivered.
	return
