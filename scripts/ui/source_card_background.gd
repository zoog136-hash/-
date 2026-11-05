extends Control
const ATLAS = preload("res://scripts/ui/source_ui_atlas.gd")
const PROFILE = preload("res://data/ui/base508_card_layout.json")
var layers: Array[Dictionary] = []
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	show_behind_parent=true
	resized.connect(queue_redraw)
	for node: Dictionary in PROFILE.data.screens["UI/Change/Change_WinTotal.csb"]:
		if node.name not in ["Img_bg1","Img_bg2"]: continue
		for ref: Dictionary in node.resources:
			if ref.field!="fileNameData": continue
			var original: Texture2D=ATLAS.texture("UI/"+ref.plistFile,ref.path)
			if original!=null: layers.append({"texture":original,"bounds":node.bounds_y_up,"alpha":float(node.alpha)/255.0})
func _draw() -> void:
	for layer: Dictionary in layers:
		var b: Array=layer.bounds
		var rect:=Rect2((600.0+b[0])/1200.0*size.x,(337.5-b[1]-b[3])/675.0*size.y,b[2]/1200.0*size.x,b[3]/675.0*size.y)
		draw_texture_rect(layer.texture,rect,false,Color(1,1,1,layer.alpha))
