# PR122 batch18 — 기존 시트 색상 변형 재사용 (검증 대기)

기준 HEAD: `a56520436f618c5cd185f9a354a742251991de1b`.

## 결과
- 사용자 지시대로 **기존 프로젝트 원본 시트를 다시 사용**하고 이름별 `color_tint`만 분리하여 **41종**의 애니메이션 프로필에 연결했다.
- 기본 대체 이미지 좌표가 같은 후보 **30종**, 이름·계열이 유사한 추가 후보 **11종**. 총 14개의 기존 `SpriteFrames.tres` 실물을 확인했으며, 각 원본에 8방향 `idle/walk/attack/hit/death` 40개 기본 모션 트랙이 존재한다.
- 새 PNG, SPX, 다른 제3자 원본, 이동/공격 속도·피해·명중·AI·드랍·수치, 레벨·충돌·저장 형식의 변경 없음. 원본 리소스 파일 자체의 덮어쓰기/복제 없음.
- 드라이어드·변이된 골렘·심해어·일부 보스는 **실제 원작 형태가 확인된 동일 캐릭터가 아닌 기존 TWILIGHT 내부의 대체 외형**이다. 색상 톤을 변경한 것만으로 외형 동일성, 기존 부족 프레임, 원작 고증이 해결됐다고 집계하지 않는다.
- 외형을 바꿀 적정 8방향 동물형 기반이 발견되지 않은 **알비노 디어, 알비노 몽크, 알비노 유니콘**의 기존 제작/HOLD는 그대로 유지한다.
- 과거 WIP인 검은숲 늑대, 분노의 데스 서번트, 가디언, 알비노 드라이어드·골렘, 커스번, 화염의 엔트 등도 기존 소스 및 실패 증거를 보존했다. 게임은 일단 명시된 공유 시트를 사용하지만 원형 고증 독립 검토는 미완료이다.
- **승인 누적 399/498 변경 없음**, PR #122 상태 파일·이전 완료 승인·기존 HOLD 증거 변경 없음. 이 41종은 **화면 연결 및 원본 트랙 확인**, **실제 Main·Android 외형 검증 전**이다.

## 기록

연결 감사 원장: `data/pr122_palette_reuse_20261019.json`. 런타임 적용 프로필: `data/combat_animation_profiles.json`. 기존 `tests/animation_catalog_test.gd`에 41개 출처·색상·필수 방향 모션·프로필 식별 검증 추가. 이 기록은 리니지M 원본 시트가 확보되었다는 뜻이 아니다.

특기: `monster:알비노 심해어`, `monster:에바 왕국 심해어인`은 **알비노 피쉬맨 변신의 인간형 대체 시트**를 공유한다. 물고기 몸체 원형이라고 주장하지 않는다. `monster:천상계 천사궁수`는 해골 궁수 대체, `monster:테베 아누비스/호루스/오시리스`는 갑옷 인간형 대체다. 새 컨셉 원화가 없는 동안 표시용으로만 적용한다.

## 41개 연결표

| 대상 | 시트 제공 개체 | 색상(RGB) | 매칭 근거 |
|---|---|---|---|
| 테베 아누비스 (`monster:테베 아누비스`) | 커츠 (`monster:커츠`) | `c6b6e3` | shared_existing_fallback_atlas_cell |
| 테베 호루스 (`monster:테베 호루스`) | 커츠 (`monster:커츠`) | `c6b6e3` | shared_existing_fallback_atlas_cell |
| 테베 오시리스 (`monster:테베 오시리스`) | 커츠 (`monster:커츠`) | `c6b6e3` | shared_existing_fallback_atlas_cell |
| 아크모 (`monster:아크모`) | 커츠 (`monster:커츠`) | `c09cc3` | shared_existing_fallback_atlas_cell |
| 제로스 (`monster:제로스`) | 커츠 (`monster:커츠`) | `bcb1e1` | shared_existing_fallback_atlas_cell |
| 검은숲 늑대 (`monster:검은숲 늑대`) | 불신의 다이어울프 (`monster:불신의 다이어울프`) | `84a78c` | wolf_quadruped_shape_exception |
| 검은숲 거미 (`monster:검은숲 거미`) | 왜곡의 웅골리언트 (`monster:왜곡의 웅골리언트`) | `84a78c` | shared_existing_fallback_atlas_cell |
| 오만의 탑 공포의 악마 (`monster:오만의 탑 공포의 악마`) | 아시타지오 (`monster:아시타지오`) | `bea4c5` | shared_existing_fallback_atlas_cell |
| 지룡의 둥지 대지수호자 (`monster:지룡의 둥지 대지수호자`) | 검은숲 나무정령 (`monster:검은숲 나무정령`) | `a1bb85` | shared_existing_fallback_atlas_cell |
| 테베라스 아누비스 수호자 (`monster:테베라스 아누비스 수호자`) | 커츠 (`monster:커츠`) | `c6b6e3` | shared_existing_fallback_atlas_cell |
| 테베라스 호루스 수호자 (`monster:테베라스 호루스 수호자`) | 커츠 (`monster:커츠`) | `c6b6e3` | shared_existing_fallback_atlas_cell |
| 아틀란티스 심해창병 (`monster:아틀란티스 심해창병`) | 커츠 (`monster:커츠`) | `84d6dc` | shared_existing_fallback_atlas_cell |
| 아틀란티스 심연수인 (`monster:아틀란티스 심연수인`) | 커츠 (`monster:커츠`) | `84d6dc` | shared_existing_fallback_atlas_cell |
| 마계 악마전사 (`monster:마계 악마전사`) | 아시타지오 (`monster:아시타지오`) | `bb8ea9` | shared_existing_fallback_atlas_cell |
| 천상계 천사궁수 (`monster:천상계 천사궁수`) | 해골 궁수 (`monster:해골 궁수`) | `f1e7b5` | shared_existing_fallback_atlas_cell |
| 가디언 (`monster:가디언`) | 아이언 골렘 (`monster:아이언 골렘`) | `b3aa85` | shared_existing_fallback_atlas_cell |
| 공포의 레서 데몬 (`monster:공포의 레서 데몬`) | 아시타지오 (`monster:아시타지오`) | `be91b7` | shared_existing_fallback_atlas_cell |
| 공포의 켈베로스 (`monster:공포의 켈베로스`) | 혼 켈베로스 (`monster:혼 켈베로스`) | `be91b7` | shared_existing_fallback_atlas_cell |
| 교만의 제노사이더 (`monster:교만의 제노사이더`) | 아시타지오 (`monster:아시타지오`) | `d1b086` | shared_existing_fallback_atlas_cell |
| 교만의 킬 하운드 (`monster:교만의 킬 하운드`) | 혼 켈베로스 (`monster:혼 켈베로스`) | `d1b086` | shared_existing_fallback_atlas_cell |
| 그리미 (`monster:그리미`) | 글루디오 던전 구울 (`monster:글루디오 던전 구울`) | `a6c6a3` | shared_existing_fallback_atlas_cell |
| 분노의 데스 도그 (`monster:분노의 데스 도그`) | 혼 켈베로스 (`monster:혼 켈베로스`) | `e8877e` | shared_existing_fallback_atlas_cell |
| 분노의 데스 라이더 (`monster:분노의 데스 라이더`) | 커츠 (`monster:커츠`) | `e8877e` | shared_existing_fallback_atlas_cell |
| 분노의 데스 서번트 (`monster:분노의 데스 서번트`) | 고스트 (`monster:고스트`) | `e8877e` | shared_existing_fallback_atlas_cell |
| 스파이더 (`monster:스파이더`) | 왜곡의 웅골리언트 (`monster:왜곡의 웅골리언트`) | `9da6c4` | shared_existing_fallback_atlas_cell |
| 알비노 데몬 (`monster:알비노 데몬`) | 아시타지오 (`monster:아시타지오`) | `d8e8fc` | shared_existing_fallback_atlas_cell |
| 오만한 플레임 팽 (`monster:오만한 플레임 팽`) | 커츠 (`monster:커츠`) | `cb9d75` | shared_existing_fallback_atlas_cell |
| 왜곡의 타란툴라 (`monster:왜곡의 타란툴라`) | 왜곡의 웅골리언트 (`monster:왜곡의 웅골리언트`) | `b8a0d9` | shared_existing_fallback_atlas_cell |
| 커스번 (`monster:커스번`) | 아시타지오 (`monster:아시타지오`) | `d78b8e` | shared_existing_fallback_atlas_cell |
| 탐욕의 코아쿡 (`monster:탐욕의 코아쿡`) | 아시타지오 (`monster:아시타지오`) | `c5ae71` | shared_existing_fallback_atlas_cell |
| 알비노 심해어 (`monster:알비노 심해어`) | 알비노 피쉬맨 (`transform:350`) | `d8e8fc` | similar_fishman_family |
| 에바 왕국 심해어인 (`monster:에바 왕국 심해어인`) | 알비노 피쉬맨 (`transform:350`) | `84d6dc` | similar_fishman_family |
| 알비노 드라이어드 (`monster:알비노 드라이어드`) | 검은숲 나무정령 (`monster:검은숲 나무정령`) | `d8e8fc` | tree_species_proxy |
| 알비노 변이된 골렘 (`monster:알비노 변이된 골렘`) | 아이언 골렘 (`monster:아이언 골렘`) | `d8e8fc` | golem_species_proxy |
| 탐욕의 엔트키아 (`monster:탐욕의 엔트키아`) | 검은숲 나무정령 (`monster:검은숲 나무정령`) | `c5ae71` | ent_species_proxy |
| 화염의 엔트 (`transform:407`) | 검은숲 나무정령 (`monster:검은숲 나무정령`) | `f0a36a` | fiery_ent_species_proxy |
| 플래티넘 바포메트 (`transform:242`) | 바포메트 (`monster:바포메트`) | `ead4ef` | same_baphomet_family |
| 각성 켄라우헬 (`transform:260`) | 켄라우헬 (`transform:10`) | `d3bded` | same_kenrauhel_variant |
| 토끼 소녀 (`transform:198`) | 검은 토끼 소녀 (`transform:328`) | `edb3c5` | same_rabbit_girl_variant |
| 공포의 뱀파이어 (`monster:공포의 뱀파이어`) | 뱀파이어 (`transform:397`) | `be91b7` | same_vampire_name |
| 경비병(창) 대장 (`transform:176`) | 경비병 (창) (`transform:2`) | `eed09b` | spear_guard_captain_variant |

## 후속 품질 검사

Godot 실제 `Main.tscn`에서 인게임 체형·바닥 앵커·공격 및 사망 루프를 관찰하여 후보별 점검한다. 원본 고유 외형을 확보할 경우 이 임시 `shared_visual_source` 매핑은 해당 개체만 교체 가능해야 한다. 체크를 통과하기 전까지 HOLD·프레임 품질 개선 상태를 승인으로 바꾸지 않는다. CI는 해당 커밋에서 자동으로 실행되는 기존 워크플로만 확인하며 수동 반복 실행 금지.
