extends SceneTree
## Opaque metadata only. No image fixtures or original source records.
const PACK = preload("res://scripts/resources/source523_image_pack.gd")
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func _initialize() -> void:
	# Python canonical JSON digests; Godot JSON numeric parsing uses floats.
	check(PACK._canonical_row_sha({"ID":17.0,"Enabled":true,"Name":"opaque / 값"}) == "95e72af77d2788df794b89a41734c50ec371b7830e32b15f8087105523bb81b1","canonical integer/bool/Unicode")
	check(PACK._canonical_row_sha({"ID":0.0,"Name":"opaque\nvalue"}) == "471827e7f55fe379a3ddbf394d951f96d15ecb6063197749cb2db92bd5c57f39","canonical escaped text")
	check(PACK._canonical_row_sha({"ID":0.5}).is_empty(),"fractional source key rejected")
	check(PACK._canonical_row_sha({"ID":9007199254740992.0}).is_empty(),"inexact JSON integer rejected")
	check(PACK._canonical_row_sha({"ID":[17]}).is_empty(),"unregistered nested schema rejected")
	for path: String in ["../opaque","/opaque","opaque//value","opaque/./value","opaque\\value","user://opaque"]:
		check(not PACK._safe_relative(path),"unsafe path " + path)
	check(PACK._safe_relative("opaque/value"),"literal path preserved")
	check(not PACK._integer(true),"bool is not integer identity")
	check(PACK.open("/tmp/opaque","invalid").status == "invalid_manifest_pin","manifest pin required")
	print("SOURCE523_IMAGE_PACK_CONTRACT ",JSON.stringify({"failures":failures,"image_fixtures":0}))
	quit(0 if failures.is_empty() else 1)
