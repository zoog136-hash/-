# 대법관 바로드 → 수정 단검 연결 (2026-10-29)

기준 main83cf145, 일반형5 identity 검토133d3ba5를 보존한 독립 후속이다.
`feature/source3-single-reviewed-drop-20261029`만 수정했다.

## 확정 범위와 근거

- source45962 `長老．巴陸德` → `l1j_tw380_npc_45962`/대법관 바로드 →
  `source3:tw380:Taiwan:weapon:11` → Inven423/수정 단검, 단1행.
- NPC 원SQL 전체 fields, tupleSHA, `$4296`의 실제 DESC C/E/K를 직접 대조했다.
  C의 `長老‧巴陸德`/E `Supreme Court Justice Barode`/K `대법관 바로드`와
  기존 `barod` 정의/gfx5471·형태 검토가 대응한다. `장로발루드`는 이전 자료 담당의
  임시 번역 오류이며 별도 몬스터나 변경 이름으로 쓰지 않는다. 배열index416은 사용하지 않는다.
- 통합 snapshot113 unique binding 전체의 source_raw_fields와 source ID를 기존 원SQL
  추출과 대조했다. Fairy45153은 활성 대상에 없다. main runtime/catalog item SHA도 동일하다.
- 원source tuple은 `('45962', '11', '1', '1', '5000', '0')`다. 실제 SQL byte range와
  file/tuple SHA를 확인했고, 근거는 source3_reviewed_drops.json에 기록했다.

## 확률·기존 pool 보존

기존 장비 희귀도 추첨은 변경하지 않는다. 일반 몬스터는 기존1회, 보스는 기존3회다.
희귀 등급 성공 후 기존 override/명시drop/coverage/crafting 후보를 모두 확인하여
**해당 등급 후보가 비어 있을 때만** 확인된 수정 단검1개를 채운다. 이미 후보가 있으면
결과·weight·수량·RNG 소비가 기존 코드와 같다. 기존 상점·가격·스폰은 변경하지 않는다.

이는 source3 드롭의 전체 확률을 재현하는 기능이 아니라 기존 TWILIGHT equipment-weight
adapter 안의 빈 성공 슬롯 연결이다. source chance5000은 provenance로만 보존한다.
분모나 global/map/item multiplier를 추정·적용하지 않는다. 원본 DropTable.java 전체는
제공 입력에 없으므로 원서버 확률 계산을 직접 실행/재현했다고 주장하지 않는다.
singleton의 상대 weight1은 유일 후보의 조건부 선택을 뜻하며 source5000을 새 확률로
복사한 값이 아니다. 기존 희귀도 확률0.001을 변경하거나 별도 성공추첨을 더하지 않는다.

몬스터 setup 시 작은 identity tuple을 매 생명마다 재설정한다. 다른 몬스터는 빈 tuple을
사용하고 드롭 시 추가 파일을 읽지 않는다. 정확한 source/game IDs, 원문명·버전·locale,
NPC SQL rowSHA·gfx/nameid·검토/authorization·HOLD 상태가 모두 일치해야 한다.
연결 증거 JSON과 identity JSON의 정확한 SHA도 runtime에 고정하며 byte drift 시 거부한다.
아이템도 기존 일반형 identity binding과 item sourceId/grade_source_id423, 이름·유형·slot·
희귀등급을 확인한다. ID나 이름만으로 연결하지 않는다. 저장 schema는 바꾸지 않는다.
원enchant0은 기존 기본 장비 생성 경로를 쓰므로 별도 강화 변환을 하지 않는다.
모든 결과는 기존 World→ground_loot 경로로 가며 직접 인벤토리에 지급하지 않는다.

## 검증

- 입력 ZIP 각각 size/SHA/CRC 및 내부manifest 통과: 통합22파일, shortlist3파일,
  최종 association/제작경계6파일.
- Godot4.6.3 headless에서 실제 loot_drop/bridge 및 실제 바닥 관리자·저장기를 읽는
  독립 프로젝트로 검사했다. UI art resolver만 `_icon` override로 null 처리한다.
  원본 서버코드·SQL은 실행하지 않는다.
- 10,000시드에서 기존 장비 grade와 물약 추첨을 대조했다. 정확한 identity/등급,
  잘못된 모든 identity 필드, item mapping·enchant, source ID 없는 요청 거부를 확인했다.
  기존 같은 아이템/다른 희귀아이템 명시pool, 원override 및 coverage가 있으면 원래 결과와
  RNG 상태가 같다. 기존 후보를 지우거나 추가로 중복 지급하지 않는다.
- `tests/source3_reviewed_drop_test.gd`의 write/read/empty를 **별도3프로세스**로 실행했다.
  실제 파일 저장 후 재시작, 두 번 restore의 중복 방지, 한 번 회수 후 중복 회수 거부,
  회수 후 저장·재시작 시 재생성 없음 모두 failures0이다.
- 기존 identity/DESC 회귀19개 및 리소스723시트/41,442프레임 검사 통과.
- 이 환경의 Godot은4.6.3이다. 저장소 기준4.7.2 및 최종 통합4cfff861 전체 게임
  부팅/실제 몬스터 처치/전체 UI 회귀는 실행하지 않았다. 통합환경 unavailable이며
  읽기 snapshot은6f23e5b5(NPC 최종 배치 전)다. 새 전체 clone이나 원격CI로 대체하지 않았다.

일반 프로젝트에서 테스트 파일은 다음 순서로 독립 실행한다. `user://` 아래의
`source3-reviewed-drop-test.json`만 사용하며 기존 게임 save는 수정하지 않는다.

```sh
godot --headless --path . --script tests/source3_reviewed_drop_test.gd -- --phase=write
godot --headless --path . --script tests/source3_reviewed_drop_test.gd -- --phase=read
godot --headless --path . --script tests/source3_reviewed_drop_test.gd -- --phase=empty
```

## 미확정 범위는 비활성

5개 무기의 소스drop23행 중 나머지22행은 대상 밖 HOLD다. 새 몬스터/스폰을 추가하지 않는다.
534제작식은5아이템과 아데나40308→gold wallet 후보를 고려해도 완전 대응0이다.
새6NPC의 명시owner 제작식0/shop행0, 장궁식은 미확정재료6개와 generic owner HOLD다.
534 disabled projection의 import_enabled=false를 확인했다. 기존414+2 자체 제작식과
상점4는 보존하며 신규 제작/NPC action 실행0이다. 퀘스트·펫·혈맹·공성 기능/보상과
잘못된45938/40196 min1/max0도 수입하지 않는다.

입력 Library: `libfile_a1e6fb5f80a88191b3d52d8447531e15`(1,110,851B,
SHA25642216fc424b657cebb00b5b4d7e71fce18b90a423225f728c6bde76ad23726e8),
`libfile_88766f07f4088191948859f6a5a78aa7`(5,153B,
SHA2560461a25f807f413a543cdb476c632b9cdcf64daa0f49cc6de2c0f4df0a0e03e8),
`libfile_fc7a8389200881919a7c86c3a26b63ff`(25,655B,
SHA256859325f896dc18a8e6664c3612d081b8353ee39bd1ce156eaa73ac6fc7e6550b).
