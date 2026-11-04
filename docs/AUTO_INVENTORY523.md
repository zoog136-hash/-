# 자동 창고·자동 판매 — 최신523 조사와 실제 로컬 거래

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`. 사용자 지시대로 독립 feature 브랜치·Draft PR이며 다른 PR/main 병합과 수동 CI 실행은 하지 않는다. 커밋은 `[skip ci]`를 사용한다.

## 사용 흐름

게임 메뉴 → 창고(보관 탭) 또는 판매 → 아이템 선택 → 남길 수량(기본0) 지정 → **자동 대상 등록** → **자동 담기·내역 확인** → 취소 또는 **모두 맡기기/모두 팔기**.

현재 소지한 스택 또는 정확한 장비 고유 ID만 등록한다. 이름이 같은 다른 장비나 이후 얻은 새 장비는 자동 선택하지 않는다. 선택한 소모품 스택 설정은 재시작 후에도 남고, 처리한 장비 ID는 설정에서 제거한다. 창고 찾기는 기존 수동/무게 제한 경로를 유지한다. 남길 수량은 TWILIGHT 편의 확장이며 0일 때 원본 도움말의 전체 소지 수량 담기 흐름이다.

자동 담기는 선택한 전체 수량을 거래 카트로 구성하며, 실제 아이템은 최종 확인 때만 이동/판매된다. 등록하지 않은 등급·이름·아이템은 추정 선택하지 않는다. 잠금(이름/고유ID), 장착, 퀘스트 보호와 기존 매입의 귀속/각인·거래제한·가격·지갑 상한을 보존한다. 원본 IsStorable=false가 명시된 기록은 자동 보관하지 않는다. 개별 장비의 강화·속성·커스텀 기록은 같은 물리 ID로 이동한다.

## 원본 증거와 경계

Library `libfile_f3e9e5b322cc8191ae441565bbd24c27`을 공식 prepare_materialize와 현재 Library 전송 helper로 반입했다. ZIP 25,031,173bytes, SHA256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`, 전체 ZIP CRC 성공. 원본·세이브는 변경하지 않는다. 원본 ZIP·원문 테이블·아트는 공개 diff에 포함하지 않는다.

`tools/audit_inventory_automation_source523.py ZIP`은 원본을 읽기 전용으로 검증한다. 요약은 `docs/auto_inventory523/source_audit.json`에 있다.

- StorageAutoStore84행/76 ItemClass. ItemBlessCodeID1=76행,2=4행,3=4행. 축복 행을 이름으로 합치지 않는다. 전부 ItemClass와 정확히 조인되며 IsStorable=true다.
- MerchantAutoSell25행/25 ItemClass. 이 표에는 ID와 ItemClassID만 있고 판매 가격·수량·확률은 없다. ItemClass.IsTradable=false인 행도23개이므로 유저 간 거래 여부를 원본 NPC 매입 허용 여부로 해석하지 않는다.
- UIStaticTextData_Korean의 STORAGE_POPUP_HELP / STORE_POPUP_HELP: 명시적 대상 선택 → 자동 담기 → 전체 수량 카트 확인 → 모두 보관/판매. 습득 즉시 아이템을 없애는 자동 판매로 해석하지 않는다.
- 실제 로컬 매입가는 기존 `local_buyback.gd`와 `buyback_rates.gd`를 사용하며 UI에 TWILIGHT 매입가라고 명시한다. 원본 NPC 최종 매입가를 추정하지 않는다.

**원본84/25 후보 전체를 현재 인벤토리에 원본 ItemClassID·축복 상태로 연결한 것은 아니다.** 현재 main의 Inven/L1J sourceId와 M ItemClassID는 서로 다른 식별자다. 이름 유사성으로 연결하지 않으며, 이 PR의 실제 사용 범위는 플레이어가 직접 선택한 현재 TWILIGHT 아이템이다. 원본 NPC 좌표·귀환/자동 이동·스케줄러 중간 정비는 검증된 호출 계약이 없어 추가하지 않는다. 자동사냥 이동 PR235 및 지역별 퀵슬롯 작업과 분리한다.

기존 main에는 수동 창고/판매와 원자 저장 writer가 있다. PR193의 지연 저장 경로와 구분해 이번 파괴성 거래는 즉시 저장 완료를 요구한다. PR247은 원본 상점 조회/미확정 가격 경계를 유지하므로 해당 가격 데이터를 가져와 임의 판매가를 만들지 않는다. 다른 PR을 병합하지 않았다.

## 저장과 실패 처리

선택 설정은 기존 단일 캐릭터 세이브의 `inventory_automation`(version1) 필드에 저장한다. 구버전 저장은 빈 설정, 잘못된 타입/중복/음수/비정수 수량/지원하지 않는 버전은 로드 거절 후 기존 저장을 보호한다. 알 수 없는 확장 필드는 보존한다.

카트는 인벤토리·물리 장비·창고·아데나·선택 설정의 복사본에서 구성한다. 현재 아이템 기록·잠금·장착·소지량·지갑·선택 설정의 확인 해시가 바뀌면 다시 담기를 요구한다. 최종 확인에서도 기존 매입/창고 검사를 다시 한다. 기존 `_save_game`의 원자 writer가 단일 payload를 기록한 후에만 live 상태를 교체한다. 저장 실패·외부 세이브 변경 보호·검수 모드·중복 요청이면 소모하지 않는다. 미리보기/취소는 저장이나 상태를 바꾸지 않는다.

## 검증

Godot4.7.2에서 자동 거래37검사, 실제 Main/current source-map·원본/진행/장비/컬렉션/보스 저장32검사, 동일 payload 저장·지연 저장 게이트·일반 저장 예약이 통과했다. 기존 창고/매입/가격 권한 검사도 원문 assertion을 유지해 통과했다. 해당 창고·매입 검사에는 main의 기존 `tests/fixtures/npc_service_field.json`을 같은 경로에 추가했다. 현재 원본 맵 고증 검사로 집계하지 않는다.

실제 OpenGL(X11/Mesa llvmpipe, Dummy audio) Main UI24검사에서 마우스/터치로 등록·카트·취소·보관·판매·저장 복원, 실제 거래/설정 writer 실패 보존, 손상 namespace의 로드 거부와 파일 보호, 재진입 수량 표시를 검사한다. 1280×720 및854×480 캡처4장을 별도 개인 증거 묶음으로 보관한다. 초기 검증에서 드러난 늦은 touch-script 부착의 release-handler 누락은 `set_process_input(true)`로 수정했다.

축소 실행 프로젝트에 없던 현재 main의 실제 몬스터 초상1개는 Git blob `8ba48c3adeb3c88ef31dd929ffeea91aac2dc69e`를 그대로 보충했다. 대체 그림을 생성하지 않았다. Linux 임시 stage에서만 Android ETC2/ASTC import를 끄고 import 병렬 작업을4개로 제한했다. 기존 파생 import cache도 사용했으며 cold-import 검증으로 주장하지 않는다. 원본 이미지 바이트·프로덕션 project.godot·리소스 장부·워크플로는 변경하지 않았다. 중단한 초기 importer와 실패 후 보완한 검증은 최종 성공 로그와 구분해 보존한다.

필수 리소스723시트/41,442프레임/233,420,026bytes의 Git 추적·SHA 검사, 전체 tools Python 구문 검사와 core staging Python7검사도 통과했다. 리소스 장부의 `--source-dir`은 예전 원본 a1.zip 부재로 실패했으며 이번523 ZIP의 별도 바이트/CRC/SHA 검사와 혼동하지 않는다. 필수 원격 CI는 `[skip ci]`로 미실행이고 수동 실행/재실행/취소를 하지 않는다. Android/Windows 실기기·실제 오디오·원본 전체 아트 동등성은 미검증이다.

재현 기준(각 실행의 XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME은 새 임시 경로):

```sh
python3 tools/audit_inventory_automation_source523.py /absolute/private/source523.zip
python3 tools/check_resource_integrity.py --root .
python3 -m unittest discover -s tests -p test_ci_core.py
python3 tools/ci_core_map_pack.py --root . --output /tmp/auto-map-review
python3 tools/ci_core.py --root . --stage /tmp/auto-review-stage --godot /absolute/Godot4.7.2 --logs /tmp/auto-review-logs --prepare-only
```

추가 검사 전에 새 stage에 이 PR의 `tests/inventory_automation_test.gd`, `tests/auto_inventory_ui_test.gd`, 기존 `warehouse_persistence_test.gd`, `shop_buyback_test.gd`, `shop_authority_test.gd`, `general_save_reservation_test.gd`와 기존 NPC fixture를 같은 경로로 복사한다. 위 Git 초상은 `assets/monsters/reviewed_source/l1j_tw380_npc_45027/portrait.png`에 복원한다. `TWILIGHT_SOURCE_MAP_PACK=/tmp/auto-map-review`를 지정해 stage를 editor/import 한 뒤 각 테스트를 `--headless --path /tmp/auto-review-stage --script res://tests/NAME.gd`로 실행한다. deferred gate에는 `-- --gate-only`를 사용한다. UI 검사는 X11/Xvfb에서 `--rendering-driver opengl3 --audio-driver Dummy --script res://tests/auto_inventory_ui_test.gd`로 실행하며 headless로 바꾸지 않는다.

최종 검사 결과·소스 및 증거 SHA는 `docs/auto_inventory523/validation.json`에 기록한다. 이 증거는 현재 로컬 기능의 동작을 보이며 원격 필수 CI 통과나 main 병합 승인을 의미하지 않는다.

[개인 검증 증거 ZIP 다운로드](https://chatgpt.com/api/library/files/libfile_2ace049706348191868c546d06b31db7/download): 3,348,596bytes, SHA256 `24b0ea122179d7dea241285b410e54a6b852dbd90b4256965dcbe1cc0bc01ad4`. 캡처4장과 최종/초기 진단 로그이며 원본 ZIP·맵 팩·실제 사용자 세이브를 포함하지 않는다.
