# 누적523 토템 연결 — 부분 구현

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`. 해당 main에는 토템 구현이 없고, 조회한 열린 PR에도 토템 작업은 없었다. 다른 PR은 가져오거나 병합하지 않는다.

## 구현 범위

- 별도 private 팩의 43표/1,294개 선택 원문을 소비한다. 제작기는 분석 ZIP의 모든 좌표와 행을 실제 누적523 ZIP에서 재확인하고, 7개 핵심 토템 표 204행의 누락 여부도 검사한다. 원문 행과 확률·단위·정의되지 않은 참조를 유지한다.
- 실제 Main의 기존 보상 생명주기에서 원본 `NpcClass.ID`로만 처치를 센다. 한 생명의 중복 사망 신호와 소환수는 기존 보상 가드로 제외한다. 지역명·몬스터 이름·파편 드롭표로 활성화 그룹을 추정하지 않는다. 원본 112종과 파편 드롭 105종을 분리한다. 파편 드롭 확률·수량은 추가하지 않는다.
- 활성화 여부·처치 횟수·강화 레벨·선택된 옵션 ID를 별도 저장한다. 활성화 직후 Lv.0을 유지한다. 레거시 저장에 토템 필드가 없어도 불러오며, private 팩이 없는 세션도 기존 토템 저장 내용을 보존한다. 잘못된 새 상태는 전체 로드 전에 거부하고 덮어쓰기를 차단한다.
- 레벨은 불투명한 LevelID 대신 명시적 Level로 조회한다. 강화 성공 Probability, 슬롯 후보 가중치, InvokeOption의 전투 발동률을 각각 보존한다. 경험치 0 후보도 지우지 않는다.
- 공명은 도달한 총 레벨 임계값을 누적해 `PierceDamageReductionPercent`로 반환한다. flat 방어/리덕션이나 자기 피해 감소로 변환하지 않는다.
- 게임 메뉴 → 토템에서 세 토템의 활성화 진행도·현재 레벨·공명, 1~10레벨의 재료와 슬롯별 옵션 비중, 뷰가 있는 6개 강화석 제작법을 확인한다. 원본 수치가 아닌 정적 UI 예시는 사용하지 않는다.

## 실행을 열지 않은 범위

이 PR은 토템 성장 전체 완료가 아니다. 강화 실행, 강화석 제작 거래, 초기화 결제, 지도 버프, 일반 성장 옵션의 전투 능력치 적용과 공명 전투 공식, Lv.10 전투 발동/독/보호막은 미완료다. 해당 효과가 실제로 적용된다고 화면에 표시하지 않는다.

원본에 없는 강화 확률 분모/현재·목표 행 전이/옵션 보존/대체 재료 결제 절차를 임의로 정하지 않았다. 강화 UI는 정보를 보여 주되 실행 버튼을 비활성화한다. 제작은 슬롯별 입력 원문과 현재 뷰만 안내하며 기존 아이템·각인 식별 및 거래 계약과의 연결이 남는다. 초기화 두 비용의 결제 선택 규칙도 확인되지 않았다.

활성화의 지도 전용 +5% 경험치 원문은 보존하지만, 실제 지도 범위와 해제 시점을 이름으로 추측하지 않았다. 일반 옵션 누적은 원본만으로 확정되지 않으므로 후보 전체나 모든 과거 단계 옵션을 합산하지 않는다. 공명 누적은 정의되지만 현재 전투의 flat 무시 수치에 더하지 않는다. 아틀란티스의 리덕션5와 미제공 Shield454를 혼동하지 않으며 흡수량을 생성하지 않는다. Lv.10 공격 발동 두 종류와 방어 발동을 서로 바꾸지 않는다.

## private 팩 설치

공개 Git에는 코드·검사·문서만 둔다. 원문 ZIP과 생성된 팩은 저장소 밖에 보관한다. 현재 제공된 분석 ZIP과 누적523 content ZIP으로 다음을 실행한다.

```sh
python3 tools/totems/build_totem_pack.py \
  --source /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --research /private/TWILIGHT_523_totem_progression_semantics_20261104.zip \
  --output /private/totem-private-523
```

이미 있는 출력 디렉터리는 덮어쓰지 않는다. 실행 환경에 `TWILIGHT_TOTEM_PACK=/private/totem-private-523`를 설정하거나, `user://original_resources/totems523/` 아래에 `manifest.json`과 `totem_data.json`을 설치한다. 재시작 후 Main이 SHA를 검사해 소비한다. 손상된 팩 교체는 이미 로드된 정의·진행도를 바꾸지 않는다. 원본 이미지나 토템 Spine 재생은 이 팩에 없고 검증하지 않았다.

검증한 입력:

- content ZIP SHA256: `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`
- 분석 ZIP SHA256: `6e4135b9db35832b81da59471a9657c5936a8eae24c8406f425b19e2316b5165`
- 실행 JSON SHA256: `4e1206b0a222247488eae2ef7ed49f4ca7867a9b38c1f911675ca0ab923779ac`

## 집중 검증 재현

```sh
TOTEM_SOURCE_ZIP=/private/content.zip TOTEM_RESEARCH_ZIP=/private/research.zip \
  python3 tests/test_totem_pack.py
TWILIGHT_TOTEM_PACK=/private/totem-private-523 \
  godot --headless --path . --script tests/totem_runtime_test.gd
```

원본 자료가 없으면 원문 집중 검사는 명시적으로 skip한다. 이를 원본 실행 검증 성공으로 집계하지 않는다. Main·화면 검사는 별도 격리 XDG 저장소에서 실행하며 기존 플레이어 저장 경로를 사용하지 않는다. 전체 CI, Android 및 토템 원본 아트의 시각 검증과 구분한다.
