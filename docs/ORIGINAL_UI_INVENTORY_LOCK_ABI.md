# Original item-detail lock controls

The actual selected item's existing lock operation now consumes the original
lock/unlock controls. This is a partial item-detail scope. It adds no ownership,
lock, save, use, equip or collection rule. No new tests, execution, rendering or
CI were run; actual lock interaction and pixels remain unverified.

## Original and current owner

- Parent `UI/ToolTipScene.csb`, SHA256
  `9304dcb5730fba9a155f73a291a6e87f96768156cee972929b003386e3904a1d`,
  original hidden Inventory_ToolTip_Layout Project1012 at[1008,345]. Its explicit
  activation follows the actual visible bag's `detail_active` state.
- Child `UI/ToolTip/ToolTip_HudType_Right.csb`, SHA256
  `7aa63b5159335c1558e9bc83f8155979b1a9bf4ee37eaed24c7e2652c392c1ce`.
- root616→ItemInfo36036→Nd_Unlock37228 contains Image37860
  `Com_Btn_UnLock.png` and Button37284.
- The same ItemInfo→Nd_Lock36120 contains Image36708 `Com_Btn_Lock.png`
  and Button36176. Group visibility follows the existing selected reference's
  actual `character_state.item_locks` boolean, using the same absent=false
  semantics already used by the owner. It is not inferred from an icon name.

Both original buttons are transparent hit controls, alpha0, extent46×36 at
[32.04999923706055,176.14149475097656]. Their sibling image supplies the actual
visible lock icon. Alpha is never promoted. Existing Default/Button textures
are retained and loaded unchanged.

The source renderer omits an invisible button title only when its serialized
alpha is integer0 and its own Alpha timeline is absent or every serialized
IntFrame is integer0. Any nonzero/unknown track retains normal font checks.
The Button receiver separately rejects this omission for an opaque source
widget. Raw `Button` title metadata remains intact; no replacement font is
created to render pixels that are permanently transparent.

The adapter fresh-checks the visible actual detail, opaque `selected_item`
reference, boolean lock state, identical existing lock_button and its disabled
state, then calls **only `bag._toggle_lock()`**. That owner retains
`world._set_item_locked`, state refresh and save failure handling. The source
adapter claims callback dispatch, not persistence success. A selection change
invalidates the previous presentation/gesture before another item can be
modified; it never reconstructs a reference from a name or numeric ID.

After successful source mount only the existing lock_button is hidden; close,
owner hiding, source failure or controller replacement restores its captured
visibility. Actual source hit Controls are used for Android routing and
PointerTransfer exclusion. The source wrapper follows the existing workspace
and bag layer, preserving the original node transforms and higher overlays.
Other item details/actions and the existing timed-name header retain their
separate lifetimes. The original `등록` controls are not assigned to quickslot
registration, and source enhancement/dissolve/repair/find/compare controls are
not relabelled as generic use.

## Combined private input v19

Drive ID `1Hf9MXiXsjMhFZwLe_gXyqb90fbQhMROG`;
`TWILIGHT_current523_main_game_original_UI_combined_v19_20261105.zip`;
**13,488,763** bytes; ZIP SHA256
`c0f21627819e85fd11d5b0a9e837c7878349f629cde5f5aef42a4120175cb615`;
manifest pin
`d561a9b420d865052ad25772e4b7fc3e96fd5150ea1dd19082f00616252f0ab2`.
Relative installation directory:
`source-ui/current523-main-game-original-ui-v19`.
Root remains `original_ui.json`, `receipt.json`, `originals/UI/...` with the
existing one-pack CLI/env selector. Earlier versions are not an installed-base
prerequisite.

v19 retains every v18 scope and adds only these original lock controls and
their dependencies. The60 raw files/38 scene trees/37 partial scopes and static
producer blockers0 are packaging facts, not completed roots or game-use counts.
Private delivery succeeded; installation, execution and rendering are unconfirmed.
All previous originals, packs, user settings, saves and fixed denominators are
preserved. Whole560 and95% use completion are not claimed.
