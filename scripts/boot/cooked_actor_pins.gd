extends RefCounted
## Pins of the cooked actor pack this build accepts (private Twm release
## `cooked-<pack id 8>-<FORMAT_TAG>`, made by .github/workflows/cook-actors.yml
## in zoog136-hash/Twm from the original pack named below).
##
## Integrity (docs/RESOURCE_INTEGRITY_POLICY.md, 2026-11-16 user approval
## "변환 시 1회 검증 + 변환물 SHA 고정"): the originals are verified once by the
## cook run (bank manifest pin + every SP2 member SHA-256 through the runtime
## bank); each cooked ZIP part is then pinned here by SHA-256 and checked once
## when it is installed. A part whose SHA-256 is not listed is rejected.
## Changing the cooked pack means changing these pins in a reviewed PR.
const COOKED_DIR := "cooked"
## Original pack the cooked pack was made from (source523_pack.json pack_id).
const SOURCE_PACK_ID := "b2162b06c49ce1c3eb8e56def65efb658d119d6724d296315fcdfc1d29263c0f"
## Identity of the cooked pack (every part's source523_part.json pack_id).
const COOKED_ID := ""
## SHA-256 of each cooked ZIP part -> [part, parts, file name].
const PARTS := {}
## Tests substitute their fixture's pins.
static var cooked_id: String = COOKED_ID
static var parts: Dictionary = PARTS
