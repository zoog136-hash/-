extends RefCounted
## C28 / P7. DESIGN_NOT_RECOVERED_API. Audio request records. Backend replacement is an
## explicit DESIGN adapter; the original path is SoundSystem -> SoundPlayer -> SoundStreamingSource -> Miles.
const VOCAB = preload("res://scripts/original_client/oc_vocab.gd")
const ORIGINAL_CHAIN := ["SoundSystem", "SoundPlayer", "SoundStreamingSource", "Miles"]
const BGM_CHAIN := ["BGMSound", "SoundBundle", "Sound", "SoundMaterial", "AssetView/AssetType"]

static func make(family: String, logical_path: String, category_gain: float, material_gain: Variant, caller_gain: float, pool_key: Variant, loop_policy: Variant, owner: String) -> Dictionary:
	return {"record": "AudioRequest", "design_status": VOCAB.EVIDENCE_DESIGN, "family": family, "logical_path": logical_path, "category_gain": category_gain,
		"material_gain": material_gain, "caller_gain": caller_gain, "pool_key": pool_key, "loop_policy": loop_policy, "owner": owner}

## SPR effect sounds: Sound/<signed decimal>.ogg.
static func spr_sound_path(sound_id: int) -> String:
	return "Sound/%d.ogg" % sound_id

## Material effect 02177380: category gain x caller gain. material.VolumeRatio is NOT multiplied again.
static func material_effect_gain(category_gain: float, caller_gain: float, _volume_ratio: float) -> float:
	return category_gain * caller_gain

## Same asset in different families keep separate owner/category policy records.
static func requests_for_asset(logical_path: String, bgm_owner: String, voice_owner: String) -> Array:
	return [make("BGM", logical_path, 1.0, null, 1.0, null, "loop", bgm_owner), make("VOICE", logical_path, 1.0, null, 1.0, null, "once", voice_owner)]
