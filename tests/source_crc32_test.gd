extends SceneTree
## Expected values were computed independently with Python zlib.crc32.
## Deterministic binary input covers high bytes, every 8-byte tail and large members.
const CRC = preload("res://scripts/resources/source_crc32.gd")
const EXPECTED = [
	[0, "00000000"],
	[1, "74beb8ea"],
	[2, "3b15f400"],
	[3, "6a845f76"],
	[4, "dcb3e3e0"],
	[5, "e86b0da0"],
	[6, "91836dea"],
	[7, "16f22658"],
	[8, "3c1a7c87"],
	[9, "7f597db7"],
	[10, "a6cc646a"],
	[11, "bf79c702"],
	[12, "3868d173"],
	[13, "f98eddce"],
	[14, "b3909e83"],
	[15, "5ab925f5"],
	[16, "518bd36f"],
	[17, "59eddcb4"],
	[18, "47e448d3"],
	[19, "be439e28"],
	[20, "9bd5eb5e"],
	[21, "34fa6667"],
	[22, "645038d6"],
	[23, "84d57b96"],
	[24, "1051c551"],
	[25, "e0cad2ab"],
	[26, "79331806"],
	[27, "30c3a681"],
	[28, "bc592acc"],
	[29, "52dbd16c"],
	[30, "365efb57"],
	[31, "8b878c61"],
	[32, "563729df"],
	[33, "59ea604e"],
	[34, "d1ede7e1"],
	[35, "860d5543"],
	[36, "b1828e01"],
	[37, "72b98f7b"],
	[38, "2012564c"],
	[39, "6444d0e6"],
	[40, "b0bbb682"],
	[41, "34d1083a"],
	[42, "0ee0334a"],
	[43, "bfd1eb55"],
	[44, "80d5dc50"],
	[45, "fb5bf3c9"],
	[46, "6044bf56"],
	[47, "0cd935f7"],
	[48, "84bdf29b"],
	[49, "d886fc58"],
	[50, "d5b7ad68"],
	[51, "afd0c691"],
	[52, "89739156"],
	[53, "77812977"],
	[54, "d9aeb185"],
	[55, "4d64a599"],
	[56, "bb4949d6"],
	[57, "a8d3fc6c"],
	[58, "31c93763"],
	[59, "ad592b01"],
	[60, "1cce5239"],
	[61, "3fa6a2ff"],
	[62, "645b6412"],
	[63, "b60d1c29"],
	[64, "15634a25"],
	[65, "49734e77"],
	[255, "324ab87e"],
	[256, "96348846"],
	[257, "9c905851"],
	[4095, "11d24275"],
	[4096, "917ad4a5"],
	[4097, "cf24853d"],
	[833000, "4c182cb4"],
	[2097152, "b618bda5"],
]
var failures: Array = []
func _initialize() -> void:
	var checks: int = 0
	for row: Array in EXPECTED:
		var bytes := PackedByteArray()
		bytes.resize(int(row[0]))
		for index: int in range(bytes.size()): bytes[index] = ((index * 73) ^ (index >> 8) ^ 0xa5) & 255
		checks += 1
		if CRC.hex_digest(bytes) != row[1]: failures.append(row[0])
		checks += 1
		if CRC.hex_digest(bytes) != row[1]: failures.append(["repeat", row[0]])
	checks += 1
	if CRC.hex_digest("123456789".to_ascii_buffer()) != "cbf43926": failures.append("standard vector")
	print("SOURCE_CRC32_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
