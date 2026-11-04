# 누적523 몬스터 도감: 실행·경제·검증 경계

기준 main은 `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`이다. 별도 브랜치와 기존 draft PR #244에서 계속 작업했다. #218 전투/드롭, #230 출현 정의, #232 아덴 로더를 병합하지 않았다. 스폰·맵·드롭 확률·기존 각성 비용은 변경하지 않는다.

## 실제 게임 경로

메뉴 → 사냥·모험 → **몬스터 도감**에서 검색, 현재33개/과거 포함557개 정의, 집계·옵션 기간, 단계별 처치·달성·보상·옵션을 확인한다. 기존 단순 몬스터 목록과 별도 기능이다.

- 현재 대상 멤버는 정확한 NPC944개/97단계다. 현재 대상 연결이0인 과거524개를 활성 도감으로 취급하지 않는다. 과거508의904개 멤버십을 재사용하지 않으며 새 핫스팟16, 알비노 리부트18+버섯6을 포함한다.
- Main의 기존 사망 중복 방지·소환 제외·EXP/드롭 처리 **뒤**에서 정확한 `source_m_npc_id`와 실제 life를 전달한다. 기존 게임에서 인정한 사망을 재사용하는 오프라인 어댑터이며 원본 서버의 막타 판정을 복제했다고 주장하지 않는다. 이름·Sprite·맵으로 원본 ID를 추측하지 않는다. 원본 ID가 없는 기존 개체는 집계하지 않는다.
- 모든 연결 도감의 기간별 총 인정 처치를 보존하고 첫 단계는 원본 목표 수에서 무료 자동 달성한다. 저장 실패 시 사망 영수증을 메모리에 남겨 재시도하며, 내구 저장 전에 진행을 공개하거나 중복 집계하지 않는다. 세이브에는 처치별 대용량 이력을 저장하지 않는다.
- 일일 Book6013은 원본96 NPC만, Level16423/1000회/옵션0개다. 실제 게임의 한국05시 일일 달력 함수를 재사용한다. 새 날짜의 첫 인정 처치에서 새 epoch를 만들고 이전 처치·수령·소유 기록은 보관한다. 시계를 되돌려 이전 보상을 다시 받지 못한다. 다른 ResetType을 임의로 해석하지 않는다.
- **보상 받기**는 지급 가능한 원본 Reward 행만 한 번씩 수령한다. 정확한 원본 아이템 ID로 인벤토리·일반 아이템 조회·기존 인벤토리 UI에 연결하고 원본 보관 제한을 적용한다. 이름이 같은 기존 아이템과 병합하지 않는다. 명예 코인1500개와 EXP를 실제로 지급·저장·재불러오기까지 검증했다. 미지원 보상이 함께 있으면 해당 행만 미수령으로 남기며 전체 수령으로 표시하지 않는다.
- 원본 `CurrencyCost`는 **즉시 완료** 비용이다. 일반 달성 비용으로 차감하지 않는다. 양수 비용의 현재96개 단계는 원본 Gem 비용으로 즉시 완료할 수 있다. 이전 단계 달성을 요구하며 실제 처치 수를 조작하지 않는다. 일일 무료 단계는 즉시 완료 구매 대상으로 만들지 않는다.
- **옵션 적용**은 달성한 한 단계를 플레이어가 명시적으로 선택한다. 단계 합산/대체에 관한 원본 서버 규칙은 자동으로 추정하지 않는다. 현재39개 옵션 계열 중26개를 기존 실제 소비자에 연결했다. 고정 대미지·명중·MR·리덕션8종 외 AC, 무게, EXP, 이동/공속, 치명타/치명타대미지, ER, MP회복, PvE리덕션, 회피무시 등을 포함한다. Percentage/ValuePercent/Weight는 원본 UIUnit.Denominator로 환산한다. 선택·만료 시 장비/스탯 캐시를 무효화한다. 미지원 효과는 UI에서 개별 이유를 표시한다.

## 원본 우선 경제와 자체 설정

공식 [시즌22 이벤트 안내](https://lineagem.plaync.com/board/event/view?articleId=50560450)와 [2026-10-07 패치 노트](https://lineagem.plaync.com/board/update/view?articleId=6ac54c38a279104f7d9d5ff1)를 검색해 기간·단계 보상·다이아 즉시 완료를 대조했다. 페이지 본문은 이 환경의 웹 열기에서 동적으로 표시되지 않아 검색 색인으로 확인했으며, 현재 비용 숫자의 기준은 검증한 최신523 원본표다. 다른 시즌 숫자로 덮어쓰지 않았다.

원본에도 공개 안내에도 현재 TWILIGHT 경제로 연결할 EXP 레벨 환산식·게임 내부 아데나/Gem 교환 규칙은 확인되지 않았다. 사용자 지시대로 다음 두 값만 `data/monsterbook523_balance.json`의 **TWILIGHT 자체 설정**으로 분리했다.

- 도감용 게임 다이아1개 = 아데나10,000. 화면에 자체 교환임을 표시하며 실제 결제는 없다. 별도 내부 지갑의 획득·소비·잔액을 함께 저장하고 원본 Gem 비용을 그대로 차감한다. 원본 Currency.ExchangeRate를 아데나 환율로 해석하거나 기존 지갑을 다이아로 바꾸지 않는다. 종료된 도감만 남은 경우 교환을 거부한다.
- EXP = 원본 Reward.Amount × 3,864,874 / 31,920,000, 반올림·최소1. 기존 TWILIGHT 3배 성장 곡선의 성수 균형을 기준으로 만든 호환 설정이며 원본 레벨별 EXP 수식이라고 주장하지 않는다. 일일 원문5,000,000은 이 설정에서605,400 EXP다. 원문 Amount, 사용한 비율, 실제 지급량, 자체 설정 출처를 수령 기록에 남긴다. Exp/Class281을 Item281로 혼동하지 않는다.

교환은 아데나+내부 지갑을, 즉시 완료는 지갑+달성을, 보상은 인벤토리+EXP/레벨/스탯+행별 수령 상태를 **한 저장 트랜잭션**으로 처리한다. 저장 실패 시 기존 자원과 기록을 유지한다. 실제 EXP 지급은 기존 성장 곡선·레벨당 HP/MP/공격/방어/스탯 포인트 규칙을 사용하며 별도 EXP 배율로 기존 사냥/각성 비용을 바꾸지 않는다.

## 남은 기술적 경계

경제 수치 미확인을 이유로 모든 진행을 잠그지 않는다. 다음은 경제 수치와 다른 미확정/미연결 항목이며 자체 확률 설정으로 해결한 것으로 취급하지 않는다.

1. 일반 **후속 단계**의 자연 처치 카운터가 누적인지 단계별 재시작인지 실행 근거가 없다. 총 인정 처치를 계속 보존하고 첫 단계 자연 달성·후속 즉시 완료는 작동한다. 자연 후속 달성만 구체적 이유와 함께 보류한다.
2. 단계별 원본 옵션의 자동 합산/대체 규칙은 확인되지 않아 한 단계 명시적 선택으로 제공한다. 원본 서버의 자동 중첩 재현 완료로 보고하지 않는다.
3. 현재 보상 아이템25종 중7종의 무기한·무게0·스택 아이템은 지급한다. 나머지18종의 DeleteTime/이벤트 만료·상자/재도전/충전 사용 조건은 원문을 보존하고 해당 지급 행만 보류한다. 삭제 시각 조건을 제거해 영구 아이템으로 만들지 않는다. 지급한 코인·재료도 별도 제작/상점/사용 기능으로 연결되었다고 주장하지 않는다.
4. 남은13개 효과 계열: Melee/Range/MagicDamageReduction, Melee/Range/MagicDamageReductionPercent, IgnoreMelee/Range/MagicDamageReductionPercent, IgnoreDamageReductionPercent, PVEPierceDamageReductionPercent, SpecialResistance, HitSpecialResistance. 원문 조건/기존 전투 소비자가 없어 전투 공식을 새로 만들어 적용하지 않는다. 조건부 특수저항의 타깃6/8도 임의 상태 이름으로 바꾸지 않는다.
5. 원본의 한국 표기 시각은 시작2026-10-07 05:00, 집계 종료10-28 05:00, 옵션 종료11-04 05:00이다. 현재 날짜에는 종료 상태가 맞다. 경제 구현 지시를 이벤트 재개 승인으로 해석하지 않는다. 과거 시각을 사용하는 검증은 격리 테스트 fixture이며 제품 시각을 바꾸지 않는다. 만료해도 소유/달성/수령 기록은 삭제하지 않는다.

## 외부 정적 규칙 팩

원본 ZIP25,031,173bytes, SHA256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`; 심층 제약 ZIP170,140bytes, SHA256 `704daa65656b7e61a2723cb5eec68edfa195ff1e17c524ebb954ae0975436961`. 소비 환경에서 정식 Library materialize 후 실제 바이트·SHA256·전체 ZIP CRC를 검증했다. 원본은 수정하지 않았다.

현재 팩 `monsterbook523.private-v2.json`은1,790,494bytes, SHA256 `a49b49e8f30ab82bbcee776a070d26bc4310a0bfa06e68d6d1126eb61ca2a129`이다. 같은 Library 항목 `libfile_f12c2bcdd0f88191a2f846955ed5e481`의 version1로 저장하고 별도 경로로 다시 정식 materialize하여 동일 바이트/SHA를 검증했다. MonsterBook557/Level1531/옵션링크1282/보상링크2570과 정확한 참조·보관/만료 근거·UI 단위를 포함한다. 원본 행은 공개 Git에 넣지 않는다. 아트 전달 상태와 별개인 정적 규칙 팩이다.

```sh
python3 tools/monsterbook523/build_pack.py \
  --source-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  --output /private/monsterbook523.private-v2.json

godot --path . -- \
  --monsterbook523-pack=/private/monsterbook523.private-v2.json \
  --monsterbook523-sha256=a49b49e8f30ab82bbcee776a070d26bc4310a0bfa06e68d6d1126eb61ca2a129
```

생성기는 저장소 내부 출력을 거부한다. 로더는 digest·snapshot·관계 검증 후 원자적으로 교체한다. 팩이 없어도 과거/알 수 없는 ID·epoch·확장 필드·등록/수령 기록을 유지하고 손상 저장의 덮어쓰기를 막는다.

## API와 재현

`world.monsterbook523_runtime`은 기본 로컬 어댑터를 즉시 연결하며 확인된 서버 어댑터로 교체할 수도 있다. `credit_authority(npc_id, life_id, actor_id, state)`, `action_authority(action, book_id, level_id, state)`, `clock_authority()` 및 `settlement(before, proposed, quote, persist)` 계약을 유지한다. `apply_confirmed`는 도감별 단조 순번·epoch·원본 시각·정확한 대상·단계 ID를 검사하고 성공 저장 뒤에만 공개한다. `claim_rewards`는 행별 수령, `instant_complete`는 원본 비용과 내부 지갑, `effects`는 명시적 적용 단계를 처리한다.

```sh
MONSTERBOOK523_SOURCE_ZIP=/private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  python3 -m unittest discover -s tests -p test_monsterbook523_pack.py -v
MONSTERBOOK523_PACK=/private/monsterbook523.private-v2.json \
MONSTERBOOK523_SHA256=a49b49e8f30ab82bbcee776a070d26bc4310a0bfa06e68d6d1126eb61ca2a129 \
  godot --headless --path . --script res://tests/monsterbook523_test.gd
# 실제 Main 검사는 격리 XDG 프로필과 검증된 현재 지도 팩을 사용한다.
TWILIGHT_SOURCE_MAP_PACK=/private/core-source-pack \
  godot --path . --script res://tests/monsterbook523_local_game_test.gd -- \
  --monsterbook523-pack=/private/monsterbook523.private-v2.json \
  --monsterbook523-sha256=a49b49e8f30ab82bbcee776a070d26bc4310a0bfa06e68d6d1126eb61ca2a129
```

실제 Godot4.7.2 원본 팩 검사995개, 원본 Python5개, 기존 실제 Main/세이브32개 및 동일 payload/지연 저장 게이트를 통과했다. 외부 확정 어댑터 UI 회귀는 실제 OpenGL/Viewport 터치·취소·두 해상도39검사를 통과했다. 기본 어댑터의 실제 사망·아이템/EXP 지급·다이아 교환·96단계 즉시 완료·실제 UI 터치·재불러오기156검사도 통과했다. 실제 OpenGL 화면에서 보상/교환/즉시 완료 버튼의 Viewport 터치를 검증하고 기본 경로 캡처를 남겼다. 원격 전체 CI·Android 실기기·원본 서버 판정·아트 동등성 검증으로 확대하지 않는다.

리소스 preflight는723시트/41,442frames/233,420,026bytes를 확인했다. 역사적 `--source-dir` 검사는 미제공 예전 `a1.zip` 부재로 실패했으며 별도 검증한 두523 ZIP과 다르다. 원본 아트/배포 장부를 승격하지 않는다. 커밋은 `[skip ci]`; 원격 CI 수동 실행/재실행/취소나 워크플로/보호 규칙 변경은 하지 않는다.
