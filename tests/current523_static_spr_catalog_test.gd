extends SceneTree
## One new parser/binding coverage pass, no rendering or logical-Land play claim.
const SPR=preload("res://scripts/maps/current523_static_spr.gd")
const SOURCE=preload("res://scripts/maps/current523_source_pack.gd")
const PACK=preload("res://scripts/resources/current523_pack.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	for key: String in ["source-root","source-sha","sp2-root"]:
		if not args.has(key):printerr("Held original input required: "+key);quit(2);return
	var pack=SOURCE.new()
	if not pack.load_catalog(args["source-root"],args["source-sha"]):printerr(pack.problem);quit(1);return
	var registry: String=args["sp2-root"].path_join(PACK.REGISTRY)
	if FileAccess.get_sha256(registry)!=PACK.REGISTRY_SHA:printerr("Original registry identity mismatch");quit(1);return
	var direct: Dictionary={}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(registry)):
		if str(row.member).ends_with("-0.sp2"):direct[int(str(row.member).trim_prefix("Sprite/").trim_suffix("-0.sp2"))]=true
	var assets: Dictionary={}
	for row: Dictionary in pack.catalog_lands():
		if row.policy_status=="classified" and row.excluded_content.is_empty():assets[str(row.declaration.AssetPath)]=true
	var failures: Array=[];var members: int=0;var records: int=0;var matched: int=0;var effect_members: int=0
	var unresolved: Dictionary={};var ids: Dictionary={};var trailer_lengths: Dictionary={}
	for asset: String in assets:
		if not pack.select_asset(asset):failures.append({"asset":asset,"error":pack.problem});continue
		for member: String in pack.supported_s32_members():
			var original: Dictionary=pack.read_member(member)
			if original.is_empty():failures.append({"member":member,"error":pack.problem});continue
			var parsed: Dictionary=SPR.parse_tail(original.sections.tail,int(pack.source_metadata(member).core_end))
			if not parsed.ok:failures.append({"member":member,"error":parsed.error});continue
			members+=1;records+=parsed.records.size()
			if not parsed.records.is_empty():effect_members+=1
			var n: int=parsed.trailer.size();trailer_lengths[n]=int(trailer_lengths.get(n,0))+1
			for row: Dictionary in parsed.records:
				ids[int(row.sprite_id)]=true
				if direct.has(int(row.sprite_id)):matched+=1
				else:unresolved[int(row.sprite_id)]=int(unresolved.get(int(row.sprite_id),0))+1
		if assets.keys().find(asset)%50==0:print("CURRENT523_STATIC_SPR_CATALOG_PROGRESS ",members," ",records)
	var result: Dictionary={"physical_roots":assets.size(),"verified_S32_members":members,"static_records":records,"members_with_static_records":effect_members,"distinct_literal_sprite_ids":ids.size(),"records_with_held_literal_0_SP2":matched,"unresolved_ids":unresolved,"preserved_trailer_lengths":trailer_lengths,"failures":failures,"new_parser_and_literal_binding_only":true,"actual_whole_map_SPR_play_or_native_semantics_verified":false}
	print("CURRENT523_STATIC_SPR_CATALOG_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() and members==6558 else 1)
