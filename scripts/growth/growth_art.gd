extends RefCounted
const SIGILS = preload("res://assets/growth/sigils.png")
const CARDS = preload("res://assets/growth/cards.png")
const BACKDROP = preload("res://assets/growth/constellation.png")
const IDS: Array = ["eva","paagrio","maphr","sayha","grankain","einhasad","shilen"]
const COLORS: Array = [Color("68c8ff"),Color("ff8b44"),Color("85d69c"),Color("9bdcf3"),Color("c296ec"),Color("ffe3a0"),Color("ca96e8")]
static func sigil(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SIGILS
	var cell: Vector2 = SIGILS.get_size()/3.0
	texture.region = Rect2(Vector2(index%3,index/3)*cell,cell)
	texture.filter_clip = true
	return texture
static func index(id: String) -> int:
	return maxi(0,IDS.find(id))

static func card(front: bool) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = CARDS
	var cell: Vector2 = CARDS.get_size()*Vector2(.5,1)
	texture.region = Rect2(Vector2(cell.x if front else 0,0),cell)
	texture.filter_clip = true
	return texture
