extends SceneTree
func _initialize() -> void:
	var field: PlayableField=preload("res://scripts/maps/native_png_registry.gd").load_field("aden_world")
	var final_review: bool="--final-mobile-feet" in OS.get_cmdline_user_args()
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/aden_world_mobile/manifest.json")).placements if final_review else JSON.parse_string(FileAccess.get_file_as_string("res://tools/map_restore/aden_mobile_review/placements_before_review.json"))
	var textures: Dictionary={};var risks: Array=[];var sampled: int=0
	for row: Dictionary in rows:
		if row.has("existing_collision") or row.id=="city_plaza_fountain":continue
		if not textures.has(row.asset):
			var im:=Image.new();im.load_webp_from_buffer(FileAccess.get_file_as_bytes("res://assets/maps/aden_world_mobile/objects/"+row.asset+".webp.bin"));textures[row.asset]=im
		var image: Image=textures[row.asset];var hits: int=0;var contacts: int=0
		for fraction: float in [.1,.3,.5,.7,.9]:
			var x: int=mini(image.get_width()-1,int(image.get_width()*fraction))
			for y: int in range(image.get_height()-1,int(image.get_height()*.78),-1):
				if image.get_pixel(x,y).a<.5:continue
				contacts+=1;sampled+=1
				if field.walkable(Vector2(row.position[0]+x,row.position[1]+y)):hits+=1
				break
		if hits>0:risks.append({"id":row.id,"asset":row.asset,"foot":row.foot,"walkable_contacts":hits,"samples":contacts})
	var result={"placements":rows.size(),"contact_samples":sampled,"risks":risks,"navigation_modified":false}
	var out:=FileAccess.open("/workspace/aden-mobile-evidence/feet-final.json" if final_review else "/workspace/aden-mobile-evidence/feet.json",FileAccess.WRITE);out.store_string(JSON.stringify(result,"  "));print("FEET_AUDIT ",rows.size()," placements / ",sampled," samples / ",risks.size()," risks");quit()
