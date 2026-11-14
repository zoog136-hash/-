extends RefCounted
## Build-wide switches that must not depend on the engine's debug template.
## The phone APK is a release export (2026-11-14: the debug template ran
## every GDScript check on device and used much more CPU/heat); its playtest
## tools stay on through the "twilight_playtest" export feature.
const PLAYTEST_FEATURE := "twilight_playtest"

static func playtest() -> bool:
	return OS.is_debug_build() or OS.has_feature(PLAYTEST_FEATURE)
