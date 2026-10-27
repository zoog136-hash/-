extends SceneTree
func _initialize() -> void:
	var f=preload("res://scripts/maps/native_png_registry.gd").load_field("aden_world")
	var base="res://assets/maps/aden_modular_pilot/compiled/"
	var m: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base+"manifest.json"))
	for r: Dictionary in m.foreground:
		if r.id!="palace":continue
		var im:=Image.load_from_file(base+r.file);var bad: Array=[];var count: int=0
		for x: int in range(8,im.get_width(),16):
			for y: int in range(im.get_height()-1,-1,-1):
				if im.get_pixel(x,y).a<.5:continue
				count+=1;var at:=Vector2(m.world_bounds[0]+r.position[0]+x,m.world_bounds[1]+r.position[1]+y)
				if f.walkable(at):bad.append([at.x,at.y])
				break
		print(JSON.stringify({"palace_contact_samples":count,"contact_on_existing_walkway":bad}))
	quit()
