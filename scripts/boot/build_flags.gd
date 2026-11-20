extends RefCounted
## Build-wide switches that must not depend on the engine's debug template.
## The phone APK is a release export (2026-11-14: the debug template ran
## every GDScript check on device and used much more CPU/heat); its playtest
## tools stay on through the "twilight_playtest" export feature.
const PLAYTEST_FEATURE := "twilight_playtest"

static func playtest() -> bool:
	return OS.is_debug_build() or OS.has_feature(PLAYTEST_FEATURE)

## Developer/verification text and grant tools on player screens (catalog
## "검수용 지급 도구", source/evidence lines). Only debug runs (editor, CI)
## or an explicit "twilight_dev_ui" export show them; the phone APK with its
## playtest feature does not (user request 2026-11-20).
const DEV_UI_FEATURE := "twilight_dev_ui"

static func developer_ui() -> bool:
	return OS.is_debug_build() or OS.has_feature(DEV_UI_FEATURE)
