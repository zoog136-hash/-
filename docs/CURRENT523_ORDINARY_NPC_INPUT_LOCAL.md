# Ordinary NPC attack input on the map receiver candidate — unexecuted

This is a separate local overlay on the real transition-receiver checkpoint `eb783f9eee65d1a66e940d47ef7c168b1706336c`, itself based on frozen Map668. The parent supplied exact 4-file patch is 11,076 bytes, SHA256 `271da1f75432cef154ed58e13c4ec2a4bc062cc81963b3a3e0b865501b925079`. All four result blobs/SHA256 match the supplied identities. This overlay does not edit Monster, World, the receiver, actor batch/RefCounted code, source environment registry, retirement, sleep/GPU or source field/travel code.

## Actual caller path

`base508_source_roster.record` sets the exact `source_m_ordinary_host_atk_default` provenance only when its fallback atk=8 is used and the caller did not provide atk/attack/공격력. It erases a caller-supplied marker before determining that fact. `for_spawn` reaches that same record factory; no new spawn tuple, position, activation, visual or identity is created.

`catalog.project_actor_record` retains its existing source admission/stat/resistance/range projection order and then calls the real `ORDINARY_DAMAGE_INPUT.project(self,result,source)`. The projection requires exact original NPC/source identity and current admitted registry, non-test/non-unused declarations, nonboss melee, no special AI/action contract, the proven fallback marker with current atk=8, and exactly one complete original owned NpcAttack row with its supported ordinary/unchained/zero-parameter form. A missing policy, wrong identity, caller override, unsupported row/set/form or bounded input returns the existing record unchanged; it does not authorize a new attack or a new map entry.

The existing map batch uses an isolated catalog/shadow to call that same projector. Its canonical prepared records therefore carry the admitted result and policy/source provenance into `materialize_actor_bodies` -> preparation-only `Monster.setup` without performing live admission. The real commit retains the exact NPC model; body adoption still requires the exact model/identity/field/epoch/media proof. Normal existing NPC setup likewise uses the catalog projection. The original record/source/actor lifetime and transaction/rollback contracts are not replaced by this numeric input.

## Explicit estimate and visible behavioral effect

`floor(DiceBonus + DiceCount * (DiceSpots + 1) / 2)` is a labelled TWILIGHT uniform-die expectation/floor estimate for the existing host atk input, not a recovered native NPC/server damage formula. Parent-supplied source witness NpcClass103712 -> NpcAttack352942 has DiceBonus563, DiceCount4, DiceSpots11; this estimate is587. No raw source operand, Prob9500, attack choice, chain, timing, RNG or save is changed. Native patch523_npc_combat.damage_spec continues using its raw dice; the estimate is never written back into that specification.

Existing Monster.setup consumes `attack_power=maxi(3,record atk/attack/공격력)`. The existing fallback melee accuracy is `monster_level+10+round(attack_power*0.25)`, and fallback magic accuracy uses `*0.20`; ranged accuracy can inherit melee accuracy. These damage-dependent existing defaults can change when an eligible atk changes from8 to the mean. Explicit corresponding accuracy inputs still take precedence. This effect is intentional and visible, not a claim that only damage display changed. Boss/special/spell/chain paths and actual hit/order/cost/effect owners are unchanged.

## Source evidence and counts

Original Content archive SHA256 remains `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.

- content/NpcClass.json:9,159,644 bytes; SHA256 `02abdf0028e3a01a4e8c7175afdc75c14ba2f1dd96e116886b7ef51fd9f7b61d`
- content/NpcCategory.json:6,635 bytes; SHA256 `88e484687b3cdaa1ea4d25da9d254645fba4614af6504fa7540d834836b66f82`
- content/NpcAttack.json:9,440,036 bytes; SHA256 `32cc2e540569bc612a427fbdb3745e719b55c513cee286f46637a461afb6a71b`

These are parent-supplied original table provenance, reused without archive rescan. The 480 count is the data owner's source-form candidate count, not actors spawned, attacked, passed tests or newly used source files. Whole table/file byte consumption is not claimed. Existing original-file usage totals are not incremented. New unique Map/Tile members/bytes remain0/0; the new policy JSON is authored TWILIGHT configuration, not an original Data member.

## Joint local identity and limits

Catalog base `8fb3d8b2eb877e40285bad827b501d92a4380ff8` -> exact result `26224dc1cb74f1fadfd227d7a80c59986776ba73`. Only its import and final projection call were changed; actor batch/RefCounted/environment code remains. Roster base `82288539dd530b852947d168388f4b83718f05d0` -> exact result `845f1f6dff28925bb2df1c0ae426a48369a5bc9d`; only the fallback-provenance hunk was applied. The new helper is `7c97a83e5496a5ce5ae3921737ac61d895bfbf34` and policy `77e978ed7b5f15ee218c0f0625791f48d7ce57e1`.

The receiver remains exact integration helper `0ab2fca4b488767abbe8b7e9dbde9d74c02e56b4`. Central integration still must preserve its independent World +57 model hunk; that full hunk is not present in this map executor, and no whole old World replacement or combined-main result is claimed. Unused action-prepare token reclamation still has no public discard API; no private registry manipulation/retry is added.

No execution, tests, parser/compiler, game/render, CI/workflow, upload/publication/merge, phone/config/save change or original asset byte change was performed. Sprite28 and other agreed exclusions remain; no missing layer is declared optional and Data933 remains in scope. No original image/Sprite/frame/UI was created. This is code composition and static artifact identity only.
