extends RefCounted
## Process-wide shared store for SP2 parse results and rendered frame textures
## (memory handoff P2). Before this, every actor's reference_sp2_bank kept its
## own parse of a member and every original_source_preview kept its own frame
## textures, so N identical NPCs held N copies of the same immutable data.
##
## What is shared: only immutable payloads (a decoder parse, frozen read-only,
## and the ImageTexture made from one exact decoder render). Selection, clocks,
## admission/exclusion checks, provenance and per-actor texture budgets stay in
## each bank/preview, unchanged.
##
## Keys never use an actor ID. A parsed key binds source domain + verified
## manifest SHA256 + member identity (SHA-pinned bytes, or the received
## receipt/CRC32/source_identity plus the absolute file it was read from, which
## is NOT promoted to a SHA pin) + decoder schema/code. A rendered key binds the
## parsed key + stored direction bit + frame + palette + pixel policy +
## compositor version. Different manifests or pixel policies never collide.
##
## Ownership: the cache holds one strong owner per entry. Callers hold leases
## (an owner token per key, idempotent, released exactly once). Only entries
## with zero leases are idle; only idle entries are evicted, oldest first, once
## idle bytes exceed the per-kind budget. Live entries are never evicted, even
## over budget (active pictures are not broken; creation is not deferred, which
## keeps today's visible behavior). Evicting drops the cache's owner only: an
## external Sprite2D/Image that still references a payload keeps it alive, so
## an eviction is not proof that memory was returned. Byte figures are payload
## lower bounds (a parse's allocated packed buffers; texture width*height*4),
## not Dictionary/Array/Variant overhead, allocator memory or driver/PSS.
##
## Pending decodes reserve their expected bytes first. A reservation is bound
## to the store generation; invalidate_all() bumps it so a late completion of
## a stale reservation is returned to its caller but never inserted.
##
## Integrity: this store does not verify bytes. reference_sp2_bank._member()
## still checks member identity, size and mtime on use, including cache hits;
## changed or not-yet-verified files are read and hashed (SHA256 or CRC32).
## The shared key comes from that verified identity. Synchronous bank loads
## also recheck the members and metadata after their local validation memos.

const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const SCHEMA = "reference_sp2_asset_service_v1"
const SOURCE_DOMAIN = "patch523_reference_sp2_bank"
const DECODER_PATH = "res://scripts/resources/current523_sp2_decoder.gd"
const RENDERER_PATH = "res://scripts/resources/current523_sp2_frame_renderer.gd"
const DECODER_SCHEMA = "current523_sp2_decoder.parse:v1"
## DECODER.render(parsed, group, frame) with no options = these policies;
## straight (not premultiplied) RGBA8, no mipmaps, no compression, no trim.
const PIXEL_POLICY = "alpha=opaque_samples;rgb=bit_replication;alpha_mode=straight;format=RGBA8;mipmaps=none;compression=none;trim=none"
const PALETTE_POLICY = "member_embedded_rgb565_palette"
const COMPOSITOR_VERSION = "reference_sp2_bank.packed_rgba_le+ImageTexture.create_from_image:v2"
## Idle (lease 0) budgets. Banks publish the format-aware packed-buffer cost
## once and reuse entry_bytes() for their local 32 MiB working sets. This is
## not a cap on the full parsed heap or on externally/live-owned payloads.
const IDLE_PARSED_BYTES = 32 * 1024 * 1024
const IDLE_TEXTURE_BYTES = 64 * 1024 * 1024
const KINDS: Array[String] = ["parsed", "texture"]

static var _entries: Dictionary = {"parsed": {}, "texture": {}} # kind -> key -> entry
static var _stale: Dictionary = {"parsed": {}, "texture": {}} # invalidated but still leased
static var _pending: Dictionary = {} # reservation id -> {kind,key,bytes,generation}
static var _generation: int = 1
static var _next_owner: int = 0
static var _next_reservation: int = 0
static var _tick: int = 0
static var _counters: Dictionary = {}
static var _decoder_code: String = ""
static var _renderer_code: String = ""

## A fresh owner token for one bank or preview (no reference to the owner kept).
static func new_owner() -> int:
	_next_owner += 1
	return _next_owner

static func decoder_version() -> String:
	if _decoder_code.is_empty():
		var code: String = BAKE.code_key([DECODER_PATH])
		_decoder_code = DECODER_SCHEMA + ":" + (code if not code.is_empty() else "code_unhashed")
	return _decoder_code

## Renderer changes affect rendered textures only, never verified parse keys.
static func renderer_version() -> String:
	if _renderer_code.is_empty():
		_renderer_code = BAKE.code_key([RENDERER_PATH])
	return _renderer_code

static func _digest(parts: Array) -> String:
	return ("\u001f".join(PackedStringArray(parts))).sha256_text()

## Key for one verified member parse; "" when an identity part is missing.
## `spec` is the manifest member record that the bytes were checked against.
static func parsed_key(manifest_sha256: String, member: String, spec: Dictionary, file_path: String) -> String:
	if manifest_sha256.is_empty() or member.is_empty(): return ""
	var identity: String
	var sha: Variant = spec.get("sha256")
	if sha is String and not (sha as String).is_empty():
		identity = "sha256_pinned:%s:bytes:%d" % [sha, int(spec.get("bytes", -1))]
	elif spec.get("stage") == "received_not_additionally_validated":
		# Received members keep their CRC/receipt domain and stay unpinned. The
		# exact file path is part of the key, so a parse is never shared between
		# two installs whose CRC-only identity merely agrees.
		identity = "received_crc32:%s:bytes:%d:receipt:%s:identity:%s:file:%s" % [str(spec.get("crc32")), int(spec.get("bytes", -1)), str(spec.get("source_receipt_id")), JSON.stringify(spec.get("source_identity"), "", true), file_path]
	else:
		return ""
	return _digest([SCHEMA, "parsed", SOURCE_DOMAIN, manifest_sha256, member, identity, decoder_version()])

## Key for one rendered frame of a parsed member. The preview only renders
## with PIXEL_POLICY; another policy (PMA, other alpha/RGB rule) is a new key.
static func rendered_key(parsed: String, group_bit: int, frame_index: int, pixel_policy: String = PIXEL_POLICY, compositor: String = COMPOSITOR_VERSION) -> String:
	if parsed.is_empty() or pixel_policy.is_empty() or compositor.is_empty(): return ""
	var renderer: String = renderer_version()
	if renderer.is_empty(): return "" # Render normally without shared insertion.
	return _digest([SCHEMA, "texture", parsed, "group_bit:%d" % group_bit, "frame:%d" % frame_index, PALETTE_POLICY, pixel_policy, compositor, renderer])

static func has_entry(kind: String, key: String) -> bool:
	return not key.is_empty() and (_entries[kind] as Dictionary).has(key)

static func entry_bytes(kind: String, key: String) -> int:
	var entry: Variant = (_entries[kind] as Dictionary).get(key)
	return int(entry.bytes) if entry is Dictionary else -1

## True when `owner` holds a live lease on `key`.
static func holds(kind: String, key: String, owner: int) -> bool:
	var entry: Variant = (_entries[kind] as Dictionary).get(key)
	return entry is Dictionary and (entry.owners as Dictionary).has(owner)

## Leases `key` for `owner` and returns its payload, or null when absent.
static func acquire(kind: String, key: String, owner: int) -> Variant:
	var entry: Variant = (_entries[kind] as Dictionary).get(key)
	if not entry is Dictionary:
		_count(kind, "misses")
		return null
	(entry.owners as Dictionary)[owner] = true
	_tick += 1
	entry.used = _tick
	_count(kind, "hits")
	return entry.payload

## Drops `owner`'s lease on `key` once. False (no change) for a double or
## foreign release. The last lease makes the entry idle and trims idle bytes.
static func release(kind: String, key: String, owner: int) -> bool:
	var stale: Variant = (_stale[kind] as Dictionary).get(key)
	if stale is Dictionary and (stale.owners as Dictionary).has(owner):
		(stale.owners as Dictionary).erase(owner)
		if (stale.owners as Dictionary).is_empty(): (_stale[kind] as Dictionary).erase(key)
		return true
	var entry: Variant = (_entries[kind] as Dictionary).get(key)
	if not entry is Dictionary or not (entry.owners as Dictionary).has(owner):
		if not key.is_empty(): _count(kind, "rejected_releases")
		return false
	(entry.owners as Dictionary).erase(owner)
	_tick += 1
	entry.used = _tick
	if (entry.owners as Dictionary).is_empty(): trim_idle(kind)
	return true

## Reserves `expected_bytes` for a decode/upload of `key` before it starts.
static func reserve(kind: String, key: String, expected_bytes: int) -> int:
	_next_reservation += 1
	_pending[_next_reservation] = {"kind":kind,"key":key,"bytes":maxi(0, expected_bytes),"generation":_generation}
	return _next_reservation

static func cancel(reservation: int) -> void:
	var pending: Variant = _pending.get(reservation)
	if not pending is Dictionary: return
	_pending.erase(reservation)
	_count(str(pending.kind), "cancelled")

## Commits a finished payload under its reservation and leases it to `owner`.
## Returns the payload to use: an already present entry wins (identical by key),
## and a stale-generation completion is returned uncached.
static func complete(reservation: int, payload: Variant, payload_bytes: int, owner: int) -> Variant:
	var pending: Variant = _pending.get(reservation)
	if not pending is Dictionary: return payload
	_pending.erase(reservation)
	var kind: String = pending.kind
	if int(pending.generation) != _generation or str(pending.key).is_empty():
		_count(kind, "stale_completions")
		return payload
	var existing: Variant = acquire(kind, pending.key, owner)
	if existing != null: return existing
	if kind == "parsed": _freeze(payload)
	_tick += 1
	(_entries[kind] as Dictionary)[pending.key] = {"payload":payload,"bytes":maxi(0, payload_bytes),"owners":{owner:true},"used":_tick,"generation":_generation}
	_count(kind, "created")
	trim_idle(kind)
	return payload

## Evicts idle (lease 0) entries, least recently used first, until idle bytes
## fit `budget` (default: the kind's const budget). Live entries are kept.
static func trim_idle(kind: String, budget: int = -1) -> int:
	var limit: int = budget if budget >= 0 else (IDLE_PARSED_BYTES if kind == "parsed" else IDLE_TEXTURE_BYTES)
	var entries: Dictionary = _entries[kind]
	var idle: Array = []
	var idle_bytes: int = 0
	for key: String in entries:
		if (entries[key].owners as Dictionary).is_empty():
			idle.append(key)
			idle_bytes += int(entries[key].bytes)
	# Within budget nothing is evicted: skip the sort (it ran on every release).
	if idle_bytes <= limit: return 0
	idle.sort_custom(func(a: String, b: String) -> bool: return int(entries[a].used) < int(entries[b].used))
	var evicted: int = 0
	for key: String in idle:
		if idle_bytes <= limit: break
		idle_bytes -= int(entries[key].bytes)
		entries.erase(key)
		evicted += 1
	if evicted > 0: _count(kind, "evicted", evicted)
	return evicted

## Blocks future hits on every current entry: idle entries are dropped, live
## entries move to a stale set and stay with their lessees until released,
## and pending reservations can no longer be committed.
static func invalidate_all() -> void:
	_generation += 1
	for kind: String in KINDS:
		var entries: Dictionary = _entries[kind]
		for key: String in entries.keys():
			if not (entries[key].owners as Dictionary).is_empty():
				var stale: Dictionary = _stale[kind]
				if stale.has(key): (stale[key].owners as Dictionary).merge(entries[key].owners)
				else: stale[key] = entries[key]
			entries.erase(key)
	_count("store", "invalidations")

static func stats() -> Dictionary:
	var result: Dictionary = {"schema":SCHEMA,"generation":_generation,"budgets":{"idle_parsed_bytes":IDLE_PARSED_BYTES,"idle_texture_bytes":IDLE_TEXTURE_BYTES},"pixel_policy":PIXEL_POLICY,"compositor_version":COMPOSITOR_VERSION,"bytes_are_payload_estimates":true,"external_owners_counted":false}
	result["parsed_payload_accounting"] = "allocated_packed_buffers_excludes_containers_allocator_GPU_RSS"
	for kind: String in KINDS:
		var live_count: int = 0
		var live_bytes: int = 0
		var idle_count: int = 0
		var idle_bytes: int = 0
		var leases: int = 0
		for entry: Dictionary in (_entries[kind] as Dictionary).values():
			var owners: int = (entry.owners as Dictionary).size()
			leases += owners
			if owners > 0:
				live_count += 1
				live_bytes += int(entry.bytes)
			else:
				idle_count += 1
				idle_bytes += int(entry.bytes)
		var pending_count: int = 0
		var pending_bytes: int = 0
		for pending: Dictionary in _pending.values():
			if pending.kind == kind:
				pending_count += 1
				pending_bytes += int(pending.bytes)
		var stale_count: int = 0
		var stale_bytes: int = 0
		for entry: Dictionary in (_stale[kind] as Dictionary).values():
			stale_count += 1
			stale_bytes += int(entry.bytes)
			leases += (entry.owners as Dictionary).size()
		var counters: Dictionary = (_counters.get(kind, {}) as Dictionary).duplicate()
		result[kind] = {"live_count":live_count,"live_bytes":live_bytes,"idle_count":idle_count,"idle_bytes":idle_bytes,"pending_count":pending_count,"pending_bytes":pending_bytes,"stale_live_count":stale_count,"stale_live_bytes":stale_bytes,"leases":leases,"cache_owned_entries":live_count + idle_count + stale_count,"counters":counters}
	return result

## Test/diagnostic only: forget every entry, reservation and counter.
static func reset_for_tests() -> void:
	_entries = {"parsed": {}, "texture": {}}
	_stale = {"parsed": {}, "texture": {}}
	_pending.clear()
	_counters.clear()
	_generation += 1

static func _count(kind: String, name: String, amount: int = 1) -> void:
	if not _counters.has(kind): _counters[kind] = {}
	_counters[kind][name] = int(_counters[kind].get(name, 0)) + amount

## Makes a parse result deeply read-only so no lessee can mutate shared data.
## Packed arrays are value types (copy on write) and need no freezing.
static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for item: Variant in (value as Dictionary).values(): _freeze(item)
		(value as Dictionary).make_read_only()
	elif value is Array:
		for item: Variant in value as Array: _freeze(item)
		(value as Array).make_read_only()
