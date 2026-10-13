extends SceneTree

## Offline 2D atlas conversion only. Reads published PNGs and their rectangle /
## pivot metadata; no model, 3D scene, interpolation, recoloring or mirrored view.
## Godot --headless --path . --script res://tools/build_open_sprite_sample.gd -- SOURCE_DIR
const CELL := 256
const PIVOT := Vector2i(256, 320) # native pixels before uniform 1/2 reduction
# Source 0 faces screen-left, 2 faces the viewer and 6 shows the back.
# The previous labels inverted all views by 180 degrees. Keep this source
# convention separate from clockwise Godot screen coordinates (positive Y down).
const SOURCE_DIRECTIONS := ["W", "SW", "S", "SE", "E", "NE", "N", "NW"]
const GAME_DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const LAYERS := {"feet":"plate_boots", "legs":"plate_greaves", "chest":"plate_cuirass",
	"hands":"plate_gauntlets", "head":"plate_helm", "main":"longsword", "off":"shield"}
const ROLES := {"idle":"stance", "walk":"run", "attack":"swing", "hit":"hit", "death":"die"}
var source: String
var failures: Array[String] = []
var image_cache: Dictionary = {}
var image_order: Array[String] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [1,2]:
		printerr("Usage: --script res://tools/build_open_sprite_sample.gd -- SOURCE_DIR [RECIPE_JSON]")
		quit(2)
		return
	source = args[0]
	var order: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(source.path_join("mods__fantasycore__engine__hero_layers.txt")).split("\n"):
		if line.begins_with("layer="):
			var parts := line.trim_prefix("layer=").split(",")
			order[parts[0]] = parts.slice(1)
	if args.size() == 2:
		var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		for actor: String in recipes.actors:
			var recipe: Dictionary = recipes.actors[actor]
			var parts: Dictionary = {}
			for layer: String in recipe.layers: parts[layer] = read_source(str(recipe.layers[layer]))
			build(actor,parts,order if recipe.get("equipment",false) else {},recipe)
		print("OPEN_SPRITE_EXPANSION_%s actors=%d" % ["OK" if failures.is_empty() else "FAILED",recipes.actors.size()])
		if not failures.is_empty(): printerr(failures)
		quit(0 if failures.is_empty() else 1)
		return
	var knight: Dictionary = {}
	for layer: String in LAYERS: knight[layer] = read_source("avatar/male/" + str(LAYERS[layer]))
	var skeleton := {"body": read_source("enemies/skeleton")}
	build("knight", knight, order)
	build("skeleton_guard", skeleton, {})
	if failures.is_empty(): print("OPEN_SPRITE_CONVERSION_OK: two 2D actors, 8 real views, original offsets")
	else: printerr(failures)
	quit(0 if failures.is_empty() else 1)

func read_source(name_value: String) -> Dictionary:
	var relative: String = name_value if name_value.begins_with("mods/") else "mods/fantasycore/animations/"+name_value+".txt"
	var stem := relative.replace("/","__")
	var mod: String = "/".join(relative.split("/").slice(0,2))
	var text := FileAccess.get_file_as_string(source.path_join(stem))
	var result := {"tracks":{},"images":{}}
	for line: String in text.split("\n"):
		if line.begins_with("INCLUDE "):
			var include := mod+"/"+line.trim_prefix("INCLUDE ").strip_edges()
			if not FileAccess.file_exists(source.path_join(include.replace("/","__"))): include="mods/fantasycore/"+line.trim_prefix("INCLUDE ").strip_edges()
			result=read_source(include)
	var role := ""
	for line: String in text.split("\n"):
		if line.begins_with("["):
			role = line.trim_prefix("[").trim_suffix("]")
			result.tracks[role] = {"cells":{}}
		elif line.begins_with("image="):
			var pair := line.trim_prefix("image=").split(",")
			result.images[pair[1] if pair.size()>1 else "default"] = mod+"/"+pair[0]
		elif not role.is_empty() and line.contains("="):
			var pair := line.split("=", true, 1)
			if pair[0] == "frame":
				var values := pair[1].split(",")
				var cell: Array = []
				for i: int in range(8): cell.append(int(values[i]))
				if values.size()>8: cell.append(str(values[8]))
				result.tracks[role].cells["%d:%d" % [cell[0], cell[1]]] = cell.slice(2)
			else: result.tracks[role][pair[0]] = pair[1]
	return result

func source_image(data: Dictionary, rect: Array) -> Image:
	var tag: String = str(rect[6]) if rect.size()>6 else "default"
	var relative: String = str(data.images.get(tag,data.images.get("default","")))
	if image_cache.has(relative):
		image_order.erase(relative);image_order.append(relative)
		return image_cache[relative]
	var value := Image.load_from_file(source.path_join(relative.replace("/","__")))
	image_cache[relative]=value;image_order.append(relative)
	while image_order.size()>16: image_cache.erase(image_order.pop_front())
	return value

func build(actor: String, layers: Dictionary, order: Dictionary, recipe: Dictionary = {}) -> void:
	var folder := "res://assets/actors/eight_direction/" + actor
	DirAccess.make_dir_recursive_absolute(folder)
	var header := "[gd_resource type=\"SpriteFrames\" load_steps=1 format=3]\n\n"
	var ext := ""
	var sub := ""
	var animations: Array[String] = []
	var sub_id := 0
	var ext_count := 0
	var all_pixels: Dictionary = {}
	var roles: Dictionary = recipe.get("roles",ROLES)
	# Fit large creatures uniformly across every pose, retaining one foot pivot.
	var fit: float = 1.0
	for role: String in roles:
		for data: Dictionary in layers.values():
			if not data.tracks.has(roles[role]):
				failures.append("missing action %s %s" % [actor,roles[role]])
				return
			for r: Array in data.tracks[roles[role]].cells.values():
				fit=minf(fit,minf(254./maxf(1,r[4]),254./maxf(1,r[2]-r[4])))
				fit=minf(fit,minf(318./maxf(1,r[5]),190./maxf(1,r[3]-r[5])))
	var metadata := {"source":"Flare Game af6eee6d339ac98011864bfe89da837fe7769c28",
		"motion":"actual sequential frames", "directions":GAME_DIRECTIONS,
		"source_directions":SOURCE_DIRECTIONS, "cell":[CELL,CELL], "foot":[128,160],
		"source_direction_indices":GAME_DIRECTIONS.map(func(compass: String) -> int: return SOURCE_DIRECTIONS.find(compass)),
		"source_scale":fit*.5, "source_roles":roles,
		"packing":"trimmed alpha rectangles; AtlasTexture.margin restores the full original canvas", "tracks":{}}
	for role: String in roles:
		var source_role: String = roles[role]
		var track: Dictionary = layers.values()[0].tracks[source_role]
		var count := int(track.frames)
		var duration := float(str(track.duration).trim_suffix("ms")) / 1000.0
		var packed: Array[Dictionary] = []
		var cursor := Vector2i(2,2)
		var row_height := 0
		var used_height := 0
		var page := 0
		var pages: Array[Dictionary] = []
		metadata.tracks[role] = {"source_frames_per_direction":count,"unique_frames_per_direction":count,"direction_unique_frames":{}, "source_duration_seconds":duration,
			"loop_type":track.type, "sha256":""}
		for game_dir: int in range(8):
			var compass: String = GAME_DIRECTIONS[game_dir]
			var source_dir := SOURCE_DIRECTIONS.find(compass)
			var stack: Array = Array(order[compass]).filter(func(key: String) -> bool: return layers.has(key)) if not order.is_empty() else layers.keys()
			var ids: Array[int] = []
			var unique_pixels: Dictionary = {}
			for index: int in range(count):
				var frame := Image.create(CELL * 2, CELL * 2, false, Image.FORMAT_RGBA8)
				for layer: String in stack:
					var data: Dictionary = layers[layer]
					var rect: Array = data.tracks[source_role].cells["%d:%d" % [index, source_dir]]
					var pos := PIVOT - Vector2i(roundi(rect[4]*fit), roundi(rect[5]*fit))
					var size_value := Vector2i(maxi(1,roundi(rect[2]*fit)), maxi(1,roundi(rect[3]*fit)))
					if pos.x < 0 or pos.y < 0 or pos.x + size_value.x > 512 or pos.y + size_value.y > 512:
						failures.append("clipped %s %s %s %d" % [actor, role, compass, index])
					var image_value := source_image(data,rect)
					if is_equal_approx(fit,1.): frame.blend_rect(image_value, Rect2i(rect[0],rect[1],rect[2],rect[3]), pos)
					else:
						var part := image_value.get_region(Rect2i(rect[0],rect[1],rect[2],rect[3]))
						part.resize(size_value.x,size_value.y,Image.INTERPOLATE_LANCZOS)
						frame.blend_rect(part,Rect2i(Vector2i.ZERO,size_value),pos)
				frame.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
				var pixel_hash := HashingContext.new()
				pixel_hash.start(HashingContext.HASH_SHA256);pixel_hash.update(frame.get_data())
				var digest := pixel_hash.finish().hex_encode()
				unique_pixels[digest]=true;all_pixels[digest]=true
				var crop := frame.get_used_rect().grow(1).intersection(Rect2i(0,0,CELL,CELL))
				if cursor.x + crop.size.x + 2 > 1024:
					cursor = Vector2i(2,cursor.y + row_height + 2)
					row_height = 0
				if cursor.y + maxi(row_height,crop.size.y) + 2 > 2048:
					pages.append({"cells":packed,"height":used_height})
					packed=[];cursor=Vector2i(2,2);row_height=0;used_height=0;page+=1
				var rect := Rect2i(cursor,crop.size)
				packed.append({"image":frame.get_region(crop),"position":cursor})
				cursor.x += crop.size.x + 2
				row_height = maxi(row_height,crop.size.y)
				used_height=maxi(used_height,cursor.y+crop.size.y+2)
				sub_id += 1
				ids.append(sub_id)
				sub += "[sub_resource type=\"AtlasTexture\" id=\"Frame_%d\"]\natlas = ExtResource(\"%s_%d\")\nregion = Rect2(%d, %d, %d, %d)\nmargin = Rect2(%d, %d, %d, %d)\nfilter_clip = true\n\n" % [sub_id,role,page,rect.position.x,rect.position.y,rect.size.x,rect.size.y,crop.position.x,crop.position.y,CELL-crop.size.x,CELL-crop.size.y]
			metadata.tracks[role].direction_unique_frames[compass]=unique_pixels.size()
			metadata.tracks[role].unique_frames_per_direction=mini(metadata.tracks[role].unique_frames_per_direction,unique_pixels.size())
			var sequence := ids.duplicate()
			if role == "idle" and str(track.type) == "back_forth":
				for index: int in range(count - 2, 0, -1): sequence.append(ids[index])
			var entries: Array[String] = []
			for id: int in sequence: entries.append('{"duration":1.0,"texture":SubResource("Frame_%d")}' % id)
			animations.append('{"frames":[%s],"loop":%s,"name":&"%s_%d","speed":%s}' % [",".join(entries),"true" if role in ["idle","walk"] else "false",role,game_dir,float(count)/duration])
		pages.append({"cells":packed,"height":used_height})
		metadata.tracks[role].atlas_files=[]
		for index: int in range(pages.size()):
			var sheet := Image.create(1024,ceili(float(pages[index].height)/4.)*4,false,Image.FORMAT_RGBA8)
			for cell: Dictionary in pages[index].cells:
				var image_value: Image = cell.image
				sheet.blit_rect(image_value,Rect2i(Vector2i.ZERO,image_value.get_size()),cell.position)
			var output := folder.path_join(role+("" if index==0 else "_"+str(index))+".png")
			if sheet.save_png(output) != OK: failures.append("write " + output)
			ext += "[ext_resource type=\"Texture2D\" path=\"%s\" id=\"%s_%d\"]\n" % [output,role,index]
			ext_count+=1
			metadata.tracks[role].atlas_files.append({"path":output,"sha256":FileAccess.get_sha256(output),"size":[sheet.get_width(),sheet.get_height()]})
			if index==0:
				metadata.tracks[role].sha256=FileAccess.get_sha256(output)
				metadata.tracks[role].atlas_size=[sheet.get_width(),sheet.get_height()]
	header = header.replace("load_steps=1", "load_steps=" + str(sub_id + ext_count + 1))
	metadata.distinct_pixel_frames=all_pixels.size()
	FileAccess.open(folder.path_join("SpriteFrames.tres"), FileAccess.WRITE).store_string(header + ext + "\n" + sub + "[resource]\nanimations = [" + ",\n".join(animations) + "]\n")
	FileAccess.open(folder.path_join("provenance.json"), FileAccess.WRITE).store_string(JSON.stringify(metadata, "\t") + "\n")
