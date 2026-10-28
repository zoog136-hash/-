extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String]=[]
	var renderer:=RemakeSourceRenderer.new()
	root.add_child(renderer)
	renderer.png_lookup_budget_bytes=0
	var image:=Image.create(8,8,false,Image.FORMAT_RGBA8)
	var texture:=ImageTexture.create_from_image(image)
	var chunk:=Node2D.new()
	var sprite:=Sprite2D.new()
	sprite.texture=texture
	chunk.add_child(sprite)
	renderer.add_child(chunk)
	renderer.chunks[Vector2i.ZERO]=chunk
	renderer.png_textures={"res://sample.png":texture}
	renderer._prune_png_lookup()
	if not renderer.png_textures.has("res://sample.png"):failures.append("active texture evicted")
	renderer.chunks.clear()
	renderer.remove_child(chunk)
	renderer.retiring_png_chunks.append(weakref(chunk))
	chunk.queue_free()
	renderer._prune_png_lookup()
	if not renderer.png_textures.has("res://sample.png"):failures.append("pending-free texture evicted")
	await process_frame
	renderer._prune_png_lookup()
	if renderer.png_textures.has("res://sample.png") or renderer.png_lookup_bytes!=0:failures.append("idle texture retained")
	print("PNG_LOOKUP_OWNER_RESULT ",JSON.stringify({"failures":failures,"active_preserved":true,"idle_evicted":true}))
	quit(0 if failures.is_empty() else 1)
