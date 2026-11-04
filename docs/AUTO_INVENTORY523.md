# 자동 창고·판매 — 523 대상·가격과 로컬 정비

기준 main `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`, 기존 브랜치 `feature/auto-storage-sale-20261104`, [Draft PR #251](https://github.com/zoog136-hash/-/pull/251)에서 이어간다. 다른 PR/main 병합, 수동 원격 CI 실행은 하지 않는다. `[skip ci]`를 유지한다.

## 실제 사용

메뉴 → 창고(보관) 또는 판매 → 소지품 선택 → 남길 수량 지정 → **자동 대상 등록** → **자동 담기·내역 확인** → 취소 또는 전체 보관/판매. 스택은 남길 수량을 빼고, 장비는 선택한 고유 ID만 처리한다. 처리한 장비 ID는 자동 대상에서 제거한다. 같은 이름의 새 장비를 대신 선택하지 않는다.

같은 화면의 **원본·정비**에서 개인 규칙 ZIP을 설치한다. 원본 보관84행/판매25행을 모두 조회하고, 원본 ID·축복 상태가 정확히 일치하는 소지품만 등록할 수 있다. 미소지 원본 아이템을 생성하지 않는다. **원본 ID·축복이 맞는 자동 대상만 처리**는 선택 설정이며, 켜도 기존 수동 판매 범위를 바꾸지 않는다.

확인된11개 매입가는 원본·공개 확인값으로 표시하며 수정할 수 없다. 나머지 실제 판매 후보10개는 기존 TWILIGHT 등급 기준(일반40 등) 또는 사용자가 저장한 자체값을 사용하고 **자체값**으로 표시한다. 기존 상점 판매가가 있다면 자체 매입가는 그 가격을 넘지 않는다.0은 매입하지 않음이며, 알려진 원본 가격을 자체값으로 덮어쓰지 않는다. 매입 가격 표시와 실제 정산은 같은 경로를 사용한다. 장비·잠금·귀속·퀘스트·명시적 거래제한·지갑 한도는 기존 보호를 유지한다.

**가방 정비 → 기존 이동진 이용**은 TWILIGHT 자체 동작이다. 사용자가 현재 맵의 확인된 이동진, 보관/판매 단계, 자체 대기 제한1~600초(기본120)를 선택하고 최종 확인하면 기존 클릭 경로로 걷는다. 도착 때 보관 → 판매를 단일 저장으로 처리한 후 기존 이동진을 이용한다. 선택된 스택은 도착 당시 수량에서 남길 수량을 유지하며, 이동 중 새로 얻은 같은 선택 스택도 포함한다. 장비는 고유 ID 선택을 유지한다. 경로가 다른 이동진을 지나면 임의 우회로를 만들지 않고 시작을 거절한다.

예약은1회다. 취소·설정 변경은 해제하며 자기 이동 경로만 정리한다. 시간 초과·시계 역행·저장 실패는 소모 없이 일시 중지하고 자기 경로를 멈춘다. 재시작하면 저장된 미완료 예약을 자동 실행하지 않고 재확인한다. 완료 토큰은 아이템·재화와 함께 저장해 중복 진입·재시작으로 재지급하지 않는다.

## 원본과 공개 근거

Library 원본 `libfile_f3e9e5b322cc8191ae441565bbd24c27`:25,031,173bytes, SHA256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`. 정식 반입, 실제 수신·해시·전체 ZIP CRC를 확인했다. 재다운로드하거나 원본을 변경하지 않았다. 원본 ZIP·원문 테이블·아트는 공개 Git에 넣지 않는다.

`tools/audit_inventory_automation_source523.py`와 `docs/auto_inventory523/source_audit.json`은 원본 읽기 전용 조사다. `tools/build_inventory_automation523.py`는 고정된 원본 바이트에서 개인 규칙 ZIP을 결정적으로 생성한다. 런타임은 ZIP/펼친 파일의 크기·SHA를 확인한 후 설치하고, 설치 실패 시 이전 규칙을 보존한다. 일반 경로는 `user://inventory523/inventory_rules523.json`; 검증용 환경 변수는 `TWILIGHT_AUTO_INVENTORY523_FILE`이다.

- StorageAutoStore84행/76개 ItemClass: 일반76, 축복4, 저주4. 축복을 이름으로 합치지 않는다.
- MerchantAutoSell25행:21개 실제 아이템과4개 가상 범주 선택자45011/45021/45031/45041. 범주 선택자를 실제 아이템으로 만들거나 일반/고급 장비 전체에 추정 확장하지 않는다.8271은 실제 정의가 있는 TestItem이므로 별도로 처리 보류한다.
- 현재 catalog는 원본 ItemClassID와 Inven sourceId·정확한 URL·정확한 설명 이름·유일한 인벤토리 이름이 모두 일치하는 보관43행/판매9행을 연결한다. 이름 유사성은 사용하지 않는다.
- 미반입 아이템은 별도 아이템 작업 PR238의 명시적 `lineagem_patch523`/`patch523`/`source_item_class_id`/`m523:item:<ID>`/축복 계약을 지원한다. PR238을 병합하거나 아이템을 지급하지 않았다. 이 계약의 추가 아이템은 단위 검사와 명시적 UI 테스트 fixture로만 검사했다.
- 원본 도움말은 명시적 대상 → 자동 담기 → 전체 수량 카트 → 최종 확인 흐름이다. 습득 즉시 무조건 판매로 해석하지 않는다. MerchantAutoSell 표에는 가격이 없으므로 ItemClass.Cost만으로 최종 매입가를 단정하지 않았다.

`data/automation/inventory523_prices.json`에는 원본 Cost와 공개 NPC 매입 설명이 함께 일치하는 값11개 및 각 URL을 기록했다.767/744/9011은 NC 공식 커뮤니티의 이용자 보고와 원본의 일치이며, 나머지8개는 공식 가이드/업데이트 근거다. 커뮤니티 글을 공식 패치 수치로 표현하지 않는다.

## 저장 계약

기존 단일 캐릭터 세이브 `inventory_automation` version1에 대상·남길 수량·가격 자체값·원본 모드·정비 토큰을 저장한다. 구버전은 빈 설정으로 읽으며 알 수 없는 확장 필드는 보존한다. 잘못된 타입·중복·음수·비정수·지원하지 않는 버전·소진된 실행 토큰을 가진 활성 예약은 로드를 거절하고 이전 파일을 보호한다.

카트는 인벤토리·물리 장비·창고·아데나·설정 복사본에서 구성한다. 아이템 ID/기록·잠금·장착·소지량·지갑·선택·원본 규칙 지문이 달라지면 재확인한다. 보관과 판매는 단일 payload에 들어가며, 기존 원자 writer 성공 후에만 live 상태를 바꾼다. 수동 판매도 같은 가격 검증 후 즉시 원자 저장을 완료하고 공개한다. 실제 writer 실패에서 인벤토리/창고/재화/기존 디스크 바이트가 보존되는지 검사한다. 미리보기·취소는 거래하지 않는다.

## 미구현 경계

현재 맵의 실제 좌표·충돌·경로와 기존 가방/창고 메뉴 서비스를 사용한다. 원본 M의 미확인 창고 NPC 위치·이동 비용·스케줄 활성 조건을 원본 동작으로 주장하지 않는다. 현재 Aden snapshot에는 배치된 창고/매입 NPC가 없고, PR235도 검증된 native M 도착 좌표가0개다. 그 작업을 병합하거나 자동사냥 이동/지역 퀵슬롯을 수정하지 않았다. 원본 M 스케줄러가 호출할 수 있는 `maintenance.preview/arm/before_portal/cancel` 거래 경계를 제공하되 실제 native M 예약 연결은 해당 좌표·활성 계약이 들어와야 한다. 사용자가 실행할 수 있는 위 자체 로컬 정비는 독립적으로 제공한다.

가상 범주4개의 장비 분류 선택 의미, 원본 전체 인벤토리 반입, 원본 전체 아트 동등성, Android/Windows 실기기와 실제 오디오는 완료 범위가 아니다.

## 검증과 전달

Godot4.7.2 official ed1daf0bf, 격리된 XDG 저장, 실제 Main/현재 source-map으로 검사한다. 기존 core save32, 자동 거래37, 기존 창고/매입/가격 권한·동일 payload·지연/일반 저장 검사를 보존한다. 추가 원본 규칙650, 정비32, 실제 개인 원본을 이용한 Python compiler8검사(결정성·손상·가격 불일치·잘못된 URL·유사/중복 이름)를 실행한다. 최종 UI/회귀 결과와 증거 SHA는 `docs/auto_inventory523/followup_validation.json`에 기록한다.

OpenGL UI는 X11/Mesa llvmpipe, Dummy audio를 사용한다. 실제 file picker를 열고 selected-file 소비 경로를 검사하되 OS 파일 선택 제스처 자동화로 주장하지 않는다. 실제 pointer/touch 거래와 작은 화면, 재시작, 실제 물리 이동·포털 트리거를 별도 검사한다. 원본 M 좌표 고증 검사로 집계하지 않는다.

축소 stage는 프로덕션 파일을 그대로 복사하고 이전 파생 import cache를 사용한다. 실제 main의 초상 Git blob `8ba48c3adeb3c88ef31dd929ffeea91aac2dc69e` 및 후속 실제 맵 이동에 필요한45041 초상(1,818bytes, SHA256 `7823d0ad31becb1989d765cf3472023613bf2175d1f58b2a75142ec0a3e1bcb4`)와 기존 `tests/fixtures/npc_service_field.json`을 같은 경로에 보충한다. Linux stage에서만 Android ETC2/ASTC import를 끄고 작업 스레드를4개로 제한했다. cold import로 주장하지 않는다. 프로덕션 project.godot·원본 이미지·워크플로·리소스 장부는 변경하지 않는다.

리소스 무결성723시트/41,442프레임/233,420,026bytes를 다시 확인한다. 예전 리소스 장부의 `--source-dir` 검사는 a1.zip 부재로 실패했으며 최신523 바이트 검증과 구분한다. 원격 CI는 `[skip ci]`로 미실행이고 필수 원격 게이트 통과로 주장하지 않는다.

적용팩과 원본 백업의 구분은 `docs/auto_inventory523/delivery.json`에 기록한다. [실제 규칙 적용팩](https://drive.google.com/file/d/1m_z0WWsRWTCYYI9L8sN4ePCw-yL8Drnz/view?usp=drivesdk)은 기존 실제적용팩 폴더에, [523 원본 백업](https://drive.google.com/file/d/1qCfbkTcVpehO-3oVU2mjo7atK2ErUQ0U/view?usp=drivesdk)은 원본소스 보존 폴더에 있다. 두 폴더/파일의 소유자 단독·비공유 상태를 확인했고 공유 권한은 변경하지 않았다.

적용 ZIP8,872bytes SHA256 `df1836767b85abd2e5f67ac023f005c80dc6df9cf8fa5022518887354eb9126d`; 펼친 JSON49,818bytes SHA256 `a6f06d657bc34a86d91ccbcaf9f2c836312df6e57d15d38e890aa74061b12bc5`. 새 `/workspace/inventory523-drive-consumer`에서 정식 Drive 응답으로 다운로드하고 크기·SHA·전체 ZIP CRC와 새 Godot 소비자의 실제 설치·읽기650검사 및 같은 Drive 다운로드본을 설치한 실제 Main/OpenGL UI39검사를 확인했다. 원본 백업25,031,173bytes도 새 Drive 객체를 한 번 재다운로드해 위 원본 SHA·CRC와 일치함을 확인했다. 백업은 설치 입력이 아니다. Drive 보관은 자동 적용이 아니며, 사용자가 규칙 ZIP을 고르면 `user://inventory523/inventory_rules523.json`에 설치한다. 규칙은 맵 팩을 대체하지 않는다.

후속 실제 UI39·기존 UI24검사, 원본650·정비32·compiler8·staging7검사가 통과했다. 손가락으로 체크박스에서 스크롤할 때 설정이 잘못 토글되지 않는 것도 확인했다. 최신 캡처8장과 후속 감사 로그는 **LOCAL_ONLY**이며 새 외부 업로드를 하지 않았다. 기존 초기 증거와 후속 검증을 혼동하지 않는다.

초기 PR251 증거: [개인 검증 ZIP](https://chatgpt.com/api/library/files/libfile_2ace049706348191868c546d06b31db7/download),3,348,596bytes, SHA256 `24b0ea122179d7dea241285b410e54a6b852dbd90b4256965dcbe1cc0bc01ad4`. 초기와 후속 검증을 구분해 보존한다.

```sh
python3 tools/build_inventory_automation523.py /private/source523.zip --output /private/inventory523
TWILIGHT_SOURCE523_ZIP=/private/source523.zip python3 -m unittest discover -s tests -p test_inventory_automation523.py
python3 tools/check_resource_integrity.py --root .
```

Godot stage 실행 시 `TWILIGHT_SOURCE_MAP_PACK`에 현재 맵 팩을 지정한다. 단위 원본 검사에는 `TWILIGHT_AUTO_INVENTORY523_FILE`/`TWILIGHT_AUTO_INVENTORY523_ZIP`을 지정한다. `inventory523_ui_test.gd`는 새 격리 프로필에서 원본 규칙 ZIP만 지정하고 파일 설치부터 검사한다. 기존 `auto_inventory_ui_test.gd`와 후속 UI는 X11/Xvfb에서 `--rendering-driver opengl3 --audio-driver Dummy`로 실행한다. UI를 headless 검사로 대체하지 않는다.
