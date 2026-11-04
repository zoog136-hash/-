# 누적523 몬스터 도감: 실행·규칙·전달 상태

기준 main은 `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`, 기존 draft PR은 #244다. 다른 PR/main은 병합하지 않았다. 스폰·맵·몬스터 드롭 확률·각성 비용은 변경하지 않는다. 메뉴 → 사냥·모험 → **몬스터 도감**, 인벤토리의 도감 보상 활성화 → **보유 보상 사용**으로 접근한다. 단순 몬스터 목록과 별도 기능이다.

## 실제 게임 연결

- 전체557개 중 현재 대상 연결33개/97단계/정확한 NPC944개를 사용한다. 대상 연결0인 과거524개를 활성 대상으로 취급하지 않는다. 과거508의904 NPC와 구분한다. 이름·Sprite·맵으로 ID를 추측하지 않는다.
- Main의 기존 인정 사망·중복 방지·소환 제외·EXP/바닥 드롭 처리 뒤에서 `source_m_npc_id`와 life를 전달한다. 원본 서버 막타 판정을 재현했다는 의미가 아니다. 원본 ID가 없는 개체는 집계하지 않는다. 저장 실패한 사망 영수증은 메모리에 대기하며 저장 성공 전 진행을 공개하지 않는다.
- 기본 호환 정책은 단계별 자연 처치와 자동 단계 달성이다. 단계별 수와 기간 총수를 보존하고, 다음 단계로 남은 실제 처치를 넘긴다. 유료 완료로 처치 수를 만들지 않는다. 첫 단계만 처리하던 경계를 제거했다. 처치마다 대용량 이력을 저장하지 않는다.
- Book6013은 원본96 NPC/Level16423/1000회/옵션0개다. 기존 게임의 한국05시 일일 달력 함수를 사용한다. 이전 epoch의 등록·처치·수령은 유지하며 시계 역행으로 보상을 재수령하지 못한다.
- 현재25종 보상은 정확한 원본 아이템 ID로 인벤토리에 지급한다. 수령 행별로 중복 지급을 막고 EXP/레벨·인벤토리·영수증을 함께 저장한다. 원본 Exp/Class281은 Item281이 아니다. 원본 CurrencyCost는 **즉시 완료 비용**이며 일반 자연 달성에 부과하지 않는다. 현재96개 유료 단계는 원본 Gem 비용을 그대로 사용한다.
- 39개 현재 효과 계열을 기존 전투·스탯 소비자에 연결했다. 26개 기존 연결에 근접/원거리/마법 리덕션 고정·비율, 리덕션 무시 비율, SpecialResistance/HitSpecialResistance를 추가했다. UIUnit 분모10000/Weight100 등 원본 단위를 사용한다. SpecialResistanceType6=Stun,8=Fear를 원본 테이블에서 확인했으며 상태창과 실제 스턴/공포 소비자에 전달한다.
- 기본 옵션은 등록 단계 누적 적용이다. UI에서 한 단계 선택 또는 자동 적용 복원을 할 수 있다. 종료·정책 변경·팩 변경 시 전투/스탯 캐시를 갱신한다.

원본 한국 시각: 시작2026-10-07 05시, 집계 종료10-28 05시, 옵션 종료11-04 05시. 현재 시각에는 종료 상태가 맞다. 과거 날짜 검사는 격리 fixture이며 제품 시즌을 재개하지 않는다. 종료해도 소유·등록·수령 기록은 보존한다.

## 보상 사용과 만료

무기한7종은 기존 코인·재료·주문서 보유 경로에 연결한다. 날짜가 있는18종도 지급·보유·사용·만료까지 연결했다. 도감 종료와 아이템 삭제 시각은 별개다.

- 선택 상자5종은 `ItemBonus → Reward(Type111) → SelectReward → SelectRewardEntity`의 원본 구성품15개 중 하나를 선택한다. Bonus.Value를 SelectReward.ID로 오해하지 않는다.
- 카드팩9종은 `MarketPurchase → MarketProduct(Unit GotChaClassID) → GotChaEntityView(Unit BuffCardID)`를 따른다. 원본5장/10장 수량과 그룹별 확률 합계1,000,000을 사용한다. 다른 시즌11장 수량이나 임의 카드 확률로 덮어쓰지 않는다.
- 축복 포인트1종은 원본 IntangibleItemClass14=BlessPoint/1000을 기존 `growth.state.points`에 지급한다. 아인하사드 축복으로 바꾸지 않는다.
- 미스터리 카드3종의 희귀~영웅 범위는 원본과 공식 안내를 사용한다. 수치 확률이 없는 부분만 아래 자체 정책을 사용한다.
- 현재 팩373개 카드 중 현재 main에 없는 성물25162는 기존 `preserved_unmapped_collection` API에 `source:m523:98:25162`로 영구 소유/중복을 보존한다. 추첨 확률에서 제외하거나 다시 뽑지 않는다. UI는 정의 연결 대기를 표시한다. PR249의 정의가 나중에 실제 카탈로그에 존재하면 자동 조정 API가 소유를 한 번 이동한다. **현재 main에서는 이 카드의 장착·외형·스탯 사용은 미연결**이며 다른 PR을 병합하거나 카드를 임의 정의하지 않았다.
- 원본 DeleteTime/Application298(DateTime)/Target277002에 따라18종은 **2026-12-30 한국05시**에 삭제된다. 인벤토리·바닥 소유를 같은 저장에서 제거하고 삭제 수량·원본 증거를 별도 보존한다. 실패한 저장은 양쪽을 유지한다. 시계 역행으로 삭제 재화를 복구하지 않는다. 원본 보관/드롭 제한·최대 스택을 유지한다. 미정의 NPC 매입 가격으로 재화를 만들지 않는다.

아이템 사용은 입력1개 소비, 결과 카드·중복·포인트·아이템, RNG 상태, 단조 순번과 마지막 결과를 함께 저장한다. 마지막 결과는 최대100개, 아이템별 사용 횟수만 누적하므로 무제한 사용 이력을 만들지 않는다. 저장 실패 시 RNG와 자원을 복원한다. 공유 거래 잠금으로 같은 저장 중 재진입을 거부한다. 별도 제작·상점 PR의 기능을 구현했다고 주장하지 않는다.

## 원본 우선과 자체 호환 설정

최신523 원본, 기존 보고서·게임 규칙을 먼저 확인한 후 공식 [시즌22 안내](https://lineagem.plaync.com/board/event/view?articleId=50560450), [10월7일 패치](https://lineagem.plaync.com/board/update/view?articleId=6ac54c38a279104f7d9d5ff1), [미스터리 카드 안내](https://lineagem.plaync.com/board/notice/view?articleId=6a7b7838eea53f5d6dbcf225)를 조사했다. 공식 페이지는 동적 본문 대신 검색 색인에서 확인한 범위만 사용한다. 단계 카운터/옵션 합산의 서버 구현과 미스터리 수치 확률은 확인하지 못했다. 사용자 지시대로 `data/monsterbook523_balance.json`에 원본과 구분한 설정을 둔다. UI에도 자체 정책/확률을 표시한다.

| 설정 | 기본값과 의미 | 대안/제약 |
|---|---|---|
| natural_counter_mode | per_stage: 단계별 처치 | cumulative: 총수 기준, manual: 첫 단계만 자동; epoch에 적용 정책 보존 |
| bonus_mode | cumulative: 등록 단계 합산 | latest: 마지막 단계, manual: 명시적 선택 |
| typed_damage_policy | existing_flat_then_percent | 기존 순서로 유형별 고정 후 비율, 비율 상한90%·최소1; disabled 가능 |
| ignore_percent_policy | existing_single_player_amplification | 기존 PvP→PvE 단독플레이 공격 배율 소비자, 기존 총300% 상한 유지; disabled 가능 |
| mystery_hero_weight_per_10000 | 1200: 영웅12%, 희귀88% | 기존 희귀 카드 합성 균형을 참고한 자체값; 기존 합성/추첨 확률 변경 없음 |
| mystery_pool_policy | current_unrestricted_pack_cards | 현재 원본373개 중 제한·날짜 없는 기존 카드만, 선택 등급 내 동일 확률; existing_game_pool 대안 |
| adena_per_internal_gem | 10000 | 실제 결제 없는 별도 게임 지갑; 종료 후 교환 거부 |
| exp_numerator/exp_denominator | 3864874/31920000 | 기존 성수 균형 참고, 반올림·최소1; 원본5백만→605400 EXP |

조건·단위·수량·기간·카드팩 확률·비용은 확인된 원본이 자체값보다 우선이다. 실제 서버 공식이라고 주장하지 않는다. 원본 Amount/비용과 변환 출처를 영수증에 남긴다. 시즌 재개·접근 거절·게시 승인까지 자체 구현 허용으로 해석하지 않는다.

## 실제 적용팩과 원본 백업

| 용도 | 버전·바이트·SHA256 | 실제 보관처와 검증 |
|---|---|---|
| **최신 적용 규칙팩** | monsterbook523.private-v3.json, 2,100,161 bytes; `18afd363904e9e07d492ea2b90327248d445726a10417236746feca2bc1d98ed` | Drive 파일 `101RFg0OrWY3ZPKLYY-XNww2LNQ5LNdVV`, [실제 적용 폴더](https://drive.google.com/drive/folders/1VD2R4JJF4Fb2Gz5KxHQmQxs0-MyBrHAC). 비공유/기존 프로젝트 하위 확인, 새 소비 폴더에 정식 다운로드·SHA/JSON 검증·실제 Godot 로드 |
| **원본 보존 백업** | lineagem_patch523_all_content_validated_and_508_520_deltas.zip, 25,031,173 bytes; `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832` | 기존 Drive 파일 `1EJGI2VV4u4P2yNlrMAlp0H2U28jjUH6K`, [원본 보존 폴더](https://drive.google.com/drive/folders/1BlB4_BIrvXJBMwngLbq0ZdFkeETYcC2V). 기존 파일 재사용, 다운로드 SHA·전체ZIP CRC 확인 |
| 구 적용팩 보존 | v2, 1,790,494 bytes; `a49b49e8f30ab82bbcee776a070d26bc4310a0bfa06e68d6d1126eb61ca2a129` | Library `libfile_f12c2bcdd0f88191a2f846955ed5e481` version1. **최신 v3가 아님** |

심층 제약 원본 ZIP170,140bytes SHA256 `704daa65656b7e61a2723cb5eec68edfa195ff1e17c524ebb954ae0975436961`도 소비 환경에서 Library 정식 수신·SHA/전체ZIP CRC를 확인했다. 원본은 수정하지 않았다. Drive 공유 범위를 넓히지 않았고 조사 보고서·감사 자료·캡처를 새로 업로드하지 않았다.

v3는557도감/1531단계/1282옵션 연결/2570보상 연결과 현재 사용 아이템의 선택·상품·카드·무형 재화·만료 참조를 포함한다. 원본 행은 공개 Git에 포함하지 않는다. 규칙팩이며 원본 이미지/엔진 배포가 아니다. 자동 설치기는 없으며 Drive 백업만으로 게임에 자동 적용되지 않는다.

```sh
python3 tools/monsterbook523/build_pack.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --output /private/monsterbook523.private-v3.json

godot --path . -- \
  --monsterbook523-pack=/private/monsterbook523.private-v3.json \
  --monsterbook523-sha256=18afd363904e9e07d492ea2b90327248d445726a10417236746feca2bc1d98ed
```

실제 검증 소비 파일은 `/workspace/monsterbook-check/drive-applied-v3/monsterbook523.private-v3.json`이다. 로더는 digest·snapshot·관계 검증 후 교체하며 실패 시 이전 상태를 유지한다. 팩이 없어도 알 수 없는 ID/epoch/확장·등록·소유 기록은 보존한다. 손상 저장의 덮어쓰기를 막는다. 생성기는 저장소 내부 출력을 거부한다.

## API와 검증 범위

`world.monsterbook523_runtime`의 로컬 어댑터와 `credit_authority`, `action_authority`, `clock_authority`, `settlement(before, proposed, quote, persist)` 계약을 유지한다. 확정 영수증은 도감별 단조 순번·epoch·정확한 NPC·단계·원본 시각을 검증한다. 다른 출현/스폰 API와 분리한다. 공유 거래 잠금·행별 지급·모든 자원 원자 저장을 사용한다.

검증은 Godot4.7.2, 격리 XDG 프로필, 실제 Main과 검증된 현재 지도 팩을 사용한다. 원본 Python5개, 원본·상태·97단계 자연 전이·18종 사용 사양1312개, 실제 Main의 신규 진행/39계열/97지급/아이템/저장·만료 검사를 수행한다. OpenGL 터치는 가상 화면/llvmpipe에서 실제 Viewport 입력으로 검증하며 headless 신호 발생과 구분한다. Android 실기기·원본 서버 판정·전 아트 동등성을 검사한 것으로 확대하지 않는다. 신규 Main 검사는 과거 시각·실제 NPC ID 배우·처치 임계 직전/전체 달성 fixture를 사용한다. 수십만 처치를 실제 플레이한 시험이나 현재 지도 자연 스폰 전체의 ID 연결을 검증한 것은 아니다. 자연 스폰 원본 ID 공급은 기존/별도 몬스터 팩 경로를 유지한다. 상세 최신 결과와 코드 전달 SHA는 작업 인계에 기록한다.

기존 Main/세이브32개 및 동일 payload·지연 저장 게이트를 유지한다. 리소스 preflight는723시트/41442frames/233420026bytes를 확인한다. 역사적 `--source-dir` 검사는 미제공 a1.zip 때문에 차단된 별도 아트 경계이며 검증한 두523 ZIP과 다르다. `[skip ci]`를 사용하고 수동 CI·워크플로/보호 규칙 변경·다른 PR 병합은 하지 않는다.
