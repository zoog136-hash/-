# source3 일반형 무기 5개 동일성 검토 (2026-10-29)

기준 main: `83cf145ad4565124c8734003b3f7d7d266d2245f`.
기존 수정 단검 검토 커밋 `8a2b318853071d8d854cf69cf4fe57ac85da3b26`을 보존하고
DESC 원문·표시 접두어 근거를 보강했다. identity JSON schema2와 읽기 전용 검증기는
다음 일반형 템플릿만 채택한다.

| source3:tw380:Taiwan:weapon ID | 실제 한국어 표시명 | game source / sourceId | source type / game type |
|---|---|---|---|
| 1 | 오크족 단검 | inven / 326 | dagger / 단검 |
| 8 | 미스릴 단검 | inven / 422 | dagger / 단검 |
| 11 | 수정 단검 | inven / 423 | dagger / 단검 |
| 29 | 은장검 | inven / 6391 | sword / 한손검 |
| 181 | 장궁 | inven / 339 | bow / 활 |

런타임 등록 또는 드롭·제작·NPC 실행 연결은 없다. 기존 DB, 가격, 수치, 물리 장비 ID,
세이브 및 NPC33/상점4·별도 통합 신규 NPC6은 수정하지 않는다.

## 검증된 입력과 독립 근거

- 기본 입력: Library `libfile_84c813fce0a08191a2b6839257f9c43e`, v0,
  `source3-item-drop-craft-input-v1.zip`, 5,054,066 bytes,
  SHA256 `2489a9ed7ff7db797bd06184b0292f75d8d8e80bee94a6d23fac678134dc1b70`.
  소비환경에서 size/SHA/CRC 및 manifest 28파일, SQL tuple 바이트 범위/SHA 20,292행,
  XML MakeItem 534개를 검증했다. SQL·서버·콜백은 실행하지 않았다.
- 보강 입력: Library `libfile_14da8902eebc81919c1110e8adddbc94`, v0,
  `source3-desc-five-weapons-variant-evidence-v1.zip`, 557,960 bytes,
  SHA256 `4bf2ead4a691bdda17c5c8ee6421e6a844e462715277db09cfc4a5ead2afecc5`.
  지원 Library materialize 후 size/SHA/CRC, 모든 manifest entry size/SHA,
  독립 검증기의 암호·복호화 3table 및 실제 표시명 9variant를 확인했다.
- 원본 descC/E/K의 정확한 암호 범위와 복호화 원문을 대조하고, encoding별 strict decode와
  tokenN→splitlines[N+1]을 사용한다. 표 header를 실제 행 수로 믿지 않는다.
- PAK 버전은 제공된 3.81c 클라이언트 Text.pak provenance이고 SQL/Java는 3.80c다.
  전체 PAK SHA/offset는 제공된 provenance이며 전체 Text.pak은 묶음에 없어 여기서 전체
  PAK 바이트 SHA를 다시 검증했다고 주장하지 않는다. 암호 범위↔복호화 바이트와 각
  명칭 C/K·형태·아이콘 근거를 개별 대조했으며 버전 전체 동일성을 가정하지 않는다.
- `S_IdentifyDesc` 29–47행의 고정 excerpt SHA와 표시 로직을 읽기/파싱으로 확인한다.
  bless0은 `$227 `, bless2는 `$228 `를 identified_name_id 앞에 **추가**한다.
  bless1만 접두어가 없다. 단어를 제거하거나 이름을 정규화해 매핑하지 않는다.
- 축복형100008/100029/100181은 각각 `축복받은 미스릴 단검/은장검/장궁`, 저주형200001은
  `저주받은 오크족 단검`이다. 이 네 template은 일반형 binding에 포함하지 않는다.
- 9개 SQL variant의 fields/tuple/provenance를 기존 source_items 및 고정 원본 weapon SQL의
  실제 byte range와 재대조한다. 일반형5개는 strict C/K 표시명, 타입, 기존 A3 검토,
  inventory/ground 참조를 모두 확인한다. A3 숫자 ID 단독이나 같은 버전이라는 가정은 없다.
  장궁도 C `尤米弓`/E `Yumi`/K `장궁` 원문과 bow 및 기존 검토를 함께 사용한다.

## 재검증

두 Library 입력은 소비환경 자체에서 materialize하고 위 size/SHA/CRC를 먼저 확인한다.
검증기에는 Python `cryptography`(TripleDES decrepit 모듈 포함)가 필요하다.

```sh
python3 tools/l1j/verify_source3_item_identities.py --source-input /path/to/base/input --desc-input /path/to/desc/input
python3 tests/test_source3_item_identities.py --source-input /path/to/base/input --desc-input /path/to/desc/input -v
python3 tools/check_resource_integrity.py --root .
```

검증기는 현재 catalog/runtime DB/기존 visual bindings, 소비 source_items/weapon SQL,
보강 입력의 모든 파일 바이트 SHA를 고정한다. 변경 시 HOLD이며 hash를 자동 갱신하지 않는다.
유효하지 않은 이름 token, 모르는 bless값, raw 변형 불일치, 중복 실제 표시명,
source/game ID 중복, 제외 기능, 타입·원문·아이콘 근거 불일치도 거부한다.
축복형을 일반형으로 재작성한 binding도 거부한다. 각인·봉인·강화형을 자동 승인하지 않는다.

결과: 검토 identity5개, gameplay=false, 활성 드롭/제작/NPC action 각각0개.
원문 검증과 변경·변형 혼합 거부를 포함한 회귀검사를 실행한다. 일반 unittest discovery는
private 입력 없이 skip한다. 게임 실행 경로 변경이 없어 Godot boot/UI는 이번 단위에서
실행하지 않았다. 필수 리소스 검사는723개 WebP/41,442프레임/233,420,026 bytes 통과했다.
이 결과는 원본 리소스 전체 납품을 뜻하지 않는다.

## 남은 HOLD

- 드롭: 통합113 exact sourceNPC→game binding과 provenance 대기. 구 main 몬스터163을 추정
  대응하지 않는다. source chance/enchant는 기존 게임 확률이나 수치로 자동 복사하지 않는다.
- 제작: 모든 재료·결과·통화 지갑 대응과 NPC ownership 확정 전 비활성.
  callback은 랜덤 성공률로 해석하지 않는다.
- 위 일반형5개 외 identity와 축복·저주·각인·봉인·강화형은 별도 검토가 필요하다.
- 퀘스트·펫·혈맹·공성 전용 기능/보상은 비활성.
  잘못된 source drop45938/40196 min1/max0는 수정하거나 수입하지 않는다.

원본 서버코드·DESC 바이너리를 저장소에 복사하지 않았다.
원격 push/새 PR/수동 CI/main 병합 없이 독립 로컬 커밋으로 전달한다.
