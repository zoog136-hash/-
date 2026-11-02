extends RefCounted
## Exact source CSB material references. Adaptive controls keep >=44px touches.
const ATLAS=preload("res://scripts/ui/source_ui_atlas.gd")
const PROFILE=preload("res://data/ui/base508_skill_awakening_layout.json")
const SCREEN="UI/Change/Change_Awaken_Skill.csb"
static var styles: Dictionary={}

static func node(name_value: String,resource: String="") -> Dictionary:
	for entry: Dictionary in PROFILE.data.screens[SCREEN]:
		if entry.name!=name_value:continue
		if resource.is_empty():return entry
		for ref: Dictionary in entry.resources:
			if ref.path==resource:return entry
	return {}

static func texture(entry: Dictionary,field: String="fileNameData") -> Texture2D:
	for ref: Dictionary in entry.get("resources",[]):
		if ref.field==field and not str(ref.plistFile).is_empty():return ATLAS.texture("UI/"+str(ref.plistFile),str(ref.path))
	return null

static func panel(name_value: String,resource: String) -> StyleBoxTexture:
	var key: String=name_value+":"+resource
	if styles.has(key):return styles[key]
	var original: Texture2D=texture(node(name_value,resource))
	if original==null:return null
	var box:=StyleBoxTexture.new();box.texture=original;styles[key]=box;return box

static func button(control: Button,name_value: String) -> bool:
	var entry: Dictionary=node(name_value);var applied: bool=false
	for field: String in ["normalData","pressedData","disabledData"]:
		var original: Texture2D=texture(entry,field)
		if original==null:continue
		var key: String=name_value+":"+field
		if not styles.has(key):
			var box:=StyleBoxTexture.new();box.texture=original;styles[key]=box
		var state: String={"normalData":"normal","pressedData":"pressed","disabledData":"disabled"}[field]
		control.add_theme_stylebox_override(state,styles[key]);applied=true
		if state=="normal":control.add_theme_stylebox_override("hover",styles[key])
	control.set_meta("source_csb_node",SCREEN+":"+name_value)
	return applied
