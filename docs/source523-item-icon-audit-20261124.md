# Original 523 item icon identity vs. installed resources

The shared resolver now passes an existing name-only caller's exact name to the original owner. An explicit record cannot acquire a new identity from a different fallback name. When a known exact item or alias cannot show its original, the resolver keeps the ItemClass and whatever IconID/AssetView evidence was actually available. A missing source row is not rewritten into a filename mismatch, and an unavailable texture is not replaced with other art. Inventory/shop/detail images use the original ItemClass IconID; the separate floor sprite route is unchanged. No player flags, item behavior, save fields, mappings, or images changed.

On the pinned release of the current523 definition ZIP (SHA-256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`), all 139 committed exact aliases matched their current ItemClass/Icon/AssetView filename. This does not establish that any player's installed copy has those pixels. For example, 각성서 조각 is ItemClass 98454, IconID 84728, `Item/SkillAwakenbook_common_piece_01.png`. It is not proven missing; the Main regression simulates a package/member failure for this real identity without generating an image. The fixture distinguishes missing member (팩에 없음), pack/hash verification unavailable (원본 확인 불가), wrong file mapping, and an unverified or unknown link.

Known scene routes are not physically missing static images: 기르타스의 단검 ItemClass 362391 and its 각인 variant 357591 share IconID 107221, `icon/Fx_Item_Weapon_Dagger_Sole_Giltas.csb`. 기르타스의 검 ItemClass 160012 uses IconID 89588, `icon/Fx_Item_Weapon_LargeSword_Myth_Girtas.csb`. A selected original CSB and an attached scene are separate acceptance checks; this change does not modify the native CSB player or its registration.

The earlier 251/4,804 result in `items523_remaining_missing_rules.md` measured a previous installed pack, covering 46 IconIDs; its per-item results were not committed and are not evidence about the current device. The image-pack comparison must use the same current base manifest and UI-icon selection. An absent IconID in the pinned definition table is a source declaration absence, not a vanished file, and test/dummy rows are not live missing artwork.

Verified the execution regression with actual headless Main and isolated profile, ten checks, and the currently required `tools/check_no_legacy_resources.py` gate. No device render or delivered art claimed.

## Full release audit (metadata and ZIP coverage)

The official eight-part `pack-63fb1355` descriptor was read from part 1 and its canonical full pack ID recomputed. Its image manifest (`db51444b…cb1f`, part 6), CSB selection (`1db37107…e027`, part 7), and selected icon-pack manifest (`b6ba90f4…26fd`, part 7) were read and SHA-256 checked without downloading the whole game pack. Exact definitions for each ItemClass/Icon/AssetView match those pinned catalog rows. ZIP directories from parts 6–8 confirm exact paths and lengths.

| Cases among 30,398 non-TestItem definitions | Count |
| --- | ---: |
| Static original member listed and size matched | 29,902 |
| Original CSB member with selected, unique clip and exact scene identity | 459 |
| No original IconID declared (32 internal/default category, 2 other) | 34 |
| Explicit named dummy exclusions | 3 |

No non-dummy row with a positive icon declaration lacks its release member. 17,278/17,278 file paths and lengths in the whole static image manifest and 474/474 in the selected UI icon-pack closure match the archive directories. This does not prove every physical payload hash or the phone's selected release. Two individual original members were also downloaded via exact ranges, CRC and SHA-256 checked against the pinned manifests: #98454 image (`icon/Item/SkillAwakenbook_common_piece_01.png`, 8,352 bytes, 64×64, independently decoded); the #357591/#362391 CSB (14,308 bytes). No substitute images, no pack redistribution, and no claim of animated playback on the device.
The scoped release sample then passed the actual Main/headless ItemVisual route: after admitting the unmodified pinned image manifest, exact table/index/decoder files and that original PNG alone, the existing item display mounted a 64×64 Texture2D with `original_linked` provenance. 12/12 combined route checks; additional icon identity 33/33 and missing-scene control 4/4 in a packless test, plus the metadata contract pass. This is not an installable or all-image-rendered pack.
