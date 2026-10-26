extends SceneTree
## Real source renderer atlas cache eviction; no private art or fixture overwrite.
const SOURCE_RENDERER = preload("res://scripts/maps/source_renderer.gd")
const ART = "res://assets/maps/reference_expansion_v2/terrain.png"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SOURCE_TEXTURE_CACHE_FAIL ",label)

func run() -> void:
	if not ResourceLoader.exists(ART):
		check(false,"committed source atlas available")
		finish()
		return
	var renderer = SOURCE_RENDERER.new()
	var mapping: Dictionary = {}
	for i: int in range(SOURCE_RENDERER.SOURCE_TEXTURE_LIMIT+1):
		mapping[str(i)] = {"images":{"0":{"path":ART}}}
	renderer.tile_mapping = mapping
	for i: int in range(SOURCE_RENDERER.SOURCE_TEXTURE_LIMIT):
		check(renderer.tile_texture(i,0)!=null,"source atlas loads "+str(i))
	check(renderer.source_textures.size()==SOURCE_RENDERER.SOURCE_TEXTURE_LIMIT,"cache stays bounded")
	check(renderer.tile_texture(0,0)!=null,"recently used atlas is reused")
	check(renderer.tile_texture(SOURCE_RENDERER.SOURCE_TEXTURE_LIMIT,0)!=null,"new atlas key loads")
	check(renderer.source_textures.size()==SOURCE_RENDERER.SOURCE_TEXTURE_LIMIT,"cache cap never expands")
	check(renderer.source_textures.has("0:0"),"recently used atlas key survives")
	check(not renderer.source_textures.has("1:0"),"oldest untouched atlas key is evicted")
	check(renderer.tile_texture(1,1)==null,"unknown atlas index stays absent")
	check(renderer.source_textures.size()==SOURCE_RENDERER.SOURCE_TEXTURE_LIMIT,"missing texture is not cached")
	renderer.free()
	finish()

func finish() -> void:
	print("SOURCE_TEXTURE_CACHE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
