extends RefCounted
## Explicit private UI pack selection, separate from image/map/card packs.
## This reads configuration only; it installs nothing and changes no save.
const Pack=preload("res://scripts/ui/original_ui/source_pack.gd")

static func selected_pack(loading_fx_only: bool = false, include_roster: bool = false, loading_fx_scope: RefCounted = null) -> Dictionary:
	var root: String=OS.get_environment("TWILIGHT_SOURCE_UI")
	var sha: String=OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-ui="):root=argument.trim_prefix("--source-ui=")
		elif argument.begins_with("--source-ui-sha256="):sha=argument.trim_prefix("--source-ui-sha256=")
	if root.is_empty() and sha.is_empty():return {"ok":true,"selected":false}
	if root.is_empty() or sha.length()!=64:return {"ok":false,"selected":true,"code":"source_ui_selection_pair_required"}
	if loading_fx_only and not include_roster and loading_fx_scope != null and loading_fx_scope.can_reuse_loading_fx(root, sha):
		return {"ok":true, "selected":true, "pack":loading_fx_scope, "reused_loading_scope":true}
	var pack=Pack.new()
	var opened: Dictionary=pack.open_loading_fx(root,sha,include_roster) if loading_fx_only else pack.open(root,sha)
	if not opened.get("ok",false):
		opened["selected"]=true
		return opened
	if loading_fx_only:
		return {"ok": true, "selected": true, "pack": pack}
	# One selection is the whole composed main UI domain. A newer combined
	# pack contains the retained main/map inputs and its inventory/quickslot
	# scopes together; this is not a competing per-window selector.
	return {"ok":true,"selected":true,"pack":pack,"selection_mode":"single_combined_original_ui_pack","selection_contract":pack.manifest.get("selection_contract",{}).duplicate(true)}
