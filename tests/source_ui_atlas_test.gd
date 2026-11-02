extends SceneTree
const ATLAS = preload("res://scripts/ui/source_ui_atlas.gd")
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var expected_path: String = ""
	var private_root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--expected="): expected_path=arg.trim_prefix("--expected=")
		if arg.begins_with("--private-ui-root="): private_root=arg.trim_prefix("--private-ui-root=")
	if expected_path.is_empty() or private_root.is_empty(): push_error("Explicit expected pixel hashes and private UI root required"); quit(2); return
	var installer: Script=load("res://scripts/lineagem_pack_install.gd"); installer._session_root=private_root
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	var count: int=0
	for plist: String in ATLAS.INDEX.data.atlases:
		for key: String in ATLAS.INDEX.data.atlases[plist].frames:
			var original: Image=ATLAS.frame(plist,key)
			count+=1
			if original==null: errors.append("missing "+key); continue
			var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(original.get_data())
			if digest.finish().hex_encode()!=expected.get(plist+":"+key,""): errors.append("pixel mismatch "+key)
			if not is_same(original,ATLAS.frame(plist,key)): errors.append("image cache miss "+key)
	if ATLAS.pages.size()!=ATLAS.INDEX.data.atlases.size(): errors.append("unexpected page decode count")
	if ATLAS.frame("UI/absent.plist","absent.png")!=null: errors.append("invented fallback")
	var record: Dictionary={"source":"lineagem_base508","sourceId":"m508:1:4","source_grade_id":3}
	var presentation: Script=load("res://scripts/ui/source_card_presentation.gd")
	var portrait: Texture2D=presentation.detail(record,true,false).get("texture")
	var skin: Script=load("res://scripts/ui/source_card_skin.gd")
	var icon: Texture2D=skin.icon(record,portrait)
	if portrait==null or portrait.get_size()!=Vector2(108,132) or icon==null or icon.get_size()!=Vector2(110,134):errors.append("centered source portrait composition failed")
	if not is_same(icon,skin.icon(record,portrait)):errors.append("card icon recreated")
	var api: Script=load("res://scripts/lineagem_base508.gd")
	var grade_checked: int=0
	var unbound: int=0
	for category: String in api.cards().catalog:
		for card: Dictionary in api.cards().catalog[category]:
			if int(card.get("source_grade_id",0))==0: continue
			var grade_key: String=str(int(card.get("source_grade_id",0)))
			if ATLAS.INDEX.data.unbound_grades.has(grade_key):
				unbound+=1
				if skin.frame_status(card)!="undeclared":errors.append("invented event frame "+str(card.sourceId))
				continue
			grade_checked+=1
			if skin.frame_status(card)!="original":errors.append("missing canonical grade frame "+str(card.sourceId))
	print("SOURCE_UI_ATLAS_RESULT ",JSON.stringify({"frames":count,"canonical_grade_cards":grade_checked,"unbound_source_event_cards":unbound,"decoded_pages":ATLAS.pages.size(),"errors":errors}))
	quit(0 if errors.is_empty() else 1)
