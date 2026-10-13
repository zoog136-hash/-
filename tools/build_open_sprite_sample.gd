extends SceneTree

## Offline 2D atlas conversion only. Reads published PNGs and their rectangle /
## pivot metadata; no model, 3D scene, interpolation, recoloring or mirrored view.
## Godot --headless --path . --script res://tools/build_open_sprite_sample.gd -- SOURCE_DIR
const CELL := 256
const PIVOT := Vector2i(256, 320) # native pixels before uniform 1/2 reduction
# Verified against the actual eight source views (front=6, back=2), not the
# unrelated ordering of entries in hero_layers.txt.
const SOURCE_DIRECTIONS := ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
const GAME_DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const LAYERS := {"feet":"plate_boots", "legs":"plate_greaves", "chest":"plate_cuirass",
	"hands":"plate_gauntlets", "head":"plate_helm", "main":"longsword", "off":"shield"}
const ROLES := {"idle":"stance", "walk":"run", "attack":"swing", "hit":"hit", "death":"die"}
var source: String
var failures: Array[String] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Usage: --script res://tools/build_open_sprite_sample.gd -- SOURCE_DIR")
		quit(2)
		return
	source = args[0]
	var order: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(source.path_join("mods__fantasycore__engine__hero_layers.txt")).split("\n"):
		if line.begins_with("layer="):
			var parts := line.trim_prefix("layer=").split(",")
			order[parts[0]] = parts.slice(1)
	var knight: Dictionary = {}
	for layer: String in LAYERS: knight[layer] = read_source("avatar/male/" + str(LAYERS[layer]))
	var skeleton := {"body": read_source("enemies/skeleton")}
	build("knight", knight, order)
	build("skeleton_guard", skeleton, {})
	if failures.is_empty(): print("OPEN_SPRITE_CONVERSION_OK: two 2D actors, 8 real views, original offsets")
	else: printerr(failures)
	quit(0 if failures.is_empty() else 1)

func read_source(name_value: String) -> Dictionary:
	var stem := "mods__fantasycore__animations__" + name_value.replace("/", "__") + ".txt"
	var result := {"tracks":{}}
	var role := ""
	for line: String in FileAccess.get_file_as_string(source.path_join(stem)).split("\n"):
		if line.begins_with("["):
			role = line.trim_prefix("[").trim_suffix("]")
			result.tracks[role] = {"cells":{}}
		elif line.begins_with("image="):
			var relative := "mods/fantasycore/" + line.trim_prefix("image=")
			result.image = Image.load_from_file(source.path_join(relative.replace("/", "__")))
		elif not role.is_empty() and line.contains("="):
			var pair := line.split("=", true, 1)
			if pair[0] == "frame":
				var cell := Array(pair[1].split(",")).map(func(x: String) -> int: return int(x))
				result.tracks[role].cells["%d:%d" % [cell[0], cell[1]]] = cell.slice(2)
			else: result.tracks[role][pair[0]] = pair[1]
	return result

func build(actor: String, layers: Dictionary, order: Dictionary) -> void:
	var folder := "res://assets/actors/eight_direction/" + actor
	DirAccess.make_dir_recursive_absolute(folder)
	var header := "[gd_resource type=\"SpriteFrames\" load_steps=1 format=3]\n\n"
	var ext := ""
	var sub := ""
	var animations: Array[String] = []
	var sub_id := 0
	var metadata := {"source":"Flare Game af6eee6d339ac98011864bfe89da837fe7769c28",
		"motion":"actual sequential frames", "directions":GAME_DIRECTIONS,
		"source_directions":SOURCE_DIRECTIONS, "cell":[CELL,CELL], "foot":[128,160], "tracks":{}}
	for role: String in ROLES:
		var source_role: String = ROLES[role]
		var track: Dictionary = layers.values()[0].tracks[source_role]
		var count := int(track.frames)
		var duration := float(str(track.duration).trim_suffix("ms")) / 1000.0
		var sheet := Image.create(CELL * count, CELL * 8, false, Image.FORMAT_RGBA8)
		var ext_id := role
		ext += "[ext_resource type=\"Texture2D\" path=\"%s/%s.png\" id=\"%s\"]\n" % [folder, role, ext_id]
		metadata.tracks[role] = {"unique_frames_per_direction":count, "source_duration_seconds":duration,
			"loop_type":track.type, "sha256":""}
		for game_dir: int in range(8):
			var compass: String = GAME_DIRECTIONS[game_dir]
			var source_dir := SOURCE_DIRECTIONS.find(compass)
			var stack: Array = Array(order[compass]) if not order.is_empty() else ["body"]
			var ids: Array[int] = []
			for index: int in range(count):
				var frame := Image.create(CELL * 2, CELL * 2, false, Image.FORMAT_RGBA8)
				for layer: String in stack:
					var data: Dictionary = layers[layer]
					var rect: Array = data.tracks[source_role].cells["%d:%d" % [index, source_dir]]
					var pos := PIVOT - Vector2i(rect[4], rect[5])
					var size_value := Vector2i(rect[2], rect[3])
					if pos.x < 0 or pos.y < 0 or pos.x + size_value.x > 512 or pos.y + size_value.y > 512:
						failures.append("clipped %s %s %s %d" % [actor, role, compass, index])
					frame.blend_rect(data.image, Rect2i(rect[0],rect[1],rect[2],rect[3]), pos)
				frame.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(frame, Rect2i(0,0,CELL,CELL), Vector2i(index * CELL, game_dir * CELL))
				sub_id += 1
				ids.append(sub_id)
				sub += "[sub_resource type=\"AtlasTexture\" id=\"Frame_%d\"]\natlas = ExtResource(\"%s\")\nregion = Rect2(%d, %d, %d, %d)\nfilter_clip = true\n\n" % [sub_id,ext_id,index*CELL,game_dir*CELL,CELL,CELL]
			var sequence := ids.duplicate()
			if role == "idle" and str(track.type) == "back_forth":
				for index: int in range(count - 2, 0, -1): sequence.append(ids[index])
			var entries: Array[String] = []
			for id: int in sequence: entries.append('{"duration":1.0,"texture":SubResource("Frame_%d")}' % id)
			animations.append('{"frames":[%s],"loop":%s,"name":&"%s_%d","speed":%s}' % [",".join(entries),"true" if role in ["idle","walk"] else "false",role,game_dir,float(count)/duration])
		var output := folder.path_join(role + ".png")
		if sheet.save_png(output) != OK: failures.append("write " + output)
		metadata.tracks[role].sha256 = FileAccess.get_sha256(output)
	header = header.replace("load_steps=1", "load_steps=" + str(sub_id + ROLES.size() + 1))
	FileAccess.open(folder.path_join("SpriteFrames.tres"), FileAccess.WRITE).store_string(header + ext + "\n" + sub + "[resource]\nanimations = [" + ",\n".join(animations) + "]\n")
	FileAccess.open(folder.path_join("provenance.json"), FileAccess.WRITE).store_string(JSON.stringify(metadata, "\t") + "\n")
