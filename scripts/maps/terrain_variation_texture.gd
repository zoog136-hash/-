extends RefCounted
## A small authored procedural field shared by all terrain materials/maps.
## R: continuous source phase; G: broad weathering; B: transition erosion.
## Texture coordinates cover the map bounds, so no non-periodic edge is tiled.
const SIZE: int = 128
static var cached: ImageTexture

static func build_image() -> Image:
	var phase := FastNoiseLite.new()
	phase.seed = 84031
	phase.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	phase.frequency = 0.13
	phase.fractal_type = FastNoiseLite.FRACTAL_NONE
	var weather := FastNoiseLite.new()
	weather.seed = 84032
	weather.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	weather.frequency = 0.032
	weather.fractal_type = FastNoiseLite.FRACTAL_NONE
	var erosion := FastNoiseLite.new()
	erosion.seed = 84033
	erosion.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	erosion.frequency = 0.42
	erosion.fractal_type = FastNoiseLite.FRACTAL_NONE
	var image := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			image.set_pixel(x,y,Color(
				clampf(.5+phase.get_noise_2d(x,y)*.55,0.0,1.0),
				clampf(.5+weather.get_noise_2d(x,y)*.55,0.0,1.0),
				clampf(.5+erosion.get_noise_2d(x,y)*.55,0.0,1.0),1.0))
	return image

static func get_texture() -> ImageTexture:
	if cached == null:
		cached = ImageTexture.create_from_image(build_image())
	return cached
