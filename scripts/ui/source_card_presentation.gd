extends RefCounted
## UI-only reader of the shared source catalog and installed private pack.
## Never infer an asset from a name, grade, or numeric ID.
const SOURCE_API = "res://scripts/lineagem_base508.gd"
const CARDS = preload("res://scripts/card_draw_fusion.gd")
const IMAGES523 = preload("res://scripts/ui/source523_image_assets.gd")
const LEGACY_ATLAS = preload("res://scripts/ui/source_ui_atlas.gd")
const EXPEDITION_CARDS = preload("res://scripts/expedition/reward_cards.gd")
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
	if canonical.get("source_snapshot", "") == "patch523":
		if IMAGES523.selected(): return _current_detail(canonical,acquired,detail_view)
		var declared: Variant = canonical.get("source_ui_assets", {}).get("DisplayBaseAssetID")
		return {"status":"missing","role":"DisplayBaseAssetID","path":str(declared.get("path", "")) if declared is Dictionary else "","texture":null,"reason":"patch523_original_pack_required","source_asset_id":int(declared.get("asset_id",0)) if declared is Dictionary else 0,"source_id":str(canonical.get("sourceId",""))}
	if not LEGACY_ATLAS.LEGACY_CARD_PACK_FINAL_USE:
		return {"status":"legacy_card_pack_excluded","texture":null,"reason":"new_original_pack_required",
			"source_id":str(canonical.get("sourceId","")),"actual_game_consumption_observed":false}
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

static func _current_detail(record: Dictionary, acquired: bool, detail_view: bool) -> Dictionary:
	var assets: Dictionary = record.get("source_ui_assets",{})
	var roles: Array[String] = ["IllustrationAssetID" if acquired else "HidedIllustrationAssetID","DisplayBaseAssetID"]
	if not detail_view: roles = ["DisplayBaseAssetID"]
	for role: String in roles:
		var asset: Variant = assets.get(role)
		if not asset is Dictionary or str(asset.get("path","")).is_empty(): continue
		return _current_asset(record,role,asset.get("asset_id"),str(asset.path))
	return _expedition_current_detail(record,roles)

static func _current_asset(record: Dictionary, role: String, id: Variant, declared_path: String = "", card_source: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"status":"missing","texture":null,"role":role,"path":declared_path,
		"source_id":str(record.get("sourceId","")),"source_asset_id":0,"reason":"source_asset_identity_required",
		"actual_game_consumption_observed":false}
	if not (id is int or id is float) or not is_finite(float(id)) or float(id) != floor(float(id)) or float(id) <= 0: return result
	result.source_asset_id = int(id)
	var original: Dictionary = IMAGES523.resolve_asset(int(id),-1,declared_path)
	result.reason = str(original.get("status","source523_image_unavailable"))
	result["provenance"] = original.get("provenance",{}).duplicate(true)
	if not card_source.is_empty(): result.provenance["card_source"] = card_source.duplicate(true)
	if declared_path.is_empty(): result.path = str(result.provenance.get("path",""))
	if result.reason == "source_dummy_excluded":
		# An excluded declared asset never tries another presentation role.
		result.status = "source_dummy_excluded"
		result["source_status"] = "source_dummy_excluded"
		result["error"] = original.get("error","source_dummy_excluded")
		return result
	if bool(original.get("ok",false)) and original.get("texture") is Texture2D:
		result.status = "original"
		result.texture = original.texture
		result["source523_verified_original"] = true
	return result

static func _expedition_current_detail(record: Dictionary, roles: Array[String]) -> Dictionary:
	var result: Dictionary = {"status":"undeclared","texture":null,"source_id":str(record.get("sourceId","")),
		"actual_game_consumption_observed":false}
	if record.get("source_expedition_definition_only") != true: return result
	result.status = "missing"
	result["reason"] = "source_expedition_card_identity_required"
	if record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or record.get("source_content_snapshot") != "patch523": return result
	var raw: Variant = record.get("source_original_card")
	if not raw is Dictionary or raw.is_empty(): return result
	for field: String in ["ID","BuffCardDeckID","GradeID"]:
		if not IMAGES523.PACK._integer(raw.get(field)) or int(raw[field]) <= 0: return result
	for field: String in ["source_card_id","source_deck_id","source_grade_id"]:
		if not IMAGES523.PACK._integer(record.get(field)) or int(record[field]) <= 0: return result
	var deck: int = int(raw.BuffCardDeckID)
	if not EXPEDITION_CARDS.CATEGORIES.has(deck): return result
	var issuer_catalog: Dictionary = {}
	issuer_catalog[EXPEDITION_CARDS.CATEGORIES[deck]] = [record]
	if EXPEDITION_CARDS.registered(issuer_catalog,raw).is_empty(): return result
	var supplied_sha: String = IMAGES523.PACK._canonical_row_sha(raw)
	if supplied_sha.is_empty(): return result
	var card_source: Dictionary = {"identity_basis":"preserved_expedition_buffcard_source_row",
		"source_table":"BuffCard","source_snapshot":"patch523","source_card_id":int(raw.ID),
		"source_deck_id":deck,"source_grade_id":int(raw.GradeID),"supplied_buffcard_row_sha256":supplied_sha}
	result["reason"] = "source_buffcard_asset_role_undeclared"
	result["provenance"] = {"card_source":card_source}
	for role: String in roles:
		if not raw.has(role): continue
		result["role"] = role
		var asset_id: Variant = raw[role]
		if not IMAGES523.PACK._integer(asset_id) or int(asset_id) < 0:
			result.reason = "source_asset_identity_required"
			return result
		if int(asset_id) == 0:
			result.reason = "zero_sentinel"
			continue
		return _current_asset(record,role,asset_id,"",card_source)
	return result

static func apply(hud: Node) -> void:
	var preview: TextureRect = hud.catalog_preview
	var badge: Label = preview.get_node_or_null("OriginalCardAssetStatus")
	var record: Dictionary = hud.selected_catalog_record
	if not native(record):
		_clear_selected_action_icon(hud.catalog_equip_button)
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
	_apply_selected_action_icon(hud.catalog_equip_button,record,acquired)
	var result: Dictionary = detail(record, acquired)
	preview.texture = null if result.get("status","") == "source_dummy_excluded" else result.get("texture")
	preview.self_modulate = Color.WHITE if acquired or result.get("source523_verified_original",false) else Color(.68,.68,.68,.62)
	badge.text = "원본 더미 이미지 제외" if result.status == "source_dummy_excluded" else "원본 카드 연결 미설치" if result.status == "runtime_missing" else "원본 이미지 미설치" if result.status in ["missing", "unreadable"] else "원본 이미지 미지정" if result.status == "undeclared" else "" if original_background else "원본 화면 배경 연결 대기"
	if result.status == "legacy_card_pack_excluded": badge.text = "이전 카드 팩 최종 사용 제외 · 새 원본 연결 대기"
	var frame_status: String = preload("res://scripts/ui/source_card_skin.gd").frame_status(record)
	if badge.text.is_empty() and frame_status not in ["original","legacy_card_pack_excluded"]:
		badge.text="원본 목록 프레임 미지정" if frame_status=="undeclared" else "원본 목록 프레임 미설치"
	badge.visible = not badge.text.is_empty()
	badge.tooltip_text = str(result.get("path", ""))
	if result.get("status","") == "source_dummy_excluded":
		badge.tooltip_text = "원본에서 더미로 선언된 이미지 자산 · " + str(result.get("reason","source_dummy_excluded")) + " · " + str(result.get("path",""))
	elif canonical_record_snapshot(record)=="patch523":
		badge.tooltip_text = "검증된 원본 초상화" if result.get("source523_verified_original",false) else "원본 초상화 또는 선언된 화면 리소스 연결 대기"
	var evidence: Dictionary = result.duplicate(true)
	evidence.erase("texture")
	preview.set_meta("original_card_asset", evidence)
	var equipped: Dictionary = hud.character_state.get("equipped", {}).get(hud.catalog_category, {})
	var applied: bool = identity == CARDS.card_id(equipped)
	hud.catalog_equip_button.disabled = not acquired or applied
	hud.catalog_equip_button.text = "미보유 · 조회 전용" if not acquired else "현재 적용 중" if applied else {"변신":"변신", "마법인형":"소환", "성물":"성물 적용"}.get(hud.catalog_category, "적용")
	hud.catalog_equip_button.tooltip_text=""
	if canonical_record_snapshot(record)=="patch523" and acquired and not applied:
		var world: Node=hud.get_parent()
		if world!=null and world.has_method("_patch523_card_available") and not world._patch523_card_available(hud.catalog_category,record):
			hud.catalog_equip_button.disabled=true
			hud.catalog_equip_button.text="원본 조건 확인 필요"
			hud.catalog_equip_button.tooltip_text="카드의 서버·기간 조건을 확인해야 적용할 수 있습니다"

static func _clear_selected_action_icon(button: Button) -> bool:
	# Clear only this image owner's presentation, not an unrelated button icon.
	if not button.has_meta("source523_selected_card_action_image"):return true
	var previous: Dictionary=button.get_meta("source523_selected_card_action_image")
	var current_id: int=button.icon.get_instance_id() if button.icon!=null else 0
	var still_owned: bool=current_id==int(previous.get("assigned_texture_instance_id",-1)) and button.expand_icon==previous.get("assigned_expand_icon")
	if still_owned:
		button.icon=null
		button.expand_icon=bool(previous.get("prior_expand_icon",button.expand_icon))
	button.remove_meta("source523_selected_card_action_image")
	return still_owned

static func _apply_selected_action_icon(button: Button, record: Dictionary, acquired: bool) -> void:
	if button.icon!=null and not button.has_meta("source523_selected_card_action_image"):return
	if not _clear_selected_action_icon(button):return
	var canonical: Dictionary=preload("res://scripts/lineagem_base508.gd").canonical(record)
	var raw: Variant=canonical.get("source_original_card")
	if canonical.get("source_snapshot")!="patch523" or not raw is Dictionary:return
	var deck: Variant=canonical.get("source_deck_id")
	if deck not in [1,2,98] or raw.get("BuffCardDeckID")!=deck or raw.get("ID")!=canonical.get("source_card_id") or CARDS.card_id(canonical)!=CARDS.card_id(record):return
	# These are the actual selected transformation/doll/relic action owners.
	# Use the same explicit list portrait role, not the larger illustration,
	# reveal front/back, decorative layer or a representative card.
	var image: Dictionary=detail(canonical,acquired,false)
	var prior_expand_icon: bool=button.expand_icon
	button.icon=null
	if image.get("source523_verified_original",false) and image.get("role")=="DisplayBaseAssetID":
		button.icon=image.get("texture") as Texture2D
		button.expand_icon=true
	var evidence: Dictionary=image.duplicate(true)
	evidence.erase("texture")
	evidence["selected_card_identity"]=CARDS.card_id(canonical)
	evidence["source_deck_id"]=deck
	evidence["prior_expand_icon"]=prior_expand_icon
	evidence["assigned_texture_instance_id"]=button.icon.get_instance_id() if button.icon!=null else 0
	evidence["assigned_expand_icon"]=button.expand_icon
	button.set_meta("source523_selected_card_action_image",evidence)

static func canonical_record_snapshot(record: Dictionary) -> String:
	var original: Variant=record.get("source_original",{})
	return str(record.get("source_snapshot",original.get("source_snapshot","") if original is Dictionary else ""))
