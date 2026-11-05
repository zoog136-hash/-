# PR231 current-main integration

This continues checkpoint `76c9e38e90fdbb77ec13931e7e0e319486b8559c`.
The integration base is main `918c8e84e6a5ecbe7a071b263751e10899c282a1`
(PR263, including the PR249 registry). Subsequent main `00b84cfe` changes only
installer/build tools and their tests, outside this runtime change.

## Connected behavior

- The current registry remains **720 cards: 402 transformations, 171 dolls,
  147 relics**. The 16 PR231 records supplement existing stable IDs; they do
  not create 16 extra cards, ownership grants or guessed gacha entries.
- Private slot v2 preserves 446 groups / 2,392 effects / 305 option profiles,
  all 141 primary/additional pairs, and 289 reviewed existing primaries.
  Only Mariela `2:25002:1` receives the source-verified Level1 correction.
  Other reviewed primaries retain their existing behavior. Awakening has 717
  source profiles; this is distinct from the complete 720-card registry.
- All 147 relic definitions, 145 subslot links / 144 distinct buffs, and 58
  secondary option groups remain available through their original graph.
  Original server, time, ownership and main-card/grade restrictions still apply.
- Native item3252 now retains a physical quantity proof when supplied by the
  current exact-ID item provider or normal source floor pickup. Recipe258482
  debits 3,000,000 proven coins and creates ticket370562; using the ticket
  grants the stable Nemesis card. Generic pre-existing wallet balances remain
  excluded from this source debit.
- The existing full quest owner can claim quest96201 after its real prerequisite
  and level96 goal. Reward394871 remains a held, exact source box346921.
  The existing inventory action opens it into item365748 and item365758, one
  each. The quest debit receipt and both outputs share the atomic save.
- Item365748 applies the existing exact Eva unlock declaration. Item365758
  uses the six original effects: duration1800 seconds, deck98, slot11,
  AutoBuffOverlapDuration5000ms, PresetConsumeItem1 and InfiniteAmount1.
  It retains the owned scroll, persists the deadline, expires derived effects,
  and clamps HP/MP. Existing inventory and quickslot controls perform the use.
  An explicitly enabled existing item-auto slot refreshes at the source five
  second boundary. No new UI skin or replacement source screen is introduced.
- A newly unlocked/selected v2 slot has no effects without a proven usable
  scroll. Previously saved untimed selections remain compatible until changed.
  Locks and the current CannotUseItem guard apply to both manual and auto use.
- Five normal source awakening books use the same exact supplier/quest receipt
  debit contract as current main. User policy still consumes **one book** and
  paid reawakening resets **Lv1 / EXP0**. Failed durable writes publish no
  currency, item, receipt, card or selection-RNG mutation.
- Duplicate-card growth preserves quest-reserved copies and first ownership.
  Source EXP rows remain unchanged. The authorized conversion/fees are visibly
  distinguished and configurable in `data/cards/skill_awakening_growth_policy.json`.
  Hunting uses the character's earned EXP for eligible equipped transformations
  and dolls, through the existing deferred save. Relic hunting conversion is
  not inferred from a different deck.
- Physical source records, quantities and provenance survive warehouse unit
  splits, withdrawal and floor round trips. Name-only items gain no proof by
  touching the floor. Current-main atomic warehouse saves remain authoritative.

## Private runtime inputs and installation

Original projections/pixels are not added to public Git. The six old PR231
projections remain in checkpoint76c9 and the authorized private input; consumers
use the shared private-pack loader rather than public raw JSON files.

| Pack | Bytes | SHA256 |
| --- | ---: | --- |
| `TWILIGHT_card_slots523_runtime_v1.json` | 952204 | `98cfdb4f604fba7dad2de41cb290aee3d35087e0d4b805d416a372570dc1cc66` |
| `TWILIGHT_card_slots523_runtime_v2.json` | 2288667 | `35f1844fe70aa8df3a3aea03a9858822715a0dff4941fdb273ae5bab9ea81cd4` |

v2 is durably stored in the existing private Drive game-application-pack folder;
v1 is retained there. Drive storage does not automatically install a pack.
The private delivery message contains the verified access link; sharing was
not broadened. A fresh authenticated download matched the size/hash and loaded
from the default installation directory in a fresh consumer profile.

Place v2 at
`user://card_slots523/TWILIGHT_card_slots523_runtime_v2.json`, or pass
`--card523-slot-pack=<absolute path>` / `TWILIGHT_CARD523_SLOT_PACK`.
The default resolver prefers present v2, otherwise v1. An invalid present v2
or invalid explicit path fails closed, preserving protected saved selections.
v1 remains byte-compatible; new acquisition operations require v2.

Native future supply additionally requires the existing full-item pack through
`--patch523-drop-root=<installed pack root>` (payload identity `38ee3ec7…`).
Quest96201 requires the existing complete `user://quests_current523.json`
installation. These are separate existing packs, not silently bundled into v2.
The source ZIP SHA is `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.
The exporter verifies every one of its 78 embedded table pins and 3,188 typed
raw references before emitting v2. Independent relic graph verification checks
11,622 source references; the narrow combat contract checks66 references in13
tables and rejects five unsafe mutations.

Rebuild v2 outside the public checkout with:

```sh
python3 tools/build_patch523_slot_support.py --help
```

Use its explicit source archive and private output arguments; its v1 mode
reproduces the already installed v1 bytes. No raw source output belongs in Git.

## Validation scope and remaining dependencies

Local Godot4.7.2, Compatibility/Mesa, isolated XDG profiles and the real current
Main/map were used. The source map staging is the607-file /725,122,448-byte
current-core subset, **not full map or full original-art delivery**.

The actual Main scenario exercises source supply, crafting, held quest reward,
inventory touch use, one-book awakening, duplicate feeds, save failure,
reawakening, deadline expiry and actual reconnect. Separate tests cover the
current owner save guards, reserved cards, physical transfer and quickslots.
Test grants/ownership are explicit fixtures; passing them does not prove
natural acquisition of every card or all gameplay. Local test results and the
final commit are reported separately from unrun remote CI.

Pending source art remains explicit: the latest19 portraits and the additional
original UI/atlas inputs are not installed in this consumer. Existing original
art is reused; canceled card-body reconstruction stays canceled. Library401
was not retried or bypassed. The private slot pack is data, not missing pixels.

The only additional relic combat invoke dispatched here is the already verified
card22182 → InvokeOption16572 → spell89552 contract (source3%, fixed500+1d1).
Other targeted weapon/CanCast/regen semantics remain pending their exact owner
contract; loading all147 definitions does not mean all conditional combat is
implemented. PR248's slot/registry/effect-combination owner remains separate.
This PR writes neither that branch nor canceled/excluded game features.
