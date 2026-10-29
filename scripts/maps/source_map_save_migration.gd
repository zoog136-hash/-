extends RefCounted
## Stage spatial migration separately from the original save. The original file
## and its SHA-verified backup survive. Only an explicit successful save updates
## a small active-file pointer; failure never overwrites the original character.
const WRITER=preload("res://scripts/skills/save_writer.gd")
const COORD=preload("res://scripts/maps/source_coordinates.gd")

static func pair(value: Variant) -> bool:
	if not value is Array or value.size()!=2:return false
	for n: Variant in value:
		if not (n is int or n is float) or not is_finite(float(n)):return false
	return true

static func clear(field: PlayableField, p: Vector2) -> bool:
	var entry:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	return p.is_finite() and field.point_clear(p,4.0) and not field.path(entry,p).is_empty()

static func converted(value: Variant, field: PlayableField, legacy: Dictionary) -> Vector2:
	if not pair(value) or legacy.is_empty():return Vector2.INF
	var old=COORD.new()
	if not old.configure(legacy.origin,legacy.dimensions,legacy.coordinate_mapping):return Vector2.INF
	var components: Array=old.source_components(Vector2(value[0],value[1]))
	return field.coordinates.components_to_world(components)

static func choose(value: Variant, field: PlayableField, legacy: Dictionary, occupied: Array, spacing: float=0) -> Vector2:
	var p: Vector2=converted(value,field,legacy)
	if clear(field,p) and separated(p,occupied,spacing):return p
	var entry:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	var cell: Vector2i=field.world_to_cell(entry)
	for ring: int in range(33):
		for y: int in range(-ring,ring+1):
			for x: int in range(-ring,ring+1):
				if maxi(absi(x),absi(y))!=ring:continue
				p=field.cell_to_world(cell+Vector2i(x,y))
				if separated(p,occupied,spacing) and clear(field,p):return p
	return Vector2.INF

static func separated(p: Vector2, occupied: Array, spacing: float) -> bool:
	for q: Vector2 in occupied:
		if p.distance_to(q)<spacing:return false
	return true

static func plan(original: Dictionary, mid: String, field: PlayableField, rule: Dictionary, original_sha: String) -> Dictionary:
	var data: Dictionary=original.duplicate(true)
	var archive: Dictionary={"schema":1,"source_save_sha256":original_sha,"map_id":mid,
		"old_layouts":original.get("source_map84_layouts",{}).duplicate(true),"player":{},"ground_drops":[],"monster_states":{}}
	# Pixel coordinates are converted only for a known, source-authenticated old
	# frame. A different geographic source (111 -> 200) always uses the entry.
	var legacy: Dictionary={}
	var proposed: Dictionary=rule.get("legacy_frame",{})
	var old_source_value: Variant=original.get("original_position",{})
	var old_source: Dictionary=old_source_value if old_source_value is Dictionary else {}
	if str(original.get("map_id",""))==mid and not proposed.is_empty():
		if int(original.get("map_layout_revision",-1))==int(proposed.layout_revision) and int(old_source.get("source_map_id",-1))==int(proposed.source_map_id) and str(old_source.get("grid_sha256",""))==str(proposed.grid_sha256) and int(proposed.source_map_id)==int(field.definition.source_map_id):legacy=proposed
	if str(data.get("map_id",""))==mid:
		archive.player={"position":data.get("position",[]),"original_position":data.get("original_position",{}),"map_layout_revision":data.get("map_layout_revision",0)}
		var p: Vector2=choose(data.get("position",[]),field,legacy,[])
		if not p.is_finite():return {"ok":false,"error":"No verified player landing"}
		data.position=[p.x,p.y];data.map_layout_revision=int(field.data.layout_revision)
		data.original_position={"source_map_id":int(field.definition.source_map_id),"grid_sha256":field.definition.source_sha256,"source":field.coordinates.source_components(p)}
		for key: String in ["native_png_plan_sha256","native_png_review_sha256","oman_png_index_sha256"]:data.erase(key)
	var drops: Variant=data.get("ground_drops",[])
	if not drops is Array:return {"ok":false,"error":"Malformed ground-drop container"}
	var occupied: Array=[]
	for row: Variant in drops:
		if not row is Dictionary or str(row.get("map_id",""))!=mid:continue
		archive.ground_drops.append(row.duplicate(true))
		var p: Vector2=choose(row.get("position",[]),field,legacy,occupied,36.0)
		if not p.is_finite():return {"ok":false,"error":"No distinct verified landing for every original drop"}
		row.position=[p.x,p.y];occupied.append(p)
	for container: String in ["monster_world","original_monster_world"]:
		var holder: Variant=data.get(container,{})
		if not holder is Dictionary:return {"ok":false,"error":"Malformed monster-state container"}
		var states: Variant=holder.get("bosses",{})
		if not states is Dictionary:return {"ok":false,"error":"Malformed monster-state container"}
		for key: Variant in states:
			if not str(key).begins_with(mid+":"):continue
			var state: Variant=states[key]
			if not state is Dictionary:return {"ok":false,"error":"Malformed monster state"}
			archive.monster_states[container+":"+str(key)]=state.duplicate(true)
			for coordinate: String in ["position","home"]:
				var previous: Variant=state.get(coordinate,[])
				if previous is Array and previous.is_empty():continue
				var p: Vector2=choose(previous,field,legacy,[])
				if not p.is_finite():return {"ok":false,"error":"No verified monster-state landing"}
				state[coordinate]=[p.x,p.y]
			state.layout_revision=int(field.data.layout_revision)
	if not data.get("source_map_migrations",[]) is Array:return {"ok":false,"error":"Malformed migration history"}
	if not data.has("source_map_migrations"):data.source_map_migrations=[]
	data.source_map_migrations.append(archive)
	return {"ok":true,"data":data,"archive":archive}

static func backup(path: String, source_sha: String) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=source_sha:return {"ok":false,"error":"Source save changed during planning"}
	var dest: String=path+".pre-source-map-"+source_sha
	if FileAccess.file_exists(dest):return {"ok":FileAccess.get_sha256(dest)==source_sha,"path":dest,"error":"Existing backup hash mismatch"}
	var temp: String=dest+".tmp"
	if DirAccess.copy_absolute(path,temp)!=OK or FileAccess.get_sha256(temp)!=source_sha:return {"ok":false,"error":"Backup copy or SHA verification failed"}
	if DirAccess.rename_absolute(temp,dest)!=OK or FileAccess.get_sha256(dest)!=source_sha:return {"ok":false,"error":"Backup publication failed"}
	return {"ok":true,"path":dest}

static func stage(path: String, data: Dictionary, expected_sha: String) -> Dictionary:
	var proof: Dictionary=backup(path,expected_sha)
	if not proof.ok:return proof
	var target: String=path+".source-map-"+expected_sha+".json"
	var attempt: int=0
	while FileAccess.file_exists(target):
		attempt+=1;target=path+".source-map-"+expected_sha+"-retry%d.json" % attempt
	if WRITER.write(target,data)!=OK:return {"ok":false,"error":"Candidate write failed; original and backup preserved"}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(target))!=OK or parser.data!=JSON.parse_string(JSON.stringify(data,"",true,true)):
		return {"ok":false,"error":"Candidate verification failed; original and backup preserved"}
	if FileAccess.get_sha256(path)!=expected_sha:return {"ok":false,"error":"Original changed; candidate not activated"}
	return {"ok":true,"target_path":target,"backup_path":proof.path,"source_save_sha256":expected_sha}

static func resolve(base: String) -> Dictionary:
	var pointer: String=base+".source-map-current.json"
	if not FileAccess.file_exists(pointer):return {"ok":true,"path":base}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(pointer))!=OK or not parser.data is Dictionary:return {"ok":false,"error":"Migration pointer damaged"}
	var record: Dictionary=parser.data
	var target: String=str(record.get("target_path",""))
	if not safe_target(base,target) or not FileAccess.file_exists(target):return {"ok":false,"error":"Migrated save missing; original preserved"}
	return {"ok":true,"path":target}

static func safe_target(base: String, target: String) -> bool:
	return target.begins_with(base+".source-map-") and target.ends_with(".json") and not target.trim_prefix(base).contains("/") and not target.contains("\\")

static func activate(base: String, record: Dictionary) -> Error:
	var target: String=str(record.get("target_path",""))
	if not safe_target(base,target) or not FileAccess.file_exists(target):return ERR_INVALID_PARAMETER
	if FileAccess.get_sha256(str(record.backup_path))!=str(record.source_save_sha256):return ERR_FILE_CORRUPT
	return WRITER.write(base+".source-map-current.json",record)
