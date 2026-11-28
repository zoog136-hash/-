extends RefCounted
## Explicit private source pack. Failed replacement preserves the prior pack.
const PMA_PIXELS=preload("res://scripts/ui/original_ui/cocos_premultiply_pixels.gd")
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const PIXELS=preload("res://scripts/ui/original_ui/atlas_pixels.gd")
const SETTINGS_FRAMES = preload("res://scripts/ui/original_ui/source_settings_frames.gd")
# A cold PNG normally needs three opens (SHA, decoder, Cocos metadata).
# Cap the same-byte buffer so unusually large/non-PNG pages retain the
# existing streaming verification path instead of increasing memory unboundedly.
const BUFFERED_PNG_MAX_BYTES: int=8*1024*1024
## Decoded CPU pages and reconstructed frames are shared across instances that
## opened the same verified pack; see source_pack_page_cache.gd for identity,
## leases and the idle byte budget. This instance holds a lease on every page
## in _pages until release_cache_leases(), a successful open() or deletion.
const PAGE_CACHE=preload("res://scripts/ui/original_ui/source_pack_page_cache.gd")
## Cache ownership is bounded even when a HUD keeps this pack for the whole
## session. Active controls/fonts keep their own textures; weak hits reuse
## those exact objects after the cache drops its strong reserve.
const TEXTURE_CACHE=preload("res://scripts/resources/source523_texture_cache.gd")
## After the first verified open, the scene and layout trees (about 250 MB
## parsed for the main HUD pack) live in a device-local record bake keyed by
## the manifest pin and source_pack_manifest.gd; `manifest.scenes`/`layout_sources` keep
## their member names with empty values and scene()/layout_source() read one
## tree at a time. The manifest bytes are still hash-checked on every open.
const BAKE=preload("res://scripts/resources/current523_bake_cache.gd")
const MANIFEST=preload("res://scripts/ui/original_ui/source_pack_manifest.gd")
const LOADING_FX_MEMBER := "UI/CommonUi/Fx_Loading.csb"
const LOADING_FX_ATLAS := "UI/UI_Resource/Atlas_Common.plist"
const LOADING_FX_FONT := "UI/Font/font_B.ttf"
const WORLD_LOADING_MEMBER := "UI/LoadingScene.csb"
const WORLD_LOADING_LAYOUT := "UI/Intro/LoadSceneLayout.csb"
const WORLD_LOADING_ATLAS := "UI/UI_Resource/Atlas_Loading.plist"
const WORLD_LOADING_SHA := "4c0c85349a26bebbfa19419d96a6ccda34024a007845da74fa379d34b208692a"
const WORLD_LOADING_LAYOUT_SHA := "fdefa8a7511102d80be44e9a5c5a88a181e41dfb48fd43b9585cd93eb4baaf05"
const MANIFEST_MAX_BYTES := 128 * 1024 * 1024
static var bake_enabled: bool=true
var _scoped_loading_fx := false
var _records: RefCounted
var manifest: Dictionary={}
var root: String=""
var manifest_sha256: String=""
var last_error: String=""
var _pages: Dictionary={}
var _texture_cache=TEXTURE_CACHE.new()
var _settings_frames: RefCounted
var _settings_frames_checked := false
var _building_settings := false
var _fonts: Dictionary={}
var _bitmap_fonts: Dictionary={}
var _page_leases: Dictionary={}
# Captured at construction: a RefCounted cannot call its own methods during
# NOTIFICATION_PREDELETE, so the lease owner id must already be stored.
var _lease_owner: int=0

func _init() -> void:
	_lease_owner=get_instance_id()

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE and not _page_leases.is_empty():
		PAGE_CACHE.release(_lease_owner,_page_leases.keys())
		_page_leases.clear()

## Screen/owner close: returns this instance's page leases so the pages become
## idle (evictable) unless another open screen still leases them. Textures
## already handed out stay valid; pages are re-acquired on the next decode.
func release_cache_leases() -> void:
	_settings_frames = null
	_settings_frames_checked = false
	var keys: Array=_page_leases.keys()
	_page_leases.clear()
	_pages.clear()
	if not keys.is_empty():PAGE_CACHE.release(_lease_owner,keys)

## Decoded RGBA payload reserve only, not a cap on externally held textures,
## FontFile allocations, GPU memory or RSS. Does not change any source pixels.
func configure_texture_cache(budget_bytes: int, max_entries: int=TEXTURE_CACHE.DEFAULT_MAX_ENTRIES) -> void:
	_texture_cache.configure(budget_bytes,max_entries)

func cache_stats() -> Dictionary:
	var result: Dictionary=PAGE_CACHE.stats()
	var textures: Dictionary=_texture_cache.metrics()
	result["instance_pages"]=_pages.size()
	result["instance_page_leases"]=_page_leases.size()
	result["instance_textures"]=textures.resident_entries
	result["instance_texture_cache"]=textures
	result["instance_fonts"]=_fonts.size()
	result["instance_bitmap_font_metadata"]=_bitmap_fonts.size()
	return result

func open(pack_root: String, expected_sha256: String) -> Dictionary:
	var manifest_path: String=pack_root.path_join("original_ui.json")
	if not FileAccess.file_exists(manifest_path): return _fail("manifest_missing")
	var file:=FileAccess.open(manifest_path,FileAccess.READ)
	if file==null or file.get_length()>MANIFEST_MAX_BYTES: return _fail("manifest_size_or_access")
	if expected_sha256.length()!=64: return _fail("manifest_hash_mismatch")
	var bake_name: String=bake_name_for(expected_sha256)
	var bake_key: String=bake_key_for(expected_sha256) if bake_enabled else ""
	if not bake_key.is_empty() and BAKE.present(bake_name,bake_key):
		# Authenticate every manifest byte without retaining a second large
		# buffer while the already-verified bake and member hashes are read.
		if FileAccess.get_sha256(manifest_path)!=expected_sha256: return _fail("manifest_hash_mismatch")
		var baked: RefCounted=BAKE.open_records(bake_name,bake_key)
		if baked!=null:
			var slim: Variant=baked.read("meta")
			if slim is Dictionary and slim.get("schema")=="twilight-original-ui-v1" and slim.get("scenes") is Dictionary and slim.get("files") is Dictionary and _files_intact(pack_root,slim.files).is_empty():
				_adopt(slim,pack_root,expected_sha256)
				_records=baked
				return {"ok":true,"scene_count":manifest.scenes.size(),"rendered":false}
	# A stale/damaged bake still falls back to the exact pinned original bytes.
	# Hash this buffer independently of the earlier streaming check.
	var raw: PackedByteArray=file.get_buffer(file.get_length())
	if _sha256(raw)!=expected_sha256: return _fail("manifest_hash_mismatch")
	var value: Variant=JSON.parse_string(raw.get_string_from_utf8())
	raw=PackedByteArray()
	var problem: String=MANIFEST.verify(value,pack_root)
	if not problem.is_empty(): return _fail(problem)
	# The bake stores the pack's own content only; code-declared texture nodes
	# are merged by _adopt() after every load (fresh or baked).
	if not bake_key.is_empty():
		var writer: RefCounted=BAKE.record_writer(bake_name,bake_key)
		if writer!=null:
			var slim: Dictionary=MANIFEST.write_records(writer,value)
			if BAKE.finish_records(writer):
				var records: RefCounted=BAKE.open_records(bake_name,bake_key)
				if records!=null:
					_adopt(slim,pack_root,expected_sha256)
					_records=records
					return {"ok":true,"scene_count":manifest.scenes.size(),"rendered":false}
	_adopt(value,pack_root,expected_sha256)
	_records=null
	return {"ok":true,"scene_count":manifest.scenes.size(),"rendered":false}

static func _loading_manifest_problem(pack_root: String, expected_sha256: String) -> String:
	var manifest_path := pack_root.path_join("original_ui.json")
	var manifest_size := FileAccess.get_size(manifest_path)
	if manifest_size <= 0 or manifest_size > MANIFEST_MAX_BYTES:
		return "manifest_size_or_access"
	if expected_sha256.length() != 64 or FileAccess.get_sha256(manifest_path) != expected_sha256:
		return "manifest_hash_mismatch"
	return ""

## Hand off only verified loading metadata. Textures and leases stay here.
func copy_loading_fx_scope() -> RefCounted:
	if not _scoped_loading_fx: return null
	var copy: RefCounted = get_script().new()
	copy._adopt(manifest.duplicate(true), root, manifest_sha256)
	copy._scoped_loading_fx = true
	return copy

## The full HUD reader still authenticates its complete pack independently.
func can_reuse_loading_fx(pack_root: String, expected_sha256: String) -> bool:
	return _scoped_loading_fx and root == pack_root and manifest_sha256 == expected_sha256 \
		and _loading_manifest_problem(pack_root, expected_sha256).is_empty() \
		and _files_intact(pack_root, manifest.files).is_empty()

## The loading indicator uses one authored CSB, one atlas and one font.
## Keep its view confined to those verified originals. The HUD still opens
## the complete pack and checks all of its original files before binding.
func open_loading_fx(pack_root: String, expected_sha256: String) -> Dictionary:
	var manifest_problem := _loading_manifest_problem(pack_root, expected_sha256)
	if not manifest_problem.is_empty(): return _fail(manifest_problem)
	var bake_key := bake_key_for(expected_sha256) if bake_enabled else ""
	var baked := BAKE.open_records(bake_name_for(expected_sha256), bake_key) if not bake_key.is_empty() else null
	if baked == null:
		return _fail("original_ui_pack_not_baked")
	var meta: Variant = baked.read("meta")
	if not meta is Dictionary or meta.get("schema") != "twilight-original-ui-v1" or not meta.get("files") is Dictionary or not meta.get("atlases") is Dictionary:
		return _fail("manifest_fields")
	var atlas: Variant = meta.atlases.get(LOADING_FX_ATLAS)
	if not atlas is Dictionary or not atlas.get("page") is String:
		return _fail("fx_loading_atlas_missing")
	var files := {}
	for member: String in [LOADING_FX_MEMBER, LOADING_FX_ATLAS, atlas.page, LOADING_FX_FONT]:
		var entry: Variant = meta.files.get(member)
		if not entry is Dictionary:
			return _fail("fx_loading_dependency_missing:" + member)
		files[member] = entry
	var problem := _files_intact(pack_root, files)
	if not problem.is_empty():
		return _fail(problem)
	var scene: Variant = baked.read("s:" + LOADING_FX_MEMBER)
	if not scene is Dictionary or scene.get("_source_sha256") != files[LOADING_FX_MEMBER].sha256:
		return _fail("scene_source_mismatch")
	var scenes := {LOADING_FX_MEMBER: scene}
	var atlases := {LOADING_FX_ATLAS: atlas}
	var world := _verified_world_loading(pack_root, baked, meta)
	if not world.is_empty():
		scenes.merge(world.scenes)
		files.merge(world.files)
		atlases.merge(world.atlases)
	_adopt({"schema": meta.schema, "scenes": scenes, "files": files, "atlases": atlases}, pack_root, expected_sha256)
	_records = null
	_scoped_loading_fx = true
	return {"ok": true, "scene_count": scenes.size(), "rendered": false}

## Only the matching current523 loading layout may extend the scoped boot read.
static func _verified_world_loading(pack_root: String, baked: RefCounted, meta: Dictionary) -> Dictionary:
	var atlas: Variant = meta.atlases.get(WORLD_LOADING_ATLAS)
	if not atlas is Dictionary or atlas.get("page") != "UI/UI_Resource/Atlas_Loading.png":
		return {}
	var files := {}
	for member: String in [WORLD_LOADING_MEMBER, WORLD_LOADING_LAYOUT, WORLD_LOADING_ATLAS, atlas.page]:
		var entry: Variant = meta.files.get(member)
		if not entry is Dictionary:
			return {}
		files[member] = entry
	if files[WORLD_LOADING_MEMBER].get("sha256") != WORLD_LOADING_SHA or files[WORLD_LOADING_LAYOUT].get("sha256") != WORLD_LOADING_LAYOUT_SHA or not _files_intact(pack_root, files).is_empty():
		return {}
	var scenes := {}
	for member: String in [WORLD_LOADING_MEMBER, WORLD_LOADING_LAYOUT]:
		var tree: Variant = baked.read("s:" + member)
		if not tree is Dictionary or tree.get("_source_sha256") != files[member].sha256:
			return {}
		scenes[member] = tree
	return {"files": files, "scenes": scenes, "atlases": {WORLD_LOADING_ATLAS: atlas}}

static func bake_name_for(manifest_sha: String) -> String:
	return "original_ui_pack_"+manifest_sha.left(16)

static func bake_key_for(manifest_sha: String) -> String:
	return BAKE.key([MANIFEST.FORMAT,manifest_sha,BAKE.code_key(["res://scripts/ui/original_ui/source_pack_manifest.gd"])])

## True when this device already holds the scene trees for this pin.
static func baked(manifest_sha: String) -> bool:
	return BAKE.present(bake_name_for(manifest_sha),bake_key_for(manifest_sha))

## Original nodes whose texture the game supplies at run time (item, skill
## and NPC portrait pictures from the 523 image pack). Installed packs built
## before these windows were connected declare only the map area image, so
## the inventory, character equipment, quickslot and NPC portrait slots were
## refused ("source_asset_slot_declaration_required"). Declared here by the
## code that binds them; the pack's own declarations are kept.
const CODE_EXTERNAL_TEXTURE_NODES := {
	"UI/CommonUi/Common_Slot.csb":[15012],
	"UI/MainFloating/Slot_Skill.csb":[18488],
	"UI/NpcDialogue/NpcDialogue_All.csb":[4912],
	"UI/Map/Map_Tab_Area.csb":[44440],
	"UI/Shop/Shop_List_Slot.csb":[10376],
	# Original weapon icons (source_main_mastery_window): MasteryWeaponType.AssetID.
	"UI/Mastery/Mastery_List_Weapon.csb":[3640],
	# Original card pictures (source_main_change_window): CardSample sprites.
	"UI/Change/Change_DetailView.csb":[38328],
	"UI/Change/Change_Card_A_Common.csb":[2256],
	"UI/Change/Change_Card_A_Rare.csb":[2260],
	"UI/Change/Change_Card_A_Unique.csb":[2304],
	"UI/Change/Change_Card_A_Epic.csb":[2304],
	"UI/Change/Change_Card_A_Legend.csb":[2304],
	"UI/Change/Change_Card_A_Myth.csb":[2300],
	"UI/Change/Change_Card_A_Sole.csb":[2332],
	# Original 혈맹 문장 pictures (source_main_emblem_window): Icn_Mark_Dummy.
	"UI/Clan/Clan_Mark_FlagSlot.csb":[6308],
	"UI/Clan/Clan_Popup_Symbol.csb":[1208],
	# Original 오림의 흔적 buff icons (source_main_dungeon_window): BuffClass OnIconID.
	"UI/Mission/Mission_Dungeon_TracesOrim_SlotBtn.csb":[4196],
}

func _adopt(value: Dictionary, pack_root: String, expected_sha256: String) -> void:
	var external: Dictionary=value.get("externally_bound_texture_nodes",{}).duplicate(true) if value.get("externally_bound_texture_nodes") is Dictionary else {}
	for member: String in CODE_EXTERNAL_TEXTURE_NODES:
		if not value.get("files",{}).has(member):continue
		var offsets: Array=external.get(member,[])
		for offset: int in CODE_EXTERNAL_TEXTURE_NODES[member]:
			if offset not in offsets:offsets.append(offset)
		external[member]=offsets
	if not external.is_empty():value["externally_bound_texture_nodes"]=external
	manifest=value
	_scoped_loading_fx = false
	root=pack_root
	manifest_sha256=expected_sha256
	release_cache_leases()
	_pages.clear()
	_texture_cache.clear(true)
	_fonts.clear()
	_bitmap_fonts.clear()
	last_error=""

## "" when every original file of the pack is present with its declared size
## and SHA-256 (and bitmap fonts have their pages); else the failure code.
static func _files_intact(pack_root: String, files: Dictionary) -> String:
	return MANIFEST._files_intact(pack_root, files)

static func _offsets(values: Variant) -> Array:
	return MANIFEST._offsets(values)

static func _font_pages_present(path: String, member: String, files: Dictionary) -> bool:
	return MANIFEST._font_pages_present(path, member, files)

func scene(member: String) -> Dictionary:
	if _records!=null:
		var tree: Variant=_records.read("s:"+member)
		return tree if tree is Dictionary else {}
	return manifest.get("scenes",{}).get(member,{}).duplicate(true)

## Read for an immediately following node-scope projection. get_var returns
## a fresh Variant graph; the in-memory manifest is borrowed and must never
## be pruned in place. Never feed the borrowed tree to a scene instance.
func scope_input(member: String) -> Dictionary:
	if _records!=null:
		var record: Variant=_records.read("s:"+member)
		return {"tree":record if record is Dictionary else {},"owned":true}
	return {"tree":manifest.get("scenes",{}).get(member,{}),"owned":false}

func layout_source(member: String) -> Dictionary:
	# Parent reference geometry is not an entry scene or gameplay use. Its
	# optional siblings are neither loaded nor marked dependency-complete.
	if _records!=null:
		var layout: Variant=_records.read("l:"+member)
		return layout if layout is Dictionary else {}
	return manifest.get("layout_sources",{}).get(member,{}).duplicate(true)

func nodes_named(member: String, source_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var tree: Dictionary=scene(member)
	if not tree.is_empty(): _find(tree.get("nodeTree",{}),source_name,result)
	return result

func _find(node: Dictionary, source_name: String, result: Array[Dictionary]) -> void:
	var options: Dictionary=node.get("options",{}) if node.get("options") is Dictionary else {}
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	if widget.get("name")==source_name: result.append(node)
	for child: Dictionary in node.get("children",[]): _find(child,source_name,result)

## Only a cache miss during a synchronous settings build needs the optional file.
func set_settings_frame_scope(active: bool) -> bool:
	var previous := _building_settings
	_building_settings = active
	return previous

func _load_settings_frames() -> void:
	_settings_frames_checked = true
	var selected_root := OS.get_environment("TWILIGHT_SOURCE_UI").simplify_path().trim_suffix("/")
	if root.simplify_path().trim_suffix("/") != selected_root or manifest_sha256 != OS.get_environment("TWILIGHT_SOURCE_UI_SHA256").to_lower():
		return
	var reader := SETTINGS_FRAMES.new()
	if reader.load_bundle(root, manifest_sha256, OS.get_environment("TWILIGHT_SOURCE_UI_SETTINGS_FRAMES_SHA256").to_lower()):
		_settings_frames = reader

func texture(reference: Dictionary, cocos_pixels: bool=false) -> Texture2D:
	if manifest.is_empty() or str(reference.get("path","")).is_empty(): return null
	var plist: String=str(reference.get("plistFile",""))
	# A shared cache hit may come from a complete pack. The loading view must
	# enforce its file scope before asking either texture cache for a hit.
	if _scoped_loading_fx:
		if plist.is_empty() and not manifest.files.has(_member(str(reference.path))): return null
		if not plist.is_empty() and not manifest.atlases.has(_member(plist)): return null
	var key: String=plist+":"+str(reference.path)+":"+str(cocos_pixels)
	var cached: Texture2D=_texture_cache.lookup(key)
	if cached!=null:return cached
	var shared_key: String=""
	# Same early rejection as the decode path below, before any shared lookup.
	if plist.is_empty() and int(reference.get("resourceType",0))!=0: return null
	if PAGE_CACHE.enabled:
		shared_key=PAGE_CACHE.frame_key(manifest_sha256,root,"page" if plist.is_empty() else "atlas",plist,str(reference.path),cocos_pixels)
		var shared: Texture2D=PAGE_CACHE.shared_frame(shared_key)
		if shared!=null:
			_texture_cache.remember(key,shared,shared.get_width()*shared.get_height()*4)
			return shared
	var original: Image
	var premultiplied: bool=false
	if plist.is_empty():
		if int(reference.get("resourceType",0))!=0: return null
		original=_page(_member(str(reference.path)))
		if original!=null:
			premultiplied=bool(original.get_meta("cocos_png_pma",false))
			if cocos_pixels and premultiplied:
				original=cocos_premultiply(original)
	else:
		var atlas: Dictionary=manifest.atlases.get(_member(plist),{})
		var frame: Dictionary=atlas.get("frames",{}).get(str(reference.path),{})
		if frame.is_empty(): return null
		if cocos_pixels and _building_settings:
			if not _settings_frames_checked:
				_load_settings_frames()
			if _settings_frames != null:
				original = _settings_frames.frame_image(_member(plist), str(reference.path), atlas, frame, self)
				premultiplied = original != null
		if original == null:
			var page: Image=_page(str(atlas.get("page","")))
			if page==null: return null
			premultiplied=bool(page.get_meta("cocos_png_pma",false))
			var decoded: Dictionary=PIXELS.decode(page,frame,cocos_pixels and premultiplied)
			if not str(decoded.get("error","")).is_empty():
				last_error=str(decoded.error); return null
			original=decoded.image
	if original==null: return null
	# Each new UI frame texture is its own GPU upload: its time and count go
	# to the phone record (menus open slowly on 523.691; upload cost unknown).
	var upload_started: int=FRAME_HITCH.now()
	var result:=ImageTexture.create_from_image(original)
	FRAME_HITCH.detail("ui.texture_new",upload_started)
	result.set_meta("cocos_premultiplied",cocos_pixels and premultiplied)
	_texture_cache.remember(key,result,original.get_data_size())
	if not shared_key.is_empty():PAGE_CACHE.register_frame(shared_key,result)
	return result

func _page(member: String) -> Image:
	if _pages.has(member): return _pages[member]
	if not _safe_member(member) or not manifest.files.has(member): return null
	var cache_key: String=""
	if PAGE_CACHE.enabled:
		cache_key=PAGE_CACHE.page_key(manifest_sha256,root,member,str(manifest.files[member].sha256))
		var shared: Image=PAGE_CACHE.acquire_page(cache_key,_lease_owner)
		if shared!=null:
			_page_leases[cache_key]=true
			_pages[member]=shared
			return shared
	var path: String=root.path_join("originals").path_join(member)
	var original: Image=_read_verified_page(path, str(manifest.files[member].sha256), member)
	if original==null: return null
	original.set_meta(PIXELS.OPAQUE_CROPS, {})
	if not cache_key.is_empty():
		original=PAGE_CACHE.store_page(cache_key,_lease_owner,original)
		_page_leases[cache_key]=true
	_pages[member]=original
	return original

## Verify and decode exactly the same bytes for ordinary PNGs. The first
## branch never falls back after a bad read or hash; doing so could render a
## different version of a file from the one just verified.
func _read_verified_page(path: String, expected_sha: String, member: String) -> Image:
	var original: Image
	var pma: bool
	if member.get_extension().to_lower()=="png":
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null:
			last_error="source_hash_or_size:"+member; return null
		var length: int=file.get_length()
		if length<=BUFFERED_PNG_MAX_BYTES:
			var raw: PackedByteArray=file.get_buffer(length)
			file.close()
			if raw.size()!=length or _sha256(raw)!=expected_sha:
				last_error="source_hash_or_size:"+member; return null
			original=Image.new()
			if original.load_png_from_buffer(raw)!=OK or original.is_empty(): return null
			pma=_png_bytes_premultiplies(raw)
			original.convert(Image.FORMAT_RGBA8)
			original.set_meta("cocos_png_pma",pma)
			return original
		file.close()
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=expected_sha:
		last_error="source_hash_or_size:"+member; return null
	original=Image.load_from_file(path)
	if original==null or original.is_empty(): return null
	original.convert(Image.FORMAT_RGBA8)
	original.set_meta("cocos_png_pma",_png_premultiplies(path))
	return original

static func _png_bytes_premultiplies(raw: PackedByteArray) -> bool:
	if raw.size()<33 or raw.decode_u64(0)!=0x0a1a0a0d474e5089: return false
	var color_type: int=raw[25]
	if color_type==6: return true
	if color_type not in [2,3]: return false
	var at: int=8
	while at+12<=raw.size():
		var length: int=(int(raw[at])<<24)|(int(raw[at+1])<<16)|(int(raw[at+2])<<8)|int(raw[at+3])
		var kind: int=raw.decode_u32(at+4)
		if kind==0x534e5274: return true # tRNS
		if kind in [0x54414449,0x444e4549]: return false # IDAT, IEND
		if length>raw.size()-at-12: return false
		at+=length+12
	return false

## Cocos (channel*(alpha+1))>>8 for every frame/page this pack decodes. The
## two-lane form (cocos_premultiply_pixels.gd) gives the same bytes
## (tests/original_ui_premultiply_exact_test.gd keeps the scalar equation as
## reference) with fewer GDScript operations per pixel: 136 ms -> 84 ms for a
## 1024x1024 page on desktop; 지배석/문양 spent 2.4 s / 0.9 s here (Twm diag
## 2026-11-19).
static func cocos_premultiply(original: Image) -> Image:
	return PMA_PIXELS.convert(original)

static func _png_premultiplies(path: String) -> bool:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<33:return false
	var head: PackedByteArray=file.get_buffer(26)
	if head.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]):return false
	var color_type: int=head[25]
	if color_type==6:return true
	if color_type not in [2,3]:return false
	# Cocos expands palette/RGB tRNS to RGBA before premultiplication.
	file.big_endian=true
	file.seek(8)
	while file.get_position()+12<=file.get_length():
		var length: int=file.get_32()
		var kind: String=file.get_buffer(4).get_string_from_ascii()
		if kind=="tRNS":return true
		if kind in ["IDAT","IEND"]:return false
		if length>file.get_length()-file.get_position()-4:return false
		file.seek(file.get_position()+length+4)
	return false

static func _member(path: String) -> String:
	return path if path.begins_with("UI/") else "UI/"+path

static func _safe_member(path: String) -> bool:
	return MANIFEST._safe_member(path)

static func _sha256(raw: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(raw)
	return context.finish().hex_encode()

func _fail(reason: String) -> Dictionary:
	last_error=reason
	return {"ok":false,"error":reason}

func font(reference: Dictionary) -> FontFile:
	if int(reference.get("resourceType",0))!=0 or not str(reference.get("plistFile","")).is_empty(): return null
	var member: String=_member(str(reference.get("path","")))
	if not _safe_member(member) or not manifest.get("files",{}).has(member): return null
	if _fonts.has(member): return _fonts[member]
	var path: String=root.path_join("originals").path_join(member)
	if FileAccess.get_sha256(path)!=manifest.files[member].sha256:
		last_error="source_font_hash:"+member; return null
	var original:=FontFile.new()
	original.data=FileAccess.get_file_as_bytes(path)
	original.allow_system_fallback=false
	if original.get_supported_chars().is_empty():
		last_error="source_font_invalid:"+member; return null
	_fonts[member]=original
	return original

func bitmap_font(reference: Dictionary) -> Dictionary:
	var started: int=FRAME_HITCH.now()
	var result: Dictionary=_bitmap_font(reference)
	FRAME_HITCH.detail("ui.bitmap_font",started)
	return result

func _bitmap_font(reference: Dictionary) -> Dictionary:
	if int(reference.get("resourceType",0))!=0 or not str(reference.get("plistFile","")).is_empty():return {"ok":false,"error":"source_bitmap_resource_type"}
	var member: String=_member(str(reference.get("path","")))
	if not _safe_member(member) or not member.ends_with(".fnt") or not manifest.get("files",{}).has(member):return {"ok":false,"error":"source_bitmap_descriptor_missing"}
	var data: Dictionary
	if _bitmap_fonts.has(member):data=_bitmap_fonts[member]
	else:
		var path: String=root.path_join("originals").path_join(member)
		if FileAccess.get_sha256(path)!=manifest.files[member].sha256:return {"ok":false,"error":"source_bitmap_descriptor_hash"}
		var parsed: Dictionary=preload("res://scripts/ui/original_ui/source_bitmap_font_data.gd").parse(FileAccess.get_file_as_bytes(path))
		if not parsed.get("ok",false):return parsed
		data=parsed.font_data
	var pages: Dictionary={}
	for page_id: int in data.pages:
		var page_member: String=member.get_base_dir().path_join(str(data.pages[page_id].file))
		if not _safe_member(page_member) or not manifest.files.has(page_member):return {"ok":false,"error":"source_bitmap_page_missing"}
		var original: Texture2D=texture({"path":page_member,"resourceType":0},true)
		if original==null:return {"ok":false,"error":"source_bitmap_page_unavailable"}
		if original.get_width()!=int(data.common.scaleW) or original.get_height()!=int(data.common.scaleH):return {"ok":false,"error":"source_bitmap_page_dimensions"}
		pages[page_id]=original
	# Newly parsed dictionaries have no external owner. Commit them only after
	# every page passed validation. A hit is read-only until the one detached
	# caller snapshot below; do not recopy/reinstall unchanged glyph metadata.
	if not _bitmap_fonts.has(member):
		data["member"]=member
		_bitmap_fonts[member]=data
	# The metadata cache never owns textures. Only the caller snapshot gets
	# page owners; public configure still takes its own independent snapshot.
	var supplied: Dictionary=data.duplicate(true)
	supplied["page_textures"]=pages
	return {"ok":true,"font_data":supplied}

func particle(reference: Dictionary) -> Dictionary:
	if int(reference.get("resourceType",0))!=0 or not str(reference.get("plistFile","")).is_empty():return {"ok":false,"error":"particle_resource_type"}
	var member: String=_member(str(reference.get("path","")))
	if not _safe_member(member) or not manifest.get("files",{}).has(member):return {"ok":false,"error":"particle_source_missing"}
	var path: String=root.path_join("originals").path_join(member)
	if FileAccess.get_sha256(path)!=manifest.files[member].sha256:return {"ok":false,"error":"particle_source_hash"}
	var decoded: Dictionary=preload("res://scripts/ui/original_ui/source_particle_data.gd").parse(FileAccess.get_file_as_bytes(path))
	if not decoded.ok:return decoded
	var texture_member: String=member.get_base_dir().path_join(str(decoded.values.get("textureFileName","")))
	var original: Texture2D
	if _safe_member(texture_member) and manifest.files.has(texture_member):
		original=texture({"path":texture_member},true)
	if original==null and not str(decoded.values.get("textureImageData","")).is_empty():
		original=_embedded_particle_texture(member,str(decoded.values.textureImageData))
		texture_member=member+"#textureImageData"
	if original==null:return {"ok":false,"error":"particle_texture_missing_or_unsupported:"+texture_member}
	return {"ok":true,"values":decoded.values,"texture":original,"member":member,"texture_member":texture_member}

func _embedded_particle_texture(member: String, encoded: String) -> Texture2D:
	var key: String="embedded_particle:"+member
	var cached: Texture2D=_texture_cache.lookup(key)
	if cached!=null:return cached
	var shared_key: String=""
	if PAGE_CACHE.enabled:
		shared_key=PAGE_CACHE.frame_key(manifest_sha256,root,"embedded_particle","",member,true)
		var shared: Texture2D=PAGE_CACHE.shared_frame(shared_key)
		if shared!=null:
			_texture_cache.remember(key,shared,shared.get_width()*shared.get_height()*4)
			return shared
	var compressed: PackedByteArray=Marshalls.base64_to_raw(encoded)
	if compressed.size()<2:return null
	var mode: int=FileAccess.COMPRESSION_GZIP if compressed[0]==31 and compressed[1]==139 else FileAccess.COMPRESSION_DEFLATE
	var png: PackedByteArray=compressed.decompress_dynamic(32*1024*1024,mode)
	# The supplied embedded original is RGBA8 PNG. Other formats stay explicit
	# until their original Cocos decode semantics have been verified.
	if png.size()<33 or png.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or png[24]!=8 or png[25]!=6:return null
	var width: int=(int(png[16])<<24)|(int(png[17])<<16)|(int(png[18])<<8)|int(png[19])
	var height: int=(int(png[20])<<24)|(int(png[21])<<16)|(int(png[22])<<8)|int(png[23])
	if width<=0 or height<=0 or width>8192 or height>8192 or width*height>16*1024*1024:return null
	var original:=Image.new()
	if original.load_png_from_buffer(png)!=OK:return null
	original.convert(Image.FORMAT_RGBA8)
	var result:=ImageTexture.create_from_image(cocos_premultiply(original))
	result.set_meta("cocos_premultiplied",true)
	result.set_meta("original_embedded_png_sha256",_sha256(png))
	_texture_cache.remember(key,result,original.get_data_size())
	if not shared_key.is_empty():PAGE_CACHE.register_frame(shared_key,result)
	return result


func declared_system_font(family: String) -> FontFile:
	# Cocos uses the serialized fontName when no fontResource was declared.
	# Resolve only that exact installed family; never choose a replacement.
	if family.is_empty() or not OS.get_system_fonts().has(family):
		last_error="declared_system_font_unavailable:"+family
		return null
	var key: String="declared_system_font:"+family
	if _fonts.has(key):return _fonts[key]
	var path: String=OS.get_system_font_path(family)
	if path.is_empty() or not FileAccess.file_exists(path):
		last_error="declared_system_font_unavailable:"+family
		return null
	var original:=FontFile.new()
	original.data=FileAccess.get_file_as_bytes(path)
	original.allow_system_fallback=false
	if original.get_font_name()!=family or original.get_supported_chars().is_empty():
		last_error="declared_system_font_identity_mismatch:"+family
		return null
	original.set_meta("source_font_kind","declared_host_system_font")
	original.set_meta("original_declared_system_font",family)
	_fonts[key]=original
	return original
