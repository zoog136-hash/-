extends Node2D
class_name FieldLandmark

# Small code-native accents complement the shared painterly stone/prop atlas.
# Static draw commands: no per-landmark process, particles, lights or textures.
var kind: String = "crystal"
var accent := Color("8bbfda")
var stone := Color("817e89")

func _poly(points: Array, color: Color) -> void:
	var polygon := PackedVector2Array()
	for p: Vector2 in points:
		polygon.append(p)
	draw_colored_polygon(polygon, color)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var polygon := PackedVector2Array()
	for i: int in range(24):
		polygon.append(center + Vector2(cos(TAU*i/24.0), sin(TAU*i/24.0))*radius)
	draw_colored_polygon(polygon, color)

func _draw() -> void:
	_ellipse(Vector2(7,3), Vector2(40,14), Color(0,0,0,.25))
	match kind:
		"crystal":
			_ellipse(Vector2(0,-16),Vector2(57,26),Color(accent,.08))
			for offset: Vector2 in [Vector2(-23,-7),Vector2(22,-4),Vector2(0,-12)]:
				var height_value: float = 75 if offset.x != 0 else 128
				_poly([offset+Vector2(-17,0),offset+Vector2(-15,-height_value*.67),offset+Vector2(0,-height_value),offset+Vector2(7,-14)],accent.darkened(.2))
				_poly([offset+Vector2(0,-height_value),offset+Vector2(18,-height_value*.56),offset+Vector2(16,-5),offset+Vector2(7,-14)],accent.lightened(.35))
				draw_line(offset+Vector2(0,-height_value),offset+Vector2(7,-14),Color(1,1,1,.65),1.4,true)
		"obelisk":
			_poly([Vector2(-24,0),Vector2(-20,-120),Vector2(0,-157),Vector2(6,-4)],stone.darkened(.22))
			_poly([Vector2(0,-157),Vector2(21,-120),Vector2(24,0),Vector2(6,-4)],stone.lightened(.16))
			draw_line(Vector2(0,-114),Vector2(3,-28),accent,3,true)
			draw_arc(Vector2(1,-72),12,0,TAU,18,accent,2,true)
		"altar":
			_poly([Vector2(-72,-18),Vector2(0,-47),Vector2(72,-18),Vector2(0,10)],stone.lightened(.16))
			_poly([Vector2(-72,-18),Vector2(0,10),Vector2(0,27),Vector2(-72,-2)],stone.darkened(.2))
			_poly([Vector2(0,10),Vector2(72,-18),Vector2(72,-2),Vector2(0,27)],stone.darkened(.36))
			_poly([Vector2(-44,-61),Vector2(0,-81),Vector2(44,-61),Vector2(0,-40)],stone.lightened(.25))
			draw_rect(Rect2(-44,-61,88,21),stone)
			draw_arc(Vector2(0,-64),18,0,TAU,24,accent,3,true)
		"torch", "spore":
			_ellipse(Vector2(0,-64),Vector2(56,43),Color(accent,.035))
			_ellipse(Vector2(0,-64),Vector2(30,27),Color(accent,.09))
			draw_line(Vector2.ZERO,Vector2(0,-55),stone.darkened(.3),9,true)
			_poly([Vector2(-14,-55),Vector2(0,-100),Vector2(14,-55),Vector2(0,-44)],accent)
			_poly([Vector2(-6,-56),Vector2(0,-83),Vector2(7,-56),Vector2(0,-48)],accent.lightened(.6))
		"arch":
			for x: float in [-89,89]:
				draw_rect(Rect2(x-14,-143,28,143),stone)
				draw_rect(Rect2(x-22,-9,44,15),stone.lightened(.15))
			_poly([Vector2(-107,-143),Vector2(-80,-174),Vector2(80,-174),Vector2(107,-143)],stone.lightened(.15))
			draw_line(Vector2(-81,-168),Vector2(81,-168),accent,3,true)
		"stairs":
			for i: int in range(6):
				var y: float = -10-i*12
				_poly([Vector2(-47,y),Vector2(-35,y-10),Vector2(35,y-10),Vector2(47,y)],stone.lightened(i*.04))
				draw_line(Vector2(-47,y),Vector2(47,y),stone.darkened(.3),3,true)
		"tomb":
			_poly([Vector2(-31,-16),Vector2(0,-36),Vector2(31,-16),Vector2(0,3)],stone.lightened(.2))
			_poly([Vector2(-31,-16),Vector2(0,3),Vector2(31,-16),Vector2(31,0),Vector2(0,18),Vector2(-31,0)],stone.darkened(.2))
			draw_line(Vector2(0,-30),Vector2(0,-8),accent.darkened(.2),2,true)
		"banner":
			draw_line(Vector2.ZERO,Vector2(0,-132),stone.lightened(.2),6,true)
			_poly([Vector2(2,-120),Vector2(48,-109),Vector2(48,-42),Vector2(25,-58),Vector2(2,-42)],accent.darkened(.18))
			draw_line(Vector2(14,-111),Vector2(14,-53),accent.lightened(.2),2,true)
		"rune":
			_ellipse(Vector2.ZERO,Vector2(31,17),Color(accent,.06))
			draw_arc(Vector2.ZERO,24,0,TAU,32,Color(accent,.42),1.2,true)
			draw_line(Vector2(-16,-6),Vector2(16,6),Color(accent,.3),1,true)
		"rubble":
			for p: Vector2 in [Vector2(-19,0),Vector2(12,-8),Vector2(22,9)]:
				_poly([p+Vector2(-12,0),p+Vector2(-7,-11),p+Vector2(9,-8),p+Vector2(14,2),p+Vector2(2,8)],stone.lightened(p.x*.003))
