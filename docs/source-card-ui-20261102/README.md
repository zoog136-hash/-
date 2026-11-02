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

Validation: source images 1267 SHA matches; native collection test 1356 checks; 14 actual World stat-consumer checks;
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
