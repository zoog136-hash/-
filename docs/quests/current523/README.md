## Current source-regeneration follow-up

[SOURCE_REGEN.md](SOURCE_REGEN.md) records two real quest potion consumers and five exact source gear regeneration connections. Amounts/duration come from source; the30second cadence is labelled TWILIGHT policy.48 of146 classes now have at least one bounded path,98 have none. Actual normal+0 gear use totals26 units/24 classes with7 raw stacks retained. New-source completions remain811; current Knight preview without skillv3 has326 some-use-pending quests. Earlier pending counts below are historical. 4318 focused assertions passed; all-effect/native-cycle/full-game completion is not claimed. Existing original saves and resource packs are unchanged.

## Current selected-equipment follow-up

[QUEST_EQUIPMENT.md](QUEST_EQUIPMENT.md) records actual21 units/19 original equipment classes individually materialized and worn;12 raw stacks remain. Genuine rune226318 retains its UUID and both proofs. AC/HP/MP/MR/STR, two weapons' damage/hit inputs, rank0XP, UI/equip/unequip, confirmed atomic save/failure/reconnect are bounded verified paths.41 of146 classes now have at least one verified consumer;105 have none. Other states/effects and four learned spell effects remain separate. 11425 incremental focused assertions include repeated unchanged-physical checks, not unique features. Private rules/view stay LOCAL_ONLY; prior packs and original811/822 saves are unchanged. Earlier checkpoints below are historical.

## Current follow-up: exact reference learning

Four additional source books have actual native learning/receipt/atomic-save connections, with explicit execution-pending UI and persistent cast/automatic/quickslot holds. See [REFERENCE_LEARNING.md](REFERENCE_LEARNING.md).1075 checks passed; native spell effects remain pending. New source completions remain811. Knight pending-use preview:359 with default ten consumers,351 with exact LOCAL_ONLY v3 and twelve books. The separate Mage context is354. Distinct adapter review is22/146, with124 remaining classes plus four learned spell effects still pending. Old822 saves/537 history and all existing packs remain unchanged. The older milestones below are historical evidence.

# PR229 후속 — 최신523 퀘스트 전수 투영과 자동 완료

원본 `QuestView` **3,621개 전체**를 읽고 원본 ID·목표·선행 조건·보상·운영 기간을 연결했다. 기존 보고서의 3,376개를 고정값으로 사용하지 않았다. 원본 전체 정의의 반영과 모든 보상의 사용 기능 완성은 구분한다. **전체 게임 기능 완료 상태는 아니다.**

최신 고정 카드 후속은 [FIXED_CARDS.md](FIXED_CARDS.md)와 [fixed-card-validation.json](fixed-card-validation.json)에 기록했다. 정상4종의 실제30개 지급분을 기존 소유자에 연결했으며 TestItem27종은 유지한다. 새811개 완료 중 일부 사용 대기는 기본10소비자359개, 정확한 v3 입력을 함께 설치한18소비자356개다. 옵션 주입 보존은 원본 NoMerge 규칙으로 확장하지 않고 새 퀘스트 중복에만 명시한 TWILIGHT 안전 정책이며 기존 자유 사본·비용·EXP를 유지한다. 아래22c7 당시 수량과 구분한다.

현재 후속 소비 연결은 [CONSUMER_FOLLOWUP.md](CONSUMER_FOLLOWUP.md)와 [consumer-followup-validation.json](consumer-followup-validation.json)에 기록한다. 기존 859/1281/239/233에 직업 상자368202·선택상자369002를 연결했다. 별도의 검증된 PR245 v3 입력을 설치하면 기존 스킬북8종도 연결된다. 신규 자동 완료는811개이며 기본6소비자 상태의 일부 보상 사용 대기369개와, 정확한 v3 입력을 함께 설치한 상태의366개를 구분한다. 출력 스킬 티켓의 소비·룬 착용 효과·4개 참고 스킬·고정 카드31종은 완료로 집계하지 않는다. 고정 카드는 공개243 API가 있으나 실제 원본 TestItem27종과 NoSwap/NoMerge 제약4종 때문에 보존한다.

스킬 v3 입력은 기존 공통 원본으로 로컬 재생성해 크기/SHA를 확인했으며 **LOCAL_ONLY**다. 기존 Drive 퀘스트v1/아이템팩을 그대로 사용하고 새 전송은 하지 않았다. 원본 정의/팩 전달/코드 공개/실제 소유·사용 검증은 별도 상태다. 아래 이전 체크포인트의 수량은 당시 검증 기록이며 현재 수량으로 바꾸어 읽지 않는다.

기준 main은 `f4cc0138613a6c98898c57d479b5247a849b96ab`다. 이미 승인되어 main에 들어온 던전·수호성·인벤토리 자동화·보스 전투와 퀘스트의 저장 보호 조건을 함께 유지하도록 작업 브랜치를 재배치했다. 인벤토리 사용/퀵슬롯의 두 보호 조건과 저장 허용 키를 합쳐 보존했다. 이 작업에서 main이나 다른 PR을 병합하지 않았다.

## 입력과 실제 전달 파일

원본은 비공개 [원본 보존 ZIP](https://drive.google.com/file/d/1EJGI2VV4u4P2yNlrMAlp0H2U28jjUH6K/view)이다. 25,031,173바이트, SHA-256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`. 현재 환경에서 재다운로드하고 ZIP CRC를 전수 검사했다. 이전 원본과 기존 적용팩을 삭제하거나 공유 권한을 바꾸지 않았다.

입력 21개 표를 읽었다. 주요 관계는 QuestGoal 4,245행, QuestPrerequisite 2,183행, QuestReward 6,276행, QuestRewardEnhancement 450행이다. 이 네 종류의 직접 참조 누락은 0개다. ItemClass 34,743행을 보상 원본 ID로 결합했고, Currency 272행과 CurrencyUnitClass 279행으로 아데나 및 기존 재화를 확인했다. 관련 원본 행과 파일별 해시는 [source-receipt.json](source-receipt.json)에 기록했다. 원본 데이터 본문은 Git에 넣지 않는다.

실제 설치 파일은 **[TWILIGHT-quests-current523-v1.zip](https://drive.google.com/file/d/1qt_ZIoU2xuSHfnhrl2Yas4_BD-8uHWcH/view)**이며, [비공개 퀘스트 적용 폴더](https://drive.google.com/drive/folders/1FWUvUuPInXzfn7hvQWm1sL7FJkYexvrY)에 보관했다.

- ZIP: 570,245바이트, SHA-256 `77866c180d4224eff6d7e578759ec0820d6e50515e5c6bd8a67dc92421c20063`.
- 실행 JSON: 9,884,157바이트, SHA-256 `2d11ecff4e695244220dc8e3a9b5707809f8bcfe34d7789a517880a6590bcb9a`.
- 최초 두 전송은 승인 검토에서 거절되어 미실행이었다. 사용자가 이 파일과 비공개 목적지를 명시 승인한 뒤 같은 파일만 전송했다. 다른 원본·보고서·캡처를 묶어 업로드하지 않았다.
- 정식 Drive 재다운로드 후 크기·SHA-256·ZIP CRC를 다시 확인했다. 재생성 도구도 같은 ZIP 바이트를 재현한다.
- 새 소비 폴더 `/workspace/quest-level-data`에서 받은 ZIP을 설치하고, 실제 Main이 `user://quests_current523.json`을 소비하는 것을 확인했다. 저장·오류 복구·새 Main 인스턴스 재시작도 검사했다. [delivery.json](delivery.json)에 전달 단계를 분리했다.

설치에는 이 Draft 브랜치의 새 로더 코드가 필요하다. 현재 main/기존 실행본에 자동 반영된 상태가 아니다. 게임 안에 Drive 자동 다운로드 기능은 없다. 사용자가 위 ZIP을 내려받아 **퀘스트 → 퀘스트 팩 설치**에서 고른 뒤 게임을 완전히 종료하고 다시 실행한다. 설치기는 크기·중앙 목록·고정 해시·전체 3,621개 ID를 확인하고 데이터 파일만 원자적으로 교체한다. 엔진/APK를 설치하지 않는다.

## 완료와 저장 동작

기존 수동 보상 버튼을 없앴다. 원본 레벨(Goal의 Level 포함)·직업·선행 퀘스트 등 확인된 획득 조건이 충족되면 목표 수량이나 NPC 복귀 없이 자동 완료한다. 부모와 새로 획득한 자식은 최대 32개씩 같은 저장 트랜잭션으로 처리한다. 목표 수행 생략은 사용자가 지정한 TWILIGHT 규칙이다.

아데나·EXP·레벨 상승 결과·재화·아이템·개체 ID·완료 상태를 함께 저장한다. 저장 전에는 원래의 라이브 상태로 돌아와 있고, 정상 저장을 확인한 뒤 새 상태를 채택한다. 쓰기 실패는 미지급 상태를 유지한다. 쓰기는 됐지만 오류가 반환된 경우에는 직렬화된 전체 트랜잭션을 디스크와 비교하고 기존 저장 보호기의 디스크 식별자도 갱신한다. 결과를 확인할 수 없으면 다음 불러오기 전까지 자동 지급을 막는다.

스키마1의 임시 퀘스트 완료·진행도와 새 원본 ID를 스키마2로 보존한다. 미설치 팩의 원본 완료 ID도 지우지 않는다. 손상된 완료 값이나 지원하지 않는 스키마는 저장을 덮어쓰지 않고 거부한다. 은퇴한 임시 일일 완료 이력은 날짜가 지나도 지우지 않는다. 날짜가 역행했을 때 기존 날짜 고수위도 낮추지 않는다. 임시 10개는 신규 보상 대상에서 은퇴하고 **기존 완료 이력** 필터에서만 별도로 보여 준다. 원본 정의의 로딩은 이 임시 항목의 몬스터/아이템 이름에 의존하지 않는다.

## 보상과 남은 연결

원본 기본 보상을 사용한다. QuestRewardEnhancement는 추가 재료를 쓰는 선택 강화다. 원본 기본 Reward 행을 지급하며 다이아몬드를 자동 소모하지 않는다. [NC의 추가 소모 방식 안내](https://lineagem.plaync.com/board/update/view?articleId=5c506548d7a85c00012c5d44)와 원본의 기본/강화 행을 대조했다.

이미 원본 ID로 연결된 재화·재료는 기존 실행 경로를 사용한다. 아직 사용 어댑터가 없는 아이템은 실제 인벤토리에 **[원본 보상]**으로 보관하고 원본 ItemClass ID·축복 코드·원본 사용 플래그·Reward ID·수량을 개체 기록에 고정한다. 대량 보상은 개별 장비 수만 개를 만들지 않고 수량이 있는 원본 보상 스택으로 저장한다. 원본 장착/사용 효과가 연결되기 전에는 장착·사용·판매·창고 이동을 막고 기존 장비와 섞지 않는다. 이 보관 상태는 전투 효과나 원본 아이콘 적용 완료가 아니다.

추가 연결 검증에서는 원본 ItemClass 전체 행, 원본 축복 코드, 중복 카탈로그 충돌과 실제 실행 중인 소비자를 함께 확인한다. 같은 ID나 도감 등록만으로 사용 가능하다고 표시하지 않는다. 기존 문양 재료 소비자와 PR238 공개 커밋의 변경 없는 소비 모듈을 재사용한다. 실제 연결한 두 원본 아이템(859/1281)의 수령·보관 개체 선택 사용·공동 저장은 [CONSUMER238.md](CONSUMER238.md)에 기록했다. 다른 PR 전체를 병합하거나 상점·보호·카드 기능을 복제하지 않았다. 도감 전용 원본은 계속 보관한다. 새 물리 보상에는 원본 SHA·완료 퀘스트·Reward ID·ItemClass ID·축복 코드·수량 영수증을 완료 상태와 함께 저장한다. 기존 완료/보상을 재지급하거나 보관 개체를 일괄 변환하지 않는다. 영수증 없는 과거822 저장본의537 대기는 그대로다. 소비 계약 대조는 [binding-dependencies.json](binding-dependencies.json)에 남긴다.

초보 퀵슬롯 등록 보상은 원본 파라미터를 저장하되 사용자가 이미 정한 50개 바인딩을 덮어쓰지 않는다. 원본의 100번대 등록값을 현재 슬롯 번호로 추정하지 않는다. 이를 재화 지급으로 해석하거나 해당 초보 퀘스트의 완료를 막는 일도 없다.

레벨 목표104행도 획득/지급 자격으로 보존한다. 이전 `5d122cfc`는 레벨 목표까지 일반 수행 목표와 함께 생략해 86레벨에서87~97레벨 업적11개를 조기 완료했다. 수정 후 새 실행에서는 해당11개가 레벨/선행 조건으로 남는다. 이전822개 완료·537개 보관 보상 상태의 세이브는 그대로 읽으며, 지급 취소·새 보상 지급·원본 항목 강제 변환을 하지 않는다. 아래526개는 이 레벨 제약 반영 후의 신규 실행 집계이며, 아이템 사용 어댑터를11개 완성했다는 의미가 아니다.

아이템 소비 팩 없이 초기 기사 상태(Lv.35)로 원본 전체를 검사하고 자동 획득을 더 이상 남지 않을 때까지 실행한 결과는 다음과 같다. 검증된 PR238 팩과 두 소비자의76a721f0 체크포인트는 완료811/사용 대기480이다. [후속239 귀환 연결](RETURN239.md)은 완료811을 유지하며 사용 대기를429로 줄였다. 각각의46개/51개 감소는 해소된 퀘스트 수이며 소비자 수가 아니다. [후속233 회복제 연결](HP233.md)은 같은811개 완료에서 사용 대기369로 줄였다. 다른 직업의 실제 전체 플레이를 완료했다고 주장하지 않는다.

| 구분 | 퀘스트 수 |
| --- | ---: |
| 원본 전체 정의 | 3,621 |
| 자동 완료·보상 저장 | 811 |
| 그중 일부 보상의 사용 연결이 남은 완료 퀘스트 | 526 |
| 제외 시스템 목표 | 160 |
| 그 밖의 잠김/기간/획득 조건/미연결 규칙 | 2,650 |

811개는 메인 635·업적 95·계정 업적 75·일반 6개다. 2,650개는 기간 종료 1,334·선행 퀘스트 미완료 379·연계 콘텐츠 획득 조건 679·반복/초기화 해석 보류 117·운영 시간 조건 128·직업 조건 10·레벨 미달 2·NPC 대화 선행 미연결 1개다. 선행 미완료에는 다른 직업 분기나 미획득 부모도 포함된다. 이 분류를 전부 구현 오류나 전부 완료로 바꾸지 않는다. [실행 집계](runtime-coverage.json)를 함께 보존했다.

실제 게임에 등록된 재화·재료 어댑터를 포함한 현재 기사 기준으로 보상 계획을 구성할 수 있는 정의는 2,677개이며, 그 안의 1,940개는 일부 원본 아이템의 사용 연결이 남는다. 나머지 944개는 Buff 3·Einasad 38·시즌 패스 EXP 894·Teleport 3·혈맹 전용 보상 6개다. 단독 투영 검사에서 빈 어댑터로 측정한 2,675개/2,016개와 구분한다. 이 보상 계획 집계는 위의 현재 획득 상태·제외 집계와 다른 축이다. 관련 서비스나 의미가 없는 값을 만들어 지급하지 않았다.

혈맹·공성·펫·투기장·지구라트 및 리니지M 엔진/APK는 재도입하지 않았다. 제외된 원본 행도 삭제하지 않고 이유를 표시한다. 일반 퀘스트는 제외 대상이 아니다. 원본 QuestType 3/Common의 한국어 설명 `[일반]`을 확인해 일반 탭으로 표시한다. 승인된 v1 ZIP의 바이트는 유지하며 런타임은 그 안의 원본 TypeID를 우선한다.

## 기간 해석

비어 있는 DateTimes.json 대신 **DateTimes_Korean.json 35,181행**을 읽었다. 원본 SHA-256은 `5867945da984e08459eb43649e3b4dff75424abab11e459f00a1832440d560a5`다. 원본 StartTime/EndTime ID를 보존하고 이 표의 날짜를 연결했다.

이 표에는 시간대 필드가 없다. ZIP의 파생 Unix 시각은 TWILIGHT의 기존 한국 시간 정책(UTC+9)을 적용한 것이며 원본에 시간대가 명시되었다는 뜻이 아니다. QuestResetType의 숫자 의미와 주간 운영 조건은 다른 초기화 표의 숫자로 대체하지 않는다. 확정되지 않은 반복/운영 규칙은 이유를 표시하고 보류한다. ServerLimitSetID는 원본 메타데이터로 보존하며 네트워크 서버 판정 서비스를 복원하지 않는다.

## 검증 범위

공식 Godot 4.7.2로 전수 원본 검사, 실제 Main 자동 실행, 저장 실패/쓰기 후 오류 확인, 손상 저장 보호, 동일 보상 재요청, 재시작, 기존 장비/소모품/퀵슬롯 보존을 검사했다. 원본 ZIP→설치 ZIP→Drive 재다운로드→새 소비 폴더의 실제 Main까지 같은 바이트를 사용했다. 화면은 실제 OpenGL에서 1280×720과 854×480을 확인하고, 검색·필터·30개 단위 페이지·기존 이력 분리·보상 스택 수량을 검사했다. 작은 화면에서 카드가 사라지던 높이는 퀘스트 창에 한정해 보정했다.

전수 정의 10,346개 검사, 새 소비 폴더 실제 Main 3,010개 검사, 원본 보상 연결18개 검사, 기존822개 저장본의 실제 OpenGL UI 752개 검사, 기존 Core 44개 검사가 통과했다. 관련 실행 결과와 코드/소비 파일 해시는 `validation.json`에 기록했다. 필수 시트 723개·41,442프레임의 기존 리소스 무결성 검사도 유지한다. 전체 수동 CI, Android 실기기, 모든 직업의 플레이나 모든 원본 보상의 사용 기능을 완료한 증거로 확대하지 않는다. 새 커밋은 `[skip ci]`이며 PR은 Draft로 유지한다.

PR238 소비 연결의 최신 실행 결과는 [consumer-validation.json](consumer-validation.json)에 별도로 기록한다. 전수 정의·Core·영수증 없는 과거 저장본의 OpenGL UI를 재검사하고, 실제 원본 지급→소지→사용/출력→실패 보존→재접속 및 선택한 기존 보관 개체의 부분 사용을 검증했다. [pending-consumer-matrix.json](pending-consumer-matrix.json)은 기존526개 대기 퀘스트에 포함된146종 아이템의 소비 분류와 남은 계약을 기록한다. 이146종을 퀘스트 수나 지급 개수로 쓰지 않는다.

The pending-use preview re-evaluates original CharacterClassID reward rows for the current class. A read-only comparison on the same owned save confirmed Knight351/Mage354 without changing bytes: two Knight-only versus five Mage-only pending quest rows, including Mage RewardID5462/Item177292 that was not issued under the old class. This does not issue or convert ownership and is not a count of raw physical stacks.
