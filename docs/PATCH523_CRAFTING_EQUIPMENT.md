# 원본523 제작·장비 가공 연결

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`. 별도 환경 `/workspace/equipment523`, 브랜치 `feature/patch523-crafting-equipment-20261104`, draft PR [239](https://github.com/zoog136-hash/-/pull/239). 시작 시 관련 열린 PR을 대조했고 다른 PR을 병합하지 않았다. main 및 이전 커밋·원본·사용자 세이브를 보존한다.

## 실제 적용

기존 414개 TWILIGHT 제작식에 원본523 제작식 **345개**(확정334·확률11)를 추가한다. ItemClass ID, 현재 Inven 카탈로그 ID, 한국어 DescID/IdentifiedDescID 이름이 모두 일치해야 실행한다. 출력 강화·축복은 원본의 명시된 결과로 새 물리 ID에 기록한다. 기존 상점 가격·각성 비용·일반 강화 설정은 그대로다. 원본 제작1572의 오크족 토템(각인)100개→20000아데나는 인벤토리에 화폐 아이템을 만들지 않고 실제 지갑에 지급한다. 출력 수치도 원본값이다.

같은 SlotIndex의 복수 재료는 UI에서 사용자가 원본 행 하나를 직접 선택한다. 임의 선택하거나 전부 소비하지 않는다. 원본 서버의 자동 후보 선택 알고리즘을 복원했다는 주장이 아닌, 원본 후보를 사용하는 명시적 TWILIGHT 선택 계약이다. 선택 전 실행은 거부한다. 64개 속성 귀걸이 변환과 룬 변환을 포함하며, 입력의 강화·축복·속성·제련 효과를 결과에 복사하지 않는다. 원본 제련 소실 경고가 있는 제작만 알려진 제련 상태를 소비하고 확인창에 경고한다. 알 수 없는 인스턴스 옵션은 보호한다.

물리 재료는 정확한 ID/강화/축복, 장착·잠금, 수량, 무게, 아데나를 검사한다. 이름으로 저장되던 일반 스택 재료는 현재 카탈로그의 고유 원본 ID/이름에 연결한다. 과거 스택마다 별도 원본 provenance가 있었다고 주장하지 않는다. 모호한 이름/ID와 별칭 병합은 허용하지 않는다.

수호/회복 인장 상자 두 영구 ID(30701/130611)는 인벤토리 사용→확인창→상자 1개 소비→일반 +0 인장 1개와 빛나는 장비 강화 주문서 8개를 함께 지급한다. LuckyBagEntityType1 `IsGiven`의 확정 보상 두 행이며 확률 대안이 아니다. 물리 인장 ID, 무게, 잠금과 저장 성공을 확인한다. 원본 상점 판매가나 공급처를 임의 추가하지 않는다. 인장 8상자→일반 +3 및 같은 단계 일반 인장 2개→축복 인장 제작도 계속 사용한다.

축복 수호/회복 인장의 exact BlessCode2·해당 강화단계에서 11종 효과를 연결했다. 근/원거리 명중·대미지, 일반 리덕션, 물약 고정/비율 회복, 경험치, 아인하사드 절약, 대상6 스턴 내성, 물약 쿨타임이다. 기존 +0 카탈로그 기본값을 한 번 빼서 강화 증가분을 만든다. 낮은 단계를 누적하지 않는다. 기존 스탯 공식·중첩·캡을 사용한다. 물리 record와 장착 정보에 저장하므로 팩 없이 로드해도 적용된다. 이전 버전에서 만든 파생 옵션은 모든 기존 값이 현재 원본과 일치할 때만 확장하며 사용자/미확인 옵션을 덮지 않는다. 효과표 raw0→Normal1은 아직 추정하지 않는다.

## 실제 강화와 확인된 경제값

정보 화면의 `원본 인장 강화`는 별도 실제 실행 버튼이다. 수호30671/회복130551와 영구 주문서320802/166044만 지원한다. 이벤트 삭제 주문서나 테스트 아이템으로 확대하지 않는다.

공식 NC 공개 표 [캐시 장비 강화](https://probability.plaync.com/lineagem/view?probCategoryId=6656e14296b3cf5ad823b7a7)의 2026-11-04 공개 버전 `20261103210002`와 원본 group81/781을 직접 대조했다. 사이트가 사용하는 공개 API `/versions`, `/contents/{category}`, `/resources`의 전체 페이지를 읽었다. 공개 리소스 토큰은 저장/커밋하지 않는다. 재현 도구 `tools/equipment/verify_public_seal_probabilities.py`는 성공·유지·소실과 현재 단계까지 대조하며 게임 설정을 자동 갱신하지 않는다.

| 대상/주문서 | 현재 단계 | 성공률 | 실패 | 원본 소비/비용 |
|---|---|---|---|---|
| 일반 인장/빛나는 강화 | +0…+7 | 62/55/40/35/30/22/15/8% | 소실 | ConsumeAmount0 / Cost1000 |
| 일반 인장/빛나는 보호 | +4…+7 | 15/10/4/0.5% | 유지 | 3/10/20/50장 / Cost11000 |
| 축복 인장/빛나는 보호 | +4…+7 | 7.5/5/2/0.25% | 유지 | 3/10/20/50장 / Cost11000 |

성공은 +1이다. 원본 비용 수치와 보호 수량은 그대로 사용한다. 원본 통화 필드 및 일반 수량0의 소비 의미는 공개 자료에서도 확정하지 못했으므로 사용자의 후속 지시에 따라 **자체 설정: 게임 내 아데나, 일반 주문서 1장**을 사용한다. `data/crafting/patch523_seal_policy.json`의 economy에 원본/공식/자체값 provenance와 설정을 분리했다. 실행 화면·확인창에도 자체 설정임을 표시한다. 실제 결제/현금 구매 기능은 없다. 축복 장비에 일반 주문서의 raw Target0을 적용하는 자격은 추정하지 않는다.

[일반 무기](https://probability.plaync.com/lineagem/view?probCategoryId=663af7390b56825a0765f23b), [갑옷](https://probability.plaync.com/lineagem/view?probCategoryId=6656e15596b3cf5ad823b7ab), [장신구](https://probability.plaync.com/lineagem/view?probCategoryId=6656e17496b3cf5ad823b7af)와 축복 주문서 공식 표도 읽었다. 일반 무기/갑옷/장신구 확률은 기존 기본 경로와 일치한다. 장인 무기의 공식5%/유지95%와 기존 TWILIGHT0.6% 차이를 확인하고, 원본523 ID·현재 Inven 이름·등급·무기 슬롯·원본 GradeID가 모두 일치하는 대상에만 공식값을 연결했다. 일반~영웅은 현재+9, 전설+9/+10, 신화+9/+10/+11만 허용한다. 유일 등급은 일반 장인 주문서 대상으로 확대하지 않는다. 기존 로컬/미식별 장비는 기존 설정을 유지한다. 다른 특수 재질·일반 주문서의 전체 원본 대상 분류는 후속 범위다.

기존 강화 실행도 정확한 물리 record 및 위의 확인된 원본 장인 자격을 사용하고, 결과를 저장한 뒤 표시한다. 실패 시 주문서·물리 장비·장착·난수 상태를 복구한다. 원본 인장 경로는 아데나까지 복구한다. 제작/상자 개봉은 사본 거래를 실제 Main 저장에 먼저 커밋한다. 저장 거부 시 메모리와 기존 저장 바이트를 보존한다. 연출 중 중복 실행으로 재소비/재추첨하지 않는다.

## 화면·팩 설치

제작 장인→`원본523` 제작식→원본 후보 선택→강화/축복·사용 가능/필요 재료·비용 확인→제작→확인창→결과. 제작/기존 강화 화면→`원본 강화 정보`→보유 물리 ID/주문서 선택→원본 인장 강화→확률·실패·소비 확인→저장 후 기존 강화 결과 연출이다. 인벤토리의 빛나는 주문서 사용도 해당 화면으로 연결한다.

팩이 없어도 위 정보 화면을 열고 `규칙 팩 설치·교체`에서 파일을 선택할 수 있다. SHA·스키마·현재 카탈로그를 검증하고 `user://patch523-equipment/<SHA>/rules.json`에 복사한다. 활성 포인터를 원자적으로 저장하며 다음 시작에 자동 복원한다. 잘못된 파일·해시·설치 실패는 마지막 정상 레지스트리/설치/세이브를 유지한다. 명시적 환경 변수는 설치 포인터보다 우선한다. 기존 세이브를 강제로 새 원본 ID로 바꾸지 않는다.

공개 Git에는 코드·검사·작은 공개 확률/자체 경제 설정과 이 문서만 넣는다. 원문 행·분석 ZIP·이미지와 큰 런타임 JSON은 Git에 넣지 않는다. Library 같은 파일 ID의 버전을 갱신했고 공식 materialization으로 소비 폴더에 재다운로드하여 실제 파일로 검증했다.

- Library: `libfile_d044c27014888191a5f78a2bf745344e`, **version4**.
- 파일: `patch523-equipment-rules.json`, **29942517 bytes**.
- SHA256: `d2af6eb5cf84314616e60f249539754ddbebbdf36fd759897c8d43b4dd3ea7f5`.
- 소비 복원 경로: `/workspace/consumer523/patch523-equipment-rules.json`. Work 경로는 임시이며 영구 전달은 Library 파일이다.

```sh
python3 tools/equipment/build_patch523_rules.py \
  --content /private/current523/content \
  --catalog data/catalog_v19.json \
  --output /private/patch523-equipment-rules.json

TWILIGHT_PATCH523_EQUIPMENT_RULES=/private/patch523-equipment-rules.json \
TWILIGHT_PATCH523_EQUIPMENT_SHA256=d2af6eb5cf84314616e60f249539754ddbebbdf36fd759897c8d43b4dd3ea7f5 \
godot --path .
```

## 원문 증거와 기술적 잔여

원본 누적523 ZIP SHA는 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`, 제작 심층 ZIP `ed26d0f3e48c58f60c403e8a526d5786139476dcbd716c7f029365425d8e4b85`, 인장 심층 ZIP `e55db3ae269d5d73bdc902c924d65da5a9d94f3fb74f26016f683d6682246c08`이다. 세 파일을 해당 환경에서 Library materialization하여 읽고 전체 ZIP CRC/SHA를 확인했다.

컴파일러는29개 현재 표의 바이트 SHA를 고정한다. 제작 입력46254행, 출력30384행, 뷰1653행(고유1650ID), 제한16462행을 원문 조회에 보존한다. 확정 단일 결과 또는 공식 대조 확률 분기·고유 현재 ID·명시 후보·유효 기간·서버/플레이어 조건 등의 실행 조건을 만족한345개가 활성이다. 나머지1305개는 미지원 단일/복수 결과334, 카탈로그 미매핑/중복430, 서버/플레이어 조건490, 아이템 조건14, 물리 슬롯11, 기간/시간26개다. 경제값 자체 설정 승인으로 서버 자격·갱신 횟수·이벤트 기간을 무시하지 않는다. 뷰 없는261764/261774를 무제한 보장 강화로 노출하지 않는다.

수호/회복161효과, Bm 확률723행과 원본 소비량·축복 분기를 조회한다. 모든 Bm 확률을 전체 장비에 일반화하지 않는다. 전체 원본 무기/갑옷·특수 주문서 자격, 일반 인장 효과의 raw0 매칭, 다중 장착 그룹/슬롯 개방, 원본 창고 조건, 세공/제련/연금술/발동 훅 전체는 미완료다. 기능이 없는 장비를 임의 공급하지 않는다.

## 검증 범위

Godot **4.7.2 ed1daf0bf**, 별도 XDG 사용자 프로필, 현재 Git 맵 팩을 사용했다. 실제 사용자 세이브는 읽거나 덮지 않았다. CI 스테이징의 현재 원본 NPC portrait 누락은 실제 Git17원본 ID/83파일/15081235bytes를 포함하도록 수정했다. 합성 이미지나 오류 무시로 통과시키지 않았다.

최종 로컬 수치는 PR 설명/최종 SHA 보고에 기록한다. 검사 파일은 `tests/test_patch523_rules.py`, `tests/patch523_equipment_test.gd`, `tests/patch523_equipment_main_test.gd`와 기존 저장·강화·제작 회귀다. 실제 원본은 `TWILIGHT_PATCH523_CONTENT`, 실제 팩은 위 두 환경 변수, Main은 `TWILIGHT_SOURCE_MAP_PACK`을 지정한다. OpenGL 캡처는 Main 검사에 `--capture-dir=/private/captures`를 전달한다.

Linux llvmpipe OpenGL960×540/1280×720은 실제 렌더링이며 실기기 성능을 뜻하지 않는다. Windows/Android, 실제 오디오, 전체 과거 맵·전체 기능은 미검증이다. 초기 렌더 검사에서 UI 프레임 사이 몬스터 생성이 검사 RNG를 소비하는 비결정성을 찾아 테스트의 population을 정지하고 확인 클릭 직전에 테스트 seed를 넣었다. 게임 난수 정책은 변경하지 않았다. 최종 로그의 SCRIPT ERROR/ERROR/_FAIL은 허용하지 않는다.

리소스723atlases/41442frames/233420026bytes SHA 검사는 통과했다. 과거 `--source-dir` 검사는 historical a1.zip 부재로 실패했고 현재 제공된523 ZIP3개는 별도로 SHA/CRC를 검증했다. 새 원본 아트 전체 배포/복원 완료를 주장하지 않는다. 사용자 지시에 따라 원격 CI를 수동 실행/재실행하지 않고 `[skip ci]` 커밋을 사용한다.

## 통합할 때 확인할 공통 경로

최종 작업 시 열린 PR237(토템),247(상점),251(자동 창고/판매)의 실제 파일 diff도 재대조했다. PR237의 전용 토템 화면과 범용 제작 화면에는 원본244153/244163/244173의 무각인 강화석→각인 강화석 교환이라는 같은 원본 행이 있다. 별도 토템 성장/초기화 엔진을 이 PR에서 중복 구현하지 않았다. 합칠 때 전용 화면과 범용 제작의 같은 원본 ID를 한 거래 계약으로 유지하고 UI 중복 노출을 정리할 수 있다. 이 PR은 전용 토템 규칙을 복사하거나 병합하지 않았다.

PR247/251과 `_save_game`의 override 허용 목록·저장 payload가 공통이다. 통합 시 `next_item_instance_id`/`crafting_log`, 상점 상태, `warehouse`/`inventory_automation`을 모두 보존해야 한다. 각각의 저장 실패 보호도 합쳐서 검증해야 한다. 최신 main 단독 대비 mergeable 상태와 여러 기능 PR을 함께 합친 실행 검증은 서로 다르며 후자는 미실행이다.

### 이전244개 단계 검사 (게임 코드 `11f55b753cc8fe6b8e2f57828f15ca7e80b4d807`, 팩v3)

- 원본 전수/제작 조건 Python11개, CI 스테이징8개, Python 구문 통과.
- Library v3 재다운로드 실제 규칙/상태/후보/확률·수량/설치89개에 장인 등급 자격5개를 더한 Godot94검사 통과.
- 실제 Main 제작·확인·지갑 지급·인벤토리 상자·인장 강화·장인 자격·장착 효과·물약/스턴/경험치·저장 실패/재로드76검사 통과. 원본 없는 합성 거래 fixture는 실제 Main22검사 통과.
- 실제 OpenGL llvmpipe960×540와1280×720 각각80검사, 각4장 캡처 통과. 최종 SCRIPT ERROR/ERROR/_FAIL 없음. Dummy audio 명시, VSync 드라이버 경고는 별도다.
- 실제 Main/current source-map/기존 저장 보존32검사, 동일 payload 저장2write/1skip, deferred-save gate 통과.
- 기존414제작식 원자성·346비법서/등급 제작 회귀, 실제 강화 연출17검사와 per-instance 강화/속성/이주/저장 회귀 통과.
- 공식 공개 API 현재 버전의 인장3분기와 장인 무기3등급 전체 단계/실패 규칙 재대조 통과. 원격 CI는 수동 실행하지 않았다.

캡처8장·최종 로그·공식 대조 JSON·코드 SHA를 [Library 증거 ZIP](https://chatgpt.com/api/library/files/libfile_f8704eb429008191aea653070e5486c9/download)에 보관했다. 5160969bytes, SHA256 `c6b9a9ad5614b549617b541c303ca18018368a4fdbb6a26de6d396a2667ada94`. 원본 ZIP·큰 규칙 팩·실제 사용자 세이브는 증거 ZIP에 없다. 이 증거 ZIP은 이전244개 단계다. 최신 게임 데이터 팩은 [별도 Library v4](https://chatgpt.com/api/library/files/libfile_d044c27014888191a5f78a2bf745344e/download)다. 증거와 팩 모두 새 소비 폴더로 정식 materialization하여 SHA를 재확인했다.

## 후속 실행 연결: 원본345 제작식

이전244개에서 **101개**를 추가했다. 이 중 확률 제작11개는 [NC 제작 공개 표](https://probability.plaync.com/lineagem/view?probCategoryId=6656e08396b3cf5ad823b793) 버전20261103210002와 원본 ItemCraftInput/Output/View를 대조한다. 현재 실행 가능한11개는 티셔츠/견갑8개(실패90%의 원래+9 장비 반환/성공10%의 영웅+0), 지배석 상자3개(각인 성공90%/무각인 대성공10%)다. 표 전체에서 재료 슬롯·이름·수량·강화·축복 및 결과·수량·상태·확률이 모두 같은55계약을 확인했다. 나머지는 카탈로그/아이템 조건 때문에 아직 실행하지 않는다. 55개를 모두 실행했다고 주장하지 않는다.

`tools/equipment/verify_public_crafting.py --content /private/current523/content --public-table /private/craft-section-0.json --output /private/verified-crafting.json`으로 실제 원본29표 SHA와 공개 표를 다시 대조한다. 공개 스냅샷은 사이트의 public /contents→/resources 전체 페이지 응답이다. 외부 인증·계정 데이터·비공개 토큰을 사용하지 않는다. 모든 확률은 원본이며 새 확률을 추정하지 않았다.

원본 ItemClassLimit는 아이템 사용 직업이고 ItemClass.LevelLimitMin/Max는 사용 레벨이다. 제작 조건은 별도 ItemCraftRestriction/View에서 검사한다. 제작 재료를 소비하는 것과 아이템을 장착/사용하는 것을 분리했다. 새로운 물리 출력에 사용 조건을 저장하고 기존 BASE508.source_class_id로 실제13직업을 연결한다. 인벤토리·제작 상세에 조건이 표시되고, 맞지 않는 직업의 사용 버튼/실제 사용을 거부한다. 직업 변경/로드 시 허용되지 않는 슬롯만 해제하며 장비 자체는 보존한다. 저장된 물리 조건은 팩 없이 재로드해도 유지한다. 전체 스택의 새로운 네이티브 효과나 오만 이동을 구현했다는 뜻은 아니다. 스택 사용 조건 조회는 현재 팩이 필요하다.

보류33개의 원인은 원본 비용 누락이 아니라 컴파일러의1억 재료 상한에 원본2.5억/5억 아데나가 걸린 것이었다. 지갑 재료만10억까지 정확한 정수로 허용하고 일반 재료 상한은 유지한다. 같은 SlotIndex의43개 결제 후보도 사용자가 원본 행을 선택한다. 예: 제작120 드래곤 슬레이어의 **5억 아데나 또는 드래곤 다이아몬드2000개**, 두 값을 함께 소비하지 않는다. 선택 전 실행을 거부하고 실제 선택 비용을 화면·확인창에 표시한다.

`data/crafting/patch523_crafting_policy.json`은 원본과 구분하는 두 TWILIGHT 호환 설정을 가진다. 원본 재료549를 기존 동명의 게임 소모품 스택에 연결하며 기존 kind=ain_charge/amount100을 검증한다. 원본의 충전 보너스와 기존 게임의 충전량이 같다고 주장하지 않고 기존 충전량100·가격50000을 바꾸지 않는다. 호환 설정은 제작 전용 index에만 적용하며 전역 카탈로그/원본 ID/기존 저장을 덮지 않는다. 실제 코드의 kind/amount가 바뀌면 해당 연결은 거부한다. 이 연결을 사용하는63개 제작식에 호환 출처를 표시한다.

두 번째 설정은 실패 보상과 소비 장비의 원본 ID·강화·축복이 모두 같을 때 기존 물리 ID/기록을 보존하는 처리다. 원본이 정의하는 반환 품목/단계/수량은 유지하고, 동일 ID 보존 자체는 TWILIGHT 설정으로 표시한다. 성공은 원본 출력의 새 ID를 만든다. 확률 제작은1회씩 확인하며, 실제 원본 확률과 재료 연결을 항상 보이는 영역·상세·확인창에 표시한다. 모든 결과의 정확한 ID와 가장 무거운 결과까지 검사하고, 추첨 후 저장 실패는 난수 상태도 복구한다. 여러 출력이 동시에 지급되지 않는다.

통합 시 PR247의 원본549 등록과 이 호환 연결의 재료 정의도 함께 확인해야 한다. 기존 PR237/247/251의 저장 허용 키 합집합·토템 교환 중복 기록은 그대로 적용한다. 다른 PR을 임의 병합하지 않았다.

## 보관과 실제 적용 구분 (v4)

현재 게임이 소비하는 것은 **제작 규칙 JSON 데이터 팩**이며 전체 게임/원본 아트 팩이 아니다. `patch523-equipment-rules.json` Library 파일ID `libfile_d044c27014888191a5f78a2bf745344e`의 확정 **v4**,29942517bytes,SHA256 `d2af6eb5cf84314616e60f249539754ddbebbdf36fd759897c8d43b4dd3ea7f5`다. 승인된 비공유 Drive 프로젝트의 `01_실제적용팩_current523_제작장비_PR239`에는 같은 바이트를 `patch523-equipment-rules-v4-345.json`으로 보관한다. 폴더/파일 모두 owner-only·shared=false를 읽어 확인했고 공유 권한을 바꾸지 않았다. 정확한 비공유 Drive 링크는 작업 인계에 기록한다.

원본 보존용은 별도 `02_원본소스_보존`의 기존 `lineagem_patch523_all_content_validated_and_508_520_deltas.zip`(patch523,25031173bytes,SHA256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`)이다. 동일 원본을 다시 업로드하지 않았다. 해당 Drive 원본 사본을 내려받아 SHA·전체 ZIP CRC를 확인했다. 입력 분석 ZIP/캡처/감사 자료는 새 Drive 업로드에 포함하지 않았다.

Drive의 보관 파일은 자동 적용되지 않는다. PR239 코드에서 정보 화면의 파일 선택 설치기를 사용하거나 `TWILIGHT_PATCH523_EQUIPMENT_RULES`/`TWILIGHT_PATCH523_EQUIPMENT_SHA256`을 지정해야 한다. 설치는 `user://patch523-equipment/<SHA>/rules.json`과 활성 포인터 `user://patch523-equipment-active.json`을 사용한다. 원본 백업 ZIP은 여기에 설치하지 않는다.

Drive에서 새 소비 폴더 `/workspace/drive-consumer239/runtime/patch523-equipment-rules-v4-345.json`로 인증된 raw-file 다운로드를 받아 바이트/SHA/JSON/345개 정의를 검사했다. JSON이므로 ZIP CRC 대상은 아니며 원본 백업 ZIP은 별도로 CRC를 검사했다. 실제 Godot102검사에서 이 Drive 사본의 로드·관리 폴더 복사·포인터 복원을 통과했다. QA 설치 실제 경로는 `/tmp/equipment-drive239-unit/data/godot/app_userdata/황혼의 기사 · Offline RPG V20 LINEAGE HUD/patch523-equipment/d2af6eb5cf84314616e60f249539754ddbebbdf36fd759897c8d43b4dd3ea7f5/rules.json`이다. 이 Linux QA 경로는 사용자 PC의 설치 경로가 아니며 일반 표기는 위 user:// 계약이다.

최신 원본/제작 Python14·staging8·Godot 규칙102·기존 실제Main76·현재 맵/기존 저장32검사는 통과했다. 신규 제작·장착 자격·원본 확률·결제 선택·실패 반환·저장/재로드의 실제 화면 검사는 별도 인계 결과를 따른다. 새 캡처/로그는 `/workspace/equipment523-logs/v4-drive-ui-*`의 **LOCAL_ONLY**이며 최신 사용자 지시에 따라 새 외부 업로드를 하지 않는다. 이전244개 단계의 Library 증거 ZIP을 최신345개 검증으로 세지 않는다. Drive 원본/적용팩, Library 버전, 코드 PR, 로컬 QA 적용을 구분한다.


### v4 최종 검사

게임 코드 `2fadf0fee390887f918877c2270da27eced8405a`에서 Python14·staging8·Godot 규칙102·기존 실제Main76·현재맵/기존저장32를 통과했다. 새 소비 폴더의 Drive v4 사본은 Godot102(실제 로드/설치/복원)와 실제Main36검사를 통과했다. 동일 Drive 사본의 실제 OpenGL960×540·1280×720 각각41검사·4장 캡처도 통과했다. 인벤토리의 실제 상세 버튼을 열어 직업 조건을 표시하고, 직업 불일치 버튼 차단·실제 사용 거부를 검증했다. 확률은 스크롤 없이 항상 보이고 확인창에도 실제 수치가 표시된다. 실패 반환 물리 ID·소모량·결제 둘 중 하나·재로드·저장 거부/RNG 복구를 확인했다. 최종 로그에 SCRIPT ERROR/ERROR/_FAIL은 없다. Dummy audio/llvmpipe이며 Windows/Android 실기기와 실제 오디오는 미검증이다.

최신 캡처8장과 로그, Drive 실제 링크/원본 백업 링크/권한/바이트/SHA/설치 경로 영수증은 `/workspace/equipment523-logs/PR239_v4_delivery_receipt_LOCAL_ONLY.json` 및 같은 로그 폴더에 남겼다. 이것들은 LOCAL_ONLY이며 새 외부 감사/캡처 업로드를 하지 않았다. 원본/실행팩 Drive 링크는 최종 인계 답변에서 제공한다. 원격 CI 수동 실행/재실행·다른 PR/main 병합·M엔진/APK/XAPK 탐색/전송/분석은 하지 않았다.
