# PR #122 빠른 색상·기존 모션 연결 마감 — 2026-10-19

기존 PR #122 브랜치와 전체 커밋 이력을 유지했다. 시작 HEAD는 `c5c0425d`, 제작 커밋은 변신 `4dcdf1a`, 몬스터 `20d1a91`이다.

## 이번 제작 완료

- 기존 8방향 모션을 변신 33개(공유 기반 랜스 마스터 포함), 몬스터 21개에 명시적으로 연결했다. 새 PNG/원화 자세는 0이다.
- 대상 498종 중 모션 경로 미연결 53종을 연결했다. 정적 경로 연결은 498/498이며 기존 승인 405종의 프로필은 정확히 보존했다.
- 랜스 마스터 레드/블루의 원래 색상, 남성 다크엘프/총사의 여성 기반 공유, ID/능력치/공격 속도/이동 물리/AI/드랍/저장 데이터를 보존했다.
- 색상은 개별 프로필의 `color_tint`에만 적용하며 원본 PNG·SpriteFrames 파일을 수정하거나 복제하지 않았다. 원격에는 한 배치로 올린다.

## 원화 및 남은 작업

**이 작업의 완료는 기존 프로젝트 모션 공유 연결의 완료다. 고유 원화 제작이나 원작 외형 승인 완료가 아니다.** 기존 승인 이력 405/498(정상391 + 프레임 부족14), 미승인 원화93 및 기존 SOURCE_HOLD/실패/UNRECOVERED 기록을 변경하지 않았다. 원본 WIP·이전 증거는 보존한다.

여왕·몽크·놀·유니콘 등의 화면에는 기존 유사 개체의 표시용 모션을 연결했다. 여왕 고유 복장, 몽크 고릴라 구조, 놀의 신규 원화, 유니콘 뿔은 이 재사용으로 완성되지 않는다. 총사/이실로테는 기존 원거리 활 모션 대체이며 총 원화가 아니다. 서커스 악기/카드·낚싯대·요정/고유 보스의 세부 구조도 원화 후속이다. 표의 `basis`와 원장에 각 한계를 명시했다.

기존 프레임 부족14의 6–8자세 걷기·전용 run, Android 실기기, 비공개 SPX의 권한/절대시계/레이어/스킬 대응은 별도 잔여다. 기존 프레임을 복제해 신규 자세로 계산하지 않았다.

## 검증과 전달

- [제작 원장 및 변경 전 프로필](../../../../../data/pr122_palette_finish_20261019.json), [정적 결과](static-result.json), [재개 상태](checkpoint.json).
- `tests/pr122_palette_motion_test.gd`는 54개 실제 프로필의 방향별 이동·공격·피격·사망 소스와 색상 적용을 production resolver로 검사한다. 기존 CI 검사를 유지하며 Remaining106 워크플로에 이 검사를 추가했다.
- 실제 실행 결과는 `validation.json`에 기록하고, 정확한 게임 SHA의 CI 결과는 기존 [PR122 검사](https://github.com/zoog136-hash/-/pull/122/checks)에서 확인한다. 과거 HEAD의 성공을 이번 성공으로 사용하지 않는다.
- 새 PR·main 병합·rebase·force push 없음. 원격이 변경되면 푸시 전 확인하고 이력을 보존한다.

## 명시적 재사용 표

| 대상 | 기존 모션 제공 ID | 색상 | 범위/한계 |
|---|---|---|---|
| transform:44 | transform:176 | `d9e2eb` | armored_spear_base |
| transform:179 | transform:44 | `ff766b` | same_lance_master_base_source_tinted |
| transform:182 | transform:44 | `75aeff` | same_lance_master_base_source_tinted |
| transform:231 | transform:44 | `edcf8a` | armored_spear_variant |
| transform:411 | transform:413 | `efc8a2` | female_chain_armored_fighter |
| transform:142 | transform:283 | `efc8a2` | male_chain_armored_fighter |
| transform:139 | transform:346 | `bc9ddc` | female_dark_armored_melee_proxy |
| transform:138 | transform:139 | `bc9ddc` | same_as_female_directional_visual |
| transform:141 | transform:135 | `c4d5ef` | female_ranged_proxy_bow_not_firearm |
| transform:140 | transform:141 | `c4d5ef` | same_as_female_directional_visual |
| transform:393 | monster:드레이크 | `d5b3ef` | winged_dragon_proxy_not_halpas_original |
| transform:267 | monster:아시타지오 | `c7a0e3` | horned_demon_proxy_not_girtas_original |
| transform:375 | transform:102 | `efcf91` | staff_caster_proxy_not_fishing_rod |
| transform:376 | transform:375 | `bbd6b9` | same_fishing_family_proxy |
| transform:339 | transform:345 | `aacdc2` | armored_sentinel_variant |
| transform:338 | transform:399 | `e5a5a7` | armored_greatsword_variant |
| transform:191 | transform:102 | `bdd6f3` | hadin_caster_variant |
| transform:166 | transform:102 | `ab92cf` | hadin_dark_caster_variant |
| transform:406 | monster:서큐버스 | `f1b28c` | winged_humanoid_fire_proxy |
| transform:405 | monster:풍룡의 둥지 하피 | `f2c79b` | winged_fairy_proxy_not_native_fairy |
| transform:386 | transform:137 | `f2bdd6` | female_pink_caster_proxy |
| transform:360 | transform:102 | `cfb0e5` | circus_caster_proxy_no_card_art |
| transform:359 | monster:스파토이 | `e8ce91` | circus_puppet_proxy_no_trombone_art |
| transform:358 | transform:212 | `e5b3a4` | circus_performer_proxy_no_drum_art |
| transform:357 | transform:345 | `edc79a` | circus_leader_armored_proxy |
| transform:276 | transform:413 | `e9d1e5` | female_humanoid_proxy_no_maid_costume |
| transform:268 | transform:345 | `e6eaf3` | celestial_armored_knight_variant |
| transform:197 | transform:399 | `c2cdec` | armored_commander_variant |
| transform:155 | transform:258 | `c6b5db` | reaper_variant |
| transform:123 | transform:141 | `edc2d6` | female_ranged_proxy_bow_not_firearm |
| transform:16 | monster:아시타지오 | `f1ad8b` | horned_fire_demon_variant |
| transform:9 | monster:정예 다크엘프 | `b8b0df` | dark_ranged_humanoid_proxy |
| transform:4 | transform:345 | `f0dfab` | celestial_knight_variant |
| monster:얼음 여왕 | transform:137 | `c5ddff` | female_caster_proxy_native_queen_WIP_preserved |
| monster:그림 리퍼 | transform:258 | `c4b5d5` | reaper_family |
| monster:말하는 섬 들개 | monster:불신의 다이어울프 | `d4bb9d` | canine_proxy_native_dog_HOLD_preserved |
| monster:천상계 성광기사 | monster:천상계 천상수호자 | `f1e5bb` | celestial_armored_knight |
| monster:교만의 왕자 데우스 | monster:커츠 | `ddc5a1` | armored_boss_proxy |
| monster:교만의 제라키엘 | monster:서큐버스 | `cbb5e7` | winged_humanoid_boss_proxy |
| monster:놀 | monster:늑대인간 | `d2b18e` | canine_biped_proxy_native_gnoll_WIP_preserved |
| monster:로머 | monster:오우거 | `c2bd9b` | large_biped_proxy_native_identity_unverified |
| monster:분노의 데스 리퍼 | transform:258 | `f0a7a1` | reaper_rage_variant |
| monster:사라만다 | monster:도마뱀 | `f2b285` | lizard_fire_variant |
| monster:알비노 몽크 | monster:에티 | `e0e9f5` | white_primate_proxy_native_gorilla_WIP_preserved |
| monster:알비노 유니콘 | monster:알비노 디어 | `e4ddf8` | quadruped_proxy_no_unicorn_horn_native_HOLD_preserved |
| monster:에스카로스 치프 | monster:마이노 | `c4b2dc` | large_biped_chief_proxy |
| monster:오만한 아스모데우스 | monster:아시타지오 | `d2b2db` | horned_demon_boss_variant |
| monster:오만한 우그누스 | monster:아시타지오 | `ddc79f` | horned_demon_boss_proxy |
| monster:왜곡의 메두사 | monster:라미아 | `a6c7b2` | serpentine_humanoid_variant |
| monster:왜곡의 제니스 퀸 | monster:라미아 | `cdb3e1` | serpentine_queen_proxy |
| monster:욥니르 | monster:에틴 | `b9d2de` | large_biped_boss_proxy |
| monster:잔혹한 아이리스 | monster:서큐버스 | `ddaec7` | winged_female_boss_proxy |
| monster:질투의 공주 이자벨 | transform:137 | `dcc2eb` | female_caster_boss_proxy |
| monster:탐욕의 여왕 벨리엘 | monster:서큐버스 | `e1c4a1` | winged_queen_proxy |

로컬 Godot 4.7.2 실행9/9 PASS(skip/not_run0), 새54프로필 motion resolver15,590검사 실패0, 변신413 전환·공격 유지, 전투 피해 공식346비교 및 타이밍 회귀 PASS. 이는 모든93종의 고유 원화/사용자 외형 승인을 뜻하지 않는다.

실제 Main OpenGL Compatibility60프레임 부팅 PASS(llvmpipe, script/engine error0). 생성된 내비게이션26파일은 SHA 검증 압축본으로 별도 보존하고 기존 추적 캐시 바이트를 유지했다. Android 실기기/전93종 Main 독립 외형 승인은 NOT_RUN이다.
