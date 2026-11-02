# Native awakening-effect reference design — not an enabled aura

Read-only inspection found no native awakening-status hook in follower_motion,
relic_motion, original_source_preview or the source card adapter. Native branches
return before the old authored aura path. Existing option_awakening_service and
its `awakened` save flag describe host option awakening; equivalence to the M
state required by BuffCardAwakenEffect has not been established.

Verified base508 source joins:

| Card | Deck/grade | BuffCardAwakenEffect | StatusEffectID | Raw attrs |
| --- | --- | --- | --- | --- |
|11692 Antaras|2/32|61|1544|48→22149,138→2,GenderID0|
|21518 Einhasad relic|98/32|101|2408|48→24748,138→98,GenderID0|

The table contains12 deck/grade rows (decks1/2/98, grades4/5/32/52). Raw attr48
values match named SPR awakening-effect declarations, but the enum/lifecycle is
not decoded. Keep the raw row IDs/values, exact source-card ID and source table
hashes. Do not turn grade32, possession or equip alone into an activation rule.

Minimal future adapter: join the equipped source card's exact deck+grade to the
unique effect row; activate only after an explicitly mapped source awakening
completion/status condition is available. Preserve gender/deck attrs without
inventing enum meanings. A dedicated native effect node should retain its own
SPR clock, offsets, attr and lifetime, following its declared target context;
it must not reuse the collectible body's loop or host procedural glow. Unset or
unverified state keeps the effect pending. Equip/state transitions remove only
that effect node and never mutate source pixels or saved awakening progress.

No always-on aura, status effects, stats, enum meanings or state migration are
implemented by this design. These references do not replace any unlocated176
layer prefix or event7.24709's source-SC pose timing observation is separate;
possible additional aura participation remains a video interpretation limit.

24748-8 is present locally.22149-8 is indexed at Client/Data/Sprite409.dat,
16501 bytes, CRC4807016d, but absent from this consumer's materialized inputs;
this is an input-transfer gap, not proof that the original asset is absent.
