extends SceneTree
## Icon CSB scene selection built from the complete 523 client.
## Without arguments only the fail-closed selection contract is checked. With
## private packs: --images=<image pack root> --images-sha=<pin>
## --selection=<selection json> --selection-sha=<pin> attaches every
## ItemClass/SpellClass/BuffClass icon whose AssetView row is an icon CSB.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const SKILL_BUFF = preload("res://scripts/ui/source523_skill_buff_images.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var missing: Dictionary = IMAGES.configure_original_ui_selection("/missing/source523-ui-icons.json","0".repeat(64))
	check(not missing.get("ok",true) and missing.get("error") == "source_scene_selection_file_unavailable","missing selection fails closed")
	check(not IMAGES.configure_original_ui_selection("/missing/source523-ui-icons.json","short").get("ok",true),"selection without a full pin is refused")
	var evidence: Dictionary = {"consumer_references":0,"linked":0,"failed":{},"by_role":{}}
	var images_root: String = argument("--images=")
	if not images_root.is_empty():
		var opened: Dictionary = IMAGES.configure(images_root,argument("--images-sha="))
		check(opened.get("ok",false),"image pack opens")
		var selection_path: String = argument("--selection=")
		var pin: String = argument("--selection-sha=")
		check(not IMAGES.configure_original_ui_selection(selection_path,"0".repeat(64)).get("ok",true),"wrong selection pin is refused")
		var registered: Dictionary = IMAGES.configure_original_ui_selection(selection_path,pin)
		check(registered.get("ok",false),"selection registers: "+str(registered.get("error","")))
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(images_root.path_join("manifest.json")))
		var csb_icons: Dictionary = {}
		var asset_status: Dictionary = {}
		for asset: Dictionary in manifest.assets: asset_status[int(asset.asset_id)] = asset.status
		for icon: Dictionary in manifest.icons:
			if asset_status.get(int(icon.asset_id),"") == "unsupported_csb": csb_icons[int(icon.id)] = true
		var view := TextureRect.new()
		view.size = Vector2(64,64)
		root.add_child(view)
		for table: String in manifest.consumers:
			for row: Dictionary in manifest.consumers[table]:
				for role: String in row.roles:
					if not csb_icons.has(int(row.roles[role])): continue
					evidence.consumer_references += 1
					# The game's own presentation routes build the icon info.
					var info: Dictionary
					if table == "ItemClass":
						info = IMAGES.describe_item_class(int(row.id))
					else:
						var source: Dictionary = IMAGES.active().source_consumer_row(table,int(row.id))
						info = SKILL_BUFF.describe_spell_class_row(source.get("row",{}),role) if table == "SpellClass" else SKILL_BUFF.describe_buff_class_row(source.get("row",{}),role)
					var label: String = "%s.%s:%d" % [table,role,int(row.id)]
					if info.get("reason") != "unsupported_csb":
						evidence.failed[label] = "not_csb:"+str(info.get("reason",""))
						continue
					var attached: Dictionary = IMAGES.attach_original_icon(view,info,{},{"usage":"list","trigger":"selection_test"})
					if not attached.get("ok",false):
						evidence.failed[label] = str(attached.get("error",""))
						continue
					if attached.get("clip") == "normal" and attached.get("repeat") == true and attached.get("original_policy_confirmed") == true and attached.get("origin") == "explicit_caller_repeat" and view.get_node_or_null("SourceItemIconScene") != null:
						evidence.linked += 1
						var key: String = table+"."+role
						evidence.by_role[key] = int(evidence.by_role.get(key,0))+1
					else:
						evidence.failed[label] = "unexpected_policy"
		IMAGES.ORIGINAL_UI_ICONS.detach(view)
		check(evidence.consumer_references > 0 and evidence.linked == evidence.consumer_references,"every icon CSB consumer reference links with the client normal loop")
		if evidence.failed.size() > 20:
			var first: Dictionary = {}
			for key: Variant in evidence.failed.keys().slice(0,20): first[key] = evidence.failed[key]
			evidence["failed_count"] = evidence.failed.size()
			evidence.failed = first
	print("SOURCE523_ICON_SCENE_SELECTION_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
