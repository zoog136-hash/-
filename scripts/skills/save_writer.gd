extends RefCounted

## Replacing a validated temporary file prevents a truncated skill migration
## from destroying the last save. The pre-migration copy is retained separately.
static func write(path: String, data: Dictionary) -> Error:
	# Source coordinates and Unix boss deadlines must survive JSON unchanged.
	return write_text(path, JSON.stringify(data, "", true, true))

## Same atomic temp-file replace for a payload the caller already serialised
## with the exact arguments above, so a large save is not stringified twice.
static func write_text(path: String, text: String) -> Error:
	return _write_text(path,text,null)

## Background snapshots may spend time staging while an external file changes.
## Check their original disk identity after flushing the temp, before replacing.
static func write_text_if_unchanged(path: String, text: String, expected_hash: String) -> Error:
	return _write_text(path,text,expected_hash)

static func _write_text(path: String, text: String, expected_hash: Variant) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK: return result
	if expected_hash != null:
		var current_hash: String=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		if current_hash != expected_hash or (current_hash.is_empty() and FileAccess.file_exists(path)):
			DirAccess.remove_absolute(temporary)
			return ERR_BUSY
	return DirAccess.rename_absolute(temporary, path)
