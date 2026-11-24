extends SceneTree
## Exercises the production pack admission + projection. Optional --pack uses
## the exact ui44 release. No originals or caches are stored in git.
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SELECT=preload("res://scripts/ui/original_ui/source_node_scope.gd")
const GACHA=preload("res://scripts/ui/original_ui/source_main_card_gacha_window.gd")
const SLOT=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const MAP=preload("res://scripts/ui/original_ui/source_main_map_bindings.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const PIN="5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c"
const CASE="UI/fixture/Scope.csb"
var n:=0;var failures: Array[String]=[]
var samples: Dictionary={}
func ck(ok: bool,msg: String)->void:
	n+=1
	if not ok: failures.append(msg);printerr("OWNED_SCOPE_FAIL ",msg)
func _initialize()->void:run.call_deferred()
class Record extends RefCounted:
	var rows: Dictionary={}
	func read(id: String)->Variant:return bytes_to_var(rows[id]) if rows.has(id) else null
func run()->void:
	var raw: Dictionary={"nodeTree":{"_offset":1,"options":{"actionTag":1},"children":[{"_offset":2,"options":{"actionTag":2},"children":[]},{"_offset":3,"options":{"actionTag":3},"children":[]}]},"action":{"timeLines":[{"actionTag":2,"frames":[{"v":1}]},{"actionTag":3,"frames":[{"v":2}]}],"duration":3},"meta":{"custom":[1,2]}}
	var p:=PACK.new();p.manifest={"scenes":{CASE:raw}}
	var ids: Array[int]=[2]
	var ref: Dictionary=SELECT.select(raw,ids)
	for record_mode: bool in [false,true]:
		if record_mode:
			var reader:=Record.new();reader.rows={"s:"+CASE:var_to_bytes(raw)};p._records=reader
		var before:=var_to_bytes(raw)
		var input: Dictionary=p.scope_input(CASE)
		var result: Dictionary=SELECT.select(input.tree,ids,input.owned)
		ck(input.owned==record_mode and var_to_bytes(result)==var_to_bytes(ref),"in-memory and baked output order, children, tracks and all metadata")
		result.tree.nodeTree.children[0].options.actionTag=999
		result.tree.action.timeLines[0].frames[0].v=-8; result.tree.meta.custom[0]=-9
		ck(var_to_bytes(raw)==before and var_to_bytes(p.scene(CASE))==before,"no mutation of pack or later scene")
		for bad: Array in [[5],[2,2]]:
			var request: Array[int]=[];request.assign(bad)
			input=p.scope_input(CASE)
			ck(SELECT.select(input.tree,request,input.owned)==SELECT.select(raw,request),"same missing/duplicate refusal")
		var partial: Dictionary=raw.duplicate(true)
		partial["_partial_source_scene"]=true;partial["_selected_source_offsets"]=[2]
		var guard:=PACK.new();guard.manifest={"scenes":{CASE:partial}}
		if record_mode:
			var guard_reader:=Record.new();guard_reader.rows={"s:"+CASE:var_to_bytes(partial)};guard._records=guard_reader
		var renderer:=SCENE.new()
		var denied: Dictionary=renderer.configure_nodes(guard,CASE,[3],{})
		ck(denied=={"ok":false,"error":"source_node_outside_pack_scope","offset":3},"real renderer keeps partial admission on both sources")
		renderer.free()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pack="):real(arg.trim_prefix("--pack="))
		elif arg.begins_with("--scope-sample="):sample_pack(arg.trim_prefix("--scope-sample="))
	print("SOURCE_UI_OWNED_SCOPE_RESULT ",JSON.stringify({"checks":n,"failures":failures,"pc_scope_usec_old_new":samples}))
	quit(0 if failures.is_empty() else 1)
func real(path: String)->void:
	var p:=PACK.new()
	var opened: Dictionary=p.open(path,PIN)
	ck(opened.get("ok",false),"real ui44 accepts pinned originals")
	if not opened.get("ok",false):return
	bench(p)
func sample_pack(path: String)->void:
	if FileAccess.get_sha256(path)!="8956873f1506303e1a2551a448ce139b55889bcaf24f460286cef51fa44111d0":ck(false,"ui44 audited 33-scene closure SHA");return
	var p:=PACK.new();p.manifest=JSON.parse_string(FileAccess.get_file_as_string(path));p.manifest_sha256=PIN
	var store:=preload("res://scripts/resources/current523_bake_cache.gd").RecordFile.new()
	var file: String="user://ui-scope-record-sample-"+str(Time.get_ticks_usec())+".bin"
	store.file=FileAccess.open(file,FileAccess.WRITE_READ)
	for member: String in p.manifest.scenes:
		store.offsets["s:"+member]=store.file.get_position()
		store.file.store_var(p.manifest.scenes[member])
	store.file.flush();p._records=store
	bench(p)
	store.file.close();p._records=null
	DirAccess.remove_absolute(file)
func bench(p: RefCounted)->void:
	var g=GACHA.new();g._pack=p;g.results=[{"name":"받은 변신","grade":"전설"}];g.category="변신";g.opened=[false] as Array[bool]
	g._stage_trees={}
	var binding: Dictionary=g._bind(g.ROOT,"",[],g._spec(),{})
	g._stage_trees=null
	var cases: Dictionary={"gacha":[g.ROOT,binding.scope],"inventory_slot":[SLOT.SLOT_MEMBER,[SLOT.BUTTON,SLOT.BACKGROUND,SLOT.SELECTED,SLOT.ICON,SLOT.AMOUNT]],"map_area":[MAP.MAP_ALL,MAP.AREA_INFO_SCOPE],"minimap":[MAP.MINIMAP_MEMBER,[MAP.MAP_NAME_TEXT,MAP.ZONE_TEXT]]}
	for key: String in cases:
		var member: String=cases[key][0];var offsets: Array[int]=[];offsets.assign(cases[key][1])
		var baseline:=PackedByteArray()
		var timings: Array=[[],[]]
		for i: int in 13:
			for arm: int in ([0,1] if i%2==0 else [1,0]):
				var start:=Time.get_ticks_usec()
				var projected: Dictionary
				if arm==0:projected=SELECT.select(p.scene(member),offsets)
				else:
					var input: Dictionary=p.scope_input(member)
					projected=SELECT.select(input.tree,offsets,input.owned)
				var elapsed:=Time.get_ticks_usec()-start
				if i>0:timings[arm].append(elapsed)
				var bytes:=var_to_bytes(projected)
				if baseline.is_empty():baseline=bytes
				ck(projected.get("ok",false) and bytes==baseline,"exact "+key+" scene and animation graph "+str(projected.get("code","")))
		samples[key]={"scope":offsets.size(),"file_read_included":true,"bake":p._records!=null,"us":timings}
