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
## Original pack the cooked pack was made from (informational: cooked actors
## are matched by content, the bank manifest SHA-256 below, so the same bank in
## pack-b2162b06 (28 parts) or its repack pack-63fb1355 (8 parts) both work).
const SOURCE_PACK_ID := "63fb13551f0335bcc83efcde79170ec0deebc850a3138fa3b90493af879a357c"
const SOURCE_BANK_MANIFEST_SHA256 := "587b419b38fd9e66639b315788011c986439a005b2525942162ff71febc81eeb"
## Release cooked-63fb1355-v2 (zoog136-hash/Twm, private), cook run 43850875214
## from game code cad411297: 3,373 bundles / 8,883 entries, 3.11 GB.
## Identity of the cooked pack (every part's source523_part.json pack_id).
const COOKED_ID := "f35bb51523a1a8d439d649916a5351cf3d4ad56badaefd5ed50f9b2823590c0d"
## SHA-256 of each cooked ZIP part -> [part, parts, file name].
const PARTS := {
	"c073475d4cf422217e9e8876d8dece12d829fb8bef5504cfee3ee3f8f12d4118": [1, 2, "twilight523-cooked-1of2.zip"],
	"c390aa3729bed61639ecc316668b98fd391d9adb18b8b98942e85855ae224b25": [2, 2, "twilight523-cooked-2of2.zip"],
}
## Tests substitute their fixture's pins.
static var cooked_id: String = COOKED_ID
static var parts: Dictionary = PARTS
