extends RefCounted
## Original TWILIGHT vector symbols. A family symbol is never original item art.
## Shared by family, rendered at 128px; no source image is edited or downsampled.
const SHAPES = {
	"sword":"M19 47L48 10l5 1-1 6-29 34z M15 40l13 11 M20 49l-9 10",
	"dagger":"M24 40L44 15l6-3-1 7-21 25z M20 37l12 10 M25 44l-8 10",
	"greatsword":"M16 49L44 8l9-2-1 11-29 36z M12 41l20 15 M20 51l-7 10",
	"bow":"M20 9Q57 31 20 55 M20 9l8 23-8 23 M11 32h43 M47 26l7 6-7 6",
	"spear":"M15 57l28-40 M37 19l5-14 9-2-1 10-13 6 M27 37l7 5",
	"axe":"M18 57l26-46 M32 16Q49 29 58 15L47 7l-8 2 M32 16l-8 8 12 11 7-8",
	"scythe":"M20 58l15-45 M15 15Q42 0 58 28Q43 15 31 20",
	"dual":"M12 45L34 10l6-2-1 8-20 34z M9 41l15 12 M32 47L50 22l6-1-1 8-17 24z M29 43l14 12",
	"claw":"M13 43l8 12 20-9 M20 43L32 10l1 28 M28 45L45 11l-7 30 M36 47L57 20l-13 29",
	"staff":"M15 57l24-36 M36 8l12-2 6 10-7 11-13-2-4-9z M37 12l8-2 4 7-6 6-8-2z",
	"rifle":"M10 49l9-16 15-2 21-17 4 4-21 20-13 2-6 15z M29 39l4 7 8-9",
	"cannon":"M10 42l30-23 14 14-29 22z M40 19l8-8 13 14-7 8 M21 45l5 6",
	"chain":"M12 54l7-11 M15 39l11 12 M22 39l5-7 8 4-5 8z M31 28l5-7 8 4-5 8z M40 17l11-12 5 2-7 17z",
	"helmet":"M14 45V27a18 18 0 0 1 36 0v18l-12 9V31H26v23z M14 28l12 6 M50 28l-12 6",
	"armor":"M20 10l12 6 12-6 13 13-11 10-3 23H21l-3-23L7 23z M24 29h16 M32 17v34",
	"cloak":"M25 8h14l7 11 9 36H9l9-36z M25 8l-7 11 14 9 14-9 M32 28v23",
	"gloves":"M18 54l-4-24 5-2 5 10V15l5-1 2 18 3-23h5l-1 24 5-18 5 2-3 22 5-10 4 4-6 20z",
	"boots":"M28 9h18l-3 29 8 9-2 8H14V44l13-9z M28 16h17 M15 49h35",
	"pants":"M18 9h28l3 45H35l-3-24-3 24H15z M18 17h28",
	"shield":"M32 7l21 9-3 24-18 17-18-17-3-24z M32 16l12 6-2 15-10 10-10-10-2-15z",
	"shoulder":"M7 37l9-19 15-6 22 12 5 13-16 7-9-17-12 20z M13 30l13-11",
	"ring":"M32 21a16 16 0 1 0 0 32a16 16 0 1 0 0-32 M22 13l10-8 10 8-10 13z M26 14h12",
	"necklace":"M12 11Q12 42 32 47Q52 42 52 11 M24 44l8-8 8 8-8 14z",
	"earring":"M29 10a8 8 0 1 1 9 12 M33 22v10 M22 41l11-12 11 12-11 15z",
	"belt":"M7 26Q32 17 57 26v17Q32 34 7 43z M25 23h14v20H25z M31 32h10",
	"bracelet":"M32 14a21 18 0 1 0 0 36a21 18 0 1 0 0-36 M13 30Q32 44 51 30 M24 38v10 M40 38v10",
	"gem":"M20 10h24l13 19-25 28L7 29z M20 10l12 19 12-19 M7 29h50 M32 29v28",
	"badge":"M22 7h20v19L32 36 22 26z M32 27l8 7 10 1-5 10 1 10-14-5-14 5 1-10-5-10 10-1z",
	"rune":"M19 7h26l9 18-8 31H16L10 25z M24 17l16 10-16 11 16 9 M32 12v39",
	"potion":"M25 7h14v13l11 13v15l-8 9H22l-8-9V33l11-13z M25 13h14 M18 36h28 M23 43l4 6",
	"scroll":"M18 10h31l-5 9v32l-6 6H10l7-8V19H9V9z M24 24h13 M24 33h13 M24 42h8",
	"coins":"M8 37a14 6 0 1 0 28 0a14 6 0 1 0-28 0 M8 37v12a14 6 0 0 0 28 0V37 M32 21a12 6 0 1 0 24 0a12 6 0 1 0-24 0 M32 21v11a12 6 0 0 0 24 0V21",
	"ore":"M8 43l9-26 18-9 21 22-10 24H20z M17 17l16 15 23-2 M33 32l-7 20",
	"food":"M10 43Q10 18 34 20Q54 19 54 43z M6 48h52 M23 27l-6 10 M36 27l-7 12",
	"arrow":"M10 54l42-42 M38 14l17-5-5 17 M10 42l10 1 1 11 M17 35l10 1 1 11",
	"item":"M32 7l24 14v28L32 60 8 49V21z M8 21l24 14 24-14 M32 35v25 M21 14l23 14"
}
static var cache: Dictionary = {}

static func family(record: Dictionary, item_name: String) -> String:
	var type: String = str(record.get("type", ""))
	var slot: String = str(record.get("slot", ""))
	var weapons: Dictionary = {"단검":"dagger","양손검":"greatsword","그레이트소드":"greatsword","활":"bow","창":"spear","도끼":"axe","사이드":"scythe","이도류":"dual","크로우":"claw","지팡이":"staff","라이플":"rifle","핸드캐넌":"cannon","핸드 캐넌":"cannon","체인소드":"chain","체인 소드":"chain"}
	if slot == "weapon": return str(weapons.get(type, "sword"))
	var slots: Dictionary = {"helmet":"helmet","body":"armor","tshirt":"armor","cloak":"cloak","gloves":"gloves","boots":"boots","pants":"pants","gaiters":"pants","offhand":"shield","shoulder":"shoulder","necklace":"necklace","belt":"belt","bracelet":"bracelet","badge":"badge","crystal":"gem","catalyst":"gem","rune":"rune"}
	if slots.has(slot): return slots[slot]
	if slot.begins_with("ring"): return "ring"
	if slot.begins_with("earring"): return "earring"
	if slot.begins_with("seal"): return "badge"
	if item_name == "아데나" or slot == "currency": return "coins"
	if item_name in ["화살", "총알"]: return "arrow" if item_name == "화살" else "ore"
	if "주문서" in item_name or "비법서" in item_name: return "scroll"
	if "물약" in item_name or "회복제" in item_name or "성수" in item_name or "엘릭서" in item_name: return "potion"
	if "요리" in type: return "food"
	if "축복" in type or "보석" in type: return "gem"
	if "재료" in type: return "ore"
	return "item"

static func texture(kind: String) -> Texture2D:
	if cache.has(kind): return cache[kind]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64"><defs><linearGradient id="metal" x2="0.8" y2="1"><stop stop-color="#fff0c9"/><stop offset="0.45" stop-color="#c9b083"/><stop offset="1" stop-color="#657b85"/></linearGradient></defs><path d="%s" fill="#17242d" stroke="url(#metal)" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>' % SHAPES.get(kind,SHAPES.item)
	var pixels := Image.new()
	if pixels.load_svg_from_string(svg) != OK: return null
	var result := ImageTexture.create_from_image(pixels)
	result.set_meta("twilight_self_authored", true)
	result.set_meta("item_family", kind)
	cache[kind] = result
	return result
