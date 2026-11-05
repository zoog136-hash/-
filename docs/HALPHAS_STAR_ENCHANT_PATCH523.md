# 할파스 성급 강화 — 원본 계약과 TWILIGHT 추정 경제

**최신 상태:** 승인된10파일은 원격 `25efa74e8163074043fc725ebc87b8071e96f2b6`에 전달됐다. 이후의 조건부 전투·자체 동작 후속13파일은 로컬 작업이며 별도 게시 범위다. 아래31/37행·12/6행 대기 표시는 단계별 검증 기록이고, 최신 자체 동작 구현은 마지막 절을 기준으로 읽는다.

기준 main `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`, 브랜치 `feature/patch523-halphas-star-enchant-20261104`, 기존 Draft PR #240을 이어 작업한다. 다른 PR/main 병합과 수동 CI 실행은 하지 않는다.

변신 목록의 **해방된 할파스 → 성급 강화**에서 원본 비용, 추정 확률, 중복 재료 선택, 확인창, 강화 결과와 획득 단계 외형 적용을 연결했다. 실제 거래는 저장 성공 후에만 재화·중복 카드·단계·난수를 반영한다. 대상은 BuffCard24504 / Group4 / `source:m508:1:24504` 하나다.

**기능 활성화와 경제 추정은 별도다.** 앞선 사용자 지시는 원본/공식 자료 우선 조사 후 찾지 못한 확률·재화 소모를 자체 설정으로 구현하도록 허용했고, 후속 지시는 원본·보고서·공개 조사 뒤에도 없는 게임 내부 동작까지 자체 구현하도록 범위를 넓혔다. 이 허용으로 원본 `ContentsControl.Enable=false`나 미확인 서버 집합274를 해제하지 않는다. 정상 설정에서는 두 기술 제한을 계속 표시하고 시도를 거절한다. 거래·UI 검사는 production JSON을 바꾸지 않는 명시적 격리 활성화 fixture에서 실행한다. 일반 플레이 활성화를 완료했다고 보고하지 않는다.

## 원본 바이트와 공개 조사

Library 정식 prepare/materialize로 받은 두 ZIP의 실제 바이트·SHA256·전체 ZIP CRC·Library xattr를 확인했다. 인증 거부 우회는 없었다.

| 원본 | 바이트 | SHA256 |
|---|---:|---|
| `libfile_f3e9e5b322cc8191ae441565bbd24c27` / `lineagem_patch523_all_content_validated_and_508_520_deltas.zip` | 25,031,173 | `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832` |
| `libfile_e5db97740a7481919ae372262480e984` / `TWILIGHT_card_activation_and_subslot_523_addendum_20261104.zip` | 440,394 | `bebe2009ae37b94e3f6c4195852c868d6d3a6a3a9e524d9ac8fbfea883a44dbc` |

해당 BuffCard24504의 원행은 main의 `source_original_card`와 같다. 빌더 `tools/build_patch523_halphas_star_enchant.py`는 원본 ZIP SHA를 고정하고 필요한 원행과 표 크기·SHA를 JSON에 기록한다. 새로 Bonus/BonusType/Unit을 조인하되 원본을 변경하지 않는다.

확인된 값은 다음과 같다.

| 항목 | 원본 값 |
|---|---|
| 단계 | 1 / 2 / 3, 최대3 |
| 재료 등급·수량 | SourceGrade52, 1 / 2 / 3장 |
| 아데나 | Currency1, 각5,500,000 |
| Probability 원값 | 1,000,000 / 666,000 / 333,000 |
| 보너스 | 43개 참조·조인 원행, 외형3개(옵션4/14/24) |
| 활성화 | ContentsControl1154 `BuffCardStarEnchantPolymorph`, Enable=false, 서버 집합274 |
| 서버 | 카드772는347행, 그룹274 정의0행, 강화 규칙0 |

전체274 참조는25표/6,912행이지만 정의 부재를 허용으로 해석하지 않는다. 해당523 클라이언트 설정은 현재 모든 실제 서버의 운영 상태를 증명하지 않는다. ContentsControl 원문15,155바이트 / SHA256 `1bc9a1d681db659e9f4347904f2aed80856209fbebcdc91ed57cec8247d7dfe8`.

2026-11-04 [공식 변신 가이드](https://lineagem.plaync.com/guidebook/view?title=%EB%B3%80%EC%8B%A0%20%EC%8B%9C%EC%8A%A4%ED%85%9C)와 공개 [가이드 API](https://lineagem.plaync.com/api/v2/lineagem/guide/%EB%B3%80%EC%8B%A0%20%EC%8B%9C%EC%8A%A4%ED%85%9C)(갱신2026-10-21), [공식 확률 공시](https://probability.plaync.com/lineagem/index) 및 [공개 카테고리 API](https://probability.plaync.com/api/lineagem/categories)를 HTTP200으로 확인했다. 가이드에는 할파스·스킬/옵션 각성이 있지만 성급 강화의 소비·실패 규칙은 확인하지 못했다. 변신 공시 하위6항목에도 별도 성급 강화 항목이 없었다. 이는 확인한 문서·목록에 한정된 결과다. 공개 화면 JS에 명시된 GET만 읽었으며 비공개 인증을 우회하지 않았다.

조사 응답은 `/workspace/scratch/official-transform-guide.json`(108,840바이트, SHA256 `ff38d11e8bcacba5b9d63d039cf7661cb0aaaf906f1631ec0a2cc9591de06ae8`)과 `official-probability-categories.json`(4,472바이트, SHA256 `62a325ecfa2a3e54807b3bebb9aeff115db39aa19422800d0022ab9bc3ab82f3`)에 보존했다. 원문 전체를 PR에 올리지 않는다.

## 자체 설정과 구현

`data/cards/halphas_estimated_policy.json`에 원본과 분리한 `twilight-halphas-estimated-v1` 정책을 기록했다.

- 확률 단위1,000,000 → 추정100% / 66.6% / 33.3%. 기존 Percentage 난수 단위와 일관되지만 해당 원본 Probability 단위로 확정된 값은 아니다. 단위 설정은1,000,000~1,000,000,000 범위에서 조정할 수 있다. 원본 확률 숫자를 덮어쓰지 않는다.
- 재료는 유일 **변신**의 보유 중복만 허용한다. 영구 최초 보유는 소비하지 않는다. 유일 인형·성물은 금지한다. 이 덱 선택은 자체 정책이다.
- 기본 실패는 재료·아데나를 소비하고 현재 단계·최초 보유를 유지한다. `failure_consumes_material_and_gold=false` 설정도 장부에 구분해 지원한다. 단계 하락·삭제는 없다. 원본 5,500,000과1/2/3 수량은 유지한다. 기존 옵션/스킬 각성·드랍 확률·사용자 지정 비용을 바꾸지 않는다.
- 자체 단계 효과 집계는 지원되는 무조건부 타입마다 현재 단계 이하의 마지막 값을 사용한다. 3단계 HP는30,000이며10,000+20,000+30,000으로 중복 합산하지 않는다. 해당 단계에 없는1단계의 근/원/마법 대미지+10 등은 이어받는다. 원본43행 중31행/17타입을 HP·MP·능력치·방어·속도·대미지·회복 경로에 연결했다. CastSpeedBonus는 현재 게임의 스킬 재사용 감소 경로로 호환한다는 자체 가정이다.
- **조건부 HitSpecialResistance / SpecialResistance와 DecreaseChargeStepTime 총12행/3타입은 미연결**이다. 원행을 보존하고 UI에 표시한다. 조건·충전 전투 체계를 경제 추정 승인으로 발명하지 않는다.
- 효과는 획득 단계가 있고 해당 할파스를 실제 장착·보유하며 기술 제한을 충족할 때만 적용한다. 다른 카드/미장착/기술 차단 상태에는 적용하지 않는다.
- 획득 단계에 대응하는 원본 옵션4/14/24는 별도 **획득 단계 외형 적용** 버튼으로 저장한다. 강화만으로 기존 선택을 바꾸지 않는다. 기존 외형24를 골랐더라도 새 장부가 없으면 획득0단계다. 원본 외형 픽셀 복원은 이 PR의 납품물이 아니다.

`offline_enable_despite_native_flag=false`, `offline_server_override=false`가 기본이다. 이 값은 경제 수치가 아니며 사용자 경제 추정 허용을 이유로 켜지 않는다. 지원하지 않는 정책 모드·재료 덱·영구 보유 소비 설정은 오류로 거절한다.

## 저장과 UI 보호

새 `halphas_star_enchant`에는 schema/policy, level, revision, 시도/성공 횟수, 단계별 시도·실제 결제 횟수, 누적 소비, 전용 RNG 문자열, 마지막 거래/결과를 둔다. 비용·재료 장부의 합이 맞아야 불러올 수 있다. 부분값/음수/소수 단계/불가능한 단계 이력은 로드 전 거절하고 자동 저장도 차단한다. 정상 파일을 다시 불러오면 해제한다.

구형 저장은 원본 바이트 SHA가 같은 `.pre-halphas-<SHA256>` 백업을 만든 후 획득0단계로 메모리 이전하며 로드만으로 원본 파일을 덮어쓰지 않는다. 옵션/스킬 각성과 기존 저장 보호를 유지한다. RNG 결과·재료·아데나는 별도 staged 값으로 계산하고 production `_save_game`의 원자적 쓰기 성공 뒤 반영한다. 저장 실패는 모두 보존하며 재시도 시 새 결과로 바뀌지 않는다. revision과 거래 ID로 오래된 확인창과 중복 요청을 거절/재생한다.

UI는 수량 선택·자동 선택 후 필요한 재료명/수량·아데나·추정 확률·실패 규칙을 확인창에 표시한다. 취소는 소비/저장을 하지 않는다. 결과와 획득 단계를 화면에서 보여준다. 정상 기본 모드에서는 원본 비활성 사실을 표시하고 실행 버튼을 비활성화한다.

world.gd에 저장·능력치·전투 연결이 필요해 작은 연결부를 추가했다. 타 기능 PR의 파일 병합은 없으며 공통 world.gd를 쓰는 PR은 통합 시 충돌 검토가 필요하다. 앞선 카드 검색의 이전 그리기 캐시 오류 보정도 유지한다.

## 로컬 재현과 전달 범위

```bash
python3 tools/build_patch523_halphas_star_enchant.py \
  /workspace/halphas-source/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  data/cards/patch523_halphas_star_enchant.json --verify
python3 tools/check_resource_integrity.py --root .
python3 tests/test_ci_core.py
# 새 stage는 tools/ci_core.py가 작성하며 실제 추적 리소스만 사용한다.
TWILIGHT_SOURCE_MAP_PACK=/workspace/halphas-core-source-pack python3 tools/ci_core.py \
  --stage /workspace/new-halphas-core-project \
  --godot /workspace/tooling/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --logs /workspace/new-halphas-core-results
```

실제 Main/current source-map, Godot4.7.2, 격리 XDG로 검증한다. 기본 비활성 UI/전 카드 대상 범위 검사는 `halphas_star_enchant_test.gd`, 실제 거래·UI·세이브는 명시적 격리 활성화 fixture를 쓰는 `halphas_star_enchant_transaction_test.gd`다. 두 테스트를 기존 핵심 실행기에 추가했다. 원격 워크플로/브랜치 보호를 변경하지 않는다.

최종 검증 결과와 로그 해시는 아래 기록에 추가한다. 이전 UI만 구현한 커밋의759/761 통과는 이전 기록이며 새 경제 구현의 통과로 대신하지 않는다.

원격 커밋은 `[skip ci]`, 수동 CI 실행/재실행은 없다. Android/Windows 실기기·원본 전체 외형·조건부 전투 효과·일반 플레이 활성화는 미완료다. 바이너리·ZIP·공식 원문 전체·스크린샷·새 원본 아트를 공개 업로드하지 않는다. 723시트/41,442프레임/233,420,026바이트의 기존 추적 리소스 SHA 검사를 유지한다. 원본 ZIP과 현재 맵 검사 팩은 현재 환경의 입력이며 배포본이 아니다. 역사적 `--source-dir`은 `a1.zip` 부재로 실패했고, 제공523 ZIP 실제 바이트/CRC 검사와 구분한다. 새 사설 팩 납품은 없고 원본 미전달 장부도 유지한다.

## 2026-11-04 최종 검증

| 검사 | 결과 | 로그 SHA256 |
|---|---|---|
| 거래·확인창·성공/실패·RNG·세이브 headless | 57검사, 실패/엔진 오류0 | `halphas-economy-final-headless.txt` / `52e373189d109a26eeb9dbd4e3823e907911a243aa44bbbe39f1cb3f0bce68e4` |
| 최종 거래·외형 UI OpenGL 1280/960 | 59검사, 실패/엔진 오류0 | `halphas-economy-final-gl.txt` / `d92a89c089929b994e5911430dfb25a00b89454122fae57b950fc7b18e701b2f` |
| 기본 비활성 UI·전 카드 범위·OpenGL2해상도 | 761검사, 실패/엔진 오류0 | `halphas-economy-default-gl.txt` / `a1893aedc5f90b06209575ad33a10107fd34e8bd7f2980205b1272ce49bce53a` |
| Main/current map·저장 이전/보존 | 32검사, 실패/엔진 오류0 | `core-economy-headless.txt` / `94f972d8406f7072080306e79a8c161a7e6900402b605688e98eb47f0d79f2cd` |
| 동일 payload 저장 | 실패/엔진 오류0 | `save-economy-identical.txt` / `6186fec3e9e79c3863ddc3ede6a746284b11080f627f6bf12ef2617cd8e8209b` |
| deferred save 게이트 | 실패/엔진 오류0 | `save-economy-deferred.txt` / `c9d060c94cdc7be5057eb4d1e8bd0a2a41db1c2bec5ccda4497e27c2076519a9` |

로그 루트는 `/workspace/halphas-core-results`다. headless57 이후 작은 화면 외형 적용 마우스 검사를 더한 최종 OpenGL59를 수행했다. 기본 비활성 UI761은1280×720과960×540의 비용·선택·제한 문구를 실제 렌더/입력으로 확인했다. 동일 payload는 쓰기2/건너뜀1, Python staging7테스트, builder --verify, 리소스723시트 SHA 검사가 통과했다. 최종 엔진 오류를 무시하지 않았고 V-Sync 미지원 경고는 llvmpipe 환경 정보다. 초기 UI 입력 fixture의 화면 크기 미지정, 기본 카드 능력치를 포함하지 않은 비교, JSON 재직렬화 전후 해시 비교를 고친 진단 실패 로그는 같은 폴더에 보존했다. 마지막 검증은 모두 통과했다.

파생 계약 JSON은77,672바이트/SHA256 `1ca457652f7be56f45e00a4b1f039d314eb6823edf34815d400e8d74322c8f28`다. 임시 캡처 `/tmp/halphas-1280.png`, `/tmp/halphas-960.png`는 UI 검토용이며 공개 업로드/배포 납품이 아니다. 새로운 원본 리소스 납품이나 Windows/Android 검증으로 확대하지 않는다.

## 후속 로컬 변경 — 남은12행의 조건·현재 전투 연결

승인된 기존10파일은 원격 `25efa74e8163074043fc725ebc87b8071e96f2b6`에 게시했고 로컬 `1ac3d40019c05f11a427206d49890b6be52e1ece`와 트리가 정확히 같다. 원격10파일의 Git blob SHA를 각각 대조했다. PR #240은 Draft·미병합이고 해당 커밋의 원격 workflow runs는0이다. 별도의 상세 PR 본문은 자동 검토에서 거절됐으나, 이미 승인·게시된 문서의 내용만 참조하는 짧은 설명으로 줄인 뒤 정상 반영됐다.

**이 절의 후속 수정은 위10파일 게시 승인에 포함하지 않는다.** 후속은 아래7파일이며 새 게시 승인을 받기 전 로컬에만 둔다.

- `data/cards/patch523_halphas_star_enchant.json`
- `tools/build_patch523_halphas_star_enchant.py`
- `scripts/cards/halphas_star_enchant_runtime.gd`
- `scripts/skills/status_service.gd` — 앞선 승인10파일에 없던 전투 소비 API 연결 파일
- `scripts/ui/halphas_star_enchant_view.gd`
- `tests/halphas_star_enchant_transaction_test.gd`
- `docs/HALPHAS_STAR_ENCHANT_PATCH523.md`

최신 main은 다시 확인한 결과 여전히 `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`다. 원본 `BonusApplicationType.ID2 = SpecialResistanceType`와 대상 정의를 조인했다. 대상6=Stun(스턴),7=Hold(홀드),8=Fear(공포),5=Dark(암흑),1=Ice(동빙)다. Unit3 Percentage의 UIUnit 분모는10,000이고 Unit211 ValuePercent의 분모는1이다. 따라서 차징 원값40/80/120은40%/80%/120% 표시값이며0.004%로 잘못 환산하면 안 된다.

| 단계 | BonusID (링크ID) | BonusTypeID / 효과 | 조건 대상 | 원값 → 표시 | 연결 |
|---:|---|---|---|---|---|
| 1 | 2144764 (74) | 5782 / 적중 | 타입2·6 Stun | 300000 →30% | 스턴 적중 |
| 1 | 2144774 (84) | 145 / 내성 | 타입2·6 Stun | 300000 →30% | 스턴 내성 |
| 1 | 2144804 (114) | 7471 / 차징 시간 감소 | 타입0·대상0 | 40 →40% | 대기 |
| 1 | 2144814 (124) | 5782 / 적중 | 타입2·6 Stun | 100000 →10% | 스턴 적중 |
| 2 | 2144874 (174) | 5782 / 적중 | 타입2·7 Hold | 600000 →60% | 홀드 적중 |
| 2 | 2144884 (184) | 145 / 내성 | 타입2·7 Hold | 600000 →60% | 홀드 내성 |
| 2 | 2144914 (214) | 7471 / 차징 시간 감소 | 타입0·대상0 | 80 →80% | 대기 |
| 2 | 2144924 (224) | 5782 / 적중 | 타입2·8 Fear | 200000 →20% | 공포 적중 |
| 3 | 2144974 (274) | 5782 / 적중 | 타입2·5 Dark | 900000 →90% | 대기 |
| 3 | 2144984 (284) | 145 / 내성 | 타입2·5 Dark | 900000 →90% | 대기 |
| 3 | 2145014 (314) | 7471 / 차징 시간 감소 | 타입0·대상0 | 120 →120% | 대기 |
| 3 | 2145024 (324) | 5782 / 적중 | 타입2·1 Ice | 300000 →30% | 대기 |

이번 후속에서는6행을 더 연결하여 총37/43행이 현재 게임의 소비 경로를 갖는다. 조건 범위는 원본 정의의 ID·이름과 보너스의 대상 ID가 모두 일치할 때만 인정한다. 스턴·홀드·공포를 일반 명중이나 모든 상태 내성으로 평탄화하지 않는다. 스턴 적중의 독립 두 링크(+30/+10)는 기존 TWILIGHT 레코드 합산으로+40이 되며, 같은 대상의 상위 단계 값이 있으면 해당 단계 집계로 대체한다. 상위 단계에 없는 대상은 기존 추정 프로필의 이전 단계 효과 유지 방식에 맞춰 유지한다. 이는 현재 게임의 호환 집계이며 리니지M 원작의 전체 누적 공식을 확인했다는 주장이 아니다. 원문을 삭제·변형하지 않는다.

`bonus_records()`가 스턴/홀드/공포의 정확한 `*_accuracy`, `*_resistance` 필드를 공급한다. 기존 `world._stun_accuracy_stat()`, `_hold_accuracy_stat()`, `_fear_accuracy_stat()`와 `_stun_resistance_stat()`, `_hold_resistance_stat()`를 거쳐 기존 플레이어 상태 공격과 몬스터 피격 판정에서 소비된다. 별도의 일반 플레이 활성화는 하지 않는다.

현재 주 스킬의 `TwilightSkillStatusService.apply()`에도 소비 경로를 연결했다. 기존 스킬 기본 확률에 획득·장착한 할파스의 해당 상태 적중 퍼센트 포인트만 더하고, 기존 대상 내성 곱과 보스 계수를 그대로 적용한다. 비활성/미장착/미보유일 때는 기존 확률 수식 그대로다. 이는 TWILIGHT의 기존 상태 판정에 원본 숫자를 연결하는 호환 방식이며 원작 전투 수식을 발명하거나 검증한 것으로 취급하지 않는다. 면역·100% 내성·죽은 대상은 기존 can_affect에서 난수 사용 전 거절한다. 보너스 적용 자체는 MP·아데나·중복 카드·성급 전용 RNG를 소비하지 않고 별도 저장 필드도 추가하지 않는다. 기존 단계 장부로부터 재계산한다.

아직 대기하는6행은 다음 이유로 현재 소비 API가 없다.

- **암흑/동빙3행:** player/monster 상태 및 주 스킬 서비스는 stun/hold/fear/silence/slow/poison/bleed를 구현한다. Dark·Ice의 적용·적중·내성 경로가 없다. 암흑을 침묵으로, 동빙을 홀드로 대체하면 원본 대상이 달라진다.
- **차징3행:** 원본에는 ChargeBonus25행, ChargeEffectBonus267행, SpellClass.IsChargeSpell, BonusType7341 ChargeID·7331 PossibleChargeSystem과 단계별 시간/발동 조건이 있다. 예를 들어 ChargeBonus61/71은 ChargeID21의1/2단계 Time1000을 정의하고, ChargeEffectBonus1081은 해당61/SpellClass82에 연결된다. SpellClass82 쇼크 스턴은 IsChargeSpell=true다. ConstantData53541/53551/53561은 길게 누름200·최대3000·최소100을 갖는다. 하지만 현재 게임은 이 단계·길게 누름·해제 API를 소비하지 않는다. `world._cast_job_charge_skill()`은 경로를 따라 이동하는 돌진이며 단계별 차징이 아니다. 이동 속도나 일반 재사용 대기시간에40/80/120을 적용하지 않는다. 특히120%의 실시간 계산/하한을 임의로 정하지 않는다.

공개 1차 자료인 [NC의 2022-03-16 보도자료](https://about.ncsoft.com/news/article/lineagem-update-20220316)도 차징 스턴을 단계에 따라 스킬 효과가 변하는 기능으로 설명한다. [공식2025-09-17 패치](https://lineagem.plaync.com/board/update/view?articleId=68c9bab8b276e6387160d1eb)와 [공식2026-03-18 패치](https://lineagem.plaync.com/board/update/view?articleId=69b9abb8232a171f20adadb8)도 확인했으나 브라우저로 읽은 페이지는 본문 없는 동적 화면이었다. 검색 미리보기/제3자 설명을 원문 수식의 근거로 삼지 않는다.

추가 원문 SHA256: BonusApplicationType4,366바이트 `f66a6b5f7a537f618daef95e8d990894546356359d774aa49bd53d483cc7dcbb`, SpecialResistanceType982바이트 `31ede31d0d027ee99107a9bbcc1e0d9f602d7814cc8ebd1bf6d34ebb54ada2c2`, UIUnit5,069바이트 `897a028a9585815972325a25fca67dbe2d51fd9d63da9f190329d537f421a62b`다. 빌더가 이3표의 해시와 조건·단위 조인을 함께 보존한다. 차징 조사표는 공개 납품하지 않는다. ChargeBonus4,349바이트 `ade8c4878771abd7874e202fec4926b95ab46c813d4ac1dfa671c443f55aa3e0`, ChargeEffectBonus41,744바이트 `212a2875dce1e632fd248ba03c3880d2dc2a144585decc5eb3aa86c4b5f47c67`, SpellClass22,596,753바이트 `db769ac3f25723289c1a63b4d1376d2bbfe8978608461712d09ef937a47d87ce`.

6행 연결 시점 검증: 실제 Main headless81검사, OpenGL80검사, 기본 비활성 UI 두 해상도761검사와 기존 상태효과 회귀41검사 모두 실패/엔진 오류0이다. 높은 기존 확률을 양의 보너스가 낮추지 않도록 보존하는 경계값도 포함했다. 최종 headless81 로그는 `halphas-conditional-final-headless.txt`, GL80은 `halphas-conditional-gl.txt`, 기본 UI761은 `halphas-conditional-default-gl.txt`, 회귀41은 `halphas-conditional-status-regression.txt`다.

`halphas-conditional-final-headless.txt` SHA256 `753b8b6bd6382a62faaf466d3ee71d7a8646ebfa499deabfeb879e96e2618d4e`.

`halphas-conditional-gl.txt` SHA256 `8b0557e7462fe74c52fc5e20cf4ff7e1d4fff7c9c9eacdd88df958acceb37486`.

`halphas-conditional-default-gl.txt` SHA256 `a1893aedc5f90b06209575ad33a10107fd34e8bd7f2980205b1272ce49bce53a`.

`halphas-conditional-status-regression.txt` SHA256 `03c2e152dbc0279cff937586df5476463debf47d61cc7ec1f1a054b432ec6b98`.

이 시점 파생 JSON88,047바이트/SHA256 `8ff45b1a5acb51accf77e6006291d97da6dd9dbbfa78637a918c175da827a685`다. Builder --verify와 리소스723시트 SHA 검사는 통과했다. 원격 CI는 수동 실행하지 않았다.

## 최신 후속 — 암흑·동빙·차징의 자체 동작 연결

사용자의 추가 지시(소스·기존 보고서 확인, 없으면 공개 검색 후 근거 있는 추정 적용)에 따라 앞 절의6행도 실행 경로를 만들었다. 원본 확정 숫자·대상·등급·비용·확률을 우선하고, 원작의 구현식이 없는 행동만 자체 정책으로 분리했다. **원본 Enable=false는 확인된 값이므로 추정으로 true로 바꾸지 않았으며 일반 플레이 강화 활성 제한도 유지한다.**

현재 원본43행은 모두 현재 게임의 읽기/소비 경로를 갖는다. 이는 원작 전투43행의 동작이 동일하다는 뜻이 아니다. 기본31행, 기존 상태 스코프6행과 마지막 암흑·동빙·차징6행을 구분하며 마지막6행의 동작은 명시적인 TWILIGHT 자체 호환 계층이다. 일반 NPC 전체에 새 상태 스킬이 배치되거나 모든 원본 차징 스킬이 구현됐다는 주장도 하지 않는다.

`halphas_combat_adapter.gd`가 원본을 수정하지 않고 다음을 처리한다.

- **암흑:** 별도 상태명·수명으로 관리하며 실제 플레이어/몬스터의 공격 명중 확률에 기본 ×0.5를 적용한다. 기존 상태나 침묵으로 이름을 바꾸지 않는다. 원본3단계의 암흑 적중+90%·암흑 내성+90%는 해당 스코프의 판정에만 사용한다. ×0.5는 자체값이다.
- **동빙:** 별도의 상태이며 이동·공격·스킬을 봉쇄한다. 기존 홀드 내성이나 스턴 내성으로 대체하지 않는다. 원본 동빙 적중+30%를 자체 동빙 판정에 연결한다. 기존 독·출혈·스턴 등의 타이머는 계속 흐르고 동빙만 따로 만료된다. NPC 명시 면역은 보존한다.
- **일반 전투 연결:** 주 스킬 StatusService는 dark/ice를 적용할 수 있다. NPC의 선택적인 dark/ice_accuracy, resistance, duration 필드는 미제공 시0이며 새 상태를 임의로 모든 NPC에 부여하지 않는다. 필드가 주어진 NPC의 실제 피격 훅은 별도의 암흑/동빙 판정을 호출한다. 기존 NPC의 기본 확률·비용·상태 구성은 그대로다. 몬스터 재사용·죽음·맵 세대가 바뀌면 이전 생명의 상태를 이어받지 않는다.
- **차징:** 새 기술을 무료로 부여하지 않는다. 실제로 습득한 기존 쇼크 스턴의 직업·레벨·무기·MP·재사용 조건을 확인한 뒤, 자체 차징 UI에서 시작·취소·해제한다. 원본 ChargeID21의2개 Time1000 단계, SpellClass82, 사거리 보너스1/3을 가져온다. 현재 쇼크 스턴 사거리96=원본2칸에 맞춘 기본48픽셀 환산은 자체 설정으로 표시한다. 해제는 같은 기존 스킬을 한 번 시전하고 기존 비용을 한 번만 지불한다. 반복 해제·대상 생명 변경·취소·시간초과로 두 번 소비하지 않는다. 실제 motion marker→flight→상태 타격까지 검사한다.
- **차징 감소식:** 원본40/80/120%를 유지한다. 기본 자체식은 `원본 초 / (1 + 감소율/100)`이며, 최소0.1초는 원본 ChargeMinTime100을 반영했다. 120%에서도 음수나0초가 되지 않는다. 대안 `linear_percent_with_source_minimum`은 `원본 초 × (1 - 감소율/100)`에 같은 최소값을 적용한다. 원작 공식으로 확정한 식은 아니다. 차징 중 이동/다른 공격 대기와 기본3초 취소도 현재 자체 입력 정책이다.
- **저장:** player의 자체 암흑/동빙 남은 시간은 `halphas_star_enchant.custom_combat`의 선택 필드로 원자 저장한다. 구형 저장에서 필드가 없으면0이며0~30초의 유한 수만 허용한다. 맵 로드가 끝난 후 현재 플레이어에 복구한다. 차징 중간 동작은 로드/맵 전환 시 취소되고 MP/아이템을 소비하거나 나중에 중복 타격하지 않는다. 몬스터의 일시 상태는 기존 생명/맵 범위이며 세이브로 옛 몬스터에 재적용하지 않는다.

스킬 사거리 외의 ChargeEffectBonus의 원본 DamageScale·IgnoreSpecialResistance·SelectorType 전체를 재현했다고 주장하지 않는다. 이 작업의 목표는 할파스 DecreaseChargeStepTime을 실제 단계 시간과 기존 유료 스킬에 연결하는 것이다. 현재 원본 사거리 외 단계 보너스의 추가 해석은 별도 범위다.

자체값은 `data/cards/halphas_estimated_policy.json.custom_combat`에서 설정한다. `enabled`, `dark_hit_multiplier`(0.05~1), `ice_blocks_movement_and_actions`, `charge_time_formula`(위2종), `charge_timeout_seconds`(0.5~10초), `charge_tile_pixels`(1~128)가 있다. 확정 원본에 없는 동작을 원본값으로 표시하지 않고 UI에 자체 전투 ON/OFF·명중 배율·동빙 봉쇄·차징 환산과 소비 시점을 보여준다. 조건부 집계는 이전 단계의 동일 대상 유지·같은 단계 독립 링크 합산이라는 현재 호환 규칙을 설정·문서에 분리한다. 원본/보고서 확인과 공식 NC의 단계별 차징 설명을 우선했으며 제3자 포럼 문장을 원작 공식의 근거로 삼지 않았다.

최종 파생 JSON은98,229바이트/SHA256 `8fd08030f41e678d9ff020c90d6c2feedb4024fdb4b2ba73c742a4d5aecb6709`다. 기존의 원본 ZIP SHA 고정·선택 원행/표 해시를 유지하고 ChargeBonus·ChargeEffectBonus·SpellClass82와3개 차징 ConstantData를 조인했다. SourceGroup4 외 카드의 강화 대상을 늘리지 않는다.

승인된 원격 커밋 이후의 최종 로컬 후속은 **13파일**이다. 앞 절의7파일에 정책 JSON, 새 combat adapter, player.gd, monster.gd, world.gd, skill_service.gd를 더한 합집합이다. 특히 actor 이동/공격, 주 스킬 상태 소비와 저장 복구 연결이 추가되어 앞선10파일 게시와 다른 범위다. 게시 승인 없이 원격 ref를 옮기지 않으며 main/다른 PR도 병합하지 않는다. 원본 아트·ZIP·스크린샷·대형 표 전체를 공개 업로드하지 않는다.

최신 자체 동작 검증: 실제 Main headless **111검사**(실제 차징 스킬의 marker/flight/스턴 타격 포함), OpenGL **109검사**(마우스 시작/취소/해제와 작은 화면 외형), 기본 제한 UI OpenGL2해상도 **761검사**, Main 저장 이전/보존 **32검사**, 기존 상태효과 회귀 **41검사**가 모두 실패/엔진 오류0이다. 최초108 이후 대안 차징식과 실제 타격·잘못된 자체 저장 검사를 추가했다. 마지막 owner 미설정 초기 export 방어는 별도 짧은 실행으로 확인했다. Builder --verify, 리소스723시트 SHA, Python staging7테스트도 통과했다. 전체/수동 원격 CI는 실행하지 않았다.

`halphas-custom-final-headless.txt` SHA256 `2c94ea939c93b78833b97f5d7992a2e349847f04b195c033fa362338d81e3968`.

`halphas-custom-gl.txt` SHA256 `ec03ce730356634a442d3de0ffda169a78a80f56ea693cf0fe5de92b2419ea8e`.

`halphas-custom-default-gl.txt` SHA256 `a1893aedc5f90b06209575ad33a10107fd34e8bd7f2980205b1272ce49bce53a`.

`halphas-custom-core.txt` SHA256 `94f972d8406f7072080306e79a8c161a7e6900402b605688e98eb47f0d79f2cd`.

`halphas-custom-status-regression.txt` SHA256 `03c2e152dbc0279cff937586df5476463debf47d61cc7ec1f1a054b432ec6b98`.

`halphas-custom-fresh.txt` SHA256 `7ae62c29ce842a0a99dbd4afbadeaff76ed8a13d791d81f32ec6061773dab3dc`.

원격 승인본25efa74e와 로컬 신규 변경을 혼동하지 않는다. 신규13파일은 아직 원격에 전달하지 않았다. 사설 원본/스크린샷/배포본 전달과 Windows/Android 실기 검증은 없다.
