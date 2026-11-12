extends SceneTree
## Synthetic packed-payload regression. The recursive oracle counts actual
## packed buffers, never serialized size or Dictionary/Array/RSS overhead.
const BUILD = preload("res://tests/sp2_parse_cache_test.gd")
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const PAYLOAD = preload("res://scripts/resources/sp2_parsed_payload.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const ASSETS = preload("res://scripts/resources/reference_sp2_asset_service.gd")
const CACHE = preload("res://scripts/resources/sp2_parse_cache.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const LIMIT: int = 32 * 1024 * 1024
## Offline BrotliEncoderCompress fixtures of BUILD.build(), all invented.
## CI only decodes these base64 constants; no Python/Brotli encoder needed.
const COMPRESSED: Dictionary = {"tiny": {"shape": [1, 4, 4, 4], "last": null, "body_bytes": 616, "body_sha": "4527f5adca3ae5080432eeeda944caaf6eaacce0c225b85a3f19c22c66a2013e", "base64": "G2cCAARabgewfftmtuRqSjrl3FPKmhd5QKlfCA4ew9ZPisP9CxpvjgrNpQhrAgJ2OCB5k2N9UzkC"}, "large_0": {"shape": [8, 200, 128, 0], "last": 0, "body_bytes": 6787755, "body_sha": "53dc8ed065bea9b0278b3c8536c88501d2541e623b0ba110935c3c59cf182285", "base64": "m6qSZxHFfADQzAHlxv7cjzKaUESRlobMVGmjWR1mMg9EWe7YeWoEIkZ7auniramH5nxhJvNDTMsdO3+tQMRq5wZnGCSQRYElstomG/z0wNqy8swDCmpLAws0T+ng364fOOei/ltkU6aVHqOsbPzSKEv67RzppQc68Cdv7Xlp5wMe8Ab49FlUlj0fUAEHHHCBFnCAXY5xaNNoA9+AMPA9cS7b2mZRNtpEdiOIyvMALLD9P2AA1sQ1796eIu2XWRZlswYrwAAssAIrwADcQgg24MSiAraBL7Dw54YxQ6ERwOgsim7OYujlhfYGzrnORzelWIVwghVYAiVQghXRB8bpQPgKMbItLjSUgEMOqSVPILIIe3MYmyjCQQztpLCXwnGDsb1Io46QYAKHINLu4jFAW7wTFBc7JZMTAIvHAGyJ6+dQnLsFL2lkppcxM5CfRwPzHMCQ4kIHazgBgtm5H0tboCGFiVICqb6oP3jITFEF8aF5z38AAABxiINVxIQ6sQAeFw4pqtEsVsELXWgJH5A7+slAFUaVNQatnevjKD+jvVbpNFNimxxZiV2cFpdUYQ8V6CO/JKA2mIw0bkhJ2UOBpaPWNrpWvxigQziVi2Il8dJnt04XCKoS1FyLan43kATr0JQC0niILJkTVEzJgSJnleQt5lp60S5F5bLSOaRBa9JbvLbUBSGXrrKmxwxbKbvoNKrN3qA/HIwK2IMDH6kTfeZ1UmsGc1x1sEm0+c7I/KQ2rc+ec8AYn3BTdWaaO9uBTnx1bP5+fc4ulbU93cVyeVjd158DdMEs5ZVhbZ/6NjrP7N5Vt/ReOprnYDHa7LbX3fsG3lAr7nR768GzDe9Sh/vlK3kr3OuP3n6w3xzOx9cJeCRO/FlzMV9dh+AxcTqvwCX+zL2q785jfF5djtfH7esGu2OP8mS/REf5NNz2x/eJfjLf8q/1H94Xj/3z9vr4Qt7oD+nL/AnKr67W1/PCIzWLq7H7v9l7+7l83z7oG/mEX/of71/6aWb+XQ+exM2/2u/+J7/1//QgliQAAAAKMAAEAAAUBgR60IcBDGEEY5jAFGYwhwWgsIQVrGEDW9jBHg5whBOc4QJXwAAHAkiggAYGWOCABwFEkEAGBVTQQIcb3OEBT3jBGz7whR/8EYBABCEYIQhFGMIRgUhEIRoxiEUc4pGARCQhGSlIRRrSkYFMZCEbOchFHvJRgEIUoRglKEUZylGBSlShGjWoRR3q0YBGNKEZLWhFG9rRgU50oRs96EUf+jGAQQxhGCMYxRjGMQEGJjGFacxgFnOYxwIWsYRlrGAVa1jHBjaxhW3sgAkW2OCACx74EEAIEcSQQAoZ5FBACRXU0EALHXaxh30c4BBHOMYJTnGGc1zgEle4xg1ucYd7POART3jGC17xhnd81CfwlcMx/vHeh2AADD3xN2UCMAGyIdIFx7A+cdYaDIBGImCzyxNoL14L3dUdEZE0O6kdXyTZv/msDHdvQsU66k31sRXHD7+N6enPmER2/5vp8jXnL/nO8gYLCKou5wo3FO9df5QH2xeuYKAWlsuSH93/1CfHH20QqPb0cHjqs+dce3GFeDhFhmL6E4h2r95L/c0Tk9FyDOQzZYd337Xx4UuJJ2av6jZXdfqUbc0vIAcjp+jDbV+ou3wr9tYPVELRv/ZJP5Ye3H5VR/sPCQ5xDrfPUZ48/jVnZ4CNRBgkAA=="}, "large_1": {"shape": [8, 200, 128, 0], "last": 1, "body_bytes": 6787755, "body_sha": "e3b05cb83c56fec31ea298d0944d1dc940e247d649e7a4965046b4e4a5518395", "base64": "m6qSZxHFfADQzAHlxv7cjzKaUESRlobMVGmjWR1mMg9EWe7YeWoEIkZ7auniramH5nxhJvNDTMsdO3+tQMRq5wZnGCSQRYElstomG/z0wNqy8swDCmpLAws0T+ng364fOOei/ltkU6aVHqOsbPzSKEv67RzppQc68Cdv7Xlp5wMe8Ab49FlUlj0fUAEHHHCBFnCAXY5xaNNoA9+AMPA9cS7b2mZRNtpEdiOIyvMALLD9P2AA1sQ1796eIu2XWRZlswYrwAAssAIrwADcQgg24MSiAraBL7Dw54YxQ6ERwOgsim7OYujlhfYGzrnORzelWIVwghVYAiVQghXRB8bpQPgKMbItLjSUgEMOqSVPILIIe3MYmyjCQQztpLCXwnGDsb1Io46QYAKHINLu4jFAW7wTFBc7JZMTAIvHAGyJ6+dQnLsFL2lkppcxM5CfRwPzHMCQ4kIHazgBgtm5H0tboCGFiVICqb6oP3jITFEF8aF5z38AAABxiINVxIQ6sQAeFw4pqtEsVsELXWgJH5A7+slAFUaVNQatnevjKD+jvVbpNFNimxxZiV2cFpdUYQ8V6CO/JKA2mIw0bkhJ2UOBpaPWNrpWvxigQziVi2Il8dJnt04XCKoS1FyLan43kATr0JQC0niILJkTVEzJgSJnleQt5lp60S5F5bLSOaRBa9JbvLbUBSGXrrKmxwxbKbvoNKrN3qA/HIwK2IMDH6kTfeZ1UmsGc1x1sEm0+c7I/KQ2rc+ec8AYn3BTdWaaO9uBTnx1bP5+fc4ulbU93cVyeVjd158DdMEs5ZVhbZ/6NjrP7N5Vt/ReOprnYDHa7LbX3fsG3lAr7nR768GzDe9Sh/vlK3kr3OuP3n6w3xzOx9cJeCRO/FlzMV9dh+AxcTqvwCX+zL2q785jfF5djtfH7esGu2OP8mS/REf5NNz2x/eJfjLf8q/1H94Xj/3z9vr4Qt7oD+nL/AnKr67W1/PCIzWLq7H7v9l7+7l83z7oG/mEX/of71/6aWb+XQ+exM2/2u/+J7/1//QgliQAAAAKMAAEAAAUBgR60IcBDGEEY5jAFGYwhwWgsIQVrGEDW9jBHg5whBOc4QJXwAAHAkiggAYGWOCABwFEkEAGBVTQQIcb3OEBT3jBGz7whR/8EYBABCEYIQhFGMIRgUhEIRoxiEUc4pGARCQhGSlIRRrSkYFMZCEbOchFHvJRgEIUoRglKEUZylGBSlShGjWoRR3q0YBGNKEZLWhFG9rRgU50oRs96EUf+jGAQQxhGCMYxRjGMQEGJjGFacxgFnOYxwIWsYRlrGAVa1jHBjaxhW3sgAkW2OCACx74EEAIEcSQQAoZ5FBACRXU0EALHXaxh30c4BBHOMYJTnGGc1zgEle4xg1ucYd7POART3jGC17xhnd81CfwlcMx/vHeh2AADD3xN2UCMAGyIdIFx7A+cdYaDIBGImCzyxNoL14L3dUdEZE0O6kdXyTZv/msDHdvQsU66k31sRXHD7+N6enPmER2/5vp8jXnL/nO8gYLCKou5wo3FO9df5QH2xeuYKAWlsuSH93/1CfHH20QqPb0cHjqs+dce3GFeDhFhmL6E4h2r95L/c0Tk9FyDOQzZYd337Xx4UuJJ2av6jZXdfqUbc0vIAcjp+jDbV+ou3wr9tYPVELRv/ZJP5Ye3H5VR/sPCQ5xDrfPUZ48/jVnZ4CNRBgkCA=="}, "large_2": {"shape": [8, 200, 128, 0], "last": 2, "body_bytes": 6787755, "body_sha": "ab911642caaf143fcafe83ecc752e661ec1649d98d2fa5c943779292baf92280", "base64": "m6qSZxHFfADQzAHlxv7cjzKaUESRlobMVGmjWR1mMg9EWe7YeWoEIkZ7auniramH5nxhJvNDTMsdO3+tQMRq5wZnGCSQRYElstomG/z0wNqy8swDCmpLAws0T+ng364fOOei/ltkU6aVHqOsbPzSKEv67RzppQc68Cdv7Xlp5wMe8Ab49FlUlj0fUAEHHHCBFnCAXY5xaNNoA9+AMPA9cS7b2mZRNtpEdiOIyvMALLD9P2AA1sQ1796eIu2XWRZlswYrwAAssAIrwADcQgg24MSiAraBL7Dw54YxQ6ERwOgsim7OYujlhfYGzrnORzelWIVwghVYAiVQghXRB8bpQPgKMbItLjSUgEMOqSVPILIIe3MYmyjCQQztpLCXwnGDsb1Io46QYAKHINLu4jFAW7wTFBc7JZMTAIvHAGyJ6+dQnLsFL2lkppcxM5CfRwPzHMCQ4kIHazgBgtm5H0tboCGFiVICqb6oP3jITFEF8aF5z38AAABxiINVxIQ6sQAeFw4pqtEsVsELXWgJH5A7+slAFUaVNQatnevjKD+jvVbpNFNimxxZiV2cFpdUYQ8V6CO/JKA2mIw0bkhJ2UOBpaPWNrpWvxigQziVi2Il8dJnt04XCKoS1FyLan43kATr0JQC0niILJkTVEzJgSJnleQt5lp60S5F5bLSOaRBa9JbvLbUBSGXrrKmxwxbKbvoNKrN3qA/HIwK2IMDH6kTfeZ1UmsGc1x1sEm0+c7I/KQ2rc+ec8AYn3BTdWaaO9uBTnx1bP5+fc4ulbU93cVyeVjd158DdMEs5ZVhbZ/6NjrP7N5Vt/ReOprnYDHa7LbX3fsG3lAr7nR768GzDe9Sh/vlK3kr3OuP3n6w3xzOx9cJeCRO/FlzMV9dh+AxcTqvwCX+zL2q785jfF5djtfH7esGu2OP8mS/REf5NNz2x/eJfjLf8q/1H94Xj/3z9vr4Qt7oD+nL/AnKr67W1/PCIzWLq7H7v9l7+7l83z7oG/mEX/of71/6aWb+XQ+exM2/2u/+J7/1//QgliQAAAAKMAAEAAAUBgR60IcBDGEEY5jAFGYwhwWgsIQVrGEDW9jBHg5whBOc4QJXwAAHAkiggAYGWOCABwFEkEAGBVTQQIcb3OEBT3jBGz7whR/8EYBABCEYIQhFGMIRgUhEIRoxiEUc4pGARCQhGSlIRRrSkYFMZCEbOchFHvJRgEIUoRglKEUZylGBSlShGjWoRR3q0YBGNKEZLWhFG9rRgU50oRs96EUf+jGAQQxhGCMYxRjGMQEGJjGFacxgFnOYxwIWsYRlrGAVa1jHBjaxhW3sgAkW2OCACx74EEAIEcSQQAoZ5FBACRXU0EALHXaxh30c4BBHOMYJTnGGc1zgEle4xg1ucYd7POART3jGC17xhnd81CfwlcMx/vHeh2AADD3xN2UCMAGyIdIFx7A+cdYaDIBGImCzyxNoL14L3dUdEZE0O6kdXyTZv/msDHdvQsU66k31sRXHD7+N6enPmER2/5vp8jXnL/nO8gYLCKou5wo3FO9df5QH2xeuYKAWlsuSH93/1CfHH20QqPb0cHjqs+dce3GFeDhFhmL6E4h2r95L/c0Tk9FyDOQzZYd337Xx4UuJJ2av6jZXdfqUbc0vIAcjp+jDbV+ou3wr9tYPVELRv/ZJP5Ye3H5VR/sPCQ5xDrfPUZ48/jVnZ4CNRBgkBA=="}, "oversize": {"shape": [8, 200, 255, 0], "last": 3, "body_bytes": 13493355, "body_sha": "98f4259219cf3c2d8ed573069f9eb6293022f311f33a18e5f97f36743c727fc8", "base64": "y///PxHFfADQzAHlxv7cjzKaUESRlobMVGmjWR1mMg9EWe7YeWoEIkZ7auniramH5nxhJvNDTMsdO3+tQMRq5wZnGCSQRYElstomG/z0wNqy8swDCmpLAws0T+ng364fOOei/ltkU6aVHqOsbPzSKEv67RzppQc68Cdv7Xlp5wMe8Ab49FlUlj0fUAEHHHCBFnCAXY5xaNNoA9+AMPA9cS7b2mZRNtpEdiOIyvMALLD9P2AA1sQ1796eIu2XWRZlswYrwAAssAIrwADcQgg24MSiAraBL7Dw54YxQ6ERwOgsim7OYujlhfYGzrnORzelWIVwghVYAiVQghXRB8bpQPgKMbItLjSUgEMOqSVPILIIe3MYmyjCQQztpLCXwnGDsb1Io46QYAKHINLu4jFAW7wTFBc7JZMTAIvHAGyJ6+dQnLsFL2lkEDA7UM9/A/McwJDiQodeA6AdMoPBuceywEjjorTIiov6HmNyXMOU8dzzHwAAQBziYBUxoU4sgMeFQ4pqNItV8EIXWsIH5I5+MlCFUWWNQWvn+jjKz2ivVTrNlNgmR1ZiF6fFJVXYQwX6yC8JqA0mI40bUlL2UGDpqLWNrtUvBugQTuWiWEm89Nmt0wWCqgQ116Ka3w0kwTo0pYA0HiJL5gQVU3KgyFkleYu5ll60S1G5rHQOadCa9BavLXVByKWrrOkxw1bKLjqNarM36A8HowL24MBH6kSfeZ3UmsEcVx1sEm2+MzI/qU3rs+ccMMYn3FSdmebOdqATXx2bv1+fs0tlbU93sVweVvf15wBdMEt5ZVjbp76NzjO7d9UtvZeO5jlYjDa77XX3voE31Io73d568GzDu9ThfvlK3gr3+qO3H+w3h/PxdQIeiRN/1lzMV9cheEyczitwiT9zr+q78xifV5fj9XH7usHu2KM82S/RUT4Nt/3xfaKfzLf8a/2H98Vj/7y9Pr6QN/pD+jJ/gvKrq/X1vPBIzeJq7P5v9t5+Lt+3D/pGPuGX/sf7l36amX/Xgydx86/2u//Jb/0/PYglSQAAgAL/AAgAAAgCAj3owwCGMIIxTGAKM5jDAlBYwgrWsIEt7GAPBzjCCc5wgStggAMBJFBAAwMscMCDACJIIIMCKmigww3u8IAnvOANH/jCD/4IQCCCEIwQhCIM4YhAJKIQjRjEIg7xSEAikpCMFKQiDenIQCaykI0c5CIP+ShAIYpQjBKUogzlqEAlqlCNGtSiDvVoQCOa0IwWtKIN7ehAJ7rQjR70og/9GMAghjCMEYxiDOOYwCSmMI0ZzGIO81jAIpawjBWsYg3r2MAmtrCNHeyCASZYYIMDLnjgQwAhRBBDAilkkEMBJVRQQwMtdNjDPg5wiCMc4wSnOMM5LnCJK1zjBre4wz0e8IgnPOMFr3jDOz7yE/jS2v7HuE+gYcAIavLfkA5ABMjE/CwckfPERIg5ABqJgM0uj6+5eC32VndERNLspHZ8kXj/5rM63L0JFeuoN9XHkh8//Danpz9jEtn9b6bLU5+/FLrLGywgqLqcK9xQtHf9UYm3L1zBQC0slyk7uv9pTI4/2iBQ7enhcFVnz/nO4grxcIoMxfQnEOqu3suDzROT0XIM5DOkh3ff9fHhS4knZq/qNkd5+pRrzy8gByOn6MNtX6C9fCv11w9UQtG/9kk/ITm4/aqN9h8SHOIcbp+tOHn8a83OABuJdJBq5E0APA5wczxwVUtbo7DU2gz7IizWgzvKxeHXGPasC4AAiIEACIAACIAACIAACIAACIBS5LAAknA3AQ=="}}
## Existing twilight.sp2-parse.v1 metadata bytes of BUILD.build(1,4,4,4),
## generated with the unchanged Godot 4.7.2 decoder before accounting changes.
const LEGACY_METADATA: String = "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"
var checks: int = 0
var failures: Array[String] = []
var scratch: String

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func write_bytes(path: String, value: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(value)
	file.close()

func write_json(path: String, value: Dictionary) -> String:
	write_bytes(path, JSON.stringify(value).to_utf8_buffer())
	return FileAccess.get_sha256(path)

func digest(value: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(value)
	return hash.finish().hex_encode()

func packed_oracle(value: Variant) -> int:
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY: return value.size()
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY: return value.size() * 4
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY: return value.size() * 8
		TYPE_PACKED_VECTOR2_ARRAY: return value.size() * 8
		TYPE_PACKED_VECTOR3_ARRAY: return value.size() * 12
		TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY: return value.size() * 16
		TYPE_DICTIONARY:
			var total: int = 0
			for nested: Variant in value.values(): total += packed_oracle(nested)
			return total
		TYPE_ARRAY:
			var total: int = 0
			for nested: Variant in value: total += packed_oracle(nested)
			return total
	return 0

func oracle(parsed: Dictionary) -> int:
	var retained: Dictionary = parsed.duplicate()
	# This is the decoder's explicit FE alias contract, not a second copy.
	if not parsed.raw.is_empty() and parsed.raw[0] == 254: retained.erase("raw")
	return packed_oracle(retained)

func fingerprint(parsed: Dictionary, group: int = 0, frame: int = 0) -> Dictionary:
	var result: Dictionary = DECODER.render(parsed, group, frame)
	return {"ok": result.get("ok", false), "offset": result.get("offset"), "empty": result.get("empty"),
		"pixels": result.image.get_data() if result.get("ok", false) else PackedByteArray(),
		"size": result.image.get_size() if result.get("ok", false) else Vector2i.ZERO}

func compressed_raw(name: String) -> PackedByteArray:
	return Marshalls.base64_to_raw(COMPRESSED[name].base64)

func member_name(id: int) -> String: return "Sprite/%d-0.sp2" % id
func layer(id: int) -> Dictionary: return {"kind": "body", "source_sprite_id": id, "group_bit": 0, "frame_index": 0, "member": member_name(id)}

func manifest_for(directory: String, originals: Dictionary) -> Dictionary:
	var members: Dictionary = {}
	var pictures: Dictionary = {}
	for id: int in originals:
		var member: String = member_name(id)
		var path: String = directory.path_join("raw/" + member)
		write_bytes(path, originals[id])
		members[member] = {"member": member, "path": "raw/" + member, "sha256": FileAccess.get_sha256(path), "bytes": FileAccess.get_size(path)}
		var static_layer: Dictionary = layer(id)
		static_layer.file_sprite_id = id
		pictures["sprite:" + str(id)] = {"branch": "client_static_no_action_descriptor", "layers": [static_layer]}
	var manifest: Dictionary = {"schema": 1, "kind": "current523_reference_sp2_action_bank", "source_snapshot": "patch523",
		"static_picture_contract": {"branch": "client_static_no_action_descriptor", "frame": "direction0_picture0", "evidence": "synthetic byte-identity fixture"},
		"static_pictures": pictures, "members": members, "actors": {}}
	var path: String = directory.path_join("manifest.json")
	return {"path": path, "sha": write_json(path, manifest), "members": members}

func measurement_count() -> int: return int(HITCH._counters.get("sp2.parsed_payload_measured", 0))

func oracle_cases() -> void:
	for shape: Array in [[1, 4, 4, 4], [4, 200, 31, 0], [8, 200, 31, 0], [8, 255, 1, 0]]:
		var raw: PackedByteArray = BUILD.build(shape[0], shape[1], shape[2], shape[3])
		var parsed: Dictionary = DECODER.parse(raw)
		check(parsed.get("ok", false), "valid FE shape decodes: " + str(shape))
		if not parsed.get("ok", false): continue
		var before: Dictionary = fingerprint(parsed)
		check(PAYLOAD.bytes_of(parsed) == oracle(parsed), "format walk equals independent recursive packed-buffer oracle: " + str(shape))
		check(PAYLOAD.bytes_of(parsed) > raw.size() and packed_oracle(parsed) - oracle(parsed) == raw.size(), "FE raw/body alias counts once while decoded arrays count: " + str(shape))
		check(fingerprint(parsed) == before and parsed.raw == raw and parsed.body == raw, "accounting preserves FE source bytes, offsets and pixels")
	for name: String in COMPRESSED:
		var raw: PackedByteArray = compressed_raw(name)
		var fixture: Dictionary = COMPRESSED[name]
		var parsed: Dictionary = DECODER.parse(raw)
		check(parsed.get("ok", false), "real synthetic Brotli input decodes: " + name)
		if not parsed.get("ok", false): continue
		check(raw[0] != 254 and parsed.body.size() == fixture.body_bytes and digest(parsed.body) == fixture.body_sha and parsed.raw == raw, "Brotli fixture has its declared separate original and FE body: " + name)
		check(PAYLOAD.bytes_of(parsed) == oracle(parsed) and oracle(parsed) == packed_oracle(parsed), "compressed raw and body both count against independent oracle: " + name)
		var before: Dictionary = fingerprint(parsed)
		PAYLOAD.bytes_of(parsed)
		check(fingerprint(parsed) == before, "accounting preserves compressed source pixels: " + name)
	check(PAYLOAD.bytes_of({}) == 0, "empty optional parsed data has zero packed payload")

func idle_and_live_cases() -> void:
	ASSETS.reset_for_tests()
	var originals: Dictionary = {}
	var base: PackedByteArray = BUILD.build(8, 200, 31, 0)
	for index: int in range(9):
		var raw: PackedByteArray = base.duplicate()
		raw[raw.size() - 1] = index
		originals[9100 + index] = raw
	var data: Dictionary = manifest_for(scratch.path_join("idle"), originals)
	var bank: RefCounted = BANK.new()
	var external: Dictionary = {}
	var key: String = ""
	var each_cost: int = 0
	var count_before: int = measurement_count()
	for id: int in originals:
		var loaded: Dictionary = bank.load_static(data.path, data.sha, id)
		check(loaded.get("ok", false), "actual verified static-bank admission: " + str(id))
		var member: String = member_name(id)
		var parsed: Dictionary = bank._parsed.get(member, {})
		var cost: int = oracle(parsed)
		check(bank._parsed_costs.get(member) == cost and ASSETS.entry_bytes("parsed", bank.parsed_asset_key(member)) == cost, "bank sidecar and canonical shared entry use exact packed cost")
		each_cost = cost
		if id == 9108:
			external = parsed
			key = bank.parsed_asset_key(member)
	bank = null
	var idle: Dictionary = ASSETS.stats().parsed
	check(measurement_count() - count_before == 9, "each fresh shared publication measures packed payload once")
	check(idle.live_count == 0 and idle.leases == 0 and idle.idle_count == 7 and idle.idle_bytes == each_cost * 7 and idle.idle_bytes <= LIMIT and int(idle.counters.get("evicted", 0)) == 2, "nine actual idle banks evict two entries to respect the 32MiB packed-payload budget")
	var pixels: Dictionary = fingerprint(external, 7, 199)
	var held_texture: Texture2D = ImageTexture.create_from_image(DECODER.render(external, 7, 199).image)
	var held_pixels: PackedByteArray = held_texture.get_image().get_data()
	var before_warm: int = measurement_count()
	var warm: RefCounted = BANK.new()
	check(warm.load_static(data.path, data.sha, 9108).get("ok", false), "warm bank acquires the existing canonical shared parse")
	check(measurement_count() == before_warm and is_same(warm._parsed[member_name(9108)], external) and warm._parsed_costs[member_name(9108)] == each_cost, "warm shared hit reuses O(1) canonical cost without measuring again")
	ASSETS.trim_idle("parsed", 0)
	check(ASSETS.stats().parsed.live_count == 1 and ASSETS.stats().parsed.idle_count == 0 and ASSETS.entry_bytes("parsed", key) == each_cost, "idle eviction never discards an actively leased parse")
	check(fingerprint(external, 7, 199) == pixels and held_texture.get_image().get_data() == held_pixels, "live parse and externally owned texture pixels remain unchanged under eviction")
	warm = null
	ASSETS.trim_idle("parsed", 0)
	check(ASSETS.entry_bytes("parsed", key) == -1 and fingerprint(external, 7, 199) == pixels and held_texture.get_image().get_data() == held_pixels, "external references remain valid after their shared cache entry is evicted")

func local_budget_cases() -> void:
	ASSETS.reset_for_tests()
	var originals: Dictionary = {9200: compressed_raw("large_0"), 9201: compressed_raw("large_1"), 9202: compressed_raw("large_2"), 9203: compressed_raw("oversize")}
	var data: Dictionary = manifest_for(scratch.path_join("local"), originals)
	var bank: RefCounted = BANK.new()
	check(bank.load_static(data.path, data.sha, 9200).get("ok", false), "large compressed bank member is admitted")
	for id: int in [9200, 9201, 9202]:
		check(bank.render_layer(layer(id), false).get("ok", false), "large current member remains usable: " + str(id))
		var total: int = 0
		for value: int in bank._parsed_costs.values(): total += value
		var parsed: Dictionary = bank._parsed[member_name(id)]
		check(parsed.body.size() * 3 < LIMIT and oracle(parsed) * 2 > LIMIT, "fixture distinguishes old body-only admission from packed-payload admission")
		check(bank._parsed.size() == 1 and bank._parsed_costs.size() == 1 and total == oracle(parsed) and total <= LIMIT, "local byte budget drops older parses although the three-member cap alone would permit them")
	check(bank.render_layer(layer(9203), true).get("ok", false), "an oversized current member remains renderable")
	var current: Dictionary = bank._parsed[member_name(9203)]
	check(oracle(current) > LIMIT and bank._parsed.size() == 1 and bank._parsed_costs[member_name(9203)] == oracle(current), "oversized current record is kept alone with its full packed cost")
	var count_before: int = measurement_count()
	check(bank.render_layer(layer(9203), false).get("ok", false) and measurement_count() == count_before, "reusing the local oversized member performs no extra accounting walk")
	bank._release_parsed()
	check(bank._parsed.is_empty() and bank._parsed_costs.is_empty() and bank._parsed_keys.is_empty(), "release clears local values and every cost/key sidecar")

func legacy_cache_case() -> void:
	var raw: PackedByteArray = BUILD.build(1, 4, 4, 4)
	var reference: Dictionary = DECODER.parse(raw)
	var source_id: String = "sha256:" + digest(raw)
	var expected_key: String = ("|".join(PackedStringArray(["twilight.sp2-parse.v1", source_id, str(raw.size()), BAKE.code_key(["res://scripts/resources/current523_sp2_decoder.gd"]), BAKE.engine_key()]))).sha256_text()
	check(CACHE.FORMAT == "twilight.sp2-parse.v1" and CACHE.key_for(source_id, raw.size()) == expected_key, "existing cache format and decoder-only identity remain unchanged")
	var payload: PackedByteArray = Marshalls.base64_to_raw(LEGACY_METADATA)
	var path: String = CACHE.path_for(expected_key)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_pascal_string("TWSP2C1")
	file.store_pascal_string(expected_key)
	file.store_pascal_string(digest(payload))
	file.store_64(raw.size())
	file.store_64(payload.size())
	file.store_buffer(payload)
	file.close()
	var original_cache: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var hits: int = CACHE.hits
	var writes: int = CACHE.writes
	var loaded: Dictionary = CACHE.parse(raw, digest(raw))
	check(CACHE.hits == hits + 1 and CACHE.writes == writes and loaded == reference, "pre-accounting metadata cache round trip returns byte-equivalent parsed values")
	check(FileAccess.get_file_as_bytes(path) == original_cache and PAYLOAD.bytes_of(loaded) == oracle(reference) and fingerprint(loaded) == fingerprint(reference), "old cache bytes, packed cost and decoded pixels are preserved on a disk hit")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	scratch = "user://reference_sp2_parsed_payload_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	CACHE.reset_for_test(scratch.path_join("parse_cache"))
	HITCH.reset_for_test(scratch)
	oracle_cases()
	idle_and_live_cases()
	local_budget_cases()
	legacy_cache_case()
	print("REFERENCE_SP2_PARSED_PAYLOAD_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "synthetic_only": true, "accounting": "packed_buffers_only_not_container_overhead_or_rss", "scratch": scratch}))
	quit(0 if failures.is_empty() else 1)
