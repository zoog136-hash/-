extends Control
## Passive bitmap border/aura for the native, scrollable fusion roster.
const Chrome=preload("res://scripts/ui/catalog_card_chrome.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const UI=preload("res://scripts/ui/renewal_theme.gd")
var listing: ItemList
var layers: Array[Control]=[]
var quantities: Control

func configure(source: ItemList) -> void:
	listing=source
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for rank: int in range(Cards.GRADES.size()):
		for aura: bool in [true,false]:
			var layer:=Control.new()
			layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
			layer.material=Chrome.material_for(rank,aura,false,false,false)
			layer.draw.connect(_paint.bind(layer,rank,aura))
			add_child(layer)
			layers.append(layer)
	listing.resized.connect(refresh)
	listing.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:refresh())
	quantities=Control.new()
	quantities.mouse_filter=Control.MOUSE_FILTER_IGNORE
	quantities.draw.connect(_paint_quantities)
	add_child(quantities)

func refresh() -> void:
	for layer: Control in layers:layer.queue_redraw()
	if is_instance_valid(quantities):quantities.queue_redraw()

func _paint_quantities() -> void:
	if not is_visible_in_tree():return
	for index: int in range(listing.item_count):
		var cell: Rect2=listing.get_item_rect(index)
		cell.position.y-=listing.get_v_scroll_bar().value
		if not Rect2(Vector2.ZERO,size).intersects(cell):continue
		var extent:=Vector2(listing.fixed_icon_size)
		var at:=cell.position+Vector2((cell.size.x-extent.x)*.5+3,extent.y-5)
		var number: String=str((listing.get_item_metadata(index) as Dictionary).get("duplicates",0))
		quantities.draw_string_outline(UI.FONT,at,number,HORIZONTAL_ALIGNMENT_RIGHT,extent.x-9,16,2,Color("10151b"))
		quantities.draw_string(UI.FONT,at,number,HORIZONTAL_ALIGNMENT_RIGHT,extent.x-9,16,Color("ecece4"))

func _paint(layer: Control, rank: int, aura: bool) -> void:
	if not is_visible_in_tree():return
	var visible:=Rect2(Vector2.ZERO,size)
	for index: int in range(listing.item_count):
		var data: Dictionary=listing.get_item_metadata(index)
		if Cards.GRADES.find(str(data.get("grade","")))!=rank:continue
		var cell: Rect2=listing.get_item_rect(index)
		cell.position.y-=listing.get_v_scroll_bar().value
		var extent:=Vector2(listing.fixed_icon_size)
		var picture:=Rect2(cell.position+Vector2((cell.size.x-extent.x)*.5,0),extent)
		if not visible.intersects(picture):continue
		if aura:layer.draw_rect(picture,Color.WHITE)
		else:layer.draw_texture_rect(Chrome.texture_for(rank),picture,false)
