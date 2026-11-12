extends SceneTree
## Actual source-pixel consumer and bounded derived cache, synthetic art only.
## Headless validates pixel conversion, signals and ownership; it is not a
## real GPU upload/readback or private-pack latency test.
const PIXELS=preload("res://scripts/ui/original_ui/source_asset_pixels.gd")
const CACHE=preload("res://scripts/ui/original_ui/source_asset_pma_cache.gd")
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const IMAGE_PACK=preload("res://scripts/resources/source523_image_pack.gd")
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _image(size: int=4, format_value: int=Image.FORMAT_RGBA8) -> Image:
	var image:=Image.create(size,size,false,format_value)
	image.fill(Color(0.7,0.4,0.2,0.5))
	return image

func _owner(texture: Texture2D, consumer: String="A") -> Dictionary:
	return {"ok":true,"texture":texture,"status":"verified_original_texture","consumer":consumer,"provenance":{"member":{"format":"PNG","sha256":"synthetic-member"},"pack_sha":"synthetic-pack"}}

func _reset(budget: int=33554432, entries: int=4096) -> RefCounted:
	PIXELS._pma_cache.clear()
	PIXELS._pma_cache=CACHE.new(budget,entries)
	return PIXELS._pma_cache

func _run() -> void:
	_reuse_and_evidence()
	_formats_and_passthrough()
	_changed_invalidation()
	_bounds_and_ownership()
	_helper_lifetime()
	_evidence_limits()
	_strict_owner_chain()
	await _dynamic_texture()
	PIXELS._pma_cache.clear()
	print("ORIGINAL_UI_PMA_CACHE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"headless_dummy_only":DisplayServer.get_name()=="headless","private_pack_used":false}))
	quit(0 if failures.is_empty() else 1)

func _reuse_and_evidence() -> void:
	var cache: RefCounted=_reset()
	var source:=ImageTexture.create_from_image(_image())
	var original_bytes: PackedByteArray=source.get_image().get_data()
	var owner: Dictionary=_owner(source)
	var first: Dictionary=PIXELS.consume_owner_result(owner)
	var second: Dictionary=PIXELS.consume_owner_result(owner)
	check(first.ok and first.texture==second.texture,"same source/evidence shares one derived texture")
	check(cache.metrics().conversions==1 and cache.metrics().derived_hits==1,"reuse skips a second pixel conversion")
	check(first.texture.get_image().get_data()==PACK.cocos_premultiply(_image()).get_data(),"cached pixels retain current exact upload math")
	check(source.get_image().get_data()==original_bytes and not source.has_meta("cocos_premultiplied"),"original pixels and PMA flag remain unchanged")
	check(first.evidence==second.evidence and not first.evidence.has("texture"),"each call retains exact texture-free evidence")
	check(first.texture.get_meta(CACHE.META).source.get_ref()==source and first.texture.get_meta(CACHE.META).policy==CACHE.POLICY,"derived metadata binds weak source and upload policy")
	var other: Dictionary=PIXELS.consume_owner_result(_owner(source,"B"))
	check(other.texture!=first.texture,"different consumer provenance cannot share a mutable metadata object")
	check(first.texture.get_meta("source523_original_asset").consumer=="A" and other.texture.get_meta("source523_original_asset").consumer=="B","provenance never overwrites a different consumer's derived texture")
	var reordered: Dictionary={"provenance":{"pack_sha":"synthetic-pack","member":{"sha256":"synthetic-member","format":"PNG"}},"consumer":"A","status":"verified_original_texture","texture":source,"ok":true}
	check(PIXELS.consume_owner_result(reordered).texture==first.texture,"canonical evidence ignores dictionary insertion order")
	var int_owner: Dictionary=_owner(source)
	var float_owner: Dictionary=_owner(source)
	int_owner["value"]=1
	float_owner["value"]=1.0
	check(PIXELS.consume_owner_result(int_owner).texture!=PIXELS.consume_owner_result(float_owner).texture,"different numeric evidence types stay separate")
	int_owner.value=0.123456789012345
	float_owner.value=0.123456789012346
	check(PIXELS.consume_owner_result(int_owner).texture!=PIXELS.consume_owner_result(float_owner).texture,"different float bits stay separate")
	var unsupported: Dictionary=_owner(source)
	unsupported["object"]=RefCounted.new()
	var bypass_before: int=cache.metrics().bypasses
	var unsupported_first: Dictionary=PIXELS.consume_owner_result(unsupported)
	check(PIXELS.consume_owner_result(unsupported).texture!=unsupported_first.texture and cache.metrics().bypasses==bypass_before+2,"unsupported evidence safely uses the uncached path")
	first.texture.set_meta("source523_original_asset",{"changed":true})
	var repaired: Dictionary=PIXELS.consume_owner_result(owner)
	check(repaired.texture!=first.texture and repaired.texture.get_meta("source523_original_asset")==repaired.evidence,"metadata changes reject stale reuse without requiring a pixel signal")
	repaired.texture.set_meta("cocos_premultiplied","unexpected type")
	var flag_repaired: Dictionary=PIXELS.consume_owner_result(owner)
	check(flag_repaired.texture!=repaired.texture and flag_repaired.texture.get_meta("cocos_premultiplied")==true,"untyped external PMA metadata safely rejects reuse")

func _formats_and_passthrough() -> void:
	_reset()
	for format_value: int in [Image.FORMAT_RGB8,Image.FORMAT_LA8]:
		var image: Image=_image(4,format_value)
		var source:=ImageTexture.create_from_image(image)
		var before: PackedByteArray=source.get_image().get_data()
		var result: Dictionary=PIXELS.consume_owner_result(_owner(source))
		var expected: Image=image.duplicate() as Image
		expected.convert(Image.FORMAT_RGBA8)
		check(result.ok and result.texture.get_image().get_data()==PACK.cocos_premultiply(expected).get_data(),"RGB/LA upload converts correctly "+str(format_value))
		check(source.get_image().get_format()==format_value and source.get_image().get_data()==before and image.get_format()==format_value,"RGB/LA source image format and bytes are preserved "+str(format_value))
	for format_value: String in ["JPEG","BMP"]:
		var source:=ImageTexture.create_from_image(_image())
		var owner: Dictionary=_owner(source)
		owner.provenance.member.format=format_value
		check(PIXELS.consume_owner_result(owner).texture==source,"opaque formats retain original identity "+format_value)
	var pma:=ImageTexture.create_from_image(_image())
	pma.set_meta("cocos_premultiplied",true)
	check(PIXELS.consume_owner_result(_owner(pma)).texture==pma,"already-premultiplied input retains existing identity")
	check(not PIXELS.consume_owner_result({"ok":true}).get("ok",true),"missing original texture still fails")
	check(PIXELS.consume_owner_result({"ok":false,"status":"file_sha_mismatch"}).get("error")=="file_sha_mismatch","owner failure remains a failure")
	var excluded: Dictionary=PIXELS.consume_owner_result({"ok":false,"status":"source_dummy_excluded","excluded_from_connection":true})
	check(excluded.get("ok",false) and excluded.get("excluded",false) and excluded.get("texture")==null,"dummy exclusion remains texture-free")

func _changed_invalidation() -> void:
	var cache: RefCounted=_reset()
	var source:=ImageTexture.create_from_image(_image())
	var owner: Dictionary=_owner(source)
	var first: Dictionary=PIXELS.consume_owner_result(owner)
	var signals: Array[int]=[0]
	source.changed.connect(func() -> void:signals[0]+=1)
	source.set_meta("nonpixel_metadata",true)
	check(signals[0]==0,"ordinary metadata does not imply Resource.changed")
	source.update(_image())
	var updated: Dictionary=PIXELS.consume_owner_result(owner)
	check(signals[0]==1 and updated.texture!=first.texture,"ImageTexture.update immediately invalidates source generation")
	source.set_image(_image())
	var replaced: Dictionary=PIXELS.consume_owner_result(owner)
	check(signals[0]==2 and replaced.texture!=updated.texture,"ImageTexture.set_image immediately invalidates source generation")
	replaced.texture.update(_image())
	var output_updated: Dictionary=PIXELS.consume_owner_result(owner)
	check(output_updated.texture!=replaced.texture,"derived ImageTexture.update invalidates that cached texture")
	# Both are under the same key/generation. A late event from the old object
	# must leave the newly remembered replacement available.
	replaced.texture.emit_changed()
	check(PIXELS.consume_owner_result(owner).texture==output_updated.texture,"old derived callback cannot evict a newer texture under the same key")
	output_updated.texture.set_image(_image())
	var output_replaced: Dictionary=PIXELS.consume_owner_result(owner)
	check(output_replaced.texture!=output_updated.texture,"derived ImageTexture.set_image invalidates that cached texture")
	cache.clear()
	var after_clear: Dictionary=PIXELS.consume_owner_result(owner)
	output_replaced.texture.emit_changed()
	check(PIXELS.consume_owner_result(owner).texture==after_clear.texture,"old callback after clear cannot evict a same-key replacement")
	check(source.get_signal_connection_list("changed").size()==2,"one source watcher plus the test observer after clear/reopen")
	cache.clear()
	check(source.get_signal_connection_list("changed").size()==1,"clear disconnects the source watcher")
	# Godot's dummy renderer returns its initially stored image after update;
	# this suite proves generation/object invalidation, not real GPU readback.

func _bounds_and_ownership() -> void:
	var cache: RefCounted=_reset(64,2)
	var source:=ImageTexture.create_from_image(_image())
	var held: Texture2D=PIXELS.consume_owner_result(_owner(source,"A")).texture
	var other: Texture2D=PIXELS.consume_owner_result(_owner(source,"B")).texture
	check(cache.metrics().resident_decoded_bytes_estimate<=64 and cache.metrics().evictions>0,"existing decoded-byte budget bounds strong cache ownership")
	check(PIXELS.consume_owner_result(_owner(source,"A")).texture==held and cache.metrics().weak_hits>0,"evicted externally owned texture is reused through its weak entry")
	check(other.get_width()==4,"eviction preserves another scene's texture")
	var ephemeral:=ImageTexture.create_from_image(_image(2))
	var source_ref: WeakRef=weakref(ephemeral)
	var derivative: Texture2D=PIXELS.consume_owner_result(_owner(ephemeral)).texture
	ephemeral=null
	check(source_ref.get_ref()==null and derivative.get_width()==2,"derived/cache/signal ownership does not retain its original source")
	var bounded=CACHE.new(64,2)
	var first:=ImageTexture.create_from_image(_image())
	var second:=ImageTexture.create_from_image(_image())
	var third:=ImageTexture.create_from_image(_image())
	bounded.request(first,{})
	bounded.request(second,{})
	check(bounded.request(third,{}).is_empty() and bounded.metrics().source_watchers==2,"live source watcher metadata is bounded; overflow bypasses")
	first=null
	check(not bounded.request(third,{}).is_empty() and bounded.metrics().source_watchers==2,"freed sources are pruned before admitting another watcher")
	bounded.clear()
	check(second.get_signal_connection_list("changed").is_empty() and third.get_signal_connection_list("changed").is_empty(),"bounded watcher cleanup disconnects live sources")

func _helper_lifetime() -> void:
	var helper=CACHE.new()
	var source:=ImageTexture.create_from_image(_image())
	var derivative:=ImageTexture.create_from_image(_image())
	var evidence: Dictionary=_owner(source)
	evidence.erase("texture")
	var request: Dictionary=helper.request(source,evidence)
	derivative.set_meta("cocos_premultiplied",true)
	derivative.set_meta("source523_original_asset",evidence)
	helper.remember(request,source,derivative,64)
	var helper_ref: WeakRef=weakref(helper)
	helper=null
	check(helper_ref.get_ref()==null,"source and derived signal callbacks do not retain the cache helper")
	check(source.get_signal_connection_list("changed").is_empty(),"helper destruction disconnects its bounded source watchers")
	source.emit_changed()
	derivative.emit_changed()
	check(source.get_width()==4 and derivative.get_width()==4,"external sources/derivatives survive helper destruction and late signals")

func _evidence_limits() -> void:
	var helper=CACHE.new()
	var source:=ImageTexture.create_from_image(_image())
	var cyclic: Dictionary={}
	cyclic["cycle"]=cyclic
	check(helper.request(source,cyclic).is_empty(),"cyclic helper evidence safely bypasses at the depth limit")
	cyclic.clear()
	var deep: Dictionary={}
	var cursor: Dictionary=deep
	for index: int in range(40):
		var child: Dictionary={}
		cursor["next"]=child
		cursor=child
	check(helper.request(source,deep).is_empty(),"deep evidence safely bypasses memoization")
	check(helper.request(source,{"text":"x".repeat(CACHE.MAX_EVIDENCE_CHARS+1)}).is_empty(),"oversized evidence cannot grow retained canonical metadata")
	check(helper.metrics().source_watchers==0,"uncacheable evidence adds no source watchers")

func _strict_owner_chain() -> void:
	_reset()
	var bytes: PackedByteArray=_image().save_png_to_buffer()
	var directory: String=ProjectSettings.globalize_path("user://pma-cache-synthetic")
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String=directory.path_join("test.png")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var pack=IMAGE_PACK.new()
	pack._root=directory
	pack._members["test.png"]={"file":"test.png","plain_bytes":bytes.size(),"sha256":FileAccess.get_sha256(path),"format":"PNG","width":4,"height":4}
	var initial: Dictionary=PIXELS.consume_owner_result(pack._texture("test.png",{}))
	check(initial.ok and PIXELS.consume_owner_result(pack._texture("test.png",{})).texture==initial.texture,"verified resident owner still feeds derived reuse")
	var changed: PackedByteArray=bytes.duplicate()
	changed[changed.size()-1]^=1
	file=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(changed)
	file.close()
	var rejected: Dictionary=PIXELS.consume_owner_result(pack._texture("test.png",{}))
	check(not rejected.get("ok",true) and rejected.get("status")=="file_sha_mismatch","same-size on-disk tamper remains rejected before a derived hit")
	check(PIXELS._pma_cache.metrics().conversions==1,"failed owner verification never bypasses to a derived result")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(directory)

func _dynamic_texture() -> void:
	var cache: RefCounted=_reset()
	var dynamic:=GradientTexture2D.new()
	dynamic.width=4
	dynamic.height=4
	dynamic.gradient=Gradient.new()
	await process_frame
	var first: Dictionary=PIXELS.consume_owner_result(_owner(dynamic))
	var second: Dictionary=PIXELS.consume_owner_result(_owner(dynamic))
	check(first.get("ok",false) and second.get("ok",false) and first.texture!=second.texture,"dynamic non-ImageTexture retains its uncached conversion path")
	check(cache.metrics().bypasses==2 and cache.metrics().source_watchers==0,"dynamic source does not add generation watchers")
