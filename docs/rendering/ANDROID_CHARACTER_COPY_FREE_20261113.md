# Android character destination-copy follow-up

Initial reproduction base: `28f3084a903d1cff4dbbd45c3a1ca5a0ed0a52a2` (main).
Publication base updated to `2cad66a6103008b087ae7d30a31c7c1e76a1eb7f`; its added minigame CI check is preserved.

The user reports a black character in the Android game screen after the earlier attachment work. PRs #432, #433 and #440 are already merged; this change addresses remaining dispatch and copy-free fallback gaps. It does not establish the precise cause of the user's current installed APK, whose revision and device GPU log are unavailable.

## Production changes and original evidence boundary

- The restored compositor's existing P02/P13 flag selection is reused without changing original textures, source offsets, scale, z order or source mappings. Those kernels are recovered from the M 1.10.22.0 static analysis and projected narrowly onto verified 523 metadata; they are not proof of full native523 rendering or dynamic-state equivalence.
- When destination copying is unavailable, verified average flag1 and parent-derived shadow129 use MIX alpha0.5. Parent-derived shadow9 uses the existing ADD host approximation. This prevents empty-own104 shadows falling through to opaque MIX and keeps flag1 bodies drawable. The parent's flags control shadows; the shadow file's own104 does not replace them. Unknown projections and strict mode are not promoted.
- The identity-scoped Girtas 22258/22260/22261 observed blend cannot bypass the Android no-copy policy. Its sibling copies also follow inherited effect visibility. This legacy observation is not generalized to all 523 actors.
- Lobby Spine meshes now share the UI copy-availability policy. Fixed-function fallback preserves the existing source texels, mesh geometry, PMA and two-color equation. Normal, additive and multiply use the documented host fixed blend; screen uses an ADD approximation. Shader caches distinguish PMA and copy policy, and stopped/setup poses refresh on policy changes.
- The existing compositor and projection unit suites explicitly scope the desktop kernel capability and restore the platform default. They no longer assume screen-copy is enabled on Android.

## Tests and interpretation

`source_preview_copy_free_test.gd` runs actual preview dispatch for body1/8/128, inline and independent parent shadows0/8/128, unresolved/strict/invalid projection boundaries, original texture/offset retention, and absence of active copies. With `--render`, twelve synthetic shadow cases are read back through a real OpenGL framebuffer.

`source_girtas_screen_copy_guard_test.gd` covers production configuration, no-copy policy, hidden/ancestor-hidden effects, copy restoration and cleanup. It does not check source image pixels.

`lobby_spine_android_blend_test.gd` configures and plays a valid production pose fixture for four blends with straight/PMA input. With `--render`, eight RGB readbacks compare the fixed host equations. Policy toggling must retain texture bytes, geometry and visibility.

The GPU workflow prepares the same production resource graph as the core gate and runs these preview and mesh pixel checks alongside the existing 152 compositor GPU cases. Synthetic texels are test input only; no game art is generated or replaced.

Linux OpenGL checks forced into the unavailable-copy policy are not Android GPU acceptance. RGB565 truncation, exact native screen/multiply behavior, original523 frame parity, the user's installed APK revision and Android device acceptance remain separate.

## Counterfactual

A separate stage restored only the three changed production files from main28f. The new Girtas guard suite failed 11 assertions (exit1) on that baseline. A production-dispatch metadata probe confirmed body flag1 hidden, inline shadows with parent0/8/128 at default opaque alpha1, and independent shadow using its own128 rather than parent8. These are structural reproductions with synthetic fixtures, not a capture of the user's Android GPU.

The candidate passes the three new headless suites: preview54, Girtas28 and lobby80 checks. GPU results and the full core gate are reported in the PR after their runs complete.

## Validation status

Results are recorded after execution; pending checks are not passes. No personal photo, original art or save file is included in this change. The historical `tools/check_resource_integrity.py` referenced by AGENTS.md is absent on this main; the current `tools/check_no_legacy_resources.py --root .` check is used and passes. No claim of full original resource delivery is made.
