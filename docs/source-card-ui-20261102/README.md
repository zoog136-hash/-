# Source card UI and collections, 2026-11-02

Base: main `0cab9b3d39e9330feb1c404d8c36b80d3e417b2d`.
Private-source runtime used for isolated UI validation: PR217
`e5b3c1f48d45397e7b4cc55a8a2c59338ac6082c`; no branch merge performed.

The native card catalog activates the source collection definitions automatically.
The former 139 definitions remain for a legacy-only catalog. Existing ownership
and spare-card save keys are never renamed, inferred from a name/integer, granted,
or consumed. PR217 preserves unmapped old keys in its own existing ledger.

Native definitions: transformation 814 sets / 2525 conditions / 930 rewards;
doll 484 / 1378 / 556; relic 438 / 1003 / 496. All 1736 definitions and 4906
requirements join exact canonical deck/card IDs. Test deck 12 stays separate;
the 12 cards with no source collection receive no invented set.

909 definitions now have supported unconditional rewards (892 at the first handoff).
827 are blocked
by at least one source server, native awakening, or unsupported effect condition.
The overlapping reasons cover 498 server-limited, 211 awakening, 443 unimplemented-effect, 2 HP-interval-runtime, and 1
unresolved-source-target sets. These reason counts overlap. Completion and bonuses are derived from permanent owned
keys, not spare counts, equipped names, UI selections, or option awakening.

The requested time policy is `permanent_user_requested_time_override`: every
source set remains visible as 상시. Original dates remain in the data; server and
awakening restrictions are retained. This snapshot has no nonzero time reference
on the 4906 member cards, so this policy changes no set count or bonus value.

Raw Bonus, Unit/UIUnit denominator, application target, interval child records,
original collection/member/grade/deck rows and provenance hashes are retained.
Percentage UI values divide by the source denominator (10000); Weight divides
by 100; ValuePercent divides by 1. Positive source ArmorClass defensive power
maps to the existing signed local AC channel. PvP is never mapped into PvE.
Unknown effects, the two HP-interval categories and DamageDampOption target 13
remain displayed and blocked; no conditional raw value is added as a flat stat.

Native card art uses the existing shared source catalog and installation resolver.
DisplayScreenAssetID is not used as a portrait: rendered source examples show
additive-only images. Declared illustration or DisplayBase artwork is used.
Missing artwork is explicit. Generated card metal/aura is suppressed on native
records; no original grade frame has been claimed installed. Quantities include
the retained first card; unowned art is dimmed/grayscale. Tabs/actions have at
least 44 logical-pixel targets. Original synthesis/awakening callbacks remain.

Validation: source images 1267 SHA matches; native collection test 1356 checks; 17 actual World stat-consumer checks;
Godot 4.6.3 import and isolated OpenGL/Mesa UI capture/input checks (44 checks,
1280x720 and 854x480). Three catalogs, details and collection views were rendered.
The fixture uses isolated XDG data and in-memory ownership only. HUD processing
is enabled only in the harness because the separate private map pack is absent;
production map guards are unchanged. Full gameplay and Android input are pending.
The render harness has two existing CanvasItem RIDs/one resource reported at exit.
The broader headless legacy test fails 11/62 input checks with that map guard;
this is not reported as a full-project or Godot 4.7.2 CI pass.

Remaining art extraction starts at Client/Data/UI1.dat:
UI/ChangeDollScene.csb, UI/Change/Change_Card_A_Doll.csb,
UI/Change/Change_MagicDoll_Info_Swap.csb,
UI/Change/Change_Card_Swap_Button.csb. Read their exact texture references before
installing original frame/tab/background/button resources. No original pixels or
large render evidence are committed. No public push, PR, main change or merge.

Follow-up capability expansion: source MeleeEvasion -> existing DG, MagicCritical
-> magic_crit, scoped Fear hit/resistance -> their existing fear readers, and
PvE percentage reduction -> its existing PvE-only channel. 43 source reward rows
are newly representable; 17 previously blocked sets become supported without
removing server or awakening requirements. Equipment collection policy and World
combat implementation are unchanged. Unknown source target is collection 12573 /
DamageDampOption 13; HP interval collections are 14813 and 16521.

PvE reduction percentage uses the existing `catalog_bonus` route, not the
equipped-record stat route. A temporary cache-only test fixture verifies damage
calculation and restoration without bypassing source server eligibility or
changing ownership. The actual derived source ownership still honors all gates.

On a pre-PR217 branch, the pure collection test explicitly labels its
requirement-derived schema fixture; only a supplied canonical cards.json run
validates the independent 701-card join. The World-consumer integration test
prints SKIPPED when the native runtime is absent instead of breaking a UI-only
branch. The recorded 1356/17 checks used the actual canonical/native runtime.

A follow-up server predicate evaluator now compares the exact original
ServerLimit rows to an explicitly supplied base508 ServiceRegionCode/WorldNo.
The runtime setter is memory-only, invalidates derived bonuses, and clears old
eligibility on invalid input. No current native server provider exists in World;
nothing is guessed from a map, language, Drive identity, or old save. Default
support remains 909 definitions. Eligible/ineligible/missing context/missing
source definition are distinct states. Native IsAwaken remains separate.
Canonical core checks: 1574; World consumer/context checks: 22. Context fixtures
exercise real source profile rows but are not the user's current game profile.

Original CSB geometry now has a bounded reproducible adapter:
`tools/build_base508_card_ui.py` consumes the three supplied inspection JSONs and
retains 11 explicit card-related CSBs / 414 nodes, exact resource references,
ancestor anchors/scales and source hashes in `data/ui/base508_card_layout.json`.
No original raster pixels or binary CSBs are committed. Shared native list metrics
read the declared 124×142 slot and 110×134 portrait directly, preserving portrait
aspect ratio across all three categories and retaining scroll state on reflow.
This is geometry integration, not a claim that original screen skins are complete.
Original runtime toggles, animation/blend, scale-nine behavior and full screen
placement still need their specific adapters and available texture dependencies.

Bundles 001–005 are received and CRC/SHA checked locally. Bundle004 is a recovery
card atlas, not the missing main card atlas. First card skin dependencies remain
Atlas_Common (56 explicitly referenced frames), Atlas_Common2 (5), Atlas_Texture
(3), Atlas_Icon (1), Atlas_Hud (1), Atlas_Shop (1), plus two optional FX atlas
references. Bundle005 includes the original white border FX atlas; the common
frame/background/tab atlases remain absent. Native source options also retain
original PvP labels instead of inheriting the legacy PvE text conversion. Exact frame names are in the local handoff dependency JSON. No
substitute frame is generated or presented as original.

Commit `9d8a782` adds exact source server predicate evaluation with an explicitly
provided base508 service region and WorldNo; it never invents a server context.
Source-condition regression: 1574 checks passed; actual World consumer regression:
22 checks passed. No live World server-context provider or native IsAwaken ledger
has been found, so the default supported/blocked definition counts remain 909/827.

Latest rendered UI regression: 50 checks passed, including original portrait
metrics in each category, at 1280×720 and 854×480. A first-open scroll bug after
switching from another category was reproduced visually and fixed by restoring
the view's saved scroll (zero for a fresh view) after container reflow. The final
doll screenshot shows the first owned row fully visible. Existing baseline exit
warnings remain (2 CanvasItem RIDs / 1 resource); full Android / Godot4.7.2
validation remains with the parent integration worker.

Next independent unit: inventory and tooltip inspection. All 9 explicitly
requested inventory CSBs are received. `Common_Slot.csb` declares a 76×76
background, 64×64 icon and amount bounds [7,50,62,20] in background coordinates;
`Inventory_Slot_Set.csb` places adjacent normal slots 76px apart. The renewal
inventory uses those dimensions while retaining its existing four/eight-column
virtual window and a larger 76px touch area. Native source detail options retain
original PvP/damage/curse labels; legacy filtering is unchanged.

Pooled inventory buttons now bind their tooltips to the exact physical reference
and enhancement, preventing stale or empty tooltips after reuse. The virtual
window regression covers 101 references and tooltip rebinding between same-name
+2 and +3 physical items. Actual starting inventory render checks pass 20/20 at
1280×720 and 854×480, including detail selection, reopen, no redundant rebuild,
and unchanged inventory/equipment/currency. No items were granted or consumed.
Original inventory skin/full tooltip layout is still pending Atlas_Common and
its declared image page. Existing missing item icon substitutes remain explicitly
marked; they are not newly generated or represented as original art.

Original card skin increment (bundles006/007/008): exact Common/Icon/Hud and
Texture/Shop/Common2 plists plus their declared PNG pages are installed privately.
`build_base508_ui_atlas.py` joins CSB resource keys to plist frames and the
metadata-declared PNG path, retaining page/plist SHA256 and original Grade ->
ColorTable evidence. No raster pixels enter Git. Grade families use explicit
presentation bindings, including Grade6/Myth and Grade7/Sole, rather than numeric
asset guesses. Sole is connected through its exact Common2 frame.

`source_ui_atlas.gd` verifies each page hash and restores rotated/trimmed sprites
into their declared original canvas. Independent Pillow decoding matches all 69
frame pixel hashes across eight pages (25 rotated frames overall).
One decoded image is cached per page; textures/styles are cached, and card icons
retain the existing 96-entry bound. Original portraits are 108×132, centered
without scaling on their 110×134 source grade frame. Unowned cards retain the
existing grayscale/dim policy. Collections reuse these same original icons.

Original action textures and transparent tab surfaces are read from declared
CSB nodes. The two original WinTotal background layers use their source bounds
and alpha at the adapted content viewport. Local controls/layout and accessibility
sizes remain; this is not an assertion of full original CSB runtime parity.
Original styles/background visibility are restored on close and legacy views.
No new FX timing/blending, badges, acquisition, or save behavior is inferred.
All seven source grade families are available. Full source screen placement and
remaining source controls still need completion; optional FX remain disabled until their runtime contract is known.


Final source UI regression: 61 checks pass, including an actual 110×134 framed
list texture in all three categories, close/background/style restoration and
legacy item panel theme restoration in the same mounted workspace. Source atlas
regression: 69 exact pixel hashes / 8 decoded pages / 690 canonical regular-grade
cards have frames. Nine native Grade71/Event cards have no declared corresponding
prefab, and two Grade0/None cards remain unframed. These are explicit source
states, not replaced with another grade. Full source control placement remains
separate from the original skin binding implemented here.

Native option awakening reconnect (separate from card skill awakening): the
original BuffCardOptionAwakenGroup.BuffCardID joins 289 native cards / 369 groups
without any name-based alias. The existing service, material/gold transaction,
probabilities and RNG/save rollback remain in use. Only the first source slot is
activated; 80 additional SlotIndex11 groups remain raw and visibly pending.
Existing per-grade success thresholds match all native first-slot probabilities.
In an unset server context, 206 native targets are eligible and 83 stay gated.
Source material-card server/time predicates are enforced before consumption.

All 264 collection IsAwaken requirement rows have exact first-slot option
bindings. The native runtime supplies only that verified ledger; legacy numeric
IDs, skill-awakening state and visual aura cannot satisfy it. Default supported
collection capability is 1034/1736 with the native option bridge (909 without
that bridge); this is not player ownership/completion. Rebuild/removal/group
mismatch tests verify no duplicate or stale reward. The existing four legacy
awakening collections remain for the legacy catalog; native UI shows relevant
original sets instead. No existing save keys or ownership are renamed.

Card skill awakening is a separate source system. The new catalog joins 701
canonical card IDs, 15 live book/pool chains and 72 non-None spells; 523 cards
have complete level1..20 stat/invoke profiles. Undefined group0, the empty test
group, None stat profiles and server/time predicates are not treated as unlocks.
A TWILIGHT-local `card_skill_awakening` namespace stores explicit saved spell,
level and decimal-string EXP, preserving unknown metadata. It is not an original
server key/RPC. Invalid state protects the save. Source CumExp remains exact;
no EXP-material/failure formula or automatic level grant is invented.

Owned/equipped/eligible saved skills contribute source HP once and use the
existing successful-hit dispatcher/cooldown store for fixed-magic procs. The
source spell's base/dice and level's proc numerator/denominator/cast-delay bonus
are retained. Local integration uses successful hits, per-card/spell cooldowns,
and millisecond delay reduction; this is not recovered original server code.
No SP/critical/equipment amplification or recursive proc is added. Original
spell effect sprite/audio references are retained; full original VFX is not
claimed. The read-only UI shows candidate-selection weights separately from
proc chance and offers level-profile previews without modifying live state.

Awaken/reawaken/EXP-feed requests are intentionally blocked: book quantity,
operation fee, success/failure/refund mechanics and nine ValueType enum meanings
remain unresolved. Neither the static UI price45,000,000 nor option-awakening
costs are reused. Blocked requests change no resources, RNG or save. Existing
option awakening and visual aura are not skill-awakening progress. Private UI
render tests use isolated XDG paths and explicit in-memory progress fixtures;
full Android/Godot4.7.2/original-client equivalence is still unverified.
