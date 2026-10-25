extends RefCounted

static func contains_user_directory(actual: String, declared: String, windows_path: bool) -> bool:
	if actual.is_empty() or declared.is_empty(): return false
	if windows_path:
		actual = actual.replace("\\", "/").to_lower()
		declared = declared.replace("\\", "/").to_lower()
	actual = actual.simplify_path()
	declared = declared.simplify_path().trim_suffix("/")
	# Keep the directory boundary: /tmp/case-other is not /tmp/case.
	return declared.is_absolute_path() and actual.is_absolute_path() and actual.begins_with(declared + "/")
