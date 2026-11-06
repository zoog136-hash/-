# Map source implementation checkpoint — 2026-11-06

Status: LOCAL CODE COMMITTED; execution unverified; not published or installed.

Latest completed code commit: `1dc969b9de75ecc7810e783ea7513ef873b13af7`.
Parent: `2b75ecf9189628f6816d9ff014d742e51b0efed9`.
Original branch: `feature/current523-regional-portal-consumer-20261106` at
`d4d04e298b6debe8e4eee5a22de9176ed2e97740`; it is preserved unchanged.
Parent-confirmed main reference: `e1513f7da10d6282f1ea7b8bdabe9606843b52fa`;
this checkpoint is not a newly fetched full-main checkout.

## Completed behavior and decisions

The retained 29-file code view composes Map source region/NpcBuff admission,
exact data producer and Land0 fix, actor buff lifetime/registered-root/retirement
guards, cross-Land explicit target encounter/container/occupancy/RNG/boss staging,
batch prepare/commit/restore/finish, authoritative save proof and population
adoption/recovery, narrow persistent-buff-preserving action cleanup, original
ordinary NPC damage numeric-input projection, and World model refresh.

The latest four paths are `scripts/maps/current523_aden_play_controller.gd`,
`scripts/maps/current523_population_transaction.gd`,
`scripts/maps/current523_transition_actions.gd`, and `scripts/world.gd`.
The latest delta SHA256 is
`ad969d2f1e6b5079aa5f870d9c1ac32a27eea0d982a79fbfaffa971d819e7600` (29,284B).

Actual travel order: exact source/target/entry/quote/field/model/generation and
passability/occupancy checks -> isolated data prepare -> catalog commit and
disabled target media/population -> capture old action owners with actual Map
history Callable -> registered route recheck -> successful begin barrier BEFORE
OPTIONS.write/session/field adoption/save -> actual save proof -> catalog finish
-> narrow action cleanup -> activation only after explicit cleanup success.

Only the first explicit registered-route rejection plus actual catalog restore
success and unchanged source/owner/life/epoch/model/position/RNG/gold may discard
uncommitted preparation metadata. Begin requests, attempted options/session/
adoption/save/finish, unknown save/cleanup and restore conflicts retain receipts.
Persistent NPC-applied player buffs/legitimate skill state and World epoch remain.
Auto-hunting OFF on accepted travel; random arrival only in verified passable,
unoccupied cells of the declared destination region. No guessed native rule.

The original ordinary NPC mean input is an explicit TWILIGHT numeric estimate,
not recovered server dice behavior; caller overrides and unsupported/special/
boss paths retain existing ownership. 480 source-form candidates are not observed
spawns/attacks or additional source-file consumption.

## Source witnesses and held inputs

Data ABI reference: PR282 immutable `21bcd2d1325fffcb27923ffccf3a59b1542e1149`
plus local source-verified Land0 correction. Definition archive identity:
`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.
Land0 is an actual original row, AssetPath `0/`, no type504 roots; this does not
relax Buff/Spell/attribute zero sentinels or activate a fabricated environment.
Target actor relations use retained original NPC/spawn/territory tuples, not
Land/World/NPC ID substitution or first-candidate selection.

Remaining runtime prerequisites: admitted explicit source entry/destination,
exact selected field/actor/media pins, current registry/model, compatible original
population and opt-ins. Missing originals/relations remain held. No empty or
guessed target population is treated as success. New Map/Tile source delta is
0 files/0B; behavior reuse is not whole-file source consumption or runtime proof.

User exclusions retained: Sprite28, Rosemary12 components, 98 unproved identities
plus dummy, declared dummy/Test, excluded Land/unmatched placements, new quest,
sound, potion, spell-stage, emoticon work. Ground-loot rules/visuals unchanged;
image new work only item/polymorph/relic/doll. All source bytes/packs/phone/saves/
settings/pins preserved. No game/parser/compiler/tests/render/CI or remote action.

## Retention and exact limitations

The original workspace filesystem has 0 available bytes. No original or cache
was deleted to create space, and no failed full-volume Git write was retried.
The code-only project/checkpoint and private small artifacts are under `/tmp` on
the already authorized separate filesystem. They are NOT durable delivery to
another environment. A project-volume durable copy remains BLOCKED on space.
No upload/publication was authorized or performed. Private handoff contains only
small code patches/receipts/bundles; no raw art/packs/saves/credentials.

The original checkout retains these four dirty paths (not staged or overwritten):

```text
M docs/CURRENT523_NPC_SOURCE_REGION_RECEIVER.md
 M scripts/maps/current523_aden_play_controller.gd
 M scripts/maps/current523_source_portal_provider.gd
 M scripts/monsters/patch523_npc_extensions.gd
```

Private artifact fingerprints:

- `HANDOFF.txt`: 6109B; SHA256 `51f59e407f94e46a99bdf9c0d2b665fa2f4be20f16105e0ff7b4d24c424ac9d5`.
- `composition-receipt.json`: 3740B; SHA256 `a1a4305b86fe6347f0fc87877899ed62bdeb41b111c0cf36dd4422acb261d1d8`.
- `delivery-receipt.json`: 239B; SHA256 `ecd145dade660565f46ad746bc8a46a42faf84241518d0ef0aba5d3847f9d3ab`.
- `guard-model-over-2b75.patch`: 29284B; SHA256 `ad969d2f1e6b5079aa5f870d9c1ac32a27eea0d982a79fbfaffa971d819e7600`.
- `guard-model-incremental.bundle`: 5605B; SHA256 `f7bf47695632bee002c7667846284fbd579887508446ebbe257bdb6fb1854967`.
- `TWILIGHT_Map_GuardedAttempt_Model_Local.zip`: 27980B; SHA256 `b64fe0d50c3feb763ec67a60fdcc875c002cf2bd8c1f586b0b63a31eb45e0ba9`.
- `ordinary-map-composition-receipt.json`: 12994B; SHA256 `6eb05ba8f4b22f3eff2f7872d588a56b2fcd0f3bace1650bdd70e3fcb381e7b0`.
- `receiver-and-ordinary-input-over-668.patch`: 53733B; SHA256 `22cdf8a960eaecec1e5bdc5bbf8afda91c4101754071549d16692fa2611bffbe`.
- `TWILIGHT_Map_Receiver_Ordinary_Local.zip`: 83748B; SHA256 `a93a3e81def4f7506d61806154a73e597eba971a108635720db49322ab3f200b`.
- `TWILIGHT_Map668_CodeHandoff_668f917c.zip`: 218858B; SHA256 `e40ba19cac2887e438ede5f75e9367eed4994d137abf68848c013a2d0c261ceb`.
