extends SceneTree
## godot --headless --path . --script tools/exchange/compile_reference_units.gd
## Record the resulting digest in trade523_market.gd after updating the capture.

const FROZEN := preload("res://scripts/exchange/frozen_catalog.gd")
const MARKET := preload("res://scripts/exchange/trade523_market.gd")

func _initialize() -> void:
	var capture := FROZEN.new()
	if not capture.load_snapshot() or not capture.captured():
		printerr("Cannot compile an unverified exchange capture. ",capture.problem)
		quit(1)
		return
	var snapshot := FileAccess.open(FROZEN.PATH,FileAccess.READ)
	var units := MARKET.normalized_capture_units(capture.rows())
	var encoded: Dictionary={}
	var bytes := PackedByteArray()
	bytes.resize(8)
	# The JSON number parser can round a median by a few ULPs. Encode the
	# exact 64-bit result so an offer never rounds differently after compiling.
	for id: int in units:
		bytes.encode_double(0,units[id])
		encoded[str(id)]=bytes.hex_encode()
	var content: String=JSON.stringify({
		"schema":1,
		"snapshot_bytes":snapshot.get_length(),
		"snapshot_sha256":capture.sha256,
		"units":encoded,
	},"\t",true,true)+"\n"
	var output := FileAccess.open(MARKET.REFERENCE_UNITS_PATH,FileAccess.WRITE)
	if output==null or not output.store_string(content):
		printerr("Cannot write the compiled exchange medians.")
		quit(1)
		return
	print(units.size()," item medians. SHA-256 ",content.sha256_text())
	quit()
