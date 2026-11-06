extends RefCounted
const IDS: Array = ["eva","paagrio","maphr","sayha","grankain","einhasad","shilen"]
const COLORS: Array = [Color("68c8ff"),Color("ff8b44"),Color("85d69c"),Color("9bdcf3"),Color("c296ec"),Color("ffe3a0"),Color("ca96e8")]
static func sigil(_index: int) -> Texture2D:
	# No current original icon-role join has been supplied. Existing node
	# names/IDs and input remain visible; no atlas or substitute image is used.
	return null
static func index(id: String) -> int:
	return maxi(0,IDS.find(id))

static func card(_front: bool) -> Texture2D:
	# Card choice is owned by the existing numbered Button/caption/result,
	# not the retired painted front/back. Original decorative role is pending.
	return null
