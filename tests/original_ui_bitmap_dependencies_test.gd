extends SceneTree
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
func _initialize() -> void:
	var args=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var pack=PACK.new()
	var good_receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("receipt.json")))
	var old_receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[1].path_join("receipt.json")))
	var good: Dictionary=pack.open(args[0],good_receipt.manifest_sha256)
	var before: String=pack.manifest_sha256
	var rejected: Dictionary=pack.open(args[1],old_receipt.manifest_sha256)
	var checks: Array[bool]=[good.ok,not rejected.ok,str(rejected.get("error","")).begins_with("bitmap_font_page_dependencies:"),pack.manifest_sha256==before]
	var failures: int=checks.count(false)
	print("BITMAP_DEPENDENCY_REJECTION ",JSON.stringify({"checks":checks.size(),"failures":failures,"scope":"explicit original packs; missing font page and preserved prior pack"}))
	quit(0 if failures==0 else 1)
