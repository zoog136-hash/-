# 누적523 탐험·용병 파견의 게임 연결

기준 main은 `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`이다. PR #243에서 실제 Main의 메뉴·출발·진행·사망/부활·완주/중단 정산·상자 개봉·인벤토리 수령을 연결한다. 확인된 원본·공개 자료를 우선하며, 원식이 없는 게임 내부 동작은 사용자의 지시에 따라 **설정 가능한 TWILIGHT 추정**으로 구분한다. 공식 서버 수식 재현을 주장하지 않는다.

## 실제 플레이 경로

Main → 메뉴 → **인형 탐험**에서 인형 탐험·변신 파견·성령 수집을 선택한다. 카드를 누르면 선택/해제되며, 파견은 서로 다른 변신4장이다. 현재 소환/추가 소환 중인 카드, 탐험·사망·완료 미수령 카드, 중복 장소는 다시 출발하지 못한다. 파견4장 모두 예약하고 일반/추가 소환 경로에서도 보호한다. 보상표의 존재가 소유·계열·등급·각성 레벨·서버·기간 제한을 덮어쓰지 않는다.

원본 입장비와 선택 버프를 확인한 뒤 한 번의 저장으로 출발한다. HP·남은 시간·진행/사망/완주 상태를 표시한다. 사망하면 부활하거나 중단하며, 살아서 원본8시간을 채우면 원본 완료 상자를 수령한다. 발견 아이템과 완료 상자는 탐험 공유 보관함에 들어가고 경험치는 카드에 반영된다. **상자1개 열기**와 **인벤토리로**는 별도 동작이다. 인벤토리의 완료 상자도 기존 아이템 사용 경로에서 열 수 있다. 조회/정산 내역/규칙 안내는 상태·난수·저장을 변경하지 않는다.

원본 아데나 HP·회복제와 다이아 행운 버프를 선택할 수 있다. 다이아는 이 단독 게임의 **TWILIGHT 탐험 로컬다이아** 지갑에서 소모한다. 명시적 아데나 교환 버튼의 교환비는 자체 설정이며 원본 구매나 운영 서버 재화와 연결하지 않는다. 기본 교환비는1개당10,000아데나이고, 네이티브 버프10다이아·파견 부활50다이아의 비용 수량은 그대로다. 확인 없이 자동 교환하거나 파견 부활비를 아데나로 직접 대체하지 않는다.

## 원본과 자체 설정

`data/expedition/twilight_estimated_rules.json`의 `field_sources`가 각 설정의 출처를 기록한다. 출발할 때 규칙을 작업별로 저장하므로 이후 설정 변경으로 기존 진행을 다시 추첨하지 않는다. 화면의 규칙 안내와 파견 조건 표시도 원본/추정을 구분한다.

| 항목 | 적용 내용 | 출처/해석 |
| --- | --- | --- |
| 장소·카드 | 원본29곳: 인형12·성물11·변신 파견6. 계열·각성 Lv.5 이상·등급·서버/기간 조건 | 누적523. 제한0인28곳이 실행 후보이며 실제 소유/카드 조건을 추가 확인 |
| 비용·시간 | 원본 장소별 아데나·28,800초, 계열별 동시5·일일15 | Spot/ConstantData. 과거 공식 공지의3곳보다 최신523의5 상수를 우선 |
| HP·경험치 표 | 기존 HP300행·CumExp60행이 최신523과 전행 동일 | 기존 게임의 카드 스킬각성 자료 사용 |
| 선택 HP/회복제 | 인형·성물 HP+200/50,000아데나,15분마다HP+50/100,000아데나. 파견 HP+800/50,000,15분마다HP+200/100,000 | Buff/Bonus 및 DescData_Korean484472/484482/1712072/1712082/2297964/2297974 |
| 행운 | 비용10다이아·주기60초 감소, 기본9분→8분 | 원본 Buff/Bonus/Desc 및 공식 파견 공지. 중첩은 기본 큰 감소량1개, additive 선택 가능(custom) |
| 일일·보관 | 05시 초기화·공유75종 스택, 기본 UTC+0 | 05시는 원본 UI 설명, 시간대는 custom. 시계 역행은 추가 초기화하지 않음 |
| 이벤트 주기·종류 | 기본540초마다 조건을 만족한 발견/없음/경험치/몬스터/넘어짐/휴식 동일 비중 | custom. 주기와 원본별 발생 확률의 완전한 수식은 없음 |
| 발견 후보 | 원본 그룹·특수 조건·ID·수량·축복·원가중치 | 원합100,000,000. 파견의 타입0/4/14/24를 보존하며 타입별 별도 정규화/임의 보정을 하지 않음. 일반/특수의 선택 분기는 custom |
| 조우 승패·피해 | Lv.5 기본70%, 이후+1%p/레벨, 상한95%. 일반 몬스터 HPDecrease 중앙값160 사용 | custom. 파견의 대표 피해 배수 기본4(custom). 몬스터를 지역에 임의 배치하지 않음 |
| 넘어짐·휴식·경험치 | 해당 원본 Bonus.Value 유지 | 원행의 HP/경험치 의미 및 설명 적용. 회복제와 이벤트의 동시각 순서는 before_event/after_event 설정(custom) |
| 부활 | 상한3·HP50%. 인형/성물 기본 입장비1배 아데나, 파견50로컬다이아 | 상한/HP는 원본. 인형/성물 비용 배수는 custom. 파견50다이아는 공식 공지에서 확인 |
| 중단·완주 | 중단은 발견품/경험치50% 내림·완료 상자 없음. 생존8시간 후 연결된 완료 Reward1건 | 회수율/생존 완료 전이는 custom, 지급 ID·수량은 원본 |
| 상자 | 기본1개당 원본 후보1행 추첨 | 횟수 설정은 custom이며 기본1. 원본193행의 수량/축복/강화와 합10,000,000을 유지. AbleMultiple=true만으로 동시 지급 횟수를 정하지 않음 |
| 오프라인 | 저장된 작업별 난수로 경과 시간을 재생 | custom. 작은 시간 조각과 같은 결과이며 반복/역행 시계로 재추첨하지 않음 |
| 카드 성장 | 기존 레벨 CumExp 하한을 보존하고 원본 발견 경험치를 더해 최대20 | 임계값은 원본. 이전 레벨5/EXP0 같은 저장의 하한 정규화는 custom. 선택 스킬·기존 각성 비용/실패 규칙 보존 |
| 파견 대표·HP·EXP | 기본 최저 GradeValue→최저 각성 레벨→카드ID로 대표 선택, HP4장 합산, 원본 팀EXP를4장 균등 분배 | custom. 대표를 최고값으로, HP를 최저값으로, EXP를 카드별 전량으로 설정 가능. 출발 때 적용값 보존 |
| 파견 시너지 | 기본 선택4장이 같은 원본 멤버 풀에 있으면 원본 효과 적용 | 조합 임계 수는 custom. HP2000/1000,15분 회복100,행운30초,휴식HP+5%,승률+1%p는 원본 연결/설명. 승률 raw10000은 UIUnit3 Denominator10000에 따라1%로 변환 |
| 로컬다이아 교환 | 기본1개당10,000아데나, 명시적 확인·원자적 저장 | TWILIGHT 자체 경제 연결. 별도 지갑이며 실제 결제·외부 거래 없음 |

`EventRate50`을50%로 쓰거나 행운60을 당첨확률+60%로 적용하지 않는다. 같은 아이템의 수량이 다른 후보행은 추첨 전에 합치지 않는다. 시너지64의 서버274와 장소223의 서버772, 각 카드의 비0 서버/기간 제한은 그대로 제한한다. Grade71을 다른 등급으로 바꾸지 않는다. 낮은 등급의18개 완료 표시도 삭제하거나 입장 허가로 사용하지 않는다.

## 획득 아이템의 후속 사용

보관함에서 넘긴 품목은 원본 ID/축복/강화를 표시명에도 남겨 기존 이름 기반 스택과 섞이지 않게 한다. issued 정의를 저장/복원하며 팩 부재 때 수량을 보존한다.

각성서75184/75194/95624/118992는 최신523의 ItemClass·ItemBonus·Bonus가 기존 스킬각성 자료와 전부 동일함을 확인한 경우에만 기존 각성 API용 물리 아이템으로 연결한다. 인벤토리/카탈로그는 patch523 출처와 이름을 유지하고, 물리 기록은 검증된 기존 canonical identity 및 `source_origin_snapshot=patch523`/`source_compatibility`를 보존한다. 수령·물리 ID를 함께 저장하며 기존 카드 스킬각성 화면에서 정상 소비된다. 기존 각성 비용·실패 규칙·잠금 검사를 변경하지 않는다. 한번에1000개까지만 물리화해 비정상 대량 할당을 막는다.

인벤토리에서 모든 탐험 보상을 완료 상자로 취급하지 않는다. 완료29상자는 이 런타임이 개봉하고, 각성서4종은 기존 각성 화면을 안내한다. 그 밖의 보상은 공용 원본 아이템 공급자(`LOOT_DROP.PATCH523_DROPS`)가 설치·등록된 경우에만 전체 `ItemClass` 정의, ID/축복/강화, 등록된 canonical record를 대조한다. 확인한 일반 상자·버프는 공용 소비자의 정체로 수량을 원자적으로 넘기고, 다음 아이템 사용은 공용 소비자가 효과·비용·조건을 처리한다. 주화는 그 공급자가 확인한 지갑 정체로 수량만 넘기며 임의 교환비를 적용하지 않는다. 잠금·정의 불일치·공급자 부재·저장 실패 시 기존 수량을 보존한다. 연결 이력도 저장하고 재접속마다 공급자를 확인하므로 소비자가 빠졌을 때 이름 기반 사용으로 우회하지 않는다. 공용 소비자 코드를 이 PR에 복제하거나 다른 PR을 병합하지 않는다.

보상 카탈로그에는 원본 `IsStorable`·거래/귀속·드롭 제한도 전달한다. 창고/판매 기능의 자체 가격·허용 판단을 새로 만들지 않는다. 원본 획득 그래프의373카드를 즉시 지급하지 않으며 탐험 정산은 몬스터 처치 드랍과 별도다.

### 다른 기능과 대조한 정확한 경계

2026-11-04의 PR238(`7d2e41b9`), PR239(`d186fc0f`), PR247(`843f735c`), PR251(`34870dff`)의 실제 코드와 보상 원문을 대조했다. 발견/완주 보상156종과 완료 상자의19종 결과를 합친 고유 아이템은166종이며, 다음 분류는 서로 중복되지 않는다.

| 보상 분류 | 종류 수 | 실제 소비 경로/의존 |
| --- | ---: | --- |
| 탐험 완료 상자 | 29 | PR243의 보관함/인벤토리 개봉·원가중치·중복 수령 방지 |
| 스킬 각성서 | 4 | PR243 수령 → 기존 카드 스킬각성 UI/API. 기존 비용/실패 규칙 유지 |
| 지정 카드 | 28 | 원본 BuffCardID/Unit33을 대조해 기존 보유 API로 연결.21종 일반 사용,6종 TestItem·1종 서버772는 아이템 보존·사용 차단. 신규2종만 좁게 등록 |
| 그 밖의 일반 상자 | 9 | PR238의 보장/가중/혼합 보상 소비자와 결과 폐쇄 집합. 탐험 팩의29개 완료 상자 정의로 대체하지 않음 |
| 일반 시간제 버프 | 3 | PR238의 원본 버프/지속시간/사용 조건 소비자 |
| 아인 충전 | 4 | 기존 충전 소비자와 PR238의 원본 정체 연결 |
| 장비 강화 주문서 | 2 | 기존 강화 소비자와 PR239의 원본 정체/강화 규칙 |
| 제작 비법서·선택 상자 | 2 | PR239의 제작/선택·재료 정체 연결. 별도 가챠 제작/선택 기능을 탐험에 만들지 않음 |
| 상품 연결 티켓 | 6 | PR247의 상품 정의와 소지 티켓 교환/뽑기 소비자 연결이 필요. 상품 구매·수령 구현만으로 티켓 사용이 된다고 판단하지 않음 |
| 재료·주화 | 79 | PR239 제작·PR247 상품·PR251 창고/판매의 원본 정체 사용. 재료는 클릭 효과가 없어도 정상이며 임의 판매가/교환 효과를 부여하지 않음 |

이전 main에 없던 지정 카드 대상 변신25242(아이템365392)와 인형25172(아이템365592)를 이번 어댑터가 등록한다. 고정 카드 보상28종의 제한은 아래와 같이 보존한다. 상품 티켓의 `MarketPurchaseID` 연결은 교환 API나 판매 활성의 증거가 아니다. 위 PR들은 조사 당시 모두 미병합이므로 이 PR 단독으로 그 소비 효과를 실행했다고 보고하지 않는다. 일반 상자/버프 공용 공급자는 합성 계약 검사로 **정확한 정체 전달·실패 원복·재접속 보호**만 확인하며 실제 PR238 효과 검증과 구분한다. 지정 카드21종의 실제 Main 인벤토리 소비는 별도로 검증한다. 이 범위를 넘어 전체 제작·상점·카드 추가를 시작하지 않는다.

## 신규 카드 연결과 원본 제한

PR249 `cd71bc2de336d5d8c1aa547f7e838f788d0015a6`의 변신402·인형171·성물147 정의와 최신523 원본을 읽기 전용으로 대조했다.720개 원본 행과 안정 ID가 일치하며 기존701개의 ID를 변경하지 않는다. 탐험 고정 카드 보상28종의 대상 중26종은 기존 정의에 있고, 실제 빠진 대상은2종이다.

- 황금성단25242: `source:m523:1:25242`, 원본 희귀. 아이템365392는 일반 사용 가능하며 원본 `IsNoMergeOut`/`IsNoSwapOut`을 보존한다.
- 투사(여)25172: `source:m523:2:25172`, 원본 고급. 카드 정의와 보유 저장 ID는 등록하되 지급 아이템365592의 **TestItem=true**를 해제하지 않는다. 아이템을 보유해도 일반 사용은 차단하며 수량은 보존한다. 고급을 희귀로 올리거나 스킬각성 Lv.5를 무료 부여하지 않는다.
- 기존 아이템113912/113922/113932/113942/113952도 원본 TestItem=true다.284328의 대상23258에는 서버772 제한이 있다. 총28종 중7종은 원본 제한 때문에 차단하고21종만 고정 지급한다. 보상표의 존재가 사용 활성의 증거가 아니다.

`scripts/expedition/reward_cards.gd`는 기존 팩의 `BuffCard`/`ItemBonus`/`Bonus`/`BonusType`/`Grade`를 읽어 누락2종만 런타임에 보충한다. PR243 단독 카탈로그는703종이며720종 전체 정의를 이 PR에 복제하지 않는다. PR249의 나머지17종이 정식 등록되면 같은 원본 정체 검사를 통과해 기존 각성 프로필 API와 탐험 자격 조회에 연결된다.720종 계약 검사는 실제 PR249 정의를 참고한 검사이며 이 PR에서720종을 설치하거나 그 전체 효과를 실행한 결과가 아니다.

신규 정의는 `source_draw_pool_pending=true`로 가챠·합성 결과 풀에서 제외해 기존 확률과 후보를 그대로 유지한다. 원본 ID/덱/등급/서버·기간을 확인하고, 아이템1개 소비와 보유·중복 수량 및 no-swap/no-merge 출처 영수증을 같은 저장으로 확정한다. 저장 실패·아이템 잠금·빈 스택 재사용 때 지급하지 않는다. 별도 팩이 빠져도 신규 소유 ID와 중복 수량을 미매핑 저장에 보존하고 팩 복귀 시 정확히 복원한다.

각성은 기존 등급별 각성서·사용자 비용·난수·성장 규칙을 사용한다. 신규 희귀 카드도 처음 각성하면 Lv.1이며 탐험 Lv.5 조건을 자동으로 충족하지 않는다. 실제 Lv.5 이상 저장/기존 성장 기능이 필요하다. 검사에서 사용하는 Lv.5/Lv.20·발견품 fixture는 통제된 검증 입력이며 일반 플레이 지급이나 원본 추첨 확률 검증이 아니다. 신규 카드의 원본 HP/CumExp는 기존 공용 표를 사용한다. 스킬각성 저장과 탐험 작업은 기존 `m508` 및 신규 `m523` 정규형을 보존한다.

신규2종의 원본 픽셀·완전한 장착/전투 효과는 이 좁은 보상 어댑터가 복원하지 않는다. 탐험 선택 목록과 카드 설명에 이미지 미설치를 표시한다. 최신523 전체 카드 효과/이미지 통합은 PR249의 범위다. 정상 원본 팩27표/크기/SHA/Drive 적용 경로는 그대로이고 새 팩·이미지를 전송하지 않는다.

이 단계의166종 분류는 직접 완료 상자29·기존 각성서4·고정 카드 사용21=54종, 원본 제한 고정 카드7종, 다른 기능 소비/재료 정체 의존105종이다. 후자에는9개 일반 상자·3버프·4아인 충전·2강화 주문서·2제작/선택·6상품 티켓·79재료/주화가 있으며 전체 일반 플레이 통합 완료로 표현하지 않는다.

## 저장과 이전

`expedition523_local` version2는 로컬 저장 공간이며 원본 서버 프로토콜이 아니다. 작업별 HP·시간·규칙·난수·발견품·파견4장·시너지, 일일 횟수, 로컬 지갑, 보관함, 인벤토리 연결과 수령 영수증을 보존한다. 전투/카드 뽑기의 난수는 소비하지 않는다.

출발/선택 버프, 부활, 정산/경험치, 상자 소비/난수, 보관함/인벤토리/물리 각성서, 지갑 교환을 각각 기존 원자적 저장으로 확정한다. 실패하면 관련 라이브 상태와 난수를 변경하지 않는다. 작업 제거/영수증으로 중복 수령을 막고, 보관함 변경은 확인창을 무효화하되 다른 탐험의 타이머 진행만으로는 무효화하지 않는다. 지도 저장 활성화가 진행 중이면 경제 거래를 보류한다.

첫 출발 또는 최초 지갑 교환 전 `.pre-expedition523-<SHA>` 백업을 만든다. 이전 version1 유료 기록은 원본 그룹 최소 레벨을 보수적인 하한으로 사용해 이행한다. 이미 경과한 시간은 초기 난수로 재생하고 입장비를 다시 받지 않는다. 최초 쓰기 전에 `.pre-expedition-estimate-<SHA>` 백업을 남긴다. 로드만으로 기존 파일을 다시 쓰지 않는다. 이전 version2에서 지갑 필드가 없으면 잔액0이고, 단일 카드 기록은 기존 형식대로 읽는다. 팩 부재 시 version1 기록은 비활성 상태로 보존한다. 손상 저장은 플레이어 변경 전에 거절하고 덮어쓰기를 차단한다.

## 데이터 팩·보관·설치

Git에는 코드/검사/문서/자체 설정만 넣고 원본 표·파생 원본 JSON·이미지는 넣지 않는다. 실제 소비자는 `expedition523.private.json` 하나이며 원본 전체 ZIP은 컴파일 입력/보존용이다.

- 런타임 schema `twilight.expedition523.v1`,27표,2,880,431bytes, SHA256 `39f075e3aea122080b060c8682c81dc6b43e3cb97e886504bdefd9dfc2034991`.
- 원본 누적523 ZIP:25,031,173bytes,1,075 ZIP members, SHA256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`.
- 런타임은 기존 Library `libfile_7c9564a9c63c8191af8b54788b9adef0` version0과 동일하다. 후속 기능은 같은 원본27표를 사용하므로 원본 팩을 임의 증보하지 않는다.
- 비공개 Drive의 `01_실제적용팩_current523_탐험`에는 런타임 JSON, 기존 `02_원본소스_보존`에는 원본 ZIP을 분리 보관한다. 폴더/파일의 비공유 상태를 확인했다. 기존 ZIP 사본을 중복 업로드하지 않았다.
- Drive에서 새 소비 폴더로 내려받은 런타임/원본 모두 SHA일치, ZIP전체 CRC와 JSON파싱을 확인했다. 실제 게임에 아래 인자로 Drive 수신 런타임을 지정해 로드/검증했다. Drive 저장이 자동 게임 설치를 뜻하지 않는다. 정확한 비공개 보관 링크/버전/소비 경로는 별도 인계 기록에 있다.

```sh
python3 tools/build_expedition523_pack.py /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip /private/expedition523.private.json
Godot_v4.7.2-stable_linux.x86_64 --path . -- --expedition523-pack=/private/expedition523.private.json --expedition523-sha256=39f075e3aea122080b060c8682c81dc6b43e3cb97e886504bdefd9dfc2034991
```

컴파일러는 원본 ZIP SHA와27표의 index SHA/CRC/바이트/행수를 확인한다. 소비자는 명시한 팩 SHA·형식·참조·행수·풀 합을 검사한다. 잘못된 교체 팩으로 카탈로그를 덮어쓰지 않는다. 팩 부재 시 기존 게임은 열리고 탐험 화면은 미설치를 표시한다.

## 조사와 검증

원본 도움말 PANEL2/3/5와 TEXT_NOTICE_2, UIText50324/59651, UIError17172, DescData_Korean 및 UIUnit을 대조했다. 추가 설명 표는 원본 index의 SHA/바이트/행수까지 확인했다. 공개 공식 자료도 검색/열람했으나 혼합 파견 대표 그룹·HP 합산·EXP 분배·전체 이벤트/전투 수식은 찾지 못했다.

- [공식2025-12-03 파견 공지](https://lounge.plaync.com/feed/51721?country=KR&locale=ko-KR): 변신4장·Lv.5·시너지·버프 비용/효과·50다이아 부활. 이전 매개변수 없는 URL의404와 구분해 실제 열린 공개 페이지를 확인했다. 과거 동시3곳은 최신523 상수5를 덮어쓰지 않는다.
- [공식2026-06-24 공지](https://lounge.plaync.com/feed/73057?country=KR&locale=ko-KR): 지저성·480분·완료 상자의1종 보상.
- [공식2025-09-17 업데이트](https://lineagem.plaync.com/board/update/view?articleId=68c9bab8b276e6387160d1ee): 인형/성물 공유 보관함 안내.

```sh
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/expedition523_estimate_model_test.gd -- --expedition523-pack=/private/expedition523.private.json --expedition523-sha256=39f075e3aea122080b060c8682c81dc6b43e3cb97e886504bdefd9dfc2034991
Godot_v4.7.2-stable_linux.x86_64 --path . --script res://tests/expedition523_completion_test.gd -- --expedition523-pack=/private/expedition523.private.json --expedition523-sha256=39f075e3aea122080b060c8682c81dc6b43e3cb97e886504bdefd9dfc2034991 --expedition523-capture=/private/completion
```

실제 Main/OpenGL에서 통제 이벤트 fixture로 완주/사망/3회 부활/중단/상자/인벤토리/기존 각성 UI, 파견4장 예약/해제/경험치 분배, 시너지, 유료 버프/회복 타이머, 로컬 지갑, 오프라인, 일일 횟수, 원자적 실패 원복, 중복 지급 방지와 이전 저장 이행을 확인한다. fixture를 공식 확률 검증으로 설명하지 않는다. 모델 검사는 기본100시드에서 희귀Lv.5 완주42/사망58의 작은 표본, 시간 조각 동등성, 원본 가중치 불변과6종 시너지 원값·제한 보존을 확인한다.

전체 게임플레이/Android 실기기/운영 서버 동등성/원본 아트 전체 전달을 주장하지 않는다. 역사적 아트 검사기의 `--source-dir`가 요구하는 `a1.zip`은 이번 데이터3ZIP과 별개이며 기존 리소스 장부를 승격하지 않는다. `[skip ci]`를 유지하고 원격 CI를 수동 실행/재실행하거나 다른 PR/main을 병합하지 않는다. 원격 CI 미실행은 통과가 아니다.

최종 로컬 결과(2026-11-04): Drive 수신 적용 JSON으로 실제 Main/OpenGL200검사·16캡처(1280×720/960×540), 원본 카탈로그67, 파견/시너지 포함 모델22, 실제 Main/current source-map·역사적 저장32와 동일/지연 저장 게이트가 실패0이다. 기존138검사에 원본 신규 카드의 완주 발견품 정산·수령·각성 UI·파견·재접속/중복 보호를 더했다. 별도 실제 Main 인벤토리109검사에서 고정 카드21종의 정확한 지급과 제한7종의 보존·재접속을 확인했다. 원본/등록 계약1481검사에서는 실제 PR249720행을 대조했다. 공용 소비자 자체는 합성 계약 fixture이며 다른 미병합 PR의 실제 효과를 실행한 결과가 아니다. Git 리소스723시트/41,442프레임 SHA검사도 통과했다. 렌더링은 Linux llvmpipe이며 사용자 기기/Android 검증은 아니다.
## Local follow-up after public df76940f (not published)

The optional producer boundary reads PR239 `432ee5a6587d2b870fe917ea9f030088f91df9ad`.
An integrated host may expose `patch523_open_expedition_enhancement(key)` to open
the exact issued137/138 target picker. The producer delegates before its unsupported
item fallback. Opening returns `committed=false`; it is not a debit, grant, RNG
advance, save, or another receipt acknowledgement. Missing owner capability and
orphaned typed scroll keys preserve stock and cannot enter legacy substring use.

Issued materials use the published `patch523_expedition_materials.owned()` reader
only when the real host has its native crafting context, executor and item index.
The context must contain the same expedition owner. After exact ownership admission
the existing owner crafting UI opens; recipe/server/calendar/quantity/lock checks,
debit/refund, output/usage/log/RNG and the single durable save remain with PR239.
The producer never renames the issued namespace or adds `source_m_native_item`.

The bounded local proof test uses actual Main, held unchanged v8 input, real storage
withdrawals and the exact published ownership reader. It distinguishes ownership
from recipe qualification, and absence of a combined crafting/enhancement host from
a successful transaction. It does not import the owner's World/engine or replace
the completed318box/195ticket/15restart evidence with mock success.

Owner-reported recipe restrictions remain separate:292302/292312/292322/292332
require server772,282863 server762, and216053 has no ItemCraftView. The held v8
input lacks341344/341354/341364; no replacement definitions/policies are invented.
Positive end-to-end execution must use the real combined host: producer claim/open/
withdraw -> inventory activation -> owner target/recipe selection -> confirmation
-> exact typed debit/refund/output/usage/RNG -> single save and reconnect. Preserve
the owner's `patch523_crafting_usage` save field and source conditions in that host.
No completed dependency count is increased by a UI opening or ownership proof.
