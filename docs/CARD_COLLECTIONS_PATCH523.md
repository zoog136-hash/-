# Current523 cards and collection runtime

Production uses402 transformations,171 dolls and147 relics, with1793 collection sets/5059 member rows/2052 rewards. Existing701 m508 identities and collection IDs remain stable. Latest19 use m523 identities and remain outside unverified draw/fusion pools. Same-card sets retain separate rewards, application targets remain distinct, and32 cross-deck member rows use the member's own deck. Class/gender variant rows are metadata, not extra acquisitions.

Permanent ownership remains the sole acquisition ledger. Collections register automatically without consuming cards or granting duplicate items/currency. User-requested permanent time policy remains. Original dates, costs, probabilities, source rows and card identities are preserved. Source server/option-awakening conditions still apply. The card/collection menus expose filtering, status, ownership/copies and reset, including responsive1280×720 and854×480 layouts.

## Source-first application and local policies

All2052 reward rows now have an explicit consumer or local compatibility policy:2050 direct/scoped rows plus the two HP-interval references. This is execution coverage, not proof that all original combat formulas are recovered. During this continuation432 previously unsupported projections received consumers; original Bonus/Unit/application rows and5059 requirements were unchanged. Some sets remain unavailable because their actual source server or awakening conditions are unmet.

201 source PvP reward rows follow current main's established single-player PvP-to-PvE rule. Raw PvP identities remain unchanged while projected labels/consumers use PvE. Flat pierce uses the existing catalog damage channels; percent pierce uses the existing local successful-hit amplification boundary. Physical avoidance pierce feeds the existing skill/normal-attack hit formula, with no second AC/MR reduction. Typed/elemental critical resistance feeds the actual incoming critical roll. Native healing and blessing percentages use their declared denominators. Absolute MP recovery uses the existing30-second local recovery clock. Source Stun/Fear conditional reduction reads live player state.

Exact SpellClass reward targets remain separate. Explicit source spell identity takes priority. The existing local base/ancient Disintegrate identities map independently to their original targets, and Triple Arrow selects one base/spirit reward profile at a time. This neither merges distinct target bonuses nor grants a missing enhancement skill. The source skill's damage/hit bonus is consumed only by the matching target. A configurable fallback can associate an otherwise unidentified local bleed status with the source bleed effect.

The HP references172/291 are never added as flat HP. Stun resistance is1/2/3 points and Fear resistance3/4/5 at61–70/51–60/0–50 source bounds. The explicit local rule defaults to rounding living HP percentage upward (the settings dialog can select floor instead) and includes both bounds; dead players and the unlisted71–100 range receive zero. Effects query live HP without rebuilding ownership or caching conditional values in equipment records. The open UI updates current/max effects and retains raw interval rows in tooltips.

The following incomplete original semantics use clearly marked, adjustable local rules. Original values/units remain immutable:

| Area | Default local interpretation |
|---|---|
| Final blow | Source probability; ordinary successful attacks only;1.5× base, then source flat/percent. Skills/procs do not recursively roll it. |
| Weapon block | Source chance on physical incoming hits;100% damage reduction on success. Magic and status ticks excluded. |
| Life / Death |1 flat magical healing /1 flat successful-hit damage per source point. No new PvP death penalty is introduced. |
| Magic penetration | Source percentage removes that fraction of outgoing target MR before the existing hit formula. |
| Physical-magic defense | Source percentage reduces physical-element magic damage, separate from ordinary physical hits. |
| Reduction efficiency | Source points offset an opponent's percent-ignore budget before mitigation; never subtract the same budget twice. |
| Ranged-burst tag | Explicit tag context wins. Otherwise the configurable fallback uses known local Triple Arrow profiles or ranged attacks with at least2 hits. |
| DamageDampOption13 | Its missing original target definition stays unresolved; an explicit local policy applies its percent after other reductions. Other unknown targets are not covered. |
| Incoming final blow | Explicit opponent context wins. Undeclared opponent probability defaults to0, preserving ordinary NPC behavior. Source resistance reduces the chance. |

“적용 규칙 · 추정 설정” opens the actual editable settings dialog. Users can disable estimated behavior or change its coefficients/profile. The source condition profile is selected from exact original region/world rows as an offline evaluation context, never inferred from an account/map/language. Defaults do not silently select a server. Changes save separately as card_collection_policy, preserve ownership/items/currency and roll back policy/context/HP/MP on save failure. A context change clamps current HP/MP only when their new caps are lower; it does not refill them. Unknown future/malformed saved policies remain preserved and do not enable estimates. Reopening/reloading restores the saved selection.

## Research evidence and boundaries

The validated current523 tables are the numeric authority. Previously obtained original collection/CSB analysis and two recovered historical references were read separately; historical base508/November2 evidence is not current523 pixel or formula proof. Normal authenticated transfer, exact byte/hash/CRC and actual reading closed the two reference-transfer blockers. Private storage identifiers, transfer links and detailed handoff inventories are kept outside Git.

Official primary sources confirm option names and distinctions, not the missing complete formulas:

- [Transformation collections](https://lineagem.plaync.com/guidebook/view?title=%EB%B3%80%EC%8B%A0+%EC%BB%AC%EB%A0%89%EC%85%98): healing/block and source target-specific reward descriptions.
- [Doll collections](https://lineagem.plaync.com/guidebook/view?title=%EB%A7%88%EB%B2%95%EC%9D%B8%ED%98%95+%EC%BB%AC%EB%A0%89%EC%85%98): HP interval resistance, final-blow and efficiency labels.
- [2023-03-22 update](https://lineagem.plaync.com/board/update/view?articleId=641a05b8c19a0110e2d3edf4&page=1&size=20&viewMode=list): the former Triple Arrow hit-reduction effect became ranged rapid-fire reduction. Full current spell-tag membership is still absent from the input.
- [2026-03-18 update](https://lineagem.plaync.com/board/update/view?articleId=69b9abb8232a171f20adadb8): introduction of the damage-reduction-efficiency option, without a complete executable formula.

No client-engine/APK/XAPK acquisition or analysis is needed for this implementation. Work uses the already acquired definitions/resources and TWILIGHT's own runtime. Missing original formulas are not mislabeled as recovered source behavior.

## Pixels, animation and Android

The preserved private card base pack was received and independently byte/hash/CRC checked, then installed through the real game installer. Existing701 card icons decode; latest19 portraits/actors are absent. The private pack remains external and was not duplicated in Git or re-uploaded. Twenty local captures from the preceding private-pack validation include explicit missing-frame states; they are not a new delivered artwork pack.

The551-CSB evidence preserves original trees/timelines, but required atlas pages/sub-scenes and a verified client timing contract remain absent. Original card-border/jewel/level-up reconstruction is incomplete. Existing original actor-track playback is separate evidence. No pixels, source archives or screenshots are added to public Git.

Android remains a separate blocker: the earlier export attempt lacked4.7.2 Android templates and SDK tools. No APK/device result is claimed. The unchanged broad animation-export audit also has an archived-data reference failure. Linux touch/render validation is not Android execution.

The root resource audit verifies723 sheets/41442 frames/233420026 bytes. Historical source-dir/release-dir options do not pass because their old original-archive/receipt format is absent; actual native-pack verification is reported separately.

## Reproduction and integration boundary

Use the existing validated source inputs with tools/build_patch523_cards.py and tools/build_patch523_card_ui.py; do not replace current definitions with historical references. Tests: patch523_card_collections_test.gd, patch523_hp_interval_test.gd, patch523_effect_runtime_test.gd and patch523_card_collection_ui_test.gd. Use Godot4.7.2, an isolated XDG data directory and a verified current map pack through TWILIGHT_SOURCE_MAP_PACK. Private-art UI validation additionally uses an already installed isolated native pack and TWILIGHT_CARD523_REQUIRE_PIXELS=1. Optional TWILIGHT_CARD523_CAPTURE saves local evidence only.

PR231 comparison is read-only. Preserve PR249's720-card catalog and PR231's16 stable-ID supplements in a future integration; do not create736 cards or mix the branches' validation claims. Current overlapping catalog-loading/detail logic needs a later explicit resolution. The current record overlay is shallow; it does not guarantee merging nested child fields. Future integration must preserve missing-art guards, PR231 availability/slot behavior and test HP/MP cap changes against HP-interval effects after the same successful save. No other PR/main is merged here.


Latest continuation validation: current523 definitions12647 checks; native508 regression1574; actual combat/stat/recovery/charge and scoped source-target paths2682; HP interval boundaries/live consumers126; local policy state preservation8; real Linux UI117 at1280×720 and854×480 with701 original icons decoded. The UI checks include physical settings-save input, saved-profile reload, exact card ID/copy preservation and rejected-save rollback. A separate input probe verifies touch toggling inside the embedded settings window. Actual Main/current-map/save gate32 and identical-payload/deferred-save guards pass. These are focused local checks; no full/manual CI or Android/device result is claimed. Private reference receipts, exact missing19-card asset declarations and pack/storage/consumer inventory are local audit records outside Git; no new audit/capture upload occurred.
