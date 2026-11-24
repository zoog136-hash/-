# Quest-awarded transformation card item icons (current523)

A held quest reward and the transformation unlocked by using it are two different source identities. The bag uses the reward's ItemClass → Icon → AssetView path. The transformation catalog uses the resulting BuffCard's declared DisplayBaseAssetID, never a generic bag picture, name match, rarity substitution, or a generated image.

An old/compact held-reward record can lose its raw item presentation row while retaining its physical quest grant receipt. Both the fallback inventory slot/detail and the original UI inventory image reader use `_item_visual_record`. That lookup can now recover only a presentation DTO for a selected physical key: it requires the verified 523 source archive, the exact ItemClass, exactly one QuestReward relation, the Reward item type/ID and blessing, and the exact original held key. Contradictory ItemClass/record/source identity or a different physical reference cannot authenticate the DTO. Current full native or pending item records keep their existing path. No item/claim/consumption/save mutation or inferred image was added.

Exact direct deck-1 reward-item declarations (QuestReward → Reward → ItemClass → non-possession ItemBonus/BuffCardID → BuffCard):

| Quest role | Item | ItemClass | IconID | Literal original icon |
| --- | --- | ---: | ---: | --- |
| Main: Quest 77381 / Reward 93201 | 매직 솔져 | 139781 | 1841 | `icon/Item/Card_Polymorph_Common.png` |
| Achievement | 다크 블레이더 | 289172 | 1845 | `icon/Item/Card_Polymorph_Rare.png` |
| Achievement | 실버 블레이더 | 289182 | 1845 | same original ItemClass icon declaration |
| Achievement | 아크 블레이더 | 289202 | 1845 | same original ItemClass icon declaration |
| Account achievement | 낚시 꿈나무 폴 | 306611 | 1846 | `icon/Item/Card_Polymorph_UnCommon.png` |
| Account achievement | 낚시 모험가 폴 | 306621 | 1845 | `icon/Item/Card_Polymorph_Rare.png` |
| Account achievement | 베테랑 낚시꾼 폴 | 306631 | 1847 | `icon/Item/Card_Polymorph_Unique.png` |
| Account achievement | 전설의 낚시왕 폴 | 306641 | 1842 | `icon/Item/Card_Polymorph_Epic.png` |

The five distinct PNGs were retrieved from official `pack-63fb1355` part 6. Their bytes, CRC, pinned manifest SHA and 64×64 decode were verified. For 매직 솔져 the bag member SHA-256 is `e370fd94dd62eee791ea4efba9bf0440c4f7d1a7d0c45edaa3bd4f579d2ecbbd` (6,153 bytes). Its separate BuffCard 12231 DisplayBaseAsset 191631 uses `Image/BuffCard/MagicSoldier.png`, present by exact pinned release index. Neither illustration role is declared for that card, so the existing portrait presenter uses the original DisplayBase role. Existing text-only quest navigation has no verified original reward-slot UI to replace.

All eight direct, non-test reward ItemClasses have their declared original icons. A remaining 56 direct deck-1 reward ItemClasses have source TestItem=true (not admitted by this fix). Receipt-free loose legacy records, missing/unverified source archives, and unproven or random downstream choices are not assigned substitute pictures. Device installation and the user's individual save were not inspected or changed.

## Nested quest rewards

The pinned source graph also checks exact ItemClass outputs of LuckyBag/SelectReward/ComplexReward; 27 deck-1 fixed-card outputs are declared under such paths, of which ten are non-test: #123403, #146202, #146282, #146292, #146262, #146252, #146192, #146182, #233964 and #271368. All ten have their existing ItemClass icon and their own BuffCard DisplayBase asset in the same release. Their new inventory copies are ordinary native ItemClass records once concretely issued; do not treat the unopened parent's chance/choice as ownership of a card or show an arbitrary outcome portrait. The exact 235 distinct direct item types in primary quest declarations were included in the graph scan.

## Choice-box display distinction

The original-window selector previously drew a box-provided TestItem's *preview* by exact ItemClass/IconID, but the fallback ItemList used the ordinary inventory eligibility check and left those same options blank. Both now use one preview-specific display path. The test exception is only used for an already-declared chooser option, and does not enable the item in inventory, change its claim entity, or change draw/consumption/ownership. Example: Quest 78333 → Reward 111213 → box ItemClass 155643 → LuckyBagClass 23233 → selectable entity 159143 → 다크 나이트 ItemClass 1025 → IconID 1845, original `icon/Item/Card_Polymorph_Rare.png`.

The separate `Image/BuffCard/MagicSoldier.png` was also read from the exact release, CRC and SHA-256 verified (`9915d6c1433ddc91fe15f977027342c175776d4a8f58310e26b724e51d50725d`, 20,061 bytes) and decoded (108×132). It is not substituted for the held reward item's 64×64 icon.
