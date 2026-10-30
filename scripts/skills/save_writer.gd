extends RefCounted

## Replacing a validated temporary file prevents a truncated skill migration
## from destroying the last save. The pre-migration copy is retained separately.
static func write(path: String, data: Dictionary) -> Error:
	# Source coordinates and Unix boss deadlines must survive JSON unchanged.
	return write_text(path, JSON.stringify(data, "", true, true))

## Same atomic temp-file replace for a payload the caller already serialised
## with the exact arguments above, so a large save is not stringified twice.
static func write_text(path: String, text: String) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK: return result
	return DirAccess.rename_absolute(temporary, path)
