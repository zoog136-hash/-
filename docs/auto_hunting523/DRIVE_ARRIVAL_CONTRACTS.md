# Drive 인계 자료 재검토와 실제 이동 소비 계약

> 이 문서는 자체 정책 허용 전의 조사 기록이다. 원본 M 계약의 미확정 결과는 보존한다.
> 이후 사용자 허용에 따른 현재 아덴 자체 이동 구현/검증은 [LOCAL_POLICY.md](LOCAL_POLICY.md)를 따른다.


이 문서는 PR235의 기존 환경/브랜치에서 수행한 후속 조사다.
PR232의 현재 게시 HEAD는 계속 `1be258b6dd90b41934c100a013dee927e3c03942`이며,
다른 PR/main을 병합하지 않았다. 실제523 이동 활성화는 여전히0개다.

## 새로 실제 읽은 자료

사용자가 승인한 Drive 작업 인계 폴더에서 공식 Drive 도구로 식별/읽기/다운로드했다.
이전에 거절된 Library 전송은 재시도하지 않았다. 비공개 Drive 링크와 원문 ZIP은 Git에 넣지 않는다.

| 파일 | 실제 검증 |
| --- | --- |
| `TWILIGHT_523_Drive_handoff_manifest_20261104.json` | 10,420바이트, SHA256 `b3de71e193185bf848bd59004bccef3c9661b13a516760ec33e2bae52c41a8a3` |
| `TWILIGHT_M현행523_좌표도구_M명시데이터교차검증_20261104.zip` | 616,779바이트, SHA256 `b406f8265b4710d3d75b937f716eab6aece16f3bbfbd5f3e8308d70174530f91`, 12항목 전체 CRC 통과 |
| `TWILIGHT_current523_M_source_evidence_PC_reference_pixel_boundary_correction_20261104.zip` | 3,518바이트, SHA256 `7e957580c404247b8b959306f74bceb96d4731fe3421af35e4ed1dd9de45df15`, 3항목 전체 CRC 통과 |
| `README_Aden523_resources_20261104.txt` | 실제 텍스트를 읽었다. S32/TI2 검토 팩이며 M 발 위치·보행·충돌·포탈은 미검증이라고 명시한다. 399MB 분할 팩 전체를 이 후속 조사에서 다운로드/복원했다는 뜻은 아니다. |

좌표 ZIP의 `inputs/Land.json`, `inputs/Portal.json`, `inputs/Territories.json`은
이미 보유한 누적523 원문과 **바이트 전체가 같다**. ZIP의236개 비교 기록을 실제 M Portal/영역/Land 선언과
다시 대조했으며224개 출발 좌표 일치,12개 불일치를 재계산했다.
다만 해당125개 S32 원문은 이12항목 ZIP에 포함되어 있지 않아, 이번 조사에서 원문125개 offset을 재검사하지 않았다.
상류의 raw-offset QA 결과와 이번 선언 대조를 구분한다.

자료에 적힌 최선 목적지 변환 대안도224개 중131개만 원본 목적 사각형에 포함된다.
이 수는 실행상 성공률이 아니다. M 스크린샷 비교와 실제 M 통행 단계는 상류 보고서에서도0이다.

## 87개 착지와의 새 교차 대조

원본 `Portal.TargetTerritoryID`와 자동사냥의87개 착지 `TerritoryID`를 **같은 FK 값으로** 연결한 결과는0건이다.
좌표가 겹친다는 것만으로 FK를 새로 만들지 않았다.

M Portal의 명시된 단일점이 착지 사각형에 기하상 겹치는 후보는 다음2개다.
아래 포함 비교는 진단용이며 게임의 영역 포함 규약을 확정한 것이 아니다.

| 메뉴 / 착지 링크 | M 선언 점 | 실제 원본 영역 / 추가 장애 |
| --- | --- | --- |
| 464 / 1612 | Portal507 → Territory174884, Land284 `284/`, `(32673,32796)` | 착지114162는 `(32672,32796)..(32673,32797)`. 점이 EndX 경계에 있다. 직접 FK가 없고, 현재84개 런타임 지도에 Land284 대응 필드가 없다. Gem10/MinLevel72를 아데나 정책으로 바꾸지 않는다. |
| 624 / 1752 | Portal14193 → Territory179094, Land43193 `13125/`, `(32665,32895)` | 착지114302는 `(32664,32894)..(32665,32895)`. 점이 EndX/EndY 경계에 있다. 직접 FK가 없고 Land43193 대응 필드가 없다. 원본 MinLevel70/아데나50000은 보존한다. |

Portal507에 대한 `Map/283/7fff8000.s32` 기록 후보는 출발 선언과 맞고 목적packed 후보도 위 점과 맞는다.
이는 자동사냥 영역과의 소속 FK, 해당 점의 몸체 통행, M 필드 로드, 영역 경계 포함 여부를 검증한 것은 아니다.
특히 두 후보 모두 끝 경계이므로 End 제외/포함 규약을 정하지 않고는 착지 영역 안이라고 확정할 수 없다.
이 두 점을 기존 `source_284`나 `source_43193` 같은 임의 map_id에 붙이지 않았다.

픽셀 경계 정정 자료는 기존 TI2/SP2 해독·PNG·기하를 PC 참고 후보로 제한한다.
픽셀·RGBA 해시 일치나 원문 왕복만으로 M 충돌 계약을 만들 수 없다는 정정과도 일치한다.

고정 공개 참조도 직접 읽었다. [L1MapHelper.cs](https://github.com/tony1223/L1MapViewer/blob/364fcff15ea019e5a9329170aaf7e245404ebba6/Helper/L1MapHelper.cs)의
ReadLineageM은 M 입력의 메타데이터 로딩을 지원하며,
[S32Parser.cs](https://github.com/tony1223/L1MapViewer/blob/364fcff15ea019e5a9329170aaf7e245404ebba6/CLI/S32Parser.cs)는
attributes를 두 Int16 값으로 읽는다. 이 입력 지원/원시 파싱을 M 통행·몸체·착지 선택 검증으로 확대하지 않았다.
공개 도구 실행이나 PC 자원 가져오기는 하지 않았다.

## 부족한 파일·필드·소비 API

다음 표의 마지막 열은 이미 존재하는 소비 지점과 **아직 없는 검증 계약**을 구분한 것이다.
필드/메서드가 필요하다고 적은 것을 구현 완료나 원본 스키마라고 주장하지 않는다.

| 계약 | 현재 자료의 파일·필드 | 실제 소비 지점 / 필요한 연결 |
| --- | --- | --- |
| M 지도 신원·좌표 | `Land.json`의 ID/AssetPath, `Territories.json`의 LandID/StartX/Y/EndX/Y. PR232 원문은 `Map/Aden/*.s32`만 연결한다. | `world._set_map`과 현재 `field_map`에523 Land/AssetPath/원문 SHA로 묶인 필드와 셀/발 좌표 계약이 필요하다. 검토 화면의 `project_half_storage`를 이 계약 대신 쓰지 않는다. |
| 실제 통행·몸체·점유 | PR232 `current523_aden_pack.read_member`가 반환하는 `sections.attributes`16,384바이트는 보존되지만 의미는 UNKNOWN이다. 두 새 후보에는 각각 `Map/284/...s32`, `Map/13125/...s32`의 검증된 판정이 필요하다. | 현재 PC 기반 `source_map_runtime_field.point_clear`/`source_v1_grid`를 M 판정으로 승격하지 않는다. M 데이터에 묶인 유효 셀/몸체/점유 검사가 확인되어야 한다. |
| 영역 경계·셀 선택 | `LandTeleportTerritories.TerritoryID`, `Territories.Start/End`, `ConstantData.ScheduleTeleportRetryCount=20`. | `source_schedule.assess_request`는 현재 읽기/차단만 수행한다. 영역 끝 규약·후보 선택·재시도·빈 영역 실패 계약을 받은 후에 실제 이동 경로를 추가해야 한다. 20회 임의 추첨을 새 규칙으로 만들지 않는다. |
| 입장/비용 | `LandTeleportPrerequisite`, `Prerequisite`, `LandTeleport.CurrencyID/TeleportCost/Allow*`, `LandAttribute`의 범위/값. | `world.auto_hunting_movement_assessment`에서 원문 조건을 확인하고, 성공한 실제 이동 후에만 해당 재화를 차감하는 트랜잭션이 필요하다. 기존 NPC 자체 가격표로 대체하지 않는다. |
| 실패/재진입/저장 | M 필드와 셀 판정이 아직 없어 실제 이동 트랜잭션을 시작하지 않는다. | 현재 검증한 `use_field_portal`의 이동 정리는 재사용 가능하다. 새 필드/셀 준비 실패, 점유 변경, 재화 부족, 저장 실패, 재진입을 실제 M 대상에 연결한 후 집중 회귀해야 한다. 기존 UI/저장 검사를 새 이동 검증으로 세지 않는다. |

원문 ZIP 재업로드를 요구하는 문제가 아니다. 이미 보존된 원문과 별도 M 선언의 해석/실행 계약이 부족하다.
확률·재화 자체값 허용을 픽셀·좌표·충돌·기능 활성 조건으로 확대하지 않았다.

## 재현과 이번 검증 범위

`tools/audit_auto_hunting523_coordinates.py`는 로컬의 승인된 사본만 읽으며 네트워크·원본 수정·게임 이동을 하지 않는다.
고정 ZIP SHA/전체 CRC, 원문 테이블 전체 바이트 일치,236개 후보의 선언 대조와87개 착지의 FK/경계 후보를 검사한다.

```sh
python3 tools/audit_auto_hunting523_coordinates.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --coordinate-zip /private/TWILIGHT_M현행523_좌표도구_M명시데이터교차검증_20261104.zip \
  --correction-zip /private/TWILIGHT_current523_M_source_evidence_PC_reference_pixel_boundary_correction_20261104.zip \
  --output /private/drive_coordinate_audit.json
```

실제 입력으로 위 검사와 다른 입력 SHA 거절을 통과했다. [검사 영수증](drive_coordinate_audit.json)을 보존했다.
새 M 이동은 활성화하지 않았으므로 새 이동의 실제 실행·저장 실패/재진입 검증도 미실행이다.
기존 실제 Main/UI·세이브·로컬 포탈 실행 결과는 앞선 영수증 범위로 유지한다.
사용자 세이브를 읽거나 쓰지 않았고 수동 CI·워크플로 변경·다른 PR 병합은 하지 않았다.
