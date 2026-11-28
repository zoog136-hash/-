extends RefCounted
## Earlier main UI addons omit this scene. The same installation contains
## the complete original UI. Read just the two scene records and five atlas
## records used by this result, then verify their original CSBs, pages and font.
const COMPLETE = preload("res://scripts/ui/original_ui/source_complete_ui_scope.gd")
const INDEX = "res://data/ui/current523_awakening_result_index.json"
const REVIEW_INDEX = "res://data/ui/current523_awakening_review_index.json"
const MEMBER = "UI/Change/Change_Upgrade_Skill_Awaken.csb"
const SOURCE_SHA = "a01d2719a91fb29a2d22fdf9e8680bf90f373ccd4db8962bbd566f639b5f28b8"
const REVIEW = "UI/CommonUi/Common_MessageBox.csb"
const REVIEW_SHA = "9ba302b365e5b5424033f0dcc358ee1cf2fd2d0fd34c442ea9621a8962c96c2a"

static func resolve(active: RefCounted, member: String = MEMBER) -> RefCounted:
	if member not in [MEMBER, REVIEW]: return null
	var expected: String = SOURCE_SHA if member == MEMBER else REVIEW_SHA
	if active != null and active.manifest.get("files", {}).get(member, {}).get("sha256") == expected and active.manifest.get("scenes", {}).has(member):
		return active
	return COMPLETE.open_selected(INDEX if member == MEMBER else REVIEW_INDEX)

static func read_installed(root: String, index_file: String = INDEX) -> RefCounted:
	if index_file not in [INDEX, REVIEW_INDEX]: return null
	return COMPLETE.read_installed(root, index_file)
