extends RefCounted
## The stock Android export provides both bridges. This file also parses on PC.
## Publish an app-owned Downloads entry via Android 10+ scoped storage.

static func publish(filename: String, payload: String) -> bool:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
		return false
	var java: Object = Engine.get_singleton("JavaClassWrapper")
	var version: Variant = java.wrap("android.os.Build$VERSION")
	if version == null or int(version.SDK_INT) < 29: return false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var context: Variant = runtime.getApplicationContext()
	if context == null: return false
	var resolver: Variant = context.getContentResolver()
	var downloads: Variant = java.wrap("android.provider.MediaStore$Downloads")
	var values_type: Variant = java.wrap("android.content.ContentValues")
	var stream_type: Variant = java.wrap("java.io.PrintStream")
	if resolver == null or downloads == null or values_type == null or stream_type == null: return false
	var collection: Variant = downloads.getContentUri("external_primary")
	if collection == null: return false
	return _write_download(resolver, collection, values_type, stream_type, filename, payload)

static func _write_download(resolver: Variant, collection: Variant, values_type: Variant, stream_type: Variant, filename: String, payload: String) -> bool:
	var values: Variant = values_type.ContentValues()
	var visible: Variant = values_type.ContentValues()
	if values == null or visible == null: return false
	values.put("_display_name", filename)
	values.put("mime_type", "application/json")
	values.put("relative_path", "Download/TWILIGHT")
	# ContentValues.getAsInteger accepts decimal strings. This uses the JNI
	# String overload consistently instead of relying on overloaded boxing.
	values.put("is_pending", "1")
	visible.put("is_pending", "0")
	# Retry after a process loss between MediaStore commit and private-file
	# removal without making a second completed row for the same session.
	var cursor: Variant = resolver.query(collection, PackedStringArray(["_id"]),
		"_display_name=? AND relative_path=? AND is_pending=0", PackedStringArray([filename, "Download/TWILIGHT/"]), "")
	if cursor != null:
		var exists: bool = bool(cursor.moveToFirst())
		cursor.close()
		if exists: return true
	var uri: Variant = resolver.insert(collection, values)
	if uri == null: return false
	var stream: Variant = resolver.openOutputStream(uri, "w")
	var wrote: bool = false
	if stream != null:
		# The String overload avoids any JNI byte-array signedness dependency.
		var writer: Variant = stream_type.PrintStream(stream, false, "UTF-8")
		if writer != null:
			writer.print(payload)
			writer.close()
			wrote = not bool(writer.checkError())
		else:
			stream.close()
	if wrote:
		var updated: Variant = resolver.update(uri, visible, "", PackedStringArray())
		if updated is int and updated == 1: return true
	resolver.delete(uri, "", PackedStringArray())
	return false
