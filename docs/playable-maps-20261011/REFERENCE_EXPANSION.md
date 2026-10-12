# Reference-informed authored terrain expansion

The user requested: “리니지m 사이트 검색해서 확장해봐” after receiving the first-map screenshots. This authorizes reference-informed expansion. It is not a statement that the previous art exactly matches Lineage M. Main and PR83 are preserved; this work is on `feature/twilight-reference-expansion-20261011`, based on PR83 `4dc7f3e2199099d3108ee3909d9661e4f8ef469c`. Main was checked at `2f5ae1013da5c7281d3020719d8a723a23adb8cc`.

## References inspected on 2026-10-11

| Reference | Observation and use | Limits |
|---|---|---|
| [Official-site community Giran screenshot](https://lineagem.plaync.com/board/free/view?articleId=65143adae08a821fd62f20c9) | Irregular stone paving, planted borders, vertical landmarks and distinct NPC silhouettes inform town detail. | A user screenshot on the official site, not an authoritative coordinate source. |
| [Official Heine castle media page](https://lineagem.plaync.com/board/movie_clip/view?articleId=658bdd55e40fbb3667d7ec48&categoryId=6584eff7db495803da316c8a) | Located during research. | The full image download failed; not used to claim implemented castle or coast geometry. |
| [Albino Basin visual guide](https://www.inven.co.kr/board/lineagem/5056/21244) | Viewed map and waterfall/arch entrances. Mossy wet terrain and mineral rock replace blanket white coloring. | 2023 reference; not a complete current map or exact floor plan. |
| [Escaros gameplay](https://www.inven.co.kr/board/lineagem/5064/38258) | Viewed gray masonry, ruined architecture and cobbled terrain. Used for restrained ruined-stone material choices. | 2021 event screenshot; does not establish five exact region IDs. |
| [Official 2026 update](https://lineagem.plaync.com/conts/260826_update) | Confirms the announced fourth Albino area. | Announcement does not establish geometry or permit assuming the existing TWILIGHT layout is original. |

Only URLs and our observations are committed. Third-party screenshots are research references and are not packaged as game textures.

## Actual changes

- Two new original PNG atlases: 16 ground materials and 16 transparent environment sprites. Full built-in image generation prompts and SHA-256 manifest are in `assets/maps/reference_expansion_v2/`.
- Explicit runtime material profiles for the existing 25 TWILIGHT maps: `aden_world`, `oman_01`–`oman_10`, `domination_summit`, `escaros_01`–`escaros_05`, `albino_01`–`albino_04`, `faith_01`–`faith_04`.
- Shared GPU textures and atlas-cell UV selection. No additional maps, collision bodies, portals or encounter tables are fabricated. Existing per-floor topology, streaming, combat, drops and saves remain.
- New cottages, market stalls, trees, portals, columns, crystals and shrines replace compatible existing scenery. Low groundcover uses the prior small debris textures instead of scaled-down tall rocks, avoiding misleading visual obstacles on clear paths.
- Albino render colors distinguish wet earth, cool rock and mineral areas. Four JSON files change only `render_style`; all other fields are compared with the parent commit.
- Separate A3 `l1_4`: new terrain atlas, blocked-cell scenery and visible NPC silhouettes. Source collision bytes are unchanged. Large source decorations require a solid footprint. Other A3 maps retain their earlier renderer.

## Completion categories

These changes are **authored graphics expansion**, not ORIGINAL_RESTORED. Exact original mapping and original art remain 0/25. The existing 25 TWILIGHT maps and A3 `l1_4` remain distinct; no equivalence is asserted. Architecture/material choices are design decisions, not decoded S32 meanings.

Validation results and actual screenshots are recorded in the accompanying evidence checkpoint. Linux software OpenGL results are not Windows or Android device verification.
