# Conditional base508 awakening VFX

The existing `card_option_awakening` accepted save state is the activation source.
An exact canonical native card must be equipped, permanently owned, and have
`cards[category]["source:m508:deck:card"].awakened == true`. Possession, grade,
legacy IDs and names never grant awakening. This read-only VFX adapter changes
no awakening costs, probabilities, stats, RNG or acquisition rules. Native
awakening acquisition remains unsupported by the legacy progression definition;
this change does not manufacture an awakening unlock.

Twelve exact BuffCardAwakenEffect -> StatusEffectAttr type48 -> SPR chains are
registered with raw rows and table hashes. Type48 is not treated as a generic
rendering enum. All twelve profiles now have private source idle and walk pixels, across all
eight directions (24 source tracks /1920 decoded original frames).
Source idle24Hz/12x4ticks and source walk36Hz/8x2ticks are retained. The verified15-file supplemental input closes the earlier source-pixel gap;
required_inputs is empty. Source input CRC/SHA and exact addresses are preserved.

Compatible presentation attaches the original source effect at the equipped
native visual anchor, with the existing common attr8 composition. Placement and
blend are unverified against M. Strict mode keeps it inactive. Recorded footage
did not establish whether awakening was active; it is not evidence for always-on
activation. Original annotations (including <24982) survive without guessed audio.
Settings can hide VFX without retiming, tinting, scaling or rewriting pixels.
Unequip, state removal and card switching clear/reconfigure the source effect;
repeated sync keeps its clock. Existing accepted save restore resyncs equipped
visuals. Legacy awakening visuals remain on their prior path.

`source_awakening_vfx_test.gd` checks explicit saved native awakening, ownership,
category/identity/canonical-grade guards, all twelve available profiles in eight
directions, source FPS, actual frame sampling, repeated sync, removal and strict
mode. It passed headless; world script parsing and real managed addon installation
also passed. Android execution and visual equivalence were not tested. The
repository resource check passed. Its optional source/release modes target the
older a1.zip/resource_delivery_receipt format, so they cannot validate this SP2
auxiliary pack; source ZIP CRC/SHA and the managed install per-file hashes were
validated separately, not reported as those legacy checks passing.

Private delivery: TWILIGHT_base508_effects_awakening_addon_v2.zip, 6,190,619 bytes,
SHA256 68031c4c5bbce57de94e9d22361bde86c967ff04bd18d4fadc09b28cd7a34d67.
Library libfile_34eb53595e888191b42559d60fad61d3 v0.
The pack contains all preceding v1 addon files plus awakening files. It accepts
only the exact original v2 or delivered v1 manifest fingerprints and preserves
the immutable active base and existing saves. Select it through the existing
original-pack installer and restart; the 1GB baseline need not be downloaded again.
No original pixels are committed to public Git.


## Complete source-input revision v3

The15 supplementary originals (Library libfile_b410e1c696608191801311dde5622d67,
SHA256 86c75166485914cce6fd200b4db1f8bacdb65064f966bcc64c1c9c03564719b2)
were consumer SHA/ZIP-CRC checked before decoding. All12 rules now have idle and
walk source tracks. Conditional activation/removal/strict/save-restoration tests
passed with all12 profiles/eight directions. Installing the new combined addon
over the existing v2 addon passed per-file hash checks and retained Girtas, UI
and event-effect loading. No source offsets/timing/pixels were retouched.

TWILIGHT_base508_effects_awakening_addon_v3.zip: 6,943,089 bytes,
SHA256 c500772ae81842df3e0021bda4f0ef38494ddba3fdffee6f4a71d6c89ce79015.
Its2068 files include every prior v1 addon file plus all source awakening assets.
Select this ZIP in the same offline installer and restart. Earlier packs remain
preserved. Android, native acquisition progression, original-client blend and
placement remain the same explicit limitations.

The v3 private Library delivery succeeded as
libfile_6d056fc06f2c81919a739f166fabb43a v0. The subsequent Drive upload was rejected
by automatic approval review for destination-sharing authorization; it was not
retried or bypassed. Do not report v3 as delivered to Drive. Earlier v2 remains
there unchanged.
