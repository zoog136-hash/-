# 25개 맵 공통 시스템 확장

기존 Main.tscn의 **25/25 맵에 공통 리메이크 경로를 연결했다**. 오만 10층은 검증한 독립 A3 격자 팩을 재사용한다. 아덴·지배·에스카로스 5·알비노 4·신념 4는 서로 다른 기존 TWILIGHT 폴리곤 지형을 유지하는 `AuthoredRemakeField`를 사용한다. **12개 완료 조건 충족 0/25, 현재 리니지M 정확 복원 0/25**다. 원본 대응이 없는 15개를 A3 원본 복원으로 계산하지 않는다.

제품 코드: `0ad57d2` → `4dbc58f`, 지역명 표시 수정 `e85fc7b`, 원거리 보스 검사 순서 수정 `920217b`. 브랜치 `feature/twilight-map-remake-20261015`, [Draft PR #119](https://github.com/zoog136-hash/-/pull/119). main `8cc6dc6`은 변경하지 않았다. PR100은 확인 시 `07bba22`로 진행 중이며 그 브랜치와 player/monster/animation 파일은 수정하지 않았다. 해당 최신 PR100과의 결합 검사는 미실시다.

## 실제 구현

- 기존 바닥·도로·물·NPC·오브젝트 아틀라스와 배치 시스템을 재사용한다. 가시 영역의 폴리곤을 잘라 재질별 메시로 묶고, 먼 바닥을 해제한다. 전체 지도 축소 시 큰 청크로 전환하여 보이는 땅을 누락하지 않는다. 바닥 청크는 최대 49개다.
- 기존에 벽으로 명시된 폴리곤/사각형만 입체감 있는 2D 벽으로 그린다. 발 높이별 메시를 Y-sort하고 가시 영역에서만 유지한다. 임의의 차단 영역을 철창으로 바꾸지 않는다.
- 원래 충돌 도형을 변경하지 않고, 플레이어와 활성 몬스터 범위에 필요한 완전한 도형을 로딩한다. 청크 경계를 가로지르는 도형도 잘라 버리지 않는다. 실제 물리 도형과 탐색 데이터는 분리한다. 물리 청크는 오만의 9개 제한과 달리 활성 범위·도형 AABB로 결정한다.
- 기존 맵의 내비게이션/스폰 입력 해시, 맵 ID, 좌표, 저장 배치 버전, 몬스터 DB/AI/수량/타이머를 유지했다. 기존 테스트용 layout-1 맵은 원래 로더와 렌더러를 사용한다.
- 신념 4층은 공식 일본판 가이드의 석재·사슬 / 녹색 유기질·거미줄 / 장식 석재 / 붉은 카펫·청록 보주를 참고해 기존 기둥 위치의 자체 제작 2D 도형과 바닥 패턴을 구분한다. 한국판 좌표/판본 일치는 미확인이다.
- 알비노 1구역의 기존 수정 장애물 표현을 같은 발 위치의 늪지 뿌리로, 3구역은 유황 기둥으로 바꿨다. 충돌은 기존 도형 그대로다. 2구역의 폭포 위치와 4구역 구성은 미확인이다. 지배 정상은 오만 정상 111에 연결하지 않았다.
- 원본 상용 이미지를 추가하지 않았다. PR108의 오만 1층 자체 제작 석판 PNG와 A3 10층 팩을 다시 생성하지 않았다.

## 확인한 결과

| 항목 | 증거와 범위 |
|---|---|
| 전 맵 실제 진입/클릭 이동/스폰/저장/화면 | [25맵 순회 원본](runs/expand25-all-r1.json): 10,831개 검사, 초기 전투 관찰 실패 3개. [맵별 최신 결과](runtime-latest-by-map.json)에 실패 대상 재검사를 연결한다. 단일 무오류 전체 실행 PASS로 합산하지 않는다. |
| 기존 15개 맵 물리 충돌 | 전부 원래 전체 충돌체를 별도 Godot World2D에 설치해 대조. 15×256 = **3,840개 실제 ray**, 진입/원거리 2지점, 실제 hit 좌표, 청크 해제·재방문 메시 해시 확인. |
| 실제 보스 전투 | 새 15개 맵의 보스 18개 지역에서 기존 플레이어 공격과 실제 보스 AI 피해를 확인했다. 기존 A3 오만 10종의 상세 전투·사망·드롭·재출현 결과는 [이전 검증](../TEST_REPORT.md)을 보존한다. QA 레벨/HP와 경로 검사 후 좌표 이동을 사용하며 실제 밸런스·수동 완주 검사가 아니다. |
| NPC/포털 | [15맵 실제 서비스 23곳·근접 포털 73개·보스 상태 유지](runs/expand25-travel.json): **1,227개 검사 실패 0**. 오만의 기존 10개 서비스/50개 포털 결과와 구분한다. 역할별 실제 창 23개는 [별도 대조](runs/travel-service-section-audit.json)했다. |
| 충돌·사냥 경로 회귀 | 초기 원거리 미로딩 도형을 즉시 조회하던 검사 실패를 보존했다. 청크를 방문한 뒤 **모든 기존 장애물과 우회/이동 조건을 유지**하여 hunting_paths **14,603개 실패 0**, 아덴 건물/지형 재검사 PASS. 제한 시간이나 조건을 완화하지 않았다. |
| 실제 화면 | 새 PNG **129장**, SHA·PNG CRC 확인: [매니페스트](PNG_MANIFEST.json). 게임 플레이/충돌/전투 69장과 정지 진단 60장을 구분한다. [동일 카메라 비교 15쌍](COMPARISON.md). 오만 10층의 이전 전체 지도/배치/비교는 재생성하지 않고 재사용한다. |
| 원본 자료 | 신규 A3 복구 없음. 기존 1,000맵 카탈로그·10층 v2 팩·아트 SHA를 유지. 나머지 15개는 기존 TWILIGHT 지형이다. 아덴 A3 4의 2048×1536 지형 적용과 S32 의미 복원은 미완료다. |
| 전체 회귀 | [원본 161개](full-regression/summary.json): **151 PASS / 7 FAIL / 3 SKIP / NOT_RUN 0**. 구현 관련 4개 실패는 대상 재검사를 통과했다. [검사명별 최신 상태](REGRESSION_STATUS.json)는 **155 PASS / 원본 리소스 누락 3 FAIL / 3 SKIP**이며 단일 전체 실행 PASS가 아니다. |
| 새 15맵 성능 | [원본 측정](performance/authored-streaming.json): 청크 예산/해제/재방문 15맵 실패 0, 동시에 실행한 다른 Godot 없음. 진입 **111–1,732ms**, 실제 draw 간격 중앙값 **21.8–41.7ms**, static memory **270–332MiB**, 실제 바닥 청크 최대 9. llvmpipe의 정지/QA 좌표 이동 측정이며 전투·실보행·Android 성능 합격이 아니다. |

지역 프로필의 맵 이름을 메뉴와 진입 안내에도 연결했다. [실제 알비노 1구역 진입 화면](diagnostic/albino_01-same-camera-detail.png)은 이 수정 이후 캡처다.

전체 회귀 중 오만 9층의 보스 공격 관찰 1개가 다시 실패했다. AI나 실제 피해 assertion은 바꾸지 않고 실제 사거리에서 정지한 플레이어를 먼저 관찰하도록 검사 순서를 보완한 뒤, [해당 층 830개 재검사](runs/expand25-oman09-r2.json)는 실패 0이다. 이전 성공 결과와 새 실패/재검사를 모두 보존하며 전체 실행 성공으로 대체하지 않는다.

## 남은 실패와 한계

아덴 재검사에서 게임플레이 assertion 2,241개는 통과했지만 `scripts/animation/impact_visuals.gd:80`의 `Invalid polygon data, triangulation failed`가 한 번 발생했다. [원본 로그](runs/expand25-aden-r2.log)를 보존한다. PR100에서도 변경 중인 파일이므로 이번 맵 작업에서 수정하지 않았다. 아덴의 무오류 실행이나 전체 회귀 성공으로 계산하지 않는다.

현재 리니지M과 교정한 기준점은 여전히 모든 맵에서 0개다. 기존 15개 맵의 방 배치·보스방·포털·스폰은 provisional이며, 에스카로스 구역별 지형과 알비노 4구역 등은 원작 대응이 미확정이다. 구조물 의미·원작 아트·오만 샘플 이상의 최종 시각 품질·장거리 실보행·각 아이템 드롭·Android 실기기·PR100 최신 결합 검증이 남았다. 기술적 적용 수와 원작 복원 완료 수를 구분한다.

원본 리소스 실패 3개는 `l1j_map_grid_test`, `l1j_png_load_test`, `l1j_spx_frames_test`다. 누락된 외부 raw/PNG/SPX를 합성 파일로 대체하지 않았다. 초기 임포트의 사용자 config/cache 경로 오류는 별도 XDG 경로로 재실행하여 해결했고 [실패 로그](runs/expand25-import-initial-env-failure.log)도 보존했다. [회귀 생성물 308개와 원래 경로/SHA](regression-generated/MANIFEST.json)를 별도 보관하고 과거 날짜의 추적 증거 155개 경로는 복원했다. 아덴의 기존 도로·수면 전역 배치는 남아 있어 약 1.7초 초기 진입과 장거리 보행 최적화가 다음 성능 대상이다.

## 재개 명령

같은 브랜치와 PR을 사용한다. A3 팩은 [기존 인계 문서](../HANDOFF.md)의 비공개 v2 ZIP을 복원한다. 이미 있는 격자/이미지를 다시 변환하지 않는다.

```bash
"$GODOT" --path . --rendering-driver opengl3 --script res://tools/map_restore/validate_all_maps.gd -- --output=/workspace/all-map-play
# --map=faith_04, --no-combat, --travel-only로 필요한 그룹만 재검사한다.
"$GODOT" --path . --rendering-driver opengl3 --script res://tools/map_restore/capture_maps.gd -- --maps=faith_04 --output=/workspace/map-captures
"$GODOT" --path . --rendering-driver opengl3 --script res://tools/map_restore/benchmark_streaming.gd -- --authored --output=/workspace/authored-streaming.json
```

별도 XDG_DATA_HOME을 사용한다. 전체 검사 도구가 과거 docs 경로에 생성하는 산출물은 새 증거 폴더에 보존한 뒤 해당 과거 추적 파일만 복원한다. 사용자나 다른 작업의 파일에 일괄 restore/clean을 실행하지 않는다. Draft 유지, 자동 병합 금지.
