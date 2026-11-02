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
rendering enum. Five idle profiles currently have private source pixels: 22149,
24747,24713,24748,26711. The four relic profiles also have source walk frames.
Source idle24Hz/12x4ticks and source walk36Hz/8x2ticks are retained. Missing walk
22149 is suppressed during movement rather than replaced with another action.
The other seven profiles require 14 indexed SP2 files; their activation stays
pending. The private pack includes exact source-file requirements and CRCs.

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
category/identity/canonical-grade guards, all five available profiles in eight
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
