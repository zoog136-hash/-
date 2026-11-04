# 할파스 성급 강화 — 원본 계약과 TWILIGHT 추정 경제

기준 main `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`, 브랜치 `feature/patch523-halphas-star-enchant-20261104`, 기존 Draft PR #240을 이어 작업한다. 다른 PR/main 병합과 수동 CI 실행은 하지 않는다.

변신 목록의 **해방된 할파스 → 성급 강화**에서 원본 비용, 추정 확률, 중복 재료 선택, 확인창, 강화 결과와 획득 단계 외형 적용을 연결했다. 실제 거래는 저장 성공 후에만 재화·중복 카드·단계·난수를 반영한다. 대상은 BuffCard24504 / Group4 / `source:m508:1:24504` 하나다.

**기능 활성화와 경제 추정은 별도다.** 사용자 최신 지시는 원본/공식 자료 우선 조사 후 찾지 못한 확률·재화 소모를 자체 설정으로 구현하도록 허용했다. 이 허용으로 원본 `ContentsControl.Enable=false`나 미확인 서버 집합274를 해제하지 않는다. 정상 설정에서는 두 기술 제한을 계속 표시하고 시도를 거절한다. 거래·UI 검사는 production JSON을 바꾸지 않는 명시적 격리 활성화 fixture에서 실행한다. 일반 플레이 활성화를 완료했다고 보고하지 않는다.

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
