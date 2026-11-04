extends RefCounted
## UI-only reader of the shared source catalog and installed private pack.
## Never infer an asset from a name, grade, or numeric ID.
const SOURCE_API = "res://scripts/lineagem_base508.gd"
const CARDS = preload("res://scripts/card_draw_fusion.gd")
const LIMIT: int = 96
static var textures: Dictionary = {}

static func native(record: Dictionary) -> bool:
	return record.get("source", "") in ["lineagem_base508","lineagem_patch523"]

static func detail(record: Dictionary, acquired: bool, detail_view: bool = true) -> Dictionary:
	if not native(record):
		return {"status":"legacy", "texture":null}
	if not ResourceLoader.exists(SOURCE_API):
		return {"status":"runtime_missing", "texture":null}
	var api: Script = load(SOURCE_API)
	if api == null: return {"status":"runtime_missing", "texture":null}
	var canonical: Dictionary = api.canonical(record)
	if canonical.get("source_snapshot","")=="patch523":
		return {"status":"missing","role":"DisplayBaseAssetID","path":str(canonical.get("source_ui_assets",{}).get("DisplayBaseAssetID",{}).get("path","")),"texture":null,"reason":"patch523_original_pack_required"}
	var assets: Dictionary = canonical.get("source_ui_assets", {})
	# Render inspection: DisplayScreenAssetID can be an additive-only effect
	# (e.g. black_wizard_A); it must never replace the portrait. Its original
	# compositing contract remains pending the source CSB layout.
	# Null means no declaration. A declared but missing file is an installation
	# failure; do not silently replace it with another image or synthesized art.
	var roles: Array[String] = ["IllustrationAssetID" if acquired else "HidedIllustrationAssetID", "DisplayBaseAssetID"]
	if not detail_view: roles = ["DisplayBaseAssetID"]
	for role: String in roles:
		var asset: Variant = assets.get(role)
		if not asset is Dictionary or str(asset.get("path", "")).is_empty():
			continue
		var source_path: String = str(asset.path)
		var path: String = api.asset_path(source_path)
		if path.is_empty() or not FileAccess.file_exists(path):
			return {"status":"missing", "role":role, "path":source_path, "texture":null}
		var key: String = path + (":owned" if acquired else ":unowned")
		if not textures.has(key):
			var image: Image = Image.load_from_file(path)
			if image == null or image.is_empty():
				return {"status":"unreadable", "role":role, "path":source_path, "texture":null}
			if not acquired and role != "HidedIllustrationAssetID":
				image.convert(Image.FORMAT_LA8)
			if textures.size() >= LIMIT: textures.erase(textures.keys()[0])
			textures[key] = ImageTexture.create_from_image(image)
		return {"status":"original", "role":role, "path":source_path, "texture":textures[key]}
	return {"status":"undeclared", "texture":null}

static func apply(hud: Node) -> void:
	var preview: TextureRect = hud.catalog_preview
	var badge: Label = preview.get_node_or_null("OriginalCardAssetStatus")
	var record: Dictionary = hud.selected_catalog_record
	if not native(record):
		preload("res://scripts/ui/source_card_skin.gd").restore(hud.catalog_equip_button)
		if badge != null: badge.hide()
		preview.self_modulate = Color.WHITE
		return
	preload("res://scripts/ui/source_card_metrics.gd").apply(hud)
	var original_background: bool = preload("res://scripts/ui/source_card_skin.gd").surface(hud)
	preload("res://scripts/ui/source_card_skin.gd").style(hud.catalog_equip_button,"UI/Change/Change_DetailView.csb","Btn_Change_On")
	if badge == null:
		badge = Label.new()
		badge.name = "OriginalCardAssetStatus"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_font_size_override("font_size", 12)
		preview.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var identity: String = CARDS.card_id(record)
	var owned: Dictionary = hud.card_collection_state.get("owned", {}).get(hud.catalog_category, {})
	var acquired: bool = owned.get(identity, false) == true
	var result: Dictionary = detail(record, acquired)
	preview.texture = result.get("texture")
	preview.self_modulate = Color.WHITE if acquired else Color(.68,.68,.68,.62)
	badge.text = "원본 카드 연결 미설치" if result.status == "runtime_missing" else "원본 이미지 미설치" if result.status in ["missing", "unreadable"] else "원본 이미지 미지정" if result.status == "undeclared" else "" if original_background else "원본 화면 배경 연결 대기"
	var frame_status: String = preload("res://scripts/ui/source_card_skin.gd").frame_status(record)
	if badge.text.is_empty() and frame_status!="original":
		badge.text="원본 목록 프레임 미지정" if frame_status=="undeclared" else "원본 목록 프레임 미설치"
	badge.visible = not badge.text.is_empty()
	badge.tooltip_text = str(result.get("path", ""))
	preview.set_meta("original_card_asset", result)
	var equipped: Dictionary = hud.character_state.get("equipped", {}).get(hud.catalog_category, {})
	var applied: bool = identity == CARDS.card_id(equipped)
	hud.catalog_equip_button.disabled = not acquired or applied
	hud.catalog_equip_button.text = "미보유 · 조회 전용" if not acquired else "현재 적용 중" if applied else {"변신":"변신", "마법인형":"소환", "성물":"성물 적용"}.get(hud.catalog_category, "적용")
	if canonical_record_snapshot(record)=="patch523" and acquired and not applied:
		var world: Node=hud.get_parent()
		if world!=null and world.has_method("_patch523_card_available") and not world._patch523_card_available(hud.catalog_category,record):
			hud.catalog_equip_button.disabled=true
			hud.catalog_equip_button.text="원본 조건 확인 필요"
			hud.catalog_equip_button.tooltip_text="카드의 서버·기간 조건을 확인해야 적용할 수 있습니다"

static func canonical_record_snapshot(record: Dictionary) -> String:
	return str(record.get("source_snapshot",record.get("source_original",{}).get("source_snapshot","")))
