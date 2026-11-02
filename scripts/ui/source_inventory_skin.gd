extends RefCounted
const ATLAS=preload("res://scripts/ui/source_ui_atlas.gd")
const PROFILE=preload("res://data/ui/base508_inventory_slot.json")
const PREFAB: String="UI/CommonUi/Common_Slot.csb"
static var styles: Dictionary={}
static func original(node_name: String) -> Image:
	for node: Dictionary in PROFILE.data.screens[PREFAB]:
		if node.name!=node_name:continue
		for ref: Dictionary in node.resources:
			if ref.field=="fileNameData":return ATLAS.frame("UI/"+ref.plistFile,ref.path)
	return null
static func style(selected: bool=false) -> StyleBoxTexture:
	var key: String="selected" if selected else "normal"
	if styles.has(key):return styles[key]
	var image: Image=original("Sp_SlotBg")
	if image==null:return null
	image=image.duplicate()
	if selected:
		var overlay: Image=original("Sp_Select")
		if overlay==null or overlay.get_size()!=image.get_size():return null
		image.blend_rect(overlay,Rect2i(Vector2i.ZERO,overlay.get_size()),Vector2i.ZERO)
	var box:=StyleBoxTexture.new();box.texture=ImageTexture.create_from_image(image)
	styles[key]=box;return box
static func apply(button: Button,selected: bool) -> void:
	var box: StyleBoxTexture=style(selected)
	if box==null:return
	for state: String in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,box)
	button.set_meta("original_inventory_slot",PREFAB)
