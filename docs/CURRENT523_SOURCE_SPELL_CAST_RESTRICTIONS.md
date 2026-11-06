# Current523 explicit spell-cast region restrictions

Status: code connected to Main's manual/auto explicit skill request paths.
Compilation, tests, game execution, rendering and CI were not run, as instructed.
This is not observed gameplay or complete native spell-restriction coverage.

## Source and identity

The held production world-links definition pack declares `LandAttributeType`
164 as `NoSpell`, Unit 12. The held current523 original Content archive declares
Unit 12 as `SpellClassID`. A LandAttribute Value is therefore an exact referenced
SpellClass ID, not a boolean, skill name, local catalog ID or family wildcard.
The original archive and world-links pins remain unchanged.

The consumer uses the existing resolved skill's admitted current523 profile,
its canonical row hash, explicit binding and original archive identity. The
resolved `source523.spell_id`, profile row ID and binding spell ID must agree.
No additional source table, spell, stage, effect, identity or art is constructed.

## Actual call path

Main `_skill_ready` and `_cast_job_skill` call
`current523_source_spell_cast_reason(record: Dictionary) -> String` before
delegating native skill requests to their existing ready/cast owner. This covers
the existing Main manual and auto-use dispatch, before cost/cooldown/effect writes.

The map controller's `source_spell_cast_status(spell_id: int) -> Dictionary`
requires the actual active generic source field and proven current player source
cell. Its production provider calls
`spell_cast_context_for_land(land_id: int, exact_asset: String, point: Vector2i, spell_id: int) -> Dictionary`.
Exact Land, AssetPath, source cell, returned spell ID and definition pin must agree.

Only exact type/name/unit, positive integral spell references and zero Param1/2/3
are consumed. Territory 0 applies to that Land; a scoped declaration requires
the matching admitted Land territory and inclusive valid source coordinates.
A matching declaration blocks that explicit spell request. Other spell IDs do
not inherit the prohibition, and malformed applicable declarations remain held.

## Boundaries retained

- Existing legacy/local skills without an admitted current523 profile keep their
  owner's existing behavior. Their numeric identity is not guessed.
- This partial consumer does not release `NoSpell` entry/teleport holds. It is
  useful at the current source-cell request boundary, including scoped rules;
  it does not grant natural admission to a restricted Land.
- No active buff is removed and no passive, NPC spell, equipment proc, child
  stage, timed rule or `NoSpellToOther` meaning is inferred.
- Direct calls made inside another skill owner, outside Main's two dispatch
  methods, are not represented as covered. If that owner needs the same gate,
  the concrete existing callback is
  `world.current523_source_spell_cast_reason(record) -> String` (empty allows
  normal owner processing; nonempty rejects before its own cost/effect writes).
- Resources, phone installation, original exclusions, existing cost/save owners
  and admission guards remain unchanged. No source-input/catalog files changed.
