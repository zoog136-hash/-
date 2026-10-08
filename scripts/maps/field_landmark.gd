extends Node2D
class_name FieldLandmark

# Static geometry uses the existing stone atlas, bevels and engraved details.
# CanvasItem caches these commands; there is no per-prop process or new image.
const VISUAL_SIZES: Dictionary = {
	"crystal":Vector2(118,157), "obelisk":Vector2(78,170),
	"altar":Vector2(160,145), "torch":Vector2(74,122),
	"spore":Vector2(94,106), "arch":Vector2(232,195),
	"stairs":Vector2(108,90), "tomb":Vector2(88,71),
	"banner":Vector2(116,149), "rune":Vector2(84,44),
	"rubble":Vector2(85,48)
}
var kind: String = "crystal"
var accent := Color("8bbfda")
var stone := Color("817e89")
var stone_texture: Texture2D

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _stone_face(points: Array, tint: Color) -> void:
	var polygon := PackedVector2Array(points)
	if stone_texture == null:
		draw_colored_polygon(polygon,tint)
		return
	var uv := PackedVector2Array()
	for p: Vector2 in polygon:
		# Stay inside the atlas's lower-left stone quadrant, including padding.
		uv.append(Vector2(.015+(p.x+130.0)/600.0,.515+(p.y+190.0)/520.0))
	draw_polygon(polygon,PackedColorArray([tint]),uv,stone_texture)

func _edge(points: Array, tint: Color, width_value: float = 1.0) -> void:
	draw_polyline(PackedVector2Array(points),tint,width_value,true)

func _block(at: Vector2, width_value: float, depth: float, height_value: float, tint: Color) -> void:
	var left: Vector2 = at+Vector2(-width_value,-height_value)
	var front: Vector2 = at+Vector2(0,depth-height_value)
	var right: Vector2 = at+Vector2(width_value,-height_value)
	var back: Vector2 = at+Vector2(0,-depth-height_value)
	_stone_face([left,front,front+Vector2(0,height_value),left+Vector2(0,height_value)],tint.darkened(.24))
	_stone_face([front,right,right+Vector2(0,height_value),front+Vector2(0,height_value)],tint.darkened(.45))
	_stone_face([left,back,right,front],tint.lightened(.22))
	_edge([left,back,right],Color(tint.lightened(.6),.75),1.3)
	_edge([left,front,right],Color(0,0,0,.38),1.2)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var polygon := PackedVector2Array()
	for i: int in range(24):
		polygon.append(center + Vector2(cos(TAU*i/24.0), sin(TAU*i/24.0))*radius)
	draw_colored_polygon(polygon, color)

func _ring(at: Vector2, radius: Vector2, tint: Color, width_value: float = 1.0) -> void:
	var points := PackedVector2Array()
	for i: int in range(33):
		points.append(at+Vector2(cos(TAU*i/32.0),sin(TAU*i/32.0))*radius)
	draw_polyline(points,tint,width_value,true)

func _sigil(at: Vector2, radius: float, tint: Color) -> void:
	_ring(at,Vector2(radius,radius*.65),tint,1.3)
	_edge([at+Vector2(0,-radius*.55),at+Vector2(radius*.52,0),at+Vector2(0,radius*.55),at+Vector2(-radius*.52,0),at+Vector2(0,-radius*.55)],tint,1.2)
	draw_line(at+Vector2(0,-radius*.8),at+Vector2(0,radius*.8),tint,1.0,true)

func _crystal() -> void:
	_ellipse(Vector2(0,-7),Vector2(57,24),Color(accent,.07))
	for rock: Vector2 in [Vector2(-29,0),Vector2(27,-4),Vector2(3,7)]:
		_stone_face([rock+Vector2(-18,-3),rock+Vector2(-9,-17),rock+Vector2(15,-10),rock+Vector2(19,3),rock+Vector2(0,10)],stone.darkened(.15))
	for offset: Vector2 in [Vector2(-23,-7),Vector2(22,-4),Vector2(0,-12)]:
		var height_value: float = 75.0 if offset.x != 0 else 128.0
		var tip: Vector2 = offset+Vector2(-3,-height_value)
		var ridge: Vector2 = offset+Vector2(5,-height_value*.67)
		var foot: Vector2 = offset+Vector2(5,-5)
		var left: Vector2 = offset+Vector2(-17,-height_value*.64)
		var right: Vector2 = offset+Vector2(18,-height_value*.53)
		draw_polygon(PackedVector2Array([tip,left,offset+Vector2(-14,1),foot,ridge]),PackedColorArray([accent.lightened(.6),accent.darkened(.3),accent.darkened(.52),accent.darkened(.14),accent.lightened(.15)]))
		draw_polygon(PackedVector2Array([tip,ridge,foot,offset+Vector2(16,-2),right]),PackedColorArray([accent.lightened(.85),accent.lightened(.48),accent.darkened(.1),accent.lightened(.16),accent.lightened(.65)]))
		_poly([tip,left,ridge],Color(accent.lightened(.65),.6))
		_edge([tip,ridge,foot],Color(1,1,1,.68),1.1)
		_edge([offset+Vector2(-12,-height_value*.39),offset+Vector2(4,-height_value*.29),offset+Vector2(13,-height_value*.42)],Color(accent.lightened(.5),.32))
		draw_line(ridge+Vector2(5,11),foot+Vector2(5,-21),Color(1,1,1,.28),2.0,true)

func _obelisk() -> void:
	_block(Vector2(0,4),34,13,12,stone)
	_stone_face([Vector2(-24,-8),Vector2(-20,-120),Vector2(0,-157),Vector2(6,-12)],stone.darkened(.12))
	_stone_face([Vector2(0,-157),Vector2(21,-120),Vector2(24,-8),Vector2(6,-12)],stone.lightened(.24))
	_poly([Vector2(0,-157),Vector2(4,-150),Vector2(10,-13),Vector2(6,-12)],Color(stone.lightened(.7),.38))
	_edge([Vector2(-20,-120),Vector2(0,-157),Vector2(21,-120)],stone.lightened(.5))
	for y: float in [-106,-77,-48]:
		_edge([Vector2(-8,y-5),Vector2(-1,y+1),Vector2(-7,y+8)],Color(accent,.8),1.5)
		draw_line(Vector2(-1,y+1),Vector2(0,y-9),Color(accent,.66),1.1,true)
	_edge([Vector2(-20,-34),Vector2(-13,-41),Vector2(-15,-57)],Color(0,0,0,.44))

func _altar() -> void:
	_block(Vector2(0,5),72,26,13,stone)
	_block(Vector2(0,-9),59,22,9,stone)
	_block(Vector2(0,-25),31,13,22,stone.darkened(.1))
	_block(Vector2(0,-49),47,19,9,stone.lightened(.15))
	_edge([Vector2(-46,-58),Vector2(0,-40),Vector2(46,-58)],accent.darkened(.16),1.8)
	_sigil(Vector2(0,-61),22,Color(accent,.86))
	# Chiseled panels and joints make the side faces read as built masonry.
	for x: float in [-42,-21,21,42]:
		var y: float = -8.0+absf(x)*.35
		draw_line(Vector2(x,y-9),Vector2(x,y-2),Color(0,0,0,.35),1.0,true)
	for x: float in [-32,32]:
		_ellipse(Vector2(x,-64),Vector2(6,3),stone.darkened(.6))
		draw_line(Vector2(x,-64),Vector2(x,-80),Color("c5bfa4"),3.0,true)
		_poly([Vector2(x-3,-81),Vector2(x+1,-91),Vector2(x+4,-81)],accent.lightened(.6))
	_ring(Vector2(0,-103),Vector2(16,17),Color(accent,.48),1.3)
	_poly([Vector2(0,-118),Vector2(7,-102),Vector2(0,-88),Vector2(-7,-102)],Color(accent,.68))

func _torch() -> void:
	_ellipse(Vector2(0,-75),Vector2(40,35),Color(accent,.035))
	_block(Vector2(0,2),15,7,8,stone)
	draw_line(Vector2(0,-5),Vector2(0,-56),stone.darkened(.58),8,true)
	draw_line(Vector2(-2,-9),Vector2(-2,-56),stone.lightened(.35),2,true)
	_stone_face([Vector2(-17,-58),Vector2(17,-58),Vector2(10,-46),Vector2(-10,-46)],stone.darkened(.16))
	_edge([Vector2(-17,-58),Vector2(0,-54),Vector2(17,-58)],accent.darkened(.35),2)
	_poly([Vector2(-12,-58),Vector2(-15,-74),Vector2(-6,-70),Vector2(2,-105),Vector2(5,-80),Vector2(14,-88),Vector2(12,-66),Vector2(4,-55)],accent.darkened(.18))
	_poly([Vector2(-7,-61),Vector2(-3,-80),Vector2(1,-74),Vector2(5,-92),Vector2(8,-65),Vector2(0,-57)],accent.lightened(.4))
	_poly([Vector2(-3,-60),Vector2(1,-75),Vector2(5,-60)],Color("fff0c2"))

func _spore() -> void:
	for offset: Vector2 in [Vector2(-20,0),Vector2(22,3),Vector2(0,-12)]:
		var height_value: float = 41 if offset.x != 0 else 68
		draw_line(offset,offset+Vector2(3,-height_value),stone.darkened(.15),7,true)
		draw_line(offset+Vector2(-2,-4),offset+Vector2(1,-height_value),stone.lightened(.48),2,true)
		var cap: Vector2 = offset+Vector2(3,-height_value)
		_ellipse(cap+Vector2(0,-3),Vector2(23,12),accent.darkened(.24))
		_ellipse(cap+Vector2(-4,-6),Vector2(16,7),accent.lightened(.16))
		_edge([cap+Vector2(-20,2),cap+Vector2(0,9),cap+Vector2(21,2)],Color(accent.lightened(.65),.8),1.5)
		for spot: Vector2 in [Vector2(-11,-5),Vector2(1,-10),Vector2(11,-3)]:
			_ellipse(cap+spot,Vector2(2,1.6),accent.lightened(.7))

func _arch() -> void:
	for x: float in [-89,89]:
		_block(Vector2(x,0),22,8,10,stone)
		_stone_face([Vector2(x-14,-9),Vector2(x-14,-121),Vector2(x+14,-121),Vector2(x+14,-9)],stone)
		_poly([Vector2(x+7,-9),Vector2(x+7,-121),Vector2(x+14,-121),Vector2(x+14,-9)],Color(0,0,0,.24))
		draw_line(Vector2(x-11,-12),Vector2(x-11,-119),stone.lightened(.55),1.2,true)
		for y: float in [-30,-54,-78,-102]:
			draw_line(Vector2(x-14,y),Vector2(x+14,y),stone.darkened(.62),1.5,true)
		_block(Vector2(x,-119),22,7,8,stone)
	for i: int in range(9):
		var a: float = PI+PI*i/9.0+.01
		var b: float = PI+PI*(i+1)/9.0-.01
		var at := Vector2(0,-112)
		var outer_a: Vector2 = at+Vector2(cos(a)*112,sin(a)*70)
		var outer_b: Vector2 = at+Vector2(cos(b)*112,sin(b)*70)
		var inner_a: Vector2 = at+Vector2(cos(a)*78,sin(a)*45)
		var inner_b: Vector2 = at+Vector2(cos(b)*78,sin(b)*45)
		_stone_face([outer_a,outer_b,inner_b,inner_a],stone.lightened(.1+sin(a)*-.15))
		_edge([inner_a,outer_a,outer_b],Color(stone.lightened(.55),.5),1.2)
		_edge([inner_a,inner_b],stone.darkened(.6),2)
	_sigil(Vector2(0,-170),8,accent)

func _stairs() -> void:
	for i: int in range(6):
		var y: float = -10-i*12
		_stone_face([Vector2(-47,y+5),Vector2(-47,y),Vector2(47,y),Vector2(47,y+5)],stone.darkened(.4))
		_stone_face([Vector2(-47,y),Vector2(-35,y-10),Vector2(35,y-10),Vector2(47,y)],stone.lightened(i*.04))
		draw_line(Vector2(-47,y),Vector2(47,y),stone.lightened(.55),1.2,true)
		var joint_x: float = -12.0 if i%2 == 0 else 17.0
		draw_line(Vector2(joint_x,y),Vector2(joint_x-2,y-9),stone.darkened(.4),1,true)

func _tomb() -> void:
	_block(Vector2(0,2),35,17,17,stone)
	_block(Vector2(0,-15),39,19,5,stone.lightened(.2))
	_edge([Vector2(0,-34),Vector2(26,-20),Vector2(0,-8),Vector2(-26,-20),Vector2(0,-34)],stone.darkened(.4),1.4)
	_sigil(Vector2(0,-21),10,accent.darkened(.26))
	_edge([Vector2(-31,-12),Vector2(-20,-16),Vector2(-14,-13)],Color(0,0,0,.5),1.1)
	_stone_face([Vector2(-9,-31),Vector2(-9,-49),Vector2(0,-56),Vector2(9,-49),Vector2(9,-31)],stone.lightened(.12))
	draw_line(Vector2(0,-49),Vector2(0,-34),stone.darkened(.48),1.5,true)

func _banner() -> void:
	_block(Vector2(0,0),12,6,6,stone)
	draw_line(Vector2.ZERO,Vector2(0,-136),stone.darkened(.6),6,true)
	draw_line(Vector2(-1,-5),Vector2(-1,-136),stone.lightened(.6),1.4,true)
	_poly([Vector2(0,-144),Vector2(5,-135),Vector2(0,-131),Vector2(-5,-135)],accent.lightened(.3))
	draw_line(Vector2(-5,-122),Vector2(54,-111),stone.lightened(.5),3,true)
	draw_polygon(PackedVector2Array([Vector2(3,-119),Vector2(49,-109),Vector2(49,-40),Vector2(28,-54),Vector2(3,-40)]),PackedColorArray([accent.lightened(.18),accent.darkened(.2),accent.darkened(.34),accent,accent.darkened(.16)]))
	_poly([Vector2(12,-117),Vector2(19,-115),Vector2(19,-49),Vector2(12,-46)],Color(accent.lightened(.55),.23))
	_poly([Vector2(35,-112),Vector2(40,-111),Vector2(40,-48),Vector2(35,-51)],Color(0,0,0,.2))
	_edge([Vector2(7,-112),Vector2(45,-104),Vector2(45,-48),Vector2(28,-61),Vector2(7,-48),Vector2(7,-112)],accent.lightened(.62),1.2)
	_sigil(Vector2(28,-87),10,accent.lightened(.8))

func _rune() -> void:
	_ellipse(Vector2.ZERO,Vector2(38,19),Color(accent,.05))
	_ring(Vector2.ZERO,Vector2(35,17),Color(accent,.36),1.1)
	_ring(Vector2.ZERO,Vector2(28,13),Color(accent,.22),1.0)
	_sigil(Vector2.ZERO,17,Color(accent,.4))
	for i: int in range(8):
		var direction := Vector2(cos(TAU*i/8.0),sin(TAU*i/8.0)*.5)
		draw_line(direction*30,direction*34,Color(accent,.55),1.3,true)

func _rubble() -> void:
	for p: Vector2 in [Vector2(-19,0),Vector2(12,-8),Vector2(22,9)]:
		_stone_face([p+Vector2(-12,0),p+Vector2(-7,-11),p+Vector2(9,-8),p+Vector2(14,2),p+Vector2(2,8)],stone.lightened(p.x*.003))
		_edge([p+Vector2(-7,-11),p+Vector2(9,-8),p+Vector2(2,1)],stone.lightened(.35),1.0)
		_poly([p+Vector2(2,1),p+Vector2(14,2),p+Vector2(2,8)],Color(0,0,0,.22))

func _draw() -> void:
	if kind != "rune":
		_ellipse(Vector2(6,5),Vector2(44,16),Color(0,0,0,.08))
		_ellipse(Vector2(4,3),Vector2(35,12),Color(0,0,0,.2))
	match kind:
		"crystal": _crystal()
		"obelisk": _obelisk()
		"altar": _altar()
		"torch": _torch()
		"spore": _spore()
		"arch": _arch()
		"stairs": _stairs()
		"tomb": _tomb()
		"banner": _banner()
		"rune": _rune()
		"rubble": _rubble()
