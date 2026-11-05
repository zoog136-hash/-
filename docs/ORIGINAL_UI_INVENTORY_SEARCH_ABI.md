# Original inventory search input

The authored extension search entry now opens its own original input bar and
connects the existing bag query/filter. No new LineEdit, keypad, search rule,
image or layout is created. This is a partial source input scope; original
search-result rows, the full inventory and whole560 are not completed. No
additional tests, execution, rendering or CI were run.

## Original nodes and actual caller

- `UI/FloatingUiScene.csb`, SHA256
  `b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8`,
  original inventory Project1572 and its existing opening end state17.
- `UI/FloatingUi/Inventory_All.csb`, SHA256
  `c2c021fbc49f0699f2002a3f1cb73f523c3dd629bd1df567192dcb7f4da22293`.
  Search44780 is under Nd_BG_Extension43300→Nd_SearchBar44724. Its source
  Text46132 stays a literal. It is enabled only in this actual eight-slot
  extension branch; a normal-branch entry is not invented.
- The same inventory declares hidden Project728 at
  `[-407.9992980957031,78]` referencing
  `UI/FloatingUi/Inventory_Popup_Keypad.csb`, SHA256
  `3892e910ad1c6b3e04714f26402ed171a98a08fe3e7e97362cd4fe07a79478d5`.
  Clicking the authored entry explicitly opens this project without changing
  its source position. No start/loop policy is inferred.
- Root172→Nd_Input_Bar228→Nd_TextField308→TextField1472 is a **string** input,
  with font `Font/font_B.ttf`, size24, extent790×51, original anchor/transform,
  original placeholder `아이템 이름을 입력해주세요. `, and maxLength14.
  A preexisting query exceeding that source limit is preserved and declined,
  rather than silently truncated.
- Search5072/Text5132 retains `검색`; Close2808/Text2868 retains `닫기`.
  The original input backgrounds8316/7556 own their authored hit areas.

`source_main_inventory_view` connects the actual chrome search signal to
`source_main_inventory_search`. The native bag continues to consume its
owner's complete filtered `sorted_references`, including nonempty searches,
only while every row fits its authored four/eight slots and has its original
image. Additional rows still return to the existing complete owner; no repeated
row layout is synthesized. Search closes and returns the input before that
fallback, bag close or controller replacement.

## Existing input lifetime and filter

The renderer binding is `{role:"source_text_field",editor:bag.search_line}`.
`source_text_field.configure()` prepares original options/font/glyphs but
never moves the editor. After actual mount, `attach_editor()` temporarily
reparents **the same existing** LineEdit and applies original input properties.
Empty styles remove the old/default background and border; the existing font
resource and original size/limit/placeholder supply this source field. Its
original display tint/alpha follows the same source renderer cascade.

`release_editor()` or tree exit restores the original parent/order, geometry,
input settings, theme overrides and previous focus/selection without resetting
the query or replacing its existing signal connections. Password fields,
custom callbacks, flips and unavailable original glyphs remain unsupported;
a later unsupported glyph returns the editor and closes this partial input.
No missing font is supplied by a replacement font.

The current owner's live `text_changed→_on_search_changed→
_refresh_inventory_grid` behavior is preserved. Explicit Search commits any
active engine IME composition, then invokes the same current-query handler.
It does not impose a new close/reset/delayed-search policy. Close only returns
the editor and closes the popup. Android touch focuses the actual original
field and uses the existing source-button router for Search/Close. Existing
modal/death/result/pointer guards keep precedence; focus in this particular
field alone does not prevent its own source buttons from working. Escape
closes this input before closing the bag.

This renderer bridge uses engine text editing; exact shaping, caret behavior,
IME and pixel equivalence have **not** been executed or rendered. Engine
[LineEdit focus/edit handling](https://github.com/godotengine/godot/blob/master/scene/gui/line_edit.cpp)
provides the existing input lifecycle. Original font/placeholder/length/widget
size handling follows the held CSB and Cocos3.6
[TextFieldReader](https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/editor-support/cocostudio/WidgetReader/TextFieldReader/TextFieldReader.cpp).
The opaque127 placeholder default is declared by
[TextFieldTTF](https://github.com/cocos2d/cocos2d-x/blob/cocos2d-x-3.6/cocos/2d/CCTextFieldTTF.cpp),
not an inferred game value.

## Precise remaining source scope

Result ListView8940 and its row/data/selection relation remain unestablished.
They are not displayed as a completed result list. Cancel364/its icon412 has
no recovered clear callback and is not assigned one. No source cancellation,
query reset, sorting or item-use transaction is invented.

The held Array19772 entry and separate option buttons8004/4764/2864 are not
connected to `sort_inventory_now()`: their original literals are deletion date,
weight and category; the existing owner sorts grade/name/physicalID and saves
that preference. Equating these actions would introduce an unsupported rule.

## Single combined v17 private input

- Drive ID: `1pSlq_hlrie_nDDVYgDvgcdm9kE1_QBqS`.
- Filename: `TWILIGHT_current523_main_game_original_UI_combined_v17_20261105.zip`.
- ZIP bytes: **13,464,564**.
- ZIP SHA256: `fc78ef45ce2565c2654135951d14232a9d00836725b6b1772f74a683f3cf1f34`.
- Manifest pin: `9d89ca8e7319e920ae3fa6ed8567a521ce35e716721c0c49cd17a98b9d2a0ce1`.
- Relative destination: `source-ui/current523-main-game-original-ui-v17`.
- Root: `original_ui.json`, `receipt.json`, `originals/UI/...`.
- 56 raw originals /36 scene trees /35 partial scopes; producer static blockers0.

It retains every v16 input and adds only the original search entry/project and
input bar. The one-pack CLI/env selection is unchanged and requires no earlier
pack as an installed base. Private upload succeeded; consumer installation,
search interaction and rendering are unconfirmed. Earlier packs, cfg, saves,
original files and the fixed whole-source denominators remain preserved.
