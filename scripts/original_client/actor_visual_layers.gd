extends RefCounted
## C09 / P2. DESIGN_NOT_RECOVERED_API. Main body, shadow and clothes layers of one
## actor, with explicit replace / keep / clear operations. Auxiliary layers never get
## an independent SPR action: they share the body descriptor's word0 low16 and its
## original picture byte.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const SELECT = preload("res://scripts/original_client/sprite_selection.gd")
const SHADOW_KIND := 101
const CLOTHES_KIND := 105

static func make(main: Variant, shadow: Variant, clothes: Array, identity: Variant, generation: int = 0) -> Dictionary:
	return {"record": "ActorVisualLayers", "design_status": VOCAB.EVIDENCE_DESIGN, "main": main, "shadow": shadow,
		"clothes": clothes.duplicate(true), "refresh_aux": false, "depth_key": null, "identity": identity, "generation": generation, "log": []}

## Request ids for the auxiliary layers. Shadow 101 follows the body request id AFTER the
## action alias; clothes 105 follow the actor's original sprite list. Each file request
## gets its own single whole-remap.
static func aux_requests(body_request_after_alias: int, actor_original_sprites: Array, remap: Dictionary) -> Dictionary:
	var clothes: Array = []
	for sprite: Variant in actor_original_sprites:
		clothes.append(SELECT.apply_whole_remap(VOCAB.u16(int(sprite)), remap))
	return {"shadow": SELECT.apply_whole_remap(VOCAB.u16(body_request_after_alias), remap), "clothes": clothes}

## Auxiliary layers reuse the body selection; only an FFFF word0 patch changes word0.
static func aux_selection(body: Dictionary) -> Dictionary:
	return {"word0_low16": body.get("low16"), "picture_u8": body.get("picture_u8"), "independent_action": false}

## Changing the main layer. refresh_aux=false keeps shadow and clothes. With refresh_aux
## the shadow follows the new request: an animated path with shadow id 0 clears it, a
## static path with shadow id 0 keeps the previous shadow. Clothes are resolved in order
## and the walk stops at the first missing entry, keeping only the successful prefix.
static func change_main(layers: Dictionary, new_main: Variant, refresh_aux: bool, animated: bool, new_shadow_id: int, clothes_lookup: Array) -> Dictionary:
	var out: Dictionary = layers.duplicate(true)
	out["main"] = new_main
	out["refresh_aux"] = refresh_aux
	out["generation"] = int(layers.get("generation", 0)) + 1
	var log: Array = []
	if not refresh_aux:
		log.append("shadow_kept")
		log.append("clothes_kept")
		out["log"] = log
		return out
	if new_shadow_id == 0:
		if animated:
			out["shadow"] = null
			log.append("shadow_cleared_animated_zero")
		else:
			log.append("shadow_kept_static_zero")
	else:
		out["shadow"] = new_shadow_id
		log.append("shadow_replaced")
	var kept: Array = []
	for entry: Variant in clothes_lookup:
		if entry == null:
			log.append("clothes_walk_stopped_at_first_null")
			break
		kept.append(entry)
	out["clothes"] = kept
	log.append("clothes_prefix_%d" % kept.size())
	out["log"] = log
	return out

## Final order comes from each piece's depth and cell draw order, never from the order in
## which clothes were collected. Ascending depth with a stable tie is the DESIGN choice;
## the numeric direction of the original depth byte is not part of the approved evidence.
static func draw_order(pieces: Array) -> Array:
	var indexed: Array = []
	for i: int in pieces.size():
		indexed.append({"piece": pieces[i], "collected": i})
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = int(a.piece.get("depth", 0))
		var db: int = int(b.piece.get("depth", 0))
		if da != db:
			return da < db
		return int(a.collected) < int(b.collected))
	var out: Array = []
	for item: Dictionary in indexed:
		out.append(item.piece)
	return out
