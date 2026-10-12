extends RefCounted

## Replacing a validated temporary file prevents a truncated skill migration
## from destroying the last save. The pre-migration copy is retained separately.
static func write(path: String, data: Dictionary) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK: return result
	return DirAccess.rename_absolute(temporary, path)
