# current523 신규 맵 몬스터 배치

신규(원문 S32) 필드에 몬스터를 배치한다. 구역과 종류는 원작 정의에서, 마리 수는
TWILIGHT 자체 정책(`TWILIGHT_CURRENT523_TERRITORY_DENSITY_V1`)에서, 리스폰은 **게임의 기존
리스폰 규칙**에서 온다. 원작 표에는 개체 수·정확한 좌표·리스폰 주기가 없으므로 원작 수치라고
표기하지 않는다.

## 입력

- 비공개 정의 팩 `patch523-world-links` (manifest SHA256
  `2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90`).
  `lineagem_patch523_all_content_validated_and_508_520_deltas.zip`
  (SHA256 `d5192c3c…f4832`)에서 `tools/map_restore/build_patch523_world_links.py`로 만든다.
- 찾는 순서: 실행 인수 `--patch523-world-links=` → `user://patch523-world-links`
  → 프로젝트의 `private_packs/patch523-world-links`. 인수가 없을 때는 고정 SHA만 받는다.
  `private_packs/`는 `.gdignore`로 임포트하지 않고 내용은 Git에 올리지 않는다.
- 팩이 있으면 기존 `patch523_spawn_policy` 최신 정의 검사도 함께 켜진다.

## 규칙 (`scripts/maps/current523_source_spawns.gd`)

1. Land 샤드의 `NpcSpawnPackTerritory` 행마다 Territory 사각형(원문 셀)을 구역으로 쓴다.
2. 제외: 마을 Territory, 이름에 `[QUEST]`/`[퀘스트]`/`[메인]`/`[깃발전]`/`[스케줄]`/`[이벤트]`,
   스케줄·낮밤·월드보스 조건이 있는 팩, `IsSpawn≠1`, `ServerLimitSetID≠0`, TestNPC,
   Exp 0, 공격 불가 분류와 Citizen/Guard/Slime/Siege/Party/GateKeeper/Companion 분류.
3. 마리 수: Territory 800셀당 1마리, 행당 1~6마리. 같은 팩의 여러 종류는 ID 순 라운드로빈으로
   나누며 시작 위치를 행 ID로 돌린다. 종류당 최대 4.
4. 보스(카탈로그 UI 보스 또는 `[필드보스]` 구역): 1마리. 같은 보스의 여러 후보 구역은
   생명·타이머 하나를 공유한다.
5. 리스폰 — 기존 규칙을 그대로 사용한다.
   - 일반: 기본 아덴(`data/monsters/source3_map_spawns.json`)과 같은 60~120초 랜덤,
     리스폰 위치가 화면에 보이면 미룸(`respawn_on_screen: false`).
   - 보스: `data/monsters/renewed_map_spawn_rules.json`의 기기 시계 타이머
     (아덴 Land4 = `aden_world` 28,800초 / 그 밖 = `other_maps` 86,400초). 타이머는 저장되는
     기존 `original_monster_world` 보스 상태에 함께 기록되어 게임을 다시 켜도 유지된다
     (키는 `m523_land_N` 또는 `current523_aden` 접두사로 기존 보스와 겹치지 않음).
6. 플레이어 주변 40셀 안의 구역만 생성하고(상속된 `OriginalSourcePopulation`),
   먼 개체는 풀로 돌린다. 한 프레임 2마리까지만 만든다.

각 구역은 정확한 원문 키 하나(`lineagem_base508:npc:N:spawn:V:territory:T`, 기존 키 형식)만
요청한다. 보스 판정은 현재 원본 NpcClass/Territory 이름의 `[필드보스` 표기만 쓴다.

### 구형 팩 의존 없음

- 이 기능의 코드는 base508 몬스터 팩(PACK.actor/VIEW.configure)과 base508 권위 카탈로그를
  읽지 않는다.
- `Current523SourcePopulation`은 `source_m_current523_final == true`이고
  `source_m_asset_manifest_path`가 빈 레코드만 생성한다. 구형 팩으로 해석된 레코드는
  `old_pack_record_refused`로 보류하며 대체 입력으로 쓰지 않는다.
- 현재523 레코드는 PR #269의 명단/생성 관문과 PR #272의 원본 은행이 만든다. 따라서
  main 단독에서는 구역만 만들어지고 몬스터는 나오지 않는다(안내창에 표시).
  권장 병합 순서: #272 → #269 → 이 PR.

## 실행 연결 (`current523_aden_play_controller.gd`)

- 원문 플레이 진입·원문 포탈 이동 시 전용 `Current523SourceMonsters` 루트와
  `Current523SourcePopulation`으로 교체한다. 기존 아덴 루트/개체군은 일시정지 상태로 남아
  복귀와 기존 저장(보스 상태 포함)을 그대로 쓴다.
- 신규 필드 드랍은 해당 필드의 `map_id`로 기록되어 기존 아덴에 섞이지 않는다.
- 신규 필드 보스 타이머는 기존 저장의 보스 상태(`original_monster_world`)에 함께 남는다.
- 안내창에 "원문 구역 N곳 중 M곳 사용 가능 · 보스 K"를 표시한다.

## 미리보기

```sh
python3 tools/map_restore/current523_spawn_preview.py --pack /private/patch523-world-links --land 4
```

아덴(Land4) 결과: 구역 726, 슬롯 810, 종류 153, 보스 30. 전체 1,065 Land 중 284곳에 구역이 생긴다.
이 수치는 정의 기준 미리보기이며 Godot 실행·실기기 검증이 아니다.

## 충돌·이동 검사

- 코드 경로(정적 확인): 생성 위치는 `sample_source_spawn`(통행 가능·비안전지대), 이동은 매 프레임
  `World.constrain_original_motion` → 필드 `line_clear`(S32 자체 통행 규칙)로 막히면 정지,
  경로는 `field.path`, 배회 목표는 `walkable`/`point_clear`를 통과해야 한다.
- 칸 단위 검사: `tools/map_restore/current523_spawn_collision_check.py`가 원본 Aden S32로
  구역별 통행 칸 수, 통행 칸이 0인 구역(생성 불가), 8방향 연결 덩어리와 고립 소구역(24칸 미만)을
  센다. 판정은 `current523_aden_source_field.gd`와 같은 허용 워드 {0,4,8,12,32}·바닥 센티넬·
  대각선 양쪽 직교 칸 조건이다. 합성 S32로 벽 분리·고립 소구역 검출을 확인했다.
  **원본 Aden S32로 실행한 결과는 아직 없다** (작업 환경에 원본 S32 없음).
