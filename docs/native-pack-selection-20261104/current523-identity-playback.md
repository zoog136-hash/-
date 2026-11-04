# Exact transformation identity, estimated pixels

PR236 adds an opt-in current523 actor consumer for **26 existing transformation
cards**, using the same stable `m508:1:*` save identities. It follows the latest
typed BuffCard → BuffClass/BuffBonus/Bonus → PolymorphSet/Entity joins, verifies
the complete unchanged original card row, resolves the current SPR alias and
shadow/clothing graph, and checks actual DAT member bytes and frame addresses.
Names, portrait IDs and equal integers from another namespace never bind actors.

## Use in the existing game

Open menu → settings → **523 정체 확인 변신 · 픽셀/합성 추정**. Select the
private identity ZIP, then enable and save its settings. Installation preserves
all previous source packs and does not activate a display by itself. Equip or
remove an owned card through the existing transformation menu. No card is granted
or consumed by these controls. Disable the option or choose **이전 팩·기본 외형으로
복귀** to restore the current native/class presentation. The older manual989-file
sample remains separate and has priority when explicitly applied to the player.

The identity subset is separate from the earlier989 SP2/two-PNG input: those989
files were selected for map investigation. Their absence of character identities
does not describe the full69 original DAT containers already received. These69
containers contain10,338 SP2 files; the new consumer needs328 of them.

## Source and host policies

- Native source identity, alias overrides, frame token order, duration ticks,
  source groups/mask bits, raw bounds and explicit SPR FPS remain intact.
- The26 generic idle/walk/attack roles are complete in eight stored directions.
  Fifteen have complete separately declared SpriteRun tracks. Ten declared runs
  lack exact files, and sprite16172 has no SpriteRun row. Those cases visibly
  use the host RUN→actual source WALK policy.
- The pack also contains304 complete primary weapon profiles and183 corresponding
  weapon run tracks. Runtime selects the exact source weapon type from the
  player's existing equipment context. Each run selects that weapon's walk
  action from the exact SpriteRun target; it never substitutes action0.
- Primary versus Special/Extra action choice preserves TWILIGHT's existing
  explicit primary-action policy. All selected ListSprAction rows are checked
  against current523. Native alternate-mode intent is unverified. Bow/type3 and
  Gauntlet/type10 require an unresolved AlterType1 mode and are excluded;17 of26
  actors lack complete Rifle/type34 and HandCannon/type54 roles. Unsupported
  weapon/identity pairs restore baseline instead of borrowing a generic bank.
- RGB565 expansion, SP2 commandwise pixels/alpha, layer blending, parent token
  sharing for attachments without their own actions, the existing host facing+3
  mapping and display origin remain host interpretation. The field label keeps
  **정체확인 · 픽셀/합성 추정** visible. Explicit source FPS wins; the configurable
  fallback FPS applies only when a source track omits it.
- Host gameplay owns movement, collision, attack sequence, damage timing and
  callbacks. The new consumer reads that state without advancing it or dispatching
  SPR annotations. Hit/death and other unsupported roles restore the previous
  presentation. M visual equivalence, full motion/weapon modes and all523 art
  delivery are not established.

## Private pack and recovery

`TWILIGHT_PR236_current523_exact26_identity_estimated_pixels_weapons_v2.zip` is
22,415,929 bytes, SHA256
`77ac05a4e0e3b6af81f6ae94d30d6bdf2f18324223e52f47f03e794be69617b5`.
Its manifest is2,899,411 bytes, SHA256
`e03944ee863b429f702154453fa0f6e873044b20aa5be1c93bc7f80ead91873f`.
It contains26 cards/actors,328 unchanged raw SP2 members (16,572,954 bytes), a
runtime manifest and source provenance. No raw art or native table/SPR rows are
published in Git. The portable builder accepts the already authorized private
inputs, verifies their pinned whole-file hashes/ZIP CRC/source proofs, and creates
a deterministic private ZIP outside the repository.

The actual-use ZIP is stored in the existing private `PR236_01_실제적용팩` folder.
Its identical derived-pack preservation copy is in `PR236_02_원본백업`; the earlier
checkpoint source backups remain there separately. Drive sharing is unchanged.
Owner-only links and exact consumption paths are in the private handoff. Drive
storage does not install the game: use the ZIP picker to install into
`user://current523_identity_versions/pack-*`. The earlier989-file input and base508
installation stores are not replaced.

Settings live separately at `user://current523_identity_settings.json`. A failed
write keeps previous options, pack root and active presentation. Installation
uses a new directory and atomic rename. Before an actor hides the baseline, all
its required members must pass integrity checks and every selected layer must
render. Periodic verification detects changes even to cached source frames and
restores the current baseline. No old save, source pack or prior version is deleted.

## Coverage and boundaries

[The per-ID coverage audit](current523-identity-coverage.json) records1,204 typed
card/class/run roots.930 declaration graphs resolve using26 byte-verified current
SPR files;274 remain blocked. The missing current texts are list19,22,25,27; old
same-name copies fail the current hashes and are excluded. Per-ID missing SP2
members and declaration failures are retained rather than replaced by guessed
identities. Sprite27547 (latest card25152 → BuffClass95762 → BuffBonus396512 →
Bonus2356182/type134 → NpcClass105042) has no verified current declaration or
historical file locator. Its absence does not block the independently proven26.

PR230 owns monster spawn/portal contracts; PR233 owns region/doll presentation;
PR249 owns latest card/stat/collection definitions; PR250 owns NPC/spell effects.
This PR changes their code neither by copying nor merging. It does not activate
new monsters, props, companions, arena or ziggurat. Future integration with those
PRs remains a separate review; current main is the unchanged baseline.

Direct tests and precise limitations are in
[the validation receipt](current523-identity-validation.json). First/last decoder
samples and complete source address parity are separate from whole-animation
visual approval. Prior base508 partial pose bytes remain preserved; without a
complete old native runtime pack, class fallback is the actual previous-display
path verified here. Android/device validation and a new executable are not claimed.
