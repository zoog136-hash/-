# Selected crafting conditions to original Production fields

PR286 continuation after20f52cc9e6490c8de5a67ffa3bdf83aa8bcfccec. This extends the existing original production action/quantity/search group with a coherent condition/empty-selection state. It changes no recipe selection, material selection, count bounds, eligibility, clock, quota, price, probability, transaction or save rule. Code is unexecuted/unverified; no tests/compile/game/render/fullCI/upload/merge were performed.

## Actual selected recipe supplier

`renewal_crafting._refresh_quote()` already reads `current_id`, obtains that actual recipe from the existing crafting service, then applies the existing patch523 equipment.material_selection result when present. The new read-only `source_condition_display` is derived from that **same final recipe** before the existing quote/display code continues. It never selects another recipe or invents a source class/item relation.

Snapshot shape:

```gdscript
{
    "recipe_id": current_id,
    "level_text": "", "period_text": "", "quota_text": "",
    # Only for a current523 recipe accepted by existing Conditions.valid:
    "source_conditions": actual_recipe.craft_conditions.duplicate(true),
    "basis": "actual selected current523 recipe craft_conditions and existing Conditions formatter/context; no new eligibility or clock policy"
}
```

- Level text uses only the existing validated condition.min_level/max_level, preserving the service's lower/upper bound meanings. No item-use class/level rules are substituted for crafting qualifications.
- Period text calls the existing `patch523_craft_conditions.window_text(active_window)`. It preserves original DateTimes fields, selected offset and the existing explicit game-clock label; no new UTC/KST conversion or boundary policy is implemented by UI.
- Quota text calls the existing `Conditions.brief(recipe, world._patch523_craft_context())`, exactly as this same owner already does for its current probability/condition display. Current used/limit counts, unresolved markers and existing weekly/lifetime clock-policy wording remain that formatter's. The UI does not advance/reset counters, infer server/account/character scope, add a quota or change eligibility.

Absent/noncurrent/invalid conditions produce empty fields, not preview values or implicit unlimited/zero qualifiers. Clearing the owner's filtered recipe list clears the snapshot. Source conditions retain the existing source_level_fields, quota.source_restriction, active_window DateTimes and clock_origin metadata when present.

## Exact source receiver and parents

The already proven mount remains:

1. `UI/ProductionScene.csb`, SHAcae6672733b914c0143fe376574e73012b0cd628113002693f0639c877f47328, Project132.
2. `UI/Production/Production_All.csb`, SHA328546745405eac58203853570d76e07d9cc95477ac4ecd701d786651e3786ec, Project14392.
3. `UI/Production/Production_Tab_List.csb`, SHA14c9c7ed1333e0b20a2362d9c095065716e91cc4641e1b77adefe21d03fd1afb.

No new parent, slot insertion, fit, position or animation is created. Existing renderer and source Project ancestry retain original widget transforms/fonts/colors/layout.

| Actual display | Exact existing original node/path | Authored role evidence |
|---|---|---|
|Validated selected recipe level limits|Node444/Nd_Production14172/Text26204 Label_Limited_Level|Original preview `레벨 제한 : 80 이상`; only its dynamic values are replaced.|
|Existing service quota summary|Node444/Nd_Production14172/Panel_Limited18004/Text21148 Label_Limited|Original limited-count summary preview; the service's actual quota caption/count replaces the example server-count text. No source server/account/character marker is activated.|
|Existing service active-window text|Same Panel_Limited18004/Text20368 Label_Period|Original preview `기간 : 2018.03.12-12:20 ~ 2018.09.12-12:20`.|
|No actual selected recipe|Node444/Text13448 Label_Notice|Original literal `제작할 아이템을 선택해주세요.`; no replacement label or new layout.|

`source_main_production_controls` admits these optional offsets only when they exist in the selected pack. It consumes snapshots only when recipe_id equals the actual current_id already validated against the owner's recipe_ids. On a valid selected recipe, known condition fields are updated and missing fields cleared/hidden; the original limited panel is visible only when quota/period text exists. Its authored touch area consumes read-only input and blocks through its real original control. The source Class label, server/account/character scope markers, failure notice, progress/cancel/result and ambiguous source controls are not inferred.

If the new original empty-selection notice is available, a genuinely empty current_id now presents that original notice with Nd_Production hidden and all existing source craft/reset/+10/+50 controls disabled. It does not choose a recipe, clear inventory or change quantities. Older packs without that notice retain the previous selected-recipe-only behavior. A valid selection still uses the same original action and quantity callbacks. Recipe/action changes retain the existing close/remount flow, and loss/hide/exit of the actual workspace owner clears the source presentation. Ordinary unchanged condition text is not rewritten every frame.

The source renderer/provider APIs are unchanged. The only new data boundary is the above read-only snapshot from the actual crafting view to its UI-owned original receiver; image/data/map/integration owners do not need a new adapter.

## Separate local v42

v42 retains v41 and adds four original Text offsets26204,21148,20368,13448 to the existing Production_Tab_List scope. Original bytes/pixels are unchanged.

- `TWILIGHT_current523_main_game_original_UI_crafting_conditions_v42_20261106.zip`,14,236,730B.
- ZIP SHA256 `84eb192071cb036b4ac3d8e05a8af4a3bf63d4f2e12cbe043924262ee8c18160`.
- Manifest pin `501692d6181a6a22d2f077ac5b7da90558a8cc56cfd4f7c77f435deb8b0aa11a`.
- Proposed relative root `source-ui/current523-main-game-original-ui-v42`.
-101 originals/60 scoped scenes/59 partial scopes are packaging quantities, not overall UI progress or observed game use.

No remote ID/upload/install/index/phone/source-bank change. Frozen v30/62ZIP and all original/local candidate/config/save inputs are preserved. Map/data/image owners' files and pending fixed PR281/PR287 publication scopes were not changed. Runtime/memory diagnosis remains paused and exclusions remain intact.

## Other source groups considered, without false role assignment

This implementation used the source-declared production field group instead of forcing unrelated candidates:

- Held `Recovery_All.csb` SHA2c426a0f63c2c913f9316dbec41caabc8bf43370adf7430f5e4838161a8fbb0e explicitly titles itself `TJ의 쿠폰`/ordinary equipment recovery and has historical enchant-failure/coupon instructions. It is not established as the current death-exp/item-loss recovery service UI, so those live death records were not inserted there.
- MonsterBook_All's general/mission/collection controls do not currently have a matching typed family selector in the existing progress panel. Its actual `history` flag means include historical definitions, not mission/general mode. Those modes were not aliased or a representative monster chosen.
- Store_SaleAuto/Storage_KeepAuto select-all/MAX instructions are distinct from the current physical-rule/keep-quantity setup. The absent original all-row registration contract was not replaced with a global save, single target, or arbitrary quantity action.

These are precise limitations of those candidate groups, not a claim all remaining original UI is impossible or completed. No excluded source targets were reactivated.
