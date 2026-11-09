extends RefCounted
## C03 / P1. DESIGN_NOT_RECOVERED_API. Logical-name resolution through the
## Data/info.json manifest, DAT read, loose fallback and decode, with every
## outcome kept as a distinct ReadResult status. Backends are injected callables
## so this layer never owns key values: it only records a key *provider reference*.
##
## manifest: lowercase logical name -> {"canonical","container","container_version","backend"}
## dat_backend(container, canonical)      -> {"ok":bool,"bytes":PackedByteArray,"decode":"ok"|"probe_failed"|"failed"}
## loose_backend(logical_name)            -> {"ok":bool,"bytes":PackedByteArray}
## streaming_fallback(container, canonical) -> {"ok":bool,"bytes":PackedByteArray}
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const BUNDLE_BACKEND := "DatBundleFile"

var manifest: Dictionary = {}
var dat_backend: Callable = Callable()
var loose_backend: Callable = Callable()
var streaming_fallback: Callable = Callable()
var key_provider_ref: String = ""

static func make_result(status: String, bytes: PackedByteArray, canonical_name: String, container: String, container_version: String, backend: String, provenance: Array) -> Dictionary:
	return {
		"record": "ReadResult",
		"design_status": VOCAB.EVIDENCE_DESIGN,
		"status": status,
		"bytes": bytes,
		"canonical_name": canonical_name,
		"container": container,
		"container_version": container_version,
		"backend": backend,
		"provenance": provenance,
	}

## Case-insensitive manifest key: byte-wise ASCII tolower. The backend still
## receives the manifest's canonical member name, never the caller's spelling.
static func manifest_key(logical_name: String) -> String:
	return VOCAB.lower_ascii(logical_name)

## Root removal is repeated substring replacement until the root no longer occurs.
static func strip_root(path: String, root: String) -> String:
	if root.is_empty():
		return path
	var current: String = path
	while current.contains(root):
		current = current.replace(root, "")
	return current

func _loose(logical_name: String, trail: Array, canonical: String, container: String, version: String, miss_status: String) -> Dictionary:
	if not loose_backend.is_valid():
		trail.append("loose_backend_unavailable")
		return make_result(miss_status, PackedByteArray(), canonical, container, version, "none", trail)
	var loose: Variant = loose_backend.call(logical_name)
	if loose is Dictionary and loose.get("ok", false):
		var bytes: PackedByteArray = loose.get("bytes", PackedByteArray())
		if bytes.is_empty():
			trail.append("loose_read_ok_empty")
			return make_result(VOCAB.READ_EMPTY, bytes, canonical, container, version, "loose", trail)
		trail.append("loose_read_ok_no_decode_step")
		return make_result(VOCAB.READ_DECODED, bytes, canonical, container, version, "loose", trail)
	trail.append("loose_read_failed")
	return make_result(miss_status, PackedByteArray(), canonical, container, version, "none", trail)

func read_bytes(logical_name: String) -> Dictionary:
	var key: String = manifest_key(logical_name)
	var trail: Array = ["key_provider_ref=" + key_provider_ref]
	var entry: Variant = manifest.get(key)
	if not entry is Dictionary:
		# No manifest member: the DAT read cannot succeed, so the loose layer is tried.
		trail.append("manifest_miss")
		return _loose(logical_name, trail, "", "", "", VOCAB.READ_MISSING)
	var canonical: String = str(entry.get("canonical", ""))
	var container: String = str(entry.get("container", ""))
	var version: String = str(entry.get("container_version", ""))
	var backend_name: String = str(entry.get("backend", "dat"))
	trail.append("manifest_hit")
	if not dat_backend.is_valid():
		trail.append("dat_backend_unavailable")
		return _loose(logical_name, trail, canonical, container, version, VOCAB.READ_FAILED)
	var read: Variant = dat_backend.call(container, canonical)
	if not (read is Dictionary) or not read.get("ok", false):
		trail.append("dat_read_failed")
		return _loose(logical_name, trail, canonical, container, version, VOCAB.READ_FAILED)
	var bytes: PackedByteArray = read.get("bytes", PackedByteArray())
	if bytes.is_empty():
		# Read succeeded but empty: this reader layer returns failure-like EmptySuccess
		# and does NOT retry loose. A separate Cocos delegate fallback layer is not modelled.
		trail.append("dat_read_ok_empty")
		trail.append("loose_not_retried_in_this_layer")
		trail.append("cocos_delegate_fallback_layer_not_evaluated")
		return make_result(VOCAB.READ_EMPTY, bytes, canonical, container, version, backend_name, trail)
	var decode: String = str(read.get("decode", "ok"))
	if decode == "ok":
		trail.append("dat_read_ok_decoded")
		return make_result(VOCAB.READ_DECODED, bytes, canonical, container, version, backend_name, trail)
	if decode == "probe_failed":
		# A failed Brotli-family probe is NOT plain-text success.
		trail.append("brotli_probe_failed")
		if streaming_fallback.is_valid():
			var streamed: Variant = streaming_fallback.call(container, canonical)
			if streamed is Dictionary and streamed.get("ok", false) and not (streamed.get("bytes", PackedByteArray()) as PackedByteArray).is_empty():
				trail.append("approved_streaming_fallback_ok")
				return make_result(VOCAB.READ_DECODED, streamed.get("bytes", PackedByteArray()), canonical, container, version, backend_name + "+streaming", trail)
			trail.append("approved_streaming_fallback_failed")
		else:
			trail.append("no_streaming_fallback_provided")
		return make_result(VOCAB.READ_DECODE_FAILED, PackedByteArray(), canonical, container, version, backend_name, trail)
	trail.append("decode_failed")
	return make_result(VOCAB.READ_DECODE_FAILED, PackedByteArray(), canonical, container, version, backend_name, trail)

## Bytes API and stream API are separate. The Bundle stream-open returns an empty
## shared pair; a successful bytes read says nothing about stream availability.
func open_stream(logical_name: String) -> Dictionary:
	var entry: Variant = manifest.get(manifest_key(logical_name))
	if entry is Dictionary and str(entry.get("backend", "")) == BUNDLE_BACKEND:
		return {"status": "STREAM_UNAVAILABLE", "reason": "DatBundleFile stream-open returns an empty shared pair", "bundle": true}
	return {"status": "STREAM_NOT_MODELLED", "reason": "only the Bundle stream-open boundary is part of this contract", "bundle": false}
