# Original character stats and equipment boundary

This is partial main-game original UI connection code. It does not complete a
character screen or any whole560 count. Attendance/pass remain deferred. No
new test, game run, rendering or CI was executed for these changes.

## Actual stats caller

The existing `renewal_character._show_stats_page()` first selects the owner's
stats page, then emits `original_page_requested("stats")`. The existing HUD
connects that signal to `_on_original_character_page_requested` and calls
`original_main_ui_controller.try_open_character_stats()`. A successful staged
presentation hides the existing workspace; unavailable original inputs leave
the current owner presentation available. Reopening character preserves the
owner's explicit selected tab; equipment pages are never selected by filename.

`source_main_character_view.gd` retains these exact original parents:

| Member | SHA256 | Actual project |
| --- | --- | --- |
| `UI/FloatingUiScene.csb` | `b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8` | `12856` |
| `UI/FloatingUi/CharacterInfo_All.csb` | `d19edfa099c5770cf43f08bd73f9370185ac7dbccdb67b89bf39d77330527be7` | `1384` stats |
| `UI/FloatingUi/CharacterInfo_StatInfo.csb` | `75e7ad019977077a5e447bba55a5b6f7d15794ad0bca8807143dc275abba620c` | original text nodes below |

The actual parent uses `CharacterInfo_All_On`35–47 once for opening. The
separate `CharacterInfo_StatInfo_On`20–32 clip is not substituted based on name.
The child stat-result/active effects are not played or looped without their
original action policy. Source coordinates, skew, fonts, alpha and ancestors
remain in the original renderer. Only the explicitly selected tab's existing
visibility state changes.

| Existing `character_state` integer | Original title | Original value |
| --- | ---: | ---: |
| `str` |41968|41648|
| `dex` |38220|37900|
| `con` |34444|34124|
| `int` |26948|26628|
| `wis` |23200|22880|
| `cha` |19460|19140|

`source_main_character_stats_bindings.build(pack, owner)` and
`refresh(actual_renderer, owner)` require these actual six values. They do not
invent defaults or recalculate stats. HUD character-state updates refresh the
presented texts. LFE/DTH/elixir values and the original Normal/Pressed stat
button action meanings remain unestablished; those buttons are not attached
to the owner's plus-point spending action merely because they are nearby.
When the actual owner has stat points to spend, this read-only scope declines
and retains the existing spending caller. If points become available while
open, the same owner presentation is restored; no spending controls disappear.

Original All close2544 calls the existing workspace close. Original equipment
tabs16212/14056 return to the existing owner equipment caller. Stats
tabs11168/9064 retain the explicit stats selection; their title literals are
11568/9464. Original stat detail button4552 with literal5020 (`상세 정보`)
calls the existing `hud.open_detailed_status()`. Ownership, point allocation,
cost, save and the detailed-status consumer remain their existing owners'.
Native touch uses the same actual source button router; source Bg22036 supplies
its authored hit bounds. Existing detail/companion/workspace controls retain
input precedence, Escape closes detail before character, and character bounds
block underlying slot drag capture.

## Equipment templates: exact available subset, selection still required

`source_main_character_equipment_bindings.gd` provides
`configure(pack, hud, image_provider)`, `build(explicit_member)` and
`activate(physical_slot)`. The existing actual owner `equipped_items` records
and `equipment_buttons[physical_slot].pressed` callback own physical reference
construction, equipment detail and actions. A supplied existing image-owner
Texture2D result is required for each occupied slot. No Item/Asset resolver,
equip/unequip operation or save contract is recreated.

| Original member / SHA256 | Original panel | Original Project → owner slot |
| --- | ---: | --- |
| `UI/FloatingUi/CharacterInfo_EquipSlotSet_A.csb` / `124721703e192879c6fbcf9bfaa62ae118b51b7b143a072e4595471d799678f5` |304|24680 Helmet→`helmet`;21044 Weapon→`weapon`|
| `UI/FloatingUi/CharacterInfo_EquipSlotSet_B.csb` / `404798592672d54ef558ceaf18c0e6d0889cbf881a3b17a17c9bf83f1072c0af` |24496 visible Reboot panel|44584 Belt→`belt`;35504 Necklace→`necklace`|

Both are original326×428 Layouts with anchor[.5,.5]; slot Project coordinates
and scale.92 are preserved. Original `CharacterInfo_EquipInfo.csb`
(`9f415310d74d6de1ba986413a910e7b86658719ba3d9e5568ca323d580bde274`)
has actual PageView21220 of the same extent. The shared PageView adapter now
keeps the authored anchor and actual `SourceContentOrigin`: upstream
[Cocos2d-x3.6 UIPageView.cpp](https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/ui/UIPageView.cpp)
adds the original Layout without changing its anchor; its layout pass changes
position/size. Equal-size pages need no source geometry normalization.

This mechanical anchor support does **not** establish class/mode→A/B selection,
page order, remaining slot aliases or per-slot broken/clear/detail modes. No
equipment page is automatically shown, and this adapter is not counted as
actual game consumption. CharacterInfo_Slot's locks/LV99 are not used: these
A/B originals reference Common_Slot directly. Ziggurat is not activated.

The Common_Slot original and icon target use the existing native icon ABI;
these coordinates still do not establish the missing CSB-root-to-Sprite
registration relationship. Quest/NPC/emoticon target/role inputs are unchanged.

The separate detailed-status parent is FloatingUiScene Project964, referencing
`UI/FloatingUi/CharacterInfo_StatInfo_Detail.csb`
(`bef3c2ea4e65e8fae600649bc4c8567ad88ce981fb9b59e56bb6b4fb5ffe4889`).
Its left7140/right6400 lists have authored extent374×472 and margin6, but no
children. Held row templates do exist: `CharacterInfo_StatInfo_Detail_List.csb`
(`e8467fb893eb6558711975aea0783ee57fa741100974b19d33efc759f5417154`)
has group title3760, nested List3224 and favorite controls;
`CharacterInfo_StatInfo_Detail_Text.csb`
(`59f0bb484d98539de2c457e7d72e6a180e09d25bfd4c306adbb44ca3e43f9927`)
has stat label3456, value3044 and favorite controls. The remaining missing input
is the original stat/group/left-right row assignment, dynamic group sizing and
favorite action contract. Template possession is not that assignment. The
existing owner grouping is not promoted to original-client layout evidence.

## One combined private installation input

The separately delivered v10 includes v8 plus these original character scopes;
it needs no installed v8/v9 base. There are46 raw original files,26 scene trees
and25 explicit partial scopes. The producer reports no static dependency
blocker; retained equipment templates are not automatically active screens.

- Drive ID: `1lVKi2wDS9bRtbPbEaqL6f7c5W_962r3I`.
- ZIP: `TWILIGHT_current523_main_game_original_UI_combined_v10_20261105.zip`.
- ZIP bytes: **13,294,278**.
- ZIP SHA256: `744fd8c4ba1c9313f8d8ba8479a2bff0ecfd20b58d9f3bd1e8c951e33da92009`.
- Manifest pin: `05f56e414fac5b41351074ab5a3d5d6a70f7c5d53ab12db97cf61ca98ea1b37c`.
- Relative destination: `source-ui/current523-main-game-original-ui-v10`.
- Root layout: `original_ui.json`, `receipt.json`, `originals/UI/...`.

Select the extracted root with `--source-ui=<root>` and
`--source-ui-sha256=<manifest pin>`, or `TWILIGHT_SOURCE_UI` and
`TWILIGHT_SOURCE_UI_SHA256`. ZIP hash is not the manifest pin. The private
Drive upload succeeded; metadata reports the same size and owner-user-only
permissions. Consumer installation and execution remain unconfirmed. v9 is an
unshipped intermediate, preserved locally; v8 and all older packs/configs/saves
are preserved. No public original assets, selector rewrite or old-pack fallback
is introduced.
