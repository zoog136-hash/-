extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var errors: Array[String]=[]
var checks: int=0

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: errors.append(message)

func run() -> void:
	var args: Dictionary={}
	for arg: String in OS.get_cmdline_user_args():
		var split: PackedStringArray=arg.trim_prefix("--").split("=",true,1)
		if split.size()==2: args[split[0]]=split[1]
	if not args.has("pack") or not args.has("expected") or not args.has("blocked"):
		push_error("Explicit private original pack, independent pixel hashes and blocked source closure required")
		quit(2); return
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.pack).path_join("receipt.json")))
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.expected))
	var source=PACK.new()
	var opened: Dictionary=source.open(args.pack,receipt.manifest_sha256)
	check(opened.get("ok",false),"verified original pack did not open")
	if not opened.get("ok",false):
		print("ORIGINAL_UI_PACK_RESULT ",JSON.stringify({"checks":checks,"errors":errors,"detail":opened})); quit(1); return
	var frames: int=0
	var rotated: int=0
	for plist: String in source.manifest.atlases:
		for key: String in source.manifest.atlases[plist].frames:
			var ref: Dictionary={"path":key,"plistFile":plist,"resourceType":1}
			var texture: Texture2D=source.texture(ref)
			frames+=1
			if source.manifest.atlases[plist].frames[key].rotated: rotated+=1
			check(texture!=null,"missing original frame: "+plist+":"+key)
			if texture==null: continue
			var spec: Dictionary=expected.get(plist+":"+key,{})
			check(not spec.is_empty(),"missing independent comparison")
			check(PACK._sha256(texture.get_image().get_data())==spec.get("rgba_sha256",""),"original pixel mismatch: "+key)
			check(is_same(texture,source.texture(ref)),"redecoded identical source frame")
	check(source.texture({"path":"not_declared.png","plistFile":"UI/absent.plist"})==null,"invented fallback texture")
	var prior: String=source.manifest_sha256
	check(not source.open(args.pack,"0".repeat(64)).ok,"accepted altered manifest hash")
	check(source.manifest_sha256==prior,"failed replacement discarded previous pack")
	var blocked_receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.blocked).path_join("receipt.json")))
	var blocked: Dictionary=source.open(args.blocked,blocked_receipt.manifest_sha256)
	check(not blocked.ok and blocked.error=="unresolved_source_dependencies","incomplete source closure activated")
	check(source.manifest_sha256==prior,"incomplete replacement changed active source")
	check(not PACK._safe_member("UI/../outside.png"),"accepted traversal")
	check(not PACK._safe_member("UI\\file.png"),"accepted backslash alias")
	print("ORIGINAL_UI_PACK_RESULT ",JSON.stringify({"checks":checks,"frames":frames,"rotated_frames":rotated,"errors":errors,"screen_rendering":false,"gameplay":false}))
	quit(0 if errors.is_empty() else 1)
