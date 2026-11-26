# Exact redundant reads: audit and integration

The target is rereading the exact same verified input in one synchronous action,
not all uses of the same file over time. The baseline is main immediately after
#870 (`ccd0b43a`); the separately approved #876 inventory change is not
duplicated here. The original resource data, save format, control offsets and
update mechanism are unchanged. Nothing in this audit measures the phone.

A source-wide static sweep read 981 production GDScripts. It found 685 matched
file/scene calls and 85 function-and-argument groups with more than one matching
site. These are triage results, not 85 proven duplicates: assigned paths, later
freshness checks, alternate branches and distinct representations can share a
variable or literal. The four code reviews checked original UI, effects and
field metadata, skill/crafting/loot, and shop/quest readers. The following
documents record accepted changes, test limits and known exclusions:

- [Original UI scene staging](original-ui-repeated-scene-read-audit-20261124.md).
- [World and effect payloads](runtime-pinned-single-read-20261124.md).
- [Skills, crafting and loot](skill-craft-loot-exact-reads-20261124.md).
- [Shop and quest payloads](scope-d-source-read-audit-20261124.md).

Required reads kept separate: external edit and post-write save checks;
verifying installation bytes separately from choosing a ZIP member; layout-only
geometry versus admitted active scene; checking newly written files; and
re-verification when paths or pinned bytes may legitimately have changed. Shared
or narrow bake paths judged likely to cause a large unnecessary rebuild were
not changed solely to make the count larger. Fixed-size PR238 drop registry is
a verified candidate but was not edited without its registered source fixture.
No lifetime cache or checking interval was widened. Poorly bounded payloads were
not changed to a new unbounded allocation.
