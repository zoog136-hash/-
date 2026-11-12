extends RefCounted
## Derived PNG upload pixels only. The image owner still verifies its files
## before calling this consumer. Budget/weak ownership reuse the image cache;
## this is decoded payload accounting, not total GPU/RSS or external ownership.
const TEXTURES=preload("res://scripts/resources/source523_texture_cache.gd")
const POLICY="cocos_rgba8_alpha_plus_one_shift8_v1"
const META="source_asset_pma_cache"
const MAX_EVIDENCE_DEPTH=32
const MAX_EVIDENCE_CHARS=65536
var _textures=TEXTURES.new()
var _sources: Dictionary={}
var _source_limit: int=TEXTURES.DEFAULT_MAX_ENTRIES
var _hits: int=0
var _conversions: int=0
var _bypasses: int=0

func _init(budget_bytes: int=TEXTURES.DEFAULT_BUDGET_BYTES, max_entries: int=TEXTURES.DEFAULT_MAX_ENTRIES) -> void:
	_source_limit=maxi(0,max_entries)
	_textures.configure(budget_bytes,max_entries)

func _notification(what: int) -> void:
	if what!=NOTIFICATION_PREDELETE:return
	# RefCounted is already at zero here: disconnect directly instead of
	# making another instance-method call through a temporary self reference.
	for state: Dictionary in _sources.values():
		var source: Object=state.source.get_ref()
		if source!=null and source.is_connected("changed",state.callback):source.disconnect("changed",state.callback)
	_sources.clear()

func request(source: Texture2D, evidence: Dictionary) -> Dictionary:
	# Other Texture2D implementations may generate changing frames without
	# ImageTexture's update/set_image changed notification. Keep their old path.
	if not source is ImageTexture:
		_bypasses+=1
		return {}
	var canonical: Variant=_canonical(evidence)
	if canonical==null:
		_bypasses+=1
		return {}
	var exact: String=JSON.stringify(canonical)
	if exact.length()>MAX_EVIDENCE_CHARS:
		_bypasses+=1
		return {}
	var identity: int=source.get_instance_id()
	if _sources.has(identity) and _sources[identity].source.get_ref()!=source:_sources.erase(identity)
	if not _sources.has(identity):
		if _sources.size()>=_source_limit:_prune_sources()
		if _sources.size()>=_source_limit:
			_bypasses+=1
			return {}
		var source_ref: WeakRef=weakref(source)
		var callback: Callable=Callable(get_script(),"_source_notified").bind(weakref(self),source_ref)
		_sources[identity]={"source":source_ref,"generation":0,"callback":callback}
		source.changed.connect(callback)
	var generation: int=_sources[identity].generation
	var key: String="%s:%d:%d:%s"%[POLICY,identity,generation,exact.sha256_text()]
	var request_value: Dictionary={"key":key,"source":_sources[identity].source,"generation":generation,"canonical":exact}
	var texture: Texture2D=_textures.lookup(key)
	if texture!=null:
		var metadata: Variant=texture.get_meta(META,{})
		var premultiplied: Variant=texture.get_meta("cocos_premultiplied",false)
		if metadata is Dictionary and metadata.get("source") is WeakRef and metadata.source.get_ref()==source and metadata.get("generation")==generation and metadata.get("policy")==POLICY and metadata.get("canonical")==exact and premultiplied is bool and premultiplied and _canonical(texture.get_meta("source523_original_asset",{}))==canonical:
			_hits+=1
			request_value["texture"]=texture
		else:
			_textures._forget(key)
	return request_value

func remember(request_value: Dictionary, source: Texture2D, texture: Texture2D, decoded_bytes: int) -> void:
	if request_value.is_empty() or texture==null:return
	var identity: int=source.get_instance_id()
	if not _sources.has(identity) or _sources[identity].source!=request_value.source or request_value.source.get_ref()!=source or _sources[identity].generation!=request_value.generation:return
	texture.set_meta(META,{"source":request_value.source,"generation":request_value.generation,"policy":POLICY,"canonical":request_value.canonical})
	_textures.remember(request_value.key,texture,decoded_bytes)
	texture.changed.connect(Callable(get_script(),"_derived_notified").bind(weakref(self),request_value.key,weakref(texture)))
	_conversions+=1

static func _source_notified(cache_ref: WeakRef, source_ref: WeakRef) -> void:
	var cache: RefCounted=cache_ref.get_ref() as RefCounted
	if cache!=null:cache._source_changed(source_ref)

static func _derived_notified(cache_ref: WeakRef, key: String, expected: WeakRef) -> void:
	var cache: RefCounted=cache_ref.get_ref() as RefCounted
	if cache!=null:cache._derived_changed(key,expected)

func _source_changed(source_ref: WeakRef) -> void:
	var source: Object=source_ref.get_ref()
	if source==null:return
	var identity: int=source.get_instance_id()
	if not _sources.has(identity) or _sources[identity].source!=source_ref:return
	# Old derivatives may still belong to visible scenes. Their generation
	# cannot be requested again; bounded cache ownership ages out normally.
	_sources[identity].generation+=1

func _derived_changed(key: String, expected: WeakRef) -> void:
	var texture: Texture2D=expected.get_ref() as Texture2D
	# An externally held old derivative can outlive eviction and replacement
	# under the same key. Its later changed signal must not remove the new one.
	if texture!=null and _textures.lookup(key)==texture:_textures._forget(key)

func _prune_sources() -> void:
	for identity: int in _sources.keys():
		if _sources[identity].source.get_ref()==null:_sources.erase(identity)

func clear() -> void:
	_textures.clear(true)
	for state: Dictionary in _sources.values():
		var source: Object=state.source.get_ref()
		var callback: Callable=state.callback
		if source!=null and source.is_connected("changed",callback):source.disconnect("changed",callback)
	_sources.clear()

func metrics() -> Dictionary:
	var result: Dictionary=_textures.metrics()
	result.merge({"source_watchers":_sources.size(),"source_limit":_source_limit,"derived_hits":_hits,"conversions":_conversions,"bypasses":_bypasses})
	return result

static func _canonical(value: Variant, depth: int=0) -> Variant:
	# Exact types/float bits avoid accidentally sharing evidence that merely
	# prints alike. Unsupported objects/keys bypass memoization safely.
	if depth>MAX_EVIDENCE_DEPTH:return null
	match typeof(value):
		TYPE_NIL:return ["null"]
		TYPE_BOOL:return ["bool",value]
		TYPE_INT:return ["int",str(value)]
		TYPE_FLOAT:return ["float64",var_to_bytes(value).hex_encode()] if is_finite(value) else null
		TYPE_STRING:return ["string",value]
		TYPE_ARRAY:
			var items: Array=[]
			for item: Variant in value:
				var encoded: Variant=_canonical(item,depth+1)
				if encoded==null:return null
				items.append(encoded)
			return ["array",items]
		TYPE_DICTIONARY:
			var keys: Array=value.keys()
			for key: Variant in keys:
				if not key is String:return null
			keys.sort()
			var pairs: Array=[]
			for key: String in keys:
				var encoded: Variant=_canonical(value[key],depth+1)
				if encoded==null:return null
				pairs.append([key,encoded])
			return ["dictionary",pairs]
	return null
