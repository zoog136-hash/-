extends RefCounted
const VERIFIED = preload("res://scripts/io/verified_source_bytes.gd")
## Verify the same bounded bytes that the caller will decode; no retained cache.
static func read(file: FileAccess, length: int, expected_sha: String) -> PackedByteArray:
	if file == null or length <= 0 or expected_sha.length() != 64: return PackedByteArray()
	var bytes: PackedByteArray = VERIFIED.read(file, length)
	return bytes if bytes.size() == length and VERIFIED.sha256(bytes) == expected_sha else PackedByteArray()

## Drop the raw buffer before invoking a potentially big parser. A verified
## but invalid JSON document is distinct from failure to verify its bytes.
static func read_json(file: FileAccess, length: int, expected_sha: String) -> Dictionary:
	var bytes: PackedByteArray = read(file, length, expected_sha)
	if bytes.is_empty(): return {"verified":false,"value":null}
	var source: String = bytes.get_string_from_utf8()
	bytes.clear()
	return {"verified":true,"value":JSON.parse_string(source)}
