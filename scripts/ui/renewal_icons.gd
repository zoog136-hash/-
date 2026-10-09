extends RefCounted

# Original gold SVG silhouettes. These geometric icons contain no game artwork.
const PATHS = {
	"inventory":"M18 22h28v34H18z M24 22v-8h16v8 M20 31h24 M26 41h12",
	"character":"M32 8a7 7 0 1 0 0 14a7 7 0 1 0 0-14 M18 29l14-5 14 5-4 15H22z M24 44l-5 12 M40 44l5 12",
	"skills":"M32 7l6 18 18 7-18 6-6 18-6-18-18-6 18-7z",
	"map":"M8 17l15-5 18 5 15-5v38l-15 5-18-5-15 5z M23 12v38 M41 17v38",
	"quest":"M18 9h29v46H18z M18 14H11v36h7 M25 22h15 M25 31h15 M25 40h9",
	"shop":"M23 7h18l-5 10 11 9 6 14-5 13H16l-5-13 6-14 11-9z M32 27v18 M37 30h-8l-3 5 12 4-3 5h-9",
	"menu":"M12 17h40 M12 32h40 M12 47h40",
	"settings":"M27 8h10l3 9 9 4 8 11-8 11-9 4-3 9H27l-3-9-9-4-8-11 8-11 9-4z M32 24a8 8 0 1 0 0 16a8 8 0 1 0 0-16",
	"enhance":"M22 10l23 22-9 9-23-22z M31 37L11 57 M40 45l10 4 6 8H30l6-8z",
	"auto":"M13 26a20 20 0 0 1 34-9l6 5 M53 10v12H41 M51 38a20 20 0 0 1-34 9l-6-5 M11 54V42h12",
	"log":"M13 10h38v42H29L17 59v-7h-4z M21 22h22 M21 32h22 M21 42h12",
	"transform":"M16 13l16 7 16-7v25l-16 18-16-18z M22 30l7 4 M42 30l-7 4 M27 43h10",
	"doll":"M32 10a7 7 0 1 0 0 14a7 7 0 1 0 0-14 M20 32l12-6 12 6 M32 26v18 M32 44l-10 11 M32 44l10 11",
	"relic":"M32 7l19 11v25L32 56 13 43V18z M32 17l10 6v14l-10 9-10-9V23z",
	"catalog":"M10 13h18l4 5 4-5h18v39H36l-4 5-4-5H10z M32 18v36 M17 24h9 M17 33h9 M39 24h8 M39 33h8",
	"class_select":"M15 17l10 11 7-20 7 20 10-11-5 28H20z M20 51h24",
	"attack":"M49 8l7 7-27 28-8-8z M17 33l15 15 M23 43L10 56 M7 53l6 7",
	"target":"M32 16a16 16 0 1 0 0 32a16 16 0 1 0 0-32 M32 7v16 M32 41v16 M7 32h16 M41 32h16 M32 28v8 M28 32h8",
	"return":"M29 12L9 32l20 20 M9 32h35l11 17",
	"close":"M16 16l32 32 M48 16L16 48"
}
const ALIASES={"아이템":"catalog","변신":"transform","마법인형":"doll","성물":"relic"}
static var cache: Dictionary={}

static func texture(kind: String) -> Texture2D:
	var key: String=str(ALIASES.get(kind,kind))
	if cache.has(key): return cache[key]
	var shape: String=str(PATHS.get(key,PATHS.menu))
	var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><defs><linearGradient id="gold" x2="0" y2="1"><stop stop-color="#f4e2b2"/><stop offset="1" stop-color="#ae8550"/></linearGradient></defs><path fill="none" stroke="url(#gold)" stroke-width="3" stroke-linejoin="round" stroke-linecap="round" d="'+shape+'"/></svg>'
	var source:=Image.new()
	if source.load_svg_from_string(svg) != OK: return null
	var icon: ImageTexture=ImageTexture.create_from_image(source)
	cache[key]=icon
	return icon
