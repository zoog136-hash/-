extends RefCounted
const ATLAS = preload("res://scripts/ui/source_ui_atlas.gd")
const PROFILE = preload("res://data/ui/base508_card_layout.json")
static var icons: Dictionary = {}
static var button_styles: Dictionary = {}

static func frame_ref(record: Dictionary) -> Dictionary:
	var binding: Dictionary = ATLAS.INDEX.data.grade_bindings.get(str(int(record.get("source_grade_id",0))),{})
	if binding.is_empty(): return {}
	var path: String = binding.prefab
	for node: Dictionary in PROFILE.data.screens.get(path,[]):
		if node.name==binding.sprite_node:
			for ref: Dictionary in node.resources:
				if ref.field=="fileNameData": return {"plist":"UI/"+ref.plistFile,"key":ref.path,"prefab":path}
	return {}

static func icon(record: Dictionary, portrait: Texture2D) -> Texture2D:
	if portrait==null: return null
	var identity: String = str(record.get("sourceId",""))
	if icons.has(identity): return icons[identity]
	var ref: Dictionary = frame_ref(record)
	if ref.is_empty(): return portrait
	var backdrop: Image = ATLAS.frame(ref.plist,ref.key)
	if backdrop==null: return portrait
	var original: Image = portrait.get_image()
	if original==null or original.get_width()>backdrop.get_width() or original.get_height()>backdrop.get_height(): return portrait
	if original.is_compressed() and original.decompress()!=OK: return portrait
	original.convert(Image.FORMAT_RGBA8)
	# Original CSB places CardSample over Sp_Card at the same center and size.
	var composed: Image = backdrop.duplicate()
	var centered := Vector2i((backdrop.get_size()-original.get_size())/2)
	composed.blend_rect(original,Rect2i(Vector2i.ZERO,original.get_size()),centered)
	if icons.size()>=96: icons.erase(icons.keys()[0])
	var texture: Texture2D = ImageTexture.create_from_image(composed)
	icons[identity]=texture
	return texture

static func style(button: Button, path: String, node_name: String) -> void:
	if not button.has_meta("original_ui_saved_styles"):
		var previous: Dictionary = {}
		for state: String in ["normal","pressed","disabled","hover"]:
			previous[state]=button.get_theme_stylebox(state) if button.has_theme_stylebox_override(state) else null
		button.set_meta("original_ui_saved_styles",previous)
	for node: Dictionary in PROFILE.data.screens.get(path,[]):
		if node.name!=node_name: continue
		for ref: Dictionary in node.resources:
			var state: String = {"normalData":"normal","pressedData":"pressed","disabledData":"disabled"}.get(ref.field,"")
			if state.is_empty() or ref.plistFile.is_empty(): continue
			var key: String = ref.plistFile+":"+ref.path
			if not button_styles.has(key):
				var texture: Texture2D = ATLAS.texture("UI/"+ref.plistFile,ref.path)
				if texture==null: continue
				var box:=StyleBoxTexture.new();box.texture=texture
				button_styles[key]=box
			button.add_theme_stylebox_override(state,button_styles[key])
			if state=="normal": button.add_theme_stylebox_override("hover",button_styles[key])
		button.set_meta("original_ui_node",path+":"+node_name)
		return

static func restore(button: Button) -> void:
	if not button.has_meta("original_ui_saved_styles"): return
	for state: String in button.get_meta("original_ui_saved_styles"):
		var previous: StyleBox = button.get_meta("original_ui_saved_styles")[state]
		if previous==null: button.remove_theme_stylebox_override(state)
		else: button.add_theme_stylebox_override(state,previous)
	button.remove_meta("original_ui_saved_styles")
	button.remove_meta("original_ui_node")

static func tabs(buttons: Array[Button]) -> void:
	var nodes: Array[String] = ["Btn_Change_On","Btn_Mix_On","Btn_Collection_On"]
	for index: int in range(mini(buttons.size(),nodes.size())):
		style(buttons[index],"UI/Change/Change_WinTotal.csb",nodes[index])

static func surface(hud: Node) -> bool:
	var companion_active: bool = is_instance_valid(hud.companion_detail_view) and hud.companion_detail_view.active
	var relic_active: bool = is_instance_valid(hud.relic_reference_view) and hud.relic_reference_view.active
	if not companion_active and not relic_active: return false
	var panel: PanelContainer=hud.catalog_panel
	var background: Control=panel.get_node_or_null("OriginalCardBackground")
	if background==null:
		background=preload("res://scripts/ui/source_card_background.gd").new()
		background.name="OriginalCardBackground"
		panel.add_child(background)
	if background.layers.size()!=2: return false
	if not panel.has_meta("source_saved_panel_style"):
		panel.set_meta("source_saved_panel_style",panel.get_theme_stylebox("panel"))
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	background.show()
	return true

static func restore_surface(hud: Node) -> void:
	var panel: PanelContainer=hud.catalog_panel
	var background: Control=panel.get_node_or_null("OriginalCardBackground")
	if background!=null: background.hide()
	if panel.has_meta("source_saved_panel_style"):
		panel.add_theme_stylebox_override("panel",panel.get_meta("source_saved_panel_style"))
		panel.remove_meta("source_saved_panel_style")

static func frame_status(record: Dictionary) -> String:
	var ref: Dictionary=frame_ref(record)
	if ref.is_empty(): return "undeclared"
	return "original" if ATLAS.frame(ref.plist,ref.key)!=null else "missing"
