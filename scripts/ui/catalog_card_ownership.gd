extends RefCounted

const Cards=preload("res://scripts/card_draw_fusion.gd")
const UNOWNED_ICON_TINT:=Color(.68,.68,.68,.62) # Same treatment as unlearned skills.
const UNOWNED_FRAME_TINT:=Color(.45,.45,.45,.42)
const CACHE_LIMIT: int=96
static var unowned_icons: Dictionary={}

static func original_current(record: Dictionary) -> bool:
	if not preload("res://scripts/ui/source523_image_assets.gd").selected(): return false
	var source = preload("res://scripts/ui/source_card_presentation.gd")
	if not source.native(record): return false
	return preload("res://scripts/lineagem_base508.gd").canonical(record).get("source_snapshot","") == "patch523"

static func owned_first(records: Array, permanent: Dictionary) -> Array[Dictionary]:
	# A stable partition preserves the catalog's grade/name order in each group.
	# Spendable duplicates never determine whether a card has been acquired.
	var acquired: Array[Dictionary]=[]
	var missing: Array[Dictionary]=[]
	for record: Dictionary in records:
		if permanent.has(Cards.card_id(record)):acquired.append(record)
		else:missing.append(record)
	acquired.append_array(missing)
	return acquired

static func icon_for(record: Dictionary, acquired: bool) -> Texture2D:
	if original_current(record):
		return preload("res://scripts/ui/source_card_presentation.gd").detail(record,acquired,false).get("texture")
	var path: String=str(record.get("image_path",""))
	var source: Texture2D
	if preload("res://scripts/ui/source_card_presentation.gd").native(record):
		if not preload("res://scripts/ui/source_ui_atlas.gd").LEGACY_CARD_PACK_FINAL_USE: return null
		source=preload("res://scripts/ui/source_card_presentation.gd").detail(record,true,false).get("texture")
		source=preload("res://scripts/ui/source_card_skin.gd").icon(record,source)
	else:
		if path.is_empty() or not ResourceLoader.exists(path):return null
		source=load(path) as Texture2D
	if source==null or acquired:return source
	var key: String=str(record.get("sourceId",path))
	if unowned_icons.has(key):return unowned_icons[key] as Texture2D
	var original: Image=source.get_image()
	if original==null or original.is_empty():return source
	var image: Image=original.duplicate() as Image
	if image.is_compressed() and image.decompress()!=OK:return source
	# ItemList has no per-icon material. The existing catalog art is
	# already small: retain every pixel and alpha, and cache one luminance
	# variant per source across viewport changes. Original/detail art is intact.
	image.convert(Image.FORMAT_LA8)
	var icon: ImageTexture=ImageTexture.create_from_image(image)
	if unowned_icons.size()>=CACHE_LIMIT:unowned_icons.erase(unowned_icons.keys()[0])
	unowned_icons[key]=icon
	return icon
