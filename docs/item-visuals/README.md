# TWILIGHT 아이템 이미지·등급 효과 검증

기준 main: `434b904d957fd2146b6d2e73325693a402028035` (작업 시작 및 구현 후 원격 재확인).
브랜치: `feature/item-visual-link-rarity-effects`.
단일 Draft PR: [#97](https://github.com/zoog136-hash/-/pull/97). main 병합 없음.
구현 체크포인트: `653d77dac55ce5ba6a33a5af98f8d8836def1c37`.

기존 이미지가 있어도 L1J 이름 매칭이 먼저 선택되던 경로를 sourceId 우선 공통 조회로 바꾸었다. 원본 PNG를 78px로 재가공하고 검은 부분을 투명하게 만들던 처리를 제거하고, 원래 픽셀·알파·종횡비를 유지한다. 등급 테두리와 숫자는 기존 UI에 남기고 그림에만 공유 셰이더를 적용했다. 데이터/저장/드랍/강화 수치는 수정하지 않았다.

## 전수 집계

| 데이터 집합 | 전체 행 | 정확한 원본 확인 | 원본 확인 대기 | 자체 대체 | 표시 이미지 누락 |
|---|---:|---:|---:|---:|---:|
| `catalog_v19.json` | 2,129 | 2,129 | 0 | 0 | 0 |
| `game_db_v17.json` 원시 행 | 485 | 83 | 10 | 392 | 0 |
| 실제 월드에서 병합한 런타임 DB | **2,576** | **2,129** | **10** | **437** | **0** |

원시 집합은 중복되므로 더하지 않는다. 437은 대체 그림을 사용하는 **레코드 수**다. 각 아이템의 원본 437장을 제작했다는 의미가 아니다. 437행은 33종의 자체 벡터 계열 심볼을 공유한다. 루비에 빨간 물약이 나오던 6개의 오래된 UI 자리표시자도 알맞은 계열의 명시적 대체로 바꿨다. 자체 심볼은 128px로 생성하며 인벤토리/상세 등의 공통 뷰에 `◇` 대체 표시가 있다. 데이터에는 정확한 상태와 경로/계열을 기록한다.

카탈로그의 sourceId는 2,129개, 이름은 2,085개, 파일은 1,442개다. 같은 이름을 가진 29그룹을 ID별로 유지하며 이름만으로 구별할 수 없으면 대체를 사용한다. 기존 L1J 매핑 467개(카탈로그 420 + legacy 47)와 이름 인덱스 2,085개도 검사했다. 과거의 `420/2129`는 이 L1J 부분 집합 수치이며 현재 카탈로그 PNG 존재 여부와 같은 지표가 아니다.

표의 “원본 확인”은 기존 카탈로그 출처 PNG의 아이템 신원이 확인되었다는 뜻이다. 게임 클라이언트에서 추출한 무가공·무워터마크 원본 파일 2,129개를 확보했다는 뜻이 아니다. 일부 PNG에는 출처 워터마크와 배경이 남아 있다.

확인 대기 10개: 아데나, 수호의 휘장, 강철 도끼, 용기의 반지, 지혜의 귀걸이, 지혜의 벨트, 영웅의 귀걸이, 영웅의 반지, 철 광석, 미스릴 원석. 기존 L1J 후보를 표시하지만 정확한 sourceId 대응이 불충분하여 원본 확인 수에 넣지 않았다. 대체 목록에는 `훈련용/청동/강철/...` 계열의 프로젝트 장비도 포함된다. 비슷한 원작 이름을 찾아 억지로 대입하지 않는다.

- [전수 JSON](evidence/audit.json): 원시/런타임 모든 행, 연결 상태, 해시, 원본 URL, 중복 이름, 보호 데이터 일치, L1J 파일 검사.
- [전수 CSV](evidence/audit.csv): 필터 가능한 행별 목록. 원본 미확정은 `original_review_pending`, `self_authored_substitute`, `image_missing`로 구분한다.
- [집계 JSON](evidence/summary.json), [웹 신원 증거](evidence/source-verification.json).
- [실제 참고 화면과 구현 차이](REFERENCES.md). 원본 신원 검증은 새로운 재배포 허가 취득과 다르다.

## UI 적용 범위

| 실제 경로 | 공통 이미지 조회 | 등급 애니메이션 |
|---|---|---|
| 인벤토리/물리적 강화 인스턴스 | sourceId 및 인스턴스의 기존 원본 레코드 | 영웅·전설 광택, 신화·유일 깊이 회전 |
| 상세 정보/도감 선택 미리보기 | 동일 | 동일 |
| 장비창/강화 선택 미리보기 | 동일 | 동일. 테두리와 강화 배지는 고정 |
| 아이템 도감 목록 | 동일 | 대량 목록 가독성을 위해 정적 |
| 창고/구매/판매/강화 목록 | 동일 | 정적 |
| 제작법 목록 | 공통 36px 아이콘 추가 | 정적 |
| 퀵슬롯/드래그 미리보기 | 동일 | 정적. 수량·쿨다운·입력 처리 유지 |
| 월드 바닥 드랍 | 동일. 검증된 바닥 이미지 쌍/기존 전용 바닥 후보 보존 | 정적. 바닥 경유 습득 로직 유지 |

`item_visual_resolver.gd`가 이미지를 조회하고 `item_visual.gd`가 기존 TextureRect에 한 번 부착된다. 등급별 재질은 최대 32개를 공유한다. `item_visual_scheduler.gd` 하나가 0.12초마다 실제 뷰포트와 스크롤 클립 영역을 검사해 숨겨진 아이콘의 애니메이션 재질을 해제한다. 숨겨진 부모는 즉시 반영한다. 이미지 캐시는 256개로 제한했다.

## 실제 실행 증거

Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility, Linux Mesa llvmpipe 소프트웨어 OpenGL로 실제 실행했다. 인벤토리/상세/장비/도감/창고/상점/제작/강화 8개 경로를 1280×720 및 960×540에서 캡처했다. 계정 저장과 분리한 테스트 데이터에 실제 카탈로그의 7등급 아이템을 지급했다.

- [인벤토리](evidence/captures/inventory-1280x720.png), [작은 화면 상세](evidence/captures/detail-960x540.png), [장비](evidence/captures/equipment-1280x720.png), [제작](evidence/captures/crafting-1280x720.png).
- [7등급 동시 표시](evidence/captures/rarity-frame-016.png), [실제 캡처 시간 간격을 보존한 64프레임 영상](evidence/captures/rarity-sequence.mp4).
- [80개 캡처 메타데이터](evidence/captures/captures.json), [아이콘/배지 픽셀 변화 검사](evidence/sequence-validation.json).

검증 보드는 실제 UI 캡처와 구분해서 표시했다. 보드의 `+9/E/×1`은 고정 배지 검사용이며 아이템 능력치가 아니다. Git에는 실제 UI 16장, 보드 대표 4장, 모든 64프레임을 포함한 영상이 남는다. 전체 원본 PNG 64장은 실행 환경에 있으며 새 CI가 실행되면 artifact에도 저장된다. 영상은 실제 캡처 간격을 보존한 샘플 모음이며 60FPS 녹화가 아니다.

실제 렌더 픽셀 검사에서는 영웅 광택 중심이 `(42.34,42.34)`에서 `(124.66,124.66)`으로 이동하고, 신화 측면 폭이 128→54px로 변했다. 기본 밝기 보존, 전설의 더 강한 광택, 유일의 별도 광채, UI Control 변환 불변도 확인했다. 합성 회색 텍스처는 셰이더 검사에만 쓰며 원본 아이템 수에 포함하지 않는다.

## 재현

```bash
python3 tools/check_resource_integrity.py --root .
python3 tools/test_item_source_verification.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/item_visual_test.gd
TWILIGHT_ITEM_AUDIT=/tmp/item-runtime.json godot --headless --path . --script res://tools/export_item_visual_audit.gd
python3 tools/check_item_visuals.py --runtime /tmp/item-runtime.json --source-evidence docs/item-visuals/evidence/source-verification.json --output /tmp/item-audit
godot --rendering-driver opengl3 --path . --script res://tests/item_rarity_render_test.gd
TWILIGHT_ITEM_CAPTURES=/tmp/item-captures godot --rendering-driver opengl3 --path . --script res://tests/capture_item_visuals.gd
TWILIGHT_ITEM_BENCHMARK=/tmp/item-benchmark.json godot --rendering-driver opengl3 --path . --script res://tests/benchmark_item_visuals.gd
python3 tools/test_project.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --logs /tmp/item-regression
```

실제 렌더 명령은 디스플레이 또는 Xvfb가 필요하다. 각 테스트에 서로 다른 `XDG_DATA_HOME`을 지정한다. 현재 작업은 플레이어 저장 파일에 접근하지 않았다. docs 아래 감사 JSON/CSV/스크린샷은 `.gdignore` 및 Android 내보내기 제외 경로로 게임 패키지에서 제외한다.

## 남은 작업

- 명시된 `TWILIGHT_item_visual_patch_434b904.zip`, `TWILIGHT_item_visual_status_KO.md`가 이 세션에 없어 이전 패치 직접 비교는 미실행이다. 현재 main을 분석하여 구현했으며 오래된 코드를 덮어쓰지 않았다.
- 원본 ZIP 6종/장기 보관 팩도 현재 환경에 없다. `AGENTS.md`의 “접근 불가 시 그 원본 작업을 중단” 규칙에 따라 해당 팩 변환·납품은 진행하지 않았다. 파일이 제공되면 무결성 검사 후 같은 PR에서 재개한다.
- 정확한 원본 미확정 447행(후보 10 + 대체 437), 원작 연속 애니메이션의 실측 비교, 배경 없는 허가 원본 교체가 남는다.
- Windows/Android 실기기 실행과 성능은 미검증이다. Linux 소프트웨어 GL 결과로 실기기 60FPS를 보장하지 않는다.
- 전체 회귀/성능/CI의 최종 수치와 재개 위치는 [검증 결과](VALIDATION.md)와 [체크포인트](CHECKPOINT.md)에 기록한다. 모든 검사 통과 또는 전체 원본 통합 완료로 표시하지 않는다.
