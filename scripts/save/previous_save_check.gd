extends RefCounted
## Whether a save must re-read and parse the save file already on disk before
## replacing it. The shop migration (source523_shop_runtime.prepare_load) only
## acts on a file that has no shop state yet; a file whose SHA-256 is exactly
## the one this session last wrote with that state needs nothing. Any other file
## (first save, another session's or an external edit, a failed write) is read
## in full as before.

static func needs_reading(path: String, written_with_state_sha: String) -> bool:
	if written_with_state_sha.is_empty(): return true
	var on_disk: String = FileAccess.get_sha256(path)
	return on_disk.is_empty() or on_disk != written_with_state_sha
