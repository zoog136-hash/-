# Separate source and host playback policy

The original base508 SPR/SP2 records, frames, ticks, offsets, palette pixels and104.attr values remain unchanged. The default installed runtime now uses explicitly UNVERIFIED compatibility settings; this is not a claim of Lineage M visual or timing equivalence.

`--lineagem-source-strict` selects strict source timing and disables unverified attachment compositing. `--lineagem-source-compatible` selects the host compatibility policy. A private pack may also contain `playback_settings.json` with `{"mode":"strict"}` or `{"mode":"compatible"}`. Runtime effective tracks are separate copies; raw actor records retain null FPS and original attributes.

Existing explicit110 sections are used first. Inherited actions already retain their exact base action rate. One override without its own rate has an explicit base-action36Hz candidate; using that candidate is labelled compatibility because the M client's inheritance behavior is unverified. No cross-declaration/file-global rate is asserted.

For player transformations only, an exact action-code join to base508 ListSprAction.PlayerFrameRate supplies a positive fallback. This is a source data value, while applying it to an unspecified SPR clock is an unverified compatibility decision. PlayerDelay is preserved as data and never used to rewrite native token times. Breath's zero PlayerFrameRate does not become a zero clock. Dolls, relics, effects and remaining unspecified player tracks use the publicly described PC3.81 default24Hz only in compatibility mode.

A zero-duration token is instantaneous. It is retained at its source position, emits its annotations at that time, and consumes no display time. Negative durations and tracks with no positive time remain invalid. Long deltas dispatch all crossed annotations, including zero-time tokens; this does not move the existing gameplay damage clock.

Compatibility attachments use the original decoded pixels in source declaration order after the body. attr8 uses Godot's standard additive operation, based on the PC description of a luminous filter. attr128 uses ordinary alpha mixing at0.5, a documented HOST approximation to the PC description of black-edge translucency. Its exact opacity, ordering and equation are not recovered M facts. No `sc`/`mu` filename interpretation is used to assert a formula. No glow texture, particle, outline, rig, generated frame or interpolation is created.

The raw `]SpriteID` relation can spawn an available original single-action overlay at the native token time in compatibility mode. `<` and sound annotations remain preserved without guessing their M meaning. `!` never applies gameplay damage. A spell adapter accepts only explicit source_m_snapshot=base508 and source_m_spell_id identities; cast uses CasterEffectSpriteID, impact uses EffectExplosionSpriteID, and critical uses CriticalEffectSpriteID. EffectSpriteID remains a separately explicit phase because SpellEffectType/action-number semantics are not inferred from an old skill name or ID.

## Evidence and limits

- M evidence: supplied base508 content/ListSprAction.json and original SPR declarations. No released M compositor/default-clock implementation was supplied or found.
- J.J. Huang's own PC3.81 test of110 and the24Hz default: https://morosedog.gitlab.io/private-lineage-20220524-private-lineage-119/
- The same author's PC3.81 filter examples, describing8 as luminous and128 as black-edge translucent, without an exact equation: https://morosedog.gitlab.io/private-lineage-20220520-private-lineage-115/
- Public parser documentation includes zero-duration tokens and sprite-overlay annotations: https://github.com/tony1223/PakViewer/blob/main/docs/LIST_SPR_FORMAT.md
- Generic compositor operations, not Lineage equivalence: https://docs.godotengine.org/en/stable/classes/class_canvasitemmaterial.html

Visual equivalence and Android execution remain deferred. Loading and policy-scope counts are not visual approval.

## Verified M table scope and counterexample

The supplied current `Class.json` MaleSpriteID/FemaleSpriteID references match explicit SPR Walk36Hz/16ticks, Attack24Hz/17ticks and Damage24Hz/11ticks to their `ListSprAction` player rows. Their Breath rows contain0/0 while actual SPR Breath remains explicit24Hz with varying32–60tick cycles. Preserve those SPR values and do not interpret table0/0 as a stopped animation.

This relationship is scoped to the current class references. Legacy sprite37 is a counterexample to a global override: its Attack occurs under SPR36Hz and totals19ticks while the player table says24Hz/17ticks. Giltas22258 instead matches24Hz/17ticks. There is still no M evidence that the player table supplies unspecified NPC/doll clocks or universally overrides a declared SPR rate. The current fallback remains labelled unverified compatibility; no priority or timing was tuned from these observations.

SP2 per-block reference types are not SPR104.attr values. For22258-related files, body types18/22/26, shadow8/12, sc21/25/29 and mu20/24/28 do not establish the attr8/128 compositor. Likewise, encoded GIF/video timestamps or average FPS are not the native SPR clock; compare source pose cycles and frame timestamps separately. No protected executable is run or unpacked to manufacture a missing rule.
