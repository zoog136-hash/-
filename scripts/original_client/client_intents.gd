extends RefCounted
## C24 / P6. DESIGN_NOT_RECOVERED_API. Move/attack/cast request construction and an offline
## recorder. Building or queueing a request is not a socket send, a server ACK or a hit.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")

const WIRE_MOVE := 0x96
const WIRE_ATTACK := 0x97
const WIRE_CAST := 0x98
const WIRE_CHANGE_ATTACK_TARGET := 0x9B
## Local event 0x97 is a different namespace from wire 0x97.

static func move(directions: Array, is_auto: bool, is_link: bool, is_virtual_pad: bool, luid: Variant = null) -> Dictionary:
	return {"namespace": "wire", "opcode": WIRE_MOVE, "directions": directions.duplicate(), "is_auto": is_auto, "is_link": is_link, "is_virtual_pad": is_virtual_pad, "luid": luid}

static func attack(target_luid: int, is_auto: bool, is_link: bool, priority: bool) -> Dictionary:
	return {"namespace": "wire", "opcode": WIRE_ATTACK, "target_luid": target_luid, "is_auto": is_auto, "is_link": is_link, "priority": priority}

static func cast(spell_id: int, target_parameter: Variant, is_auto: bool, slot_no: int, quickslot_auto: bool) -> Dictionary:
	return {"namespace": "wire", "opcode": WIRE_CAST, "spell_id": spell_id, "target_parameter": target_parameter, "is_auto": is_auto, "slot_no": slot_no, "quickslot_auto": quickslot_auto}

static func local_event_attack(payload: Dictionary) -> Dictionary:
	return {"namespace": "local_event", "opcode": WIRE_ATTACK, "payload": payload.duplicate(true)}

## Priority is the remembered auto-selected LUID AND the condition.
static func attack_priority(remembered_auto_luid: int, target_luid: int, condition: bool) -> bool:
	return remembered_auto_luid == target_luid and condition

## wire 0x9B: a zero input returns without building a request.
static func change_attack_target(target_luid: int) -> Variant:
	if target_luid == 0:
		return null
	return {"namespace": "wire", "opcode": WIRE_CHANGE_ATTACK_TARGET, "target_luid": target_luid}

## Cast type 4: the confirmed producer branch sends the actor LUID, not a point guessed from
## the data name "LandPoint".
static func cast_target_parameter(cast_type: int, actor_luid: int, land_point: Variant) -> Variant:
	if cast_type == 4:
		return actor_luid
	return land_point

class OfflineIntentRecorder extends RefCounted:
	var log: Array = []
	func submit(request: Dictionary) -> Dictionary:
		var entry := {"request": request.duplicate(true), "queued": true, "socket_sent": false, "server_accepted": false, "server_ack": null,
			"design_status": VOCAB.EVIDENCE_DESIGN, "key": "%s:%02X" % [request.namespace, request.opcode]}
		log.append(entry)
		return entry
