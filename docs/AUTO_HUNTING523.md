# 누적523 자동사냥 지역 선택과 TWILIGHT 아덴 이동

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`.
별도 브랜치: `feature/auto-hunting-movement523-20261104`.

기존 게임 메뉴 → 자동사냥 창에서 80개 메뉴·87개 착지 정의와 원본 비용·명시된 최소 레벨을 표시한다.
사용자 최신 지시에 따라 원문·기존 보고서·승인된 Drive 인계·공개 도구를 먼저 대조한 뒤,
**원본과 구분한 `TWILIGHT_LOCAL_ADEN_V1` 자체 이동 정책**을 연결했다.
현재 아덴의 실제 통행/몸체/점유 및 기존 저장·재진입 검사를 통과한 목적지만 이동한다.
최신 실행 결과와 차단 항목은 [자체 정책 검증](auto_hunting523/LOCAL_POLICY.md)에 있다.

게임에서 **메뉴 → 자동사냥 → TWILIGHT 자체 이동 사용**을 켜고 지역을 선택한다.
끝 셀 포함/제외와 중앙 우선/좌표 순서 선택은 설정 가능한 자체 해석이다.
**선택 지역으로 이동**은 원본 비용과 현재 상태를 다시 확인하고,
목적지·정확한 비용이 원자적으로 저장된 뒤에만 실제 위치와 아데나를 바꾼다.
조건 확인 버튼으로 현재 입장/점유 결과를 갱신할 수 있다.
기본 설정은 꺼짐이며 설정은 별도 `user://auto_hunting_local_policy.json`에 보관한다.

## 원본과 보관

Library 정식 materialize 후 두 ZIP을 실제로 읽고 전체 CRC와 SHA256을 확인했다.

| 자료 | 바이트 | SHA256 |
| --- | ---: | --- |
| 누적523 원문 ZIP (`libfile_f3e9e5b322cc8191ae441565bbd24c27`) | 25031173 | `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832` |
| 이동 심층 ZIP (`libfile_d050f61f9438819186c32b853cfa8dd6`) | 262610 | `750057555a10267019b3c7c53f5cbcc83322c9d1e262fda865356569e650352a` |
| private 파생 JSON | 136985 | `a217eec940a84d8fa67e7ece99d3f8774b9b13b90aeebbd71e4140ff4ba11fef` |
| private 전달 ZIP | 12131 | `77cb932db013c02e3daaab8b011ab748c57253612e1a5030044fb5c5ca00ba8b` |

코드만 Git에 올리고 원문·파생 팩은 올리지 않았다.
private ZIP의 Library 보관 ID: `libfile_d04fb02540e08191aa556eb0bdfe2d3c`.
이 팩에는 이미지가 없다. 공개 원본 리소스 장부의 미전달 상태를 승격하지 않는다.

재생성:

```sh
python3 tools/build_auto_hunting523.py --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip --output /private/auto_hunting523
```

Library ZIP을 private 디렉터리에 풀거나 위 빌더를 실행하고, 게임 시작 전에
`TWILIGHT_AUTO_HUNT523_DIR=/private/auto_hunting523`을 설정한다.
`-- --auto-hunt523-dir=/private/auto_hunting523`도 지원한다.
기본은 `user://auto_hunting523`이며, 세션 카탈로그는 최초 자동사냥 창 열기 시 고정한다.
설치 후에는 게임을 다시 실행한다. 경로·선택값·원문 데이터는 기존 세이브에 추가하지 않는다.

빌더는 원본 ZIP 및 10개 테이블의 SHA를 고정하고 모든 필드를 보존한다.
동일 결과의 재생성은 허용하되 다른 내용의 기존 팩은 덮어쓰지 않는다.
런타임은 크기·JSON 바이트 SHA를 확인한 뒤에만 카탈로그를 교체하며, 실패하면 기존 검증 카탈로그를 보존한다.

## 원문 의미와 보류 범위

- `AutoScheduleLandTeleport.TerritoryID`는 사냥 영역이다. 55개가 비제로이고 착지 영역과 다르다.
  예: 메뉴4의 사냥1723, LT73의 착지113222. 같은 영역으로 합치지 않는다.
- 25개 `TerritoryID=0`은 원문 `Territories0 Name=None` 센티널이다. Land0/좌표0 출발·사냥을 만들지 않는다.
  이 메뉴들의 착지 연결32개도 별도로 보존한다.
- `LandTeleportTerritories`87행 → Land22종을 보존한다. 여러 착지 후보를 첫 행으로 축약하지 않는다.
- 80개 메뉴에는 출발 Land/출발점이 없다. 필드49/하딘23/특수8을 임의의 출발 간선으로 바꾸지 않는다.
- 추천 Lv.17..91은 입장 조건이 아니다. 실제 `LandTeleportPrerequisite`가 있는19종은 별도 MinLevel을 사용한다.
- 아데나57/원문 Gem23을 구분한다. Gem을 아데나로 치환하거나 미확정 환산·할인·티켓 차감을 만들지 않는다.
- `ServerScheduleEnable`과 `IsWorking`은 정의이며 실시간 활성/입장권·서버 자격 증명이 아니다.
  `AllowMapTeleport`, `AllowInterTeleport`, `NoTicketSpend`, 비용·Currency·조건 원문은 그대로 보존한다.
- main의 `base508_game_field.gd`와 현재 PC 기반 아덴 지형은 M 원본 통행/좌표 증거가 아니다.
  자체 정책은 원본 Land4/Aden의 사각형 정수를 현재 아덴 셀에 대응하는 별도 가정을 명시한다.
  현재 아덴 내부 이동만 지원하며 Gem·다른 Land·맵 간 이동은 독립적으로 차단한다.
  PR230/232의 지도·포탈 코드를 병합하거나 변경하지 않았다.

실제 M 이동/충돌/영역 규약은 여전히 미확정이다. 원본 행과 사냥/착지 분리·0 센티널은 그대로 보존한다.
원문 `ScheduleTeleportRetryCount=20`을 자체 셀 선택 규칙이라고 주장하지 않는다.
기존 원본 카탈로그의 `assess_request`는 원본 계약 미확정 상태를 유지하며,
게임의 `world.auto_hunting_movement_assessment`는 별도의 자체 정책을 판정한다.

PR232 최신 표시/UI 구현과 원문87개 영역을 다시 대조한 결과 및 기존 로컬 포탈35개 검사는
[착지·기존 이동 재사용 조사](auto_hunting523/ARRIVAL_REUSE_FINDINGS.md)에 정리했다.
실제 원본 이동을 열기 위해 필요한 지도/통행/영역 선택 계약을 구체적으로 남겼다.

이후 승인된 Drive 인계의 좌표 교차검증/픽셀 경계 정정 ZIP도 실제로 내려받아 SHA·CRC와 원문 선언을 대조했다.
[Drive 자료와 소비 API별 남은 계약](auto_hunting523/DRIVE_ARRIVAL_CONTRACTS.md)에 새 후보2개와 활성화할 수 없는 이유를 기록했다.

## 창고·판매·지역 퀵슬롯 읽기 조사만 수행

| 원문 | 실제 범위 | 후속 연결 위치/주의 |
| --- | --- | --- |
| `StorageAutoStore` | 84행·ItemClass76종. `ItemClassID`, `SortOrder`, `ItemBlessCodeID` | `world._warehouse_transfer`와 `warehouse/local_warehouse.gd`. 이름만 합치면 축복·귀속 변형을 잃는다. 인스턴스ID·장착·잠금·기존 창고 저장 보존이 필요하다. |
| `MerchantAutoSell` | 25행·ItemClass25종. 가격 정의가 아니다. `ConstantData.AutoSellMaxCount=40` 별도 | `world._sell_shop_item`, `shop/local_buyback.gd`, `ui/renewal_sell.gd`. 원본 ID 매핑과 잠금·퀘스트·귀속·장착 필터를 먼저 확인하고 기존 가격 정책을 보존한다. 자동판매 실행 시점은 표만으로 확정하지 않는다. |
| `AutoQuickSlotData` | 13행·ID7종·중복행 보존. `AutoUseByExistBuffGroup=true` | 지역별 슬롯 저장표가 아니다. ID가 같은 다른 namespace에 곧바로 조인하지 않는다. |
| `QuickSlotChange` → `QuickSlotChangeData` | 3개 기본 아이템 → 9개 지역별 교체행, Land44544/44614/47722, 대체 ItemClass126424 | 기존 `world.quickslots`, `_on_quickslot_pressed`, `_run_auto_item_quickslots`의 실행 시 해석에 연결할 후보. 사용자의 슬롯 구성을 영구 덮어쓰지 않는 방식과 원본 ItemClass 매핑·Land 신원 확인이 필요하다. |
| `QuickSlotIndex`·`QuickSlotConstants`·`SleepModeQuickSlotPriority` | UI/서버 인덱스6행·상수5행·우선순위3행 | 자체 PC 슬롯 배열 번호를 원본 Client/ServerIndex와 같은 값으로 가정하지 않는다. 휴면 우선순위는 지역 교체 규칙과 별개다. |

이 조사 범위에는 새 자동 창고·판매 실행, 퀵슬롯 교체/저장 변경을 넣지 않았다.
퀘스트·펫·혈맹·공성·구형소스1/2·폐기 서버 프로토타입도 재도입하지 않았다.

## 검사

`tests/test_auto_hunting523.py`는 실제 원문 전수 조인·사냥/착지 분리·0센티널·비용/조건·심층 결과 대조와 다른 팩 덮어쓰기 거부를 검사한다.
실제 원문을 쓸 때 다음 환경변수를 제공한다. 없는 CI에서는 해당 원문 검사를 명시적으로 skip하고 다른 원본/fixture로 대체하지 않는다.

```sh
TWILIGHT_523_SOURCE_ZIP=/private/source.zip \
TWILIGHT_523_MOVEMENT_RESEARCH=/private/auto_hunting_regions_and_landing_routes_not_source_edges.json \
python3 tests/test_auto_hunting523.py
```

`tests/auto_hunting523_test.gd`: 실제 private팩231검사, 팩 없는 경로3검사.
`tests/auto_hunting523_main_ui_test.gd`: 실제 Main의 메뉴 → AUTO 창 → 지역/복수 도착지 선택, 상태 결과, 지도·위치·재화·장비·AUTO·저장 바이트 보존을 검사한다.
자체 경로 탐색이나 지역 이동 성공의 증거로 계산하지 않는다.

자체 이동 추가 전의 기준 검사 결과: 실제 Main/UI262검사, 팩 없는 Main/UI12검사, OpenGL1280×720 화면263검사 통과.
87개 착지 선택은 실제 UI 신호로 검사했다. OS 포인터·터치 조작 시험은 아니다.
현재 맵·세이브32검사, 동일 저장 중복 쓰기 방지, deferred-save gate도 오류0으로 통과했다.
화면을 실제로 확인했으며 캡처는 로컬 검사 자료로만 보존했다.
첫 Main/UI 실행의 시험용 stage 초상화 누락은 main의 정확한 blob으로 보충한 후 재검사했다.
Godot 임포트/오디오 환경의 실패 시도와 최종 검사 영수증은 [validation.json](auto_hunting523/validation.json)에 기록했다.
최신 자체 이동 실행과 실패 진단은 별도 영수증에 기록한다. 원격 CI는 로컬 성공과 별도다.

공개 시트723/41,442프레임 SHA 무결성 검사 통과.
옛 `--source-dir` 장부 검사는 `/workspace/autohunt-source/a1.zip` 부재로 실패했다.
523 두 ZIP의 실제 SHA/전체CRC 검증과 구분한다.
