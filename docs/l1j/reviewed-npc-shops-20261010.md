# Reviewed A3 merchant offers

The shop selector now exposes four audited merchant profiles selling the existing
TWILIGHT silver sword. The world resolves prices from registered source offers,
then reuses PR #65's quantity, wallet and carrying-capacity validation. UI events
carry vendor identity, item name and quantity; they never supply a payment amount.

| A3 NPC | Merchant | Existing game sourceId | Source item | Base sale price |
| --- | --- | --- | --- | ---: |
| 70039 | 워너 | 6391 | weapon:29 은장검 | 16,250 |
| 70047 | 데프만 | 6391 | weapon:29 은장검 | 30,000 |
| 70068 | 프랑코 | 6391 | weapon:29 은장검 | 101,200 |
| 70095 | 듀론 | 6391 | weapon:29 은장검 | 30,000 |

Prices come from `a3.zip!db/l1remaster.sql`, SHA256
`819c1741e815321cf083aaba65aa5698f2be350cca37533a1e94da8121a351b8`.
The source `ShopTable.java` explicitly converts `pack_count == 0` to one.
These four offers require enchantment zero and no pledge rank. The offline game
uses the source base selling price as Adena with no source-server tax or dynamic
configuration multipliers. Source buying prices are retained as provenance only.

The source merchant names, IDs, selling rows and reviewed visual identity are
cross-checked before exposing an offer. A game item name must identify exactly
one existing catalog record. Duplicate identities, unreviewed source snapshots,
invalid prices, pack/enchantment policies and ambiguous names cannot create an
offer. `tools/l1j/build_reviewed_shop_bindings.py` reproduces the manifest from
audited source JSON and the existing reviewed visual bindings.

Purchasing creates a new +0 physical equipment instance pinned to existing
sourceId 6391. Previous instances, enhancement levels, equipment selections,
item stats, grades and save schema remain authoritative. The default shop keeps
its original 20 goods/prices and 1–99 bulk policy. Selecting a source offer limits
each transaction to one item. A transient vendor selection survives UI refresh;
it does not introduce a saved NPC or item ID.

`l1j_reviewed_shop_test.gd` exercises actual HUD purchase events, all four prices,
forged price rejection, funds/capacity rejection, physical IDs, enhancement,
rollback and save/load. Its initial local Godot 4.7.2 run passes 99 checks.
The existing runtime combat test now confirms the startup class and clears prior
combat targets before each actor test; production combat and skills are untouched.

This integration branch composes exact PR #63 head `ccf2e44` with exact PR #65
head `cb895669`, then adds this adapter. It does not merge either PR into main
and does not incorporate PR #59 or the later warehouse/crafting/dialogue work.
Linux/Windows full regressions and Android export are checked by the configured
CI; see the exact integration PR head for final results. CI art is synthetic.
Private recovered art is installed locally for separate checks and is excluded
from Git.

## Rollback and limits

Set the reviewed manifest's `enabled` to false, or call
`TwilightReviewedShops.set_enabled(false)` through the preloaded script, to hide
and reject source offers. The default shop and owned equipment remain usable.
The source binding script has no global class registration; preload it by path.

Delivered scope is **four merchant profiles, four offers and one game item**.
It does not place source NPC actors in the field, recover NPC animation semantics,
implement their other goods, resale, taxes or quests. All SPX actions remain
unclassified. Real Android device execution and full original-game integration
are separate unfinished work. Main requires explicit user approval to merge.
