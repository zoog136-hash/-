# TWILIGHT Codex internet allowlist — researched Lineage M sites (2026-10-11)

The following 13 exact hostnames were extracted from actual TWILIGHT source-reference documents in `main` and PR #84. This is a documented set, not a claim that every site ever visited in unrecorded browser research is known. Reference screenshots are for visual comparison only; usage/redistribution rights require checking.

## Copy into Codex Cloud environment > Internet access > Additional allowed domains

```text
lineagem.plaync.com
rc-wstatic.plaync.co.kr
probability.plaync.com
lounge.plaync.com
lineagem.inven.co.kr
www.inven.co.kr
m.inven.co.kr
game.inven.co.kr
saimplay.tistory.com
what.tistory.com
jessinews.tistory.com
www.gamechosun.co.kr
www.gamemeca.com
```

### Evidence in repository

- `docs/playable-maps-20261011/REFERENCE_EXPANSION.md` (PR #84): NC official site, Inven.
- `docs/MONSTER_WORLD_SOURCES.md`: Inven, `saimplay.tistory.com`, `what.tistory.com`, NC lounge.
- `docs/UI_RENEWAL_FIDELITY_20261009.md`: `www.gamemeca.com`, Inven, official guide.
- `docs/CONSUMABLES_20261008.md`: NC archived static guide, mobile Inven, probability.
- `docs/EQUIPMENT_BLESSING_SCROLL_20261009.md`: `jessinews.tistory.com`, Gamechosun.
- `docs/FULL_INVEN_CATALOG_INTEGRATION_20261009.md`: `game.inven.co.kr`.
- `docs/NON_SKILL_OPTION_AUDIT_20261008.md`, `docs/PR70_CRAFTING_RESEARCH_20261010.md`, `docs/ORIGINAL_OPTIONS_RECHECK_20261009.md`: Inven & NC.

## Optional domains for future browsing (not documented as previously researched)

```text
www.google.com
www.bing.com
www.youtube.com
i.ytimg.com
```

## Scope and security notes

The environment internet allowlist cannot be changed merely by committing this file. The owner must edit the Codex environment UI and publish again. Keep package-manager access as required for Godot installation and other tools. Whitelisting a domain does not guarantee its pages or media can be fetched: access may require permission, redirects, antibot checks, or other asset-CDN hosts. Check failed requests and add only verified missing destination hostnames. In particular, never submit private Google Drive links or credentials to a third-party research page. The broad All domains option is convenient for exploratory image research but expands risk of data exfiltration and untrusted downloaded content; use it only if the owner accepts that.
