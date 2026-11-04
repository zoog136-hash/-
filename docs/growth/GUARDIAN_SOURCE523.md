# 수호성 누적523 기능과 UI

기준 main `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`, draft PR #246. 기존 PR에서 기능을 이어가며 다른 PR/main을 병합하지 않는다. 사용자의 “서버조건 말곤 구현해” 지시에 따라 ServerLimitSet1294의60슬롯은 계속 보류한다.

## 구현

- 6분류172슬롯·166개 비영 선행행·274개 보상·27개 강화행. UIPosX/Y와 직접 선행을 사용하며 선행 Lv3 조건을 만들지 않는다. 기존41노드 원본과 개발 프로필은 보존한다.
- 능력치142행(무게2행 포함), 조건부64행, 발동62행, 사용6행에 실행 어댑터를 연결했다. 서버 조건이 없는4분류112슬롯은 능력치92행/조건부37행/발동44행/사용6행이다. 나머지2분류의 효과는 소유 데이터가 있어도 실행하지 않는다.
- 능력치는 대표 선택 없이 상시 적용한다. CarryPlus의 Weight44 분모100을 적용한다(20000→200,25000→250). PvP 수치는 PvP 이벤트만, 급소 수치는 실제 급소 이벤트만, 상태이상/주문 태그 수치는 정확한 대상 ID만 적용한다. 관통은 실제 방어 감소 예산까지만 복원한다. 현재 PvE에 존재하지 않는 PvP 전투나 급소 확률을 임의로 생성하지 않는다.
- 공격 Type1, 치명타 Type27, 피격 회복 Type2, 감소 Type5를 구분한다. 물리/마법·주 대상·최소 피해·확률·재사용시간·분류별 대표 조건을 지킨다. Type5 Param1은 감소량이고 Param2를 주문으로 실행하지 않는다. TargetEffectSpriteID는 기존 원본 compositor에 전달한다.
- 55개 주문과18개 버프의 원문 closure를 포함한다. 피해 기본값/주사위·셀 사거리/범위·시야·회복·일시적인 AC/ER/MR/리덕션·6속성 및 비율 감소를 연결한다. 몬스터 재사용 life_id가 바뀌면 버프가 상속되지 않는다. NPC 속성 파생은 현 게임의 스탯 계산을 사용하는 **로컬 어댑터**다. 원본 서버 전투 공식 복원으로 주장하지 않는다.
- 질리언 사용 스킬3개는 기본/강화 보상을 대체하여 HP/MP를 회복한다. 원본 명예 코인10개, CastDelay900000은 현재 게임의 밀리초 정책으로900초, CastGroup311 공용이다. `스킬 → 특수 · 수호성`, 수호성 상세, 퀵슬롯에서 사용할 수 있다. 업그레이드·재접속·초기화로 공용 대기시간을 지우지 않는다. 현재 재료 상점 가격100아데나/명예 코인으로10개 구입도 연결했다.
- 분류별 대표 변경은 SkillTreeConstant.CoolTimeSec=3초다. [NC 공식 2022-07-20 공지](https://lineagem.plaync.com/board/update/view?articleId=50196375)의10→3초 변경과 교차 확인했다. 분류별 절대 종료 시각을 저장한다.
- 해금은 카드 선택 확정 때 원본 Currency822 수호석을 한 번 차감한다. 강화는 원문 비용/확률, 실패 시 단계 유지·재료 소모를 유지한다. 카드 승자/실패 이력의 기존 로컬 덱 모델도 보존한다. 서버의 덱 재배치 정책이라고 주장하지 않는다.

## 경제 설정과 초기화

원본523 → 확인된 공식 공개 자료 → 기존 TWILIGHT 설정 → 명시적인 자체 설정 순으로 적용한다. 기존 사용자 지정 드랍/각성 수치는 변경하지 않는다.

원본 InitializeCost1200 / Currency4(Gem)를 사용한다. 선택한 분류만 초기화하고 실제 기록된 성공·실패 시도/강화 지출을 수호석으로 환급한다. 구버전에 기록되지 않은 실패 강화 비용은 추정하지 않는다. 이전 카드 시도와 성공 강화 비용으로 입증되는 최소액만 환급하며 화면에 해당 제한을 표시한다. 다른 분류·옛41노드·공용 사용 스킬 대기시간은 보존한다.

현행 공식 자료에서 현대 분류별 초기화·수호석 환급 범위까지 확정하지 못해 `data/growth/guardian_local_rules.json`에 자체 정책을 분리했다. `reset.refund_rate`(기본1.0)는 설정 가능하다. 분류 단위 초기화, 실제 지출 기록 기준, 실패 지출 포함, 공용 대기시간 보존은 명시된 고정 불변조건이다. 이미 알려진 원본 비용을0으로 대체하지 않는다.

초기화는 기존 게임 `inventory["다이아"]`를 우선 소비한다. 기존 `currency_drops.gd` / `loot_drop.gd`에 아덴월드 제외 유효 맵의 재료 드랍 확률과1–10개 스택 규칙이 이미 있고, 바닥 드랍→습득→인벤토리→HUD→저장이 연결돼 있다. 이 수급 API와 확률·수량·아덴 제외 규칙을 변경하지 않는다. 개발 검증1200개는 `guardian_wallet["4"]`에 별도로 남기고 일반 다이아와 구분해 표시한다. 일반 잔액이 부족한 경우에만 개발 빌드에서 검증 잔액을 사용하며 release 빌드는 이를 사용할 수 없다. 기존 코드를 재대조하여 발견한 연결로, 새 결제/현금 교환/무료 출시 지급을 추가하지 않는다.

## UI·연출

실제 메뉴 수호성 진입·원본 좌표 보드·가로/세로 터치 이동·선행/비용 상세·카드 확인/실패/성공·강화·대표 변경·사용 스킬·초기화 확인/결과를 연결한다. 스킬 특수 탭은 세로 터치 스크롤과 개별 퀵슬롯 등록을 지원하며 실시간 대기시간/재료 상태를 갱신한다.

UI551 CSB에서 카드 Fx_Start40–75, 성공5–20, 실패25–40의 정확한 Scale/Alpha 트랙을 추출해 현재 TWILIGHT 카드에 재생한다. Cocos ActionTimeline의1/60초 프레임과 speed1을 사용한다([엔진 원문](https://github.com/cocos2d/cocos2d-x/blob/v3/cocos/editor-support/cocostudio/ActionTimeline/CCActionTimeline.cpp)). 연출은 거래나 결과 선택을 실행하지 않는다. 강화 결과 라벨에도 동일한 성공/실패 부모 트랙을 적용한다.

현재 제공된 UI1/UI47/UI128 DAT에는 전체 Atlas_SkillTree와 음성 OGG 바이트가 없다. 카드 픽셀은 기존 게임 아트이고 전체 원본 시각/음성 재현은 미완료다. 다만 UI128의 실제 광원 아틀라스40프레임을 새로 연결했다. 수호성의 `원본 UI551 자료 설치`에서 이미 보유한 `TWILIGHT_UI551_binding_animation_evidence_20261104.zip` 또는 내부 `UI128.dat`를 직접 선택한다. 전체 입력·내부 DAT·PNG/PLIST SHA를 확인한 뒤 필요한2파일만 사용자 영역에 설치하고, 설치 설정은 게임 세이브와 분리한다. 잘못된 입력은 기존 설치를 바꾸지 않는다. 신규 원본 파일을 공개 Git에 올리지 않는다.

원본 `SkillTree_Icon_SkillEnchant.csb`의 Fx_Active305–383, action_tag1572849955, FileData01–39·60fps·원본 색/위치/크기·additive blend를 실제 PNG로 재생한다. 현재 게임에서는 강화 성공 노드에 한 번 재생하는 표시 어댑터이며 전체 원본 장면/활성 판정 복원이라는 주장이 아니다. 40개 atlas frame의 RGBA SHA를 Python 원본 추출과 Godot 결과로 전수 대조한다. 별도 원본 아트 검사에 필요한 `/workspace/guardian-sources/a1.zip`도 없다. 저장소 규칙에 따라 해당 원본 아트 단계는 중단하고 데이터·기능·기존 아트 UI 작업을 완료한다. 원본 시각효과는 설치된 private compositor가 바인딩을 제공할 때만 재생하고 없는 바인딩은 `original_binding_unavailable`로 기록한다.

## 보존과 제한

기존 schema1 및 옛 ID는 보존한다. 새 optional fields: guardian_levels, guardian_representatives, guardian_spent, guardian_enchant_attempts, guardian_wallet, guardian_switch_until, guardian_cast_until, guardian_legacy_refund_uncertain. 모든 재화 거래는 저장 성공 후 월드에 반영하며 실패 시 재료·HP/MP·아데나·지갑·진행·대기시간을 변경하지 않는다. 문양/다른 시스템의 동작을 재설정하지 않는다.

Category262 크리스터의 최신523 ServerLimitSetID는0이며508의1294를 복사하지 않는다. Category273/288은1294의406행을 보존하되 판정하지 않는다. LandGroup241의 NoSpell은 스킬 실행 시 현재 맵의 명시적 source_land_group_ids와 대조한다. 해당 지도 메타데이터가 없는데 지리적 범위를 추측하지 않는다.

공포 SpecialResistanceType8과 스턴6을 구분한다. 독의 원본 레벨 계수만으로 완전한 서버 명중 공식을 만들지 않으며 기존 상태이상 정책을 사용한다. 독 틱 간격1초는 설정 가능한 현 게임 로컬 정책으로 기록한다. 태그/PvP 등 이벤트 메타데이터가 없는 기존 공격을 임의로 해당 공격으로 바꾸지 않는다.

구형 소스1/2·폐기 서버 프로토타입·퀘스트·펫·혈맹·공성을 재도입하지 않는다.

## 현재 환경에서 실제 읽은 입력

지정 Library 파일을 이 소비 환경에서 정식 prepare_materialize 및 최신 Library transfer helper로 설치하고 `user.library-file-id` xattr를 검증했다. ZIP CRC 전수검사와 SHA256:

| Library ID | 파일 | SHA256 |
| --- | --- | --- |
| libfile_3acd63a50c148191b10d669d77efd5e3 | TWILIGHT_523_symbol_guardian_crosslinks_20261104.zip | 60fa306d6310cddd4b5eb042bbf59720e6dc732d92b3438cf54044815f76811f |
| libfile_0ba507ea27888191b60532f6aa6b6ff0 | TWILIGHT_UI551_binding_animation_evidence_20261104.zip | 6e5c636cabe48ab8d4aa4a5d6d26122c3300ca65789568668335b71fdb386d91 |
| libfile_f3e9e5b322cc8191ae441565bbd24c27 | lineagem_patch523_all_content_validated_and_508_520_deltas.zip | d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832 |

실제로 읽은 자료: REPORT_KO, guardian_invoke_conditions, guardian_active_skill_costs, relevant_ui_source, source_row_evidence, UI551 focus_growth_bindings/implementation_findings 및 생성기가 참조하는523테이블 전체 행. UI551은 레이아웃·노드·강화 상태와 카드 property timeline의 근거로 사용했다. CSB 예시 텍스트를 비용값으로 쓰지 않는다. 원본 음성·전체 아틀라스를 이식했다는 주장은 하지 않는다.

`data/growth/guardian_source523.json`은 선택한 원문 행·1부터 시작하는 행 번호·원본 테이블 SHA256/바이트 수를 보존한다. 원본 ZIP은 수정하지 않고 Library에 보존하며 공개 Git에 제3자 원본 아트를 추가하지 않는다.

재생성/원문 대조:

```sh
python3 tools/build_guardian_source523.py --source-dir /workspace/guardian-sources/lineagem_patch523_all_content_validated_and_508_520_deltas/content --output data/growth/guardian_source523.json --check
```

## 검증 증거

1차 커밋 `ddf83b4b68017b03321539ad5504e9914bc816bf`의 로그/캡처는 [1차 manifest](guardian-source523-evidence/manifest.json)에 그대로 보존한다. 해당 manifest의140매핑/134보류 및 코드 해시는 **1차 구현 당시 기록**이며 현재 최종 범위와 구별한다.

후속 최종 코드 검증 및 스크린샷은 [후속 manifest](guardian-followup-evidence/manifest.json)에 기록한다. Godot4.7.2의 실제 Main/current source map과 격리된 테스트 저장소를 사용한다. Linux Compatibility/llvmpipe의 검증은 Android 실기기 검증이나 원본 아트 전체 완료를 의미하지 않는다.

사용자 지시대로 `[skip ci]` 커밋을 사용하며 원격 CI 수동 실행/재실행을 요청하지 않는다. 워크플로·브랜치 보호·원격 실행 중 작업은 변경하지 않는다. 원격 CI 미실행은 통과로 기록하지 않는다.

최종 로컬 검증: 거래39, 전투/재화55, 성장/터치111, 개발 프로필37, 연출11, 원본 보드 UI35, 특수 탭/퀵슬롯/초기화 UI33, 실제Main32 및 추가 저장 게이트2개 모두 통과했다. 723시트/41,442프레임SHA도 통과했다. 병행한 첫 핵심 검사에서180초 종료 제한을 넘긴 시도는 실패 기록으로 남겼으며, 동일180초/동일 assertion의 최종 검사3개는 종료코드0이다.

후속 특수 탭 첫 실행은 검증 stage에 동적으로 읽는 스킬 SVG가 빠져 리소스 오류가 있었다. 기존 Git125개 SVG의 실제 바이트를 검증 stage에 복사하고 SHA 영수증을 보존했다. 최종 화면33항목은 리소스/스크립트 오류 없이 통과했다. 화면의 폭과 탭 선택 표시도 직접 확인했다.

화면: [특수 탭](guardian-followup-evidence/guardian-special-ready.png), [공용 대기시간](guardian-followup-evidence/guardian-special-shared-cooldown.png), [퀵슬롯 시전](guardian-followup-evidence/guardian-quickslot-cast.png), [초기화 확인](guardian-followup-evidence/guardian-reset-confirmation.png), [초기화 결과](guardian-followup-evidence/guardian-reset-result.png), [854×480](guardian-followup-evidence/guardian-special-854x480.png).

## 원본 광원·기존 다이아 소비 후속

새 보유 입력: Drive `full_resource_inventory.zip`(SHA d50445dbb5bab01f7118a52220d236e05a1c065b5cc14e314734facb62c6d4b8)와 `TWILIGHT-source-card-ui-collections-review.zip`(SHA04343b1d7b90bb81928ec398357f1481723d82cece71ed58c534cfcb47ceae73)을 정상 Drive fetch로 받아 실제 바이트/CRC와 내부 자료를 읽었다. 전자는 목록·SPR이며 후자는 코드/UI 검증 자료이고 수호성 카드 아틀라스/원본 음성을 포함하지 않는다. 원본 픽셀 연결은 이미 정식 materialize한 Library UI551 입력의 UI128을 사용한다.

최신 audio557 분석 ZIP(libfile_e994888010c881918373efebb0a6201a)과 구현 가이드(libfile_5a339b0b26c481919a1afc006cf89cde)의 신규 Library 다운로드는 tools/list HTTP401로 거부됐다. 재시도/우회하지 않았다. 원본 광원 편의 ZIP의 신규 Drive 업로드는 처음 자동 승인 검토에서 거부됐다. 이후 사용자의 명시적 승인에 따라 같은 비공유 프로젝트 폴더에1회 정상 업로드했고, Drive에서 다시 내려받아287,134바이트/SHA256/ZIP CRC/설치·픽셀91항목을 확인했다. [전달 영수증](guardian-media-evidence/approved-drive-delivery.json)에 정확한 Drive 링크와 해시를 기록한다. 원본 입력 Library ID/해시는 보존하며, 앱의 **기존 UI551 원본 ZIP 직접 설치**도 계속 지원한다.

남은 정확한 입력은 `UI_Resource/Atlas_SkillTree.plist` 및 PNG(카드 Enchant/Success/Fail/Select/Glow 프레임), 그리고 Sound/UI/90285.ogg·90299.ogg·90301.ogg·90303.ogg·90304.ogg·90305.ogg다. SoundMaterial/Asset 조인은 [media manifest](guardian-media-evidence/manifest.json)에 기록한다. 위 파일명/이벤트의 공개 검색에서도 원본 바이트를 확인하지 못했다. 해당 음성이나 카드를 새로 만들어 원본으로 표시하지 않는다. 서버 조건60슬롯은 계속 보류한다.

후속 최종 검증은 [원본 광원/다이아 manifest](guardian-media-evidence/manifest.json)에 보존한다. 기존 원본 ZIP·원본 DAT·로컬 subset의3입력 경로에서 각각91개 설치/픽셀 검증, 전투/경제60, 기존 거래39, 기존 재화 드랍, 실제 Main 저장32와 추가 게이트2개, 원본 설치/실제 강화/바닥 습득/일반 다이아 초기화/재접속 UI29가 통과했다. 원본 설치 전후 게임 세이브 SHA가 동일함도 확인했다. 723시트/41,442프레임SHA 통과. 파일 선택 fixture의 첫 실패와 수정 후 성공을 구분해 보존하며, 원본 광원 실기동 캡처는 공개하지 않고 해시/로컬 경로만 기록한다.

[일반 다이아 초기화 확인](guardian-media-evidence/guardian-earned-diamonds-reset-confirm.png), [초기화 결과](guardian-media-evidence/guardian-earned-diamonds-reset-result.png).


## 자체 표현 마무리

추가로 승인된 정상 Drive 사본의 전역 오디오 조사와 기존 구현 가이드를 이 소비 환경에서 수신했고, 전체 바이트·SHA256·ZIP CRC와 실제 내용을 읽었다. 앞선 Library401 경로는 재시도하지 않았다. 오디오 보고서는 지도 BGM/환경음 조사이며 대상 수호성 UI OGG 실물은 포함하지 않는다. 구현 가이드는508 기준이므로 최신523 조건/비용을 덮어쓰지 않는다. 제공 원본·분석 자료와 공개 정확 파일명 검색에서 카드 전체 아틀라스/대상6OGG의 사용 가능한 바이트를 확보하지 못했다. 검색 결과 없음은 인터넷 전체의 부재를 증명하지 않는다.

사용자 지시로 미수신 미디어의 표현을 TWILIGHT 자체 카드/효과음으로 마무리했다. 기존 카드 픽셀과 이미 Git에 있는 TWILIGHT WAV3개를 재사용하며 신규 원본 이미지/음성을 만들거나 확보했다고 표시하지 않는다. 화면 상단과 카드 선택 화면에 자체 표현임을 표시한다. 카드/효과음 켜기·끄기, 음량0/25/50/75/100%를 수호성 화면에서 저장한다. 카드를 끄면 번호/성공/실패와 선택 기능을 유지한다. 원본으로 확인된 광원 설치/재생, 노드 정체·설명·원본 수치와 서버 조건60슬롯 잠금은 유지한다.

설정과 자체 믹싱 선택은 `data/growth/guardian_authored_presentation.json`, 소비자는 `guardian_authored_presentation.gd`다. 기본 카드/음원 켜짐·음량75% 및 각 이벤트 gain/pitch는 TWILIGHT 자체 선택이며 원본 타이밍/오디오 복원 수치가 아니다. 카드 개방, 선택 성공/실패, 강화 성공/실패, 대표 변경, 초기화의 **실제 저장 성공 후**에만 재생한다. 취소·재진입·실패한 저장은 결과음을 발생시키지 않는다. 고정2보이스를 재사용하며 기존 전체 presentation mute도 존중한다.

설정은 `user://guardian_authored_presentation_v1.cfg`에 별도 저장한다. 후보 파일을 쓰고 다시 읽어 대조한 뒤 rename에 성공해야 메모리/UI 설정을 변경한다. 설정 실패 시 직전 설정/게임 세이브를 보존하며, 끄기/음량 변경은 현재 소리도 중단한다. 게임 재화나 진행 저장 형식을 변경하지 않는다.

추가 원본 파일/팩을 업로드하지 않았다. 기존 원본 백업/실제 적용 광원팩은 이전 인계 상태이며 Drive 보관이 게임 자동 적용을 의미하지 않는다. 이번 자체 표현은 Git 코드·설정과 기존 추적 음원을 소비하므로 새 외부 팩이 필요 없다. 로컬 실제 Main 적용과 원격 feature 게시는 구별하고, main 병합/사용자 실행본 재배포는 하지 않는다.

최종 후속 검증: 자체 설정/비영PCM32항목, 실제 Main/native touch UI55항목, 기존 원본 설치·광원 강화·일반 다이아 초기화/재접속 UI29항목, 거래39·전투/경제60, Main32와 추가 저장2게이트 및723시트/41,442프레임SHA를 오류 없이 통과했다. 최종 파일/로그 SHA와 첫 실패를 [자체 표현 manifest](guardian-authored-evidence/manifest.json)에 기록한다. 1280×720·854×480 화면 캡처는 해당 manifest의 LOCAL_ONLY 경로에 보존하고 새 외부 업로드를 하지 않았다. 오디오 검증은 Dummy 드라이버의 실제 믹서 출력을 확인한 것이며 물리 스피커/Android 실기기 검증은 아니다.
