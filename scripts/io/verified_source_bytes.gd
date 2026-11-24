extends RefCounted
## For bounded source inputs only, never durable save/installer verification.
## Bind parsing to the exact bytes that were hashed; no path reopen or cache.
static func read(file: FileAccess, maximum: int) -> PackedByteArray:
	if file == null: return PackedByteArray()
	var length := file.get_length()
	if length <= 0 or length > maximum: return PackedByteArray()
	var bytes := file.get_buffer(length)
	if bytes.size() != length or file.get_length() != length: return PackedByteArray()
	return bytes

static func sha256(bytes: PackedByteArray) -> String:
	if bytes.is_empty(): return ""
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(bytes) != OK: return ""
	return hash.finish().hex_encode()
