# 할파스 성급 강화 — patch523 조건 조회 연결

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`.
별도 브랜치: `feature/patch523-halphas-star-enchant-20261104`.

게임의 변신 목록에서 **해방된 할파스 → 성급 강화**로 들어가 단계별 재료 수와 아데나 비용을 조회한다. 미보유 상태에서도 조회할 수 있고 **강화 조건 다시 확인** 버튼으로 현재 차단 결과를 표시한다. 다른 변신·인형·성물에는 이 진입 버튼과 규칙을 적용하지 않는다. 후속 조사에서 원본 ContentsControl의 해당 활성화 값도 false로 확인했다. UI와 직접 요청은 이 사실을 표시하며 실행을 거절한다. 강화 완료, 확률 판정, 재료 소비, 단계 효과 적용은 구현 완료가 아니다.

## 확인한 원본과 현재 main

Library의 정식 prepare/materialize와 현행 전송 helper로 다음 두 파일을 내려받았다. 실제 바이트 수·SHA256·ZIP 전체 CRC·Library ID xattr를 확인했다. 인증 거부나 다른 다운로드 경로로 우회한 일은 없다.

| Library 파일 | 바이트 | SHA256 |
|---|---:|---|
| `libfile_f3e9e5b322cc8191ae441565bbd24c27` / `lineagem_patch523_all_content_validated_and_508_520_deltas.zip` | 25,031,173 | `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832` |
| `libfile_e5db97740a7481919ae372262480e984` / `TWILIGHT_card_activation_and_subslot_523_addendum_20261104.zip` | 440,394 | `bebe2009ae37b94e3f6c4195852c868d6d3a6a3a9e524d9ac8fbfea883a44dbc` |

해당 원본 BuffCard 24504는 현재 main의 `m508:1:24504`의 `source_original_card`와 모든 필드가 같다. 원본 변화 비교표에서도 성급 강화 3표와 외형 옵션표는 508→523, 520→523 바이트 변경 목록에 없다. 최신523 원문에서 다시 추출했으며 다른 버전의 원행을 섞지 않았다.

현재 main의 `lineagem_base508.select_visual()`은 명시적으로 선택한 할파스 외형의 원본 연결을 지원하지만, StarEnchant 자격을 달성했다고 판정하지 않는다. 이번 연결에서도 기존 외형 선택값을 달성 이력으로 승격하거나 삭제하지 않는다. 기존 비용·각성·영구 보유·시간 제한 예외·저장 형식을 변경하지 않는다.

PR #231의 변경 파일 13개를 확인했다. 이번 PR은 그 파일을 수정하지 않고 새 할파스 모듈·화면과 HUD의 별도 진입부를 사용한다. 다른 PR이나 main을 병합하지 않는다.

실제 화면 검사에서 검색 결과가 바뀐 직후 카드 수량 그리기가 이전 페이지의 인덱스를 읽는 오류를 재현했다. `catalog_card_chrome.gd`가 목록 세대가 바뀐 동안 이전 그리기 캐시를 사용하지 않도록 보정했다. 새 페이지의 지연 레이아웃 이후 정상 그리기를 유지한다.

## 확정된 계약

- BuffCardStarEnchantGroup: 1행, GroupID 4, BuffCardID 24504만 대상이다. 같은 유일 등급의 기르타스나 할파스 인형도 대상에 포함하지 않는다.
- BuffCardStarEnchantRule: 3행. Enchant 1/2/3, SourceGradeID 52, SourceAmount 1/2/3, CurrencyID 1(Adena), CurrencyCost 각 5,500,000.
- Probability 원값은 1,000,000 / 666,000 / 333,000이며 데이터에 그대로 보존한다. 판정 단위는 별도 근거가 필요하여 백분율이나 RNG 상한을 만들어 사용하지 않는다.
- StarEnchantMaxLevel: 3. 보너스 참조는 43행(단계 1:21, 2:11, 3:11), 외형 옵션은 3행이다. 이 참조를 실제 능력치로 합산하지 않는다.
- 카드 서버 집합은 772, 강화 그룹 서버 집합은 274, 각 규칙의 ServerLimitsetID는 0이다. 서버 조건을 서로 대체하지 않는다.

`tools/build_patch523_halphas_star_enchant.py`는 원본 ZIP SHA를 고정하고 필요한 표의 원문 크기·SHA와 선택 원행을 `data/cards/patch523_halphas_star_enchant.json`에 기록한다. 그룹이 추가되거나 단계/조인이 달라지면 새 검토가 필요하다.

## 미해결과 차단

0. ContentsControl ID1154 / `BuffCardStarEnchantPolymorph`는 `Enable=false`, `ServerLimitSetID=274`다. 값과 범위를 그대로 보존한다. 이는 해당523 클라이언트 설정의 관측이며 현재 모든 리니지M 서버의 실제 운영 동작을 증명하는 것은 아니다. 빈 서버 집합을 허용으로 해석하거나 false를 true로 바꾸지 않는다.
1. 제공된 전체 ServerLimit 표에는 ServerLimitSetID 274의 정의가 없다. 특정 서버 문맥이 카드 집합 772와 일치해도 강화 그룹은 허용하지 않는다.
2. SourceGradeID 52만으로 재료의 덱 종류와 영구 보유/중복 카드 소비 정책을 확정할 수 없다. 같은 등급 원본은 변신·인형·성물에 걸쳐 5개다. 원본 UI에는 변신 카드 목록과 마법인형 소비 주의문이 함께 있어 한쪽으로 추정하지 않는다.
3. 실패 후 대상/단계 유지·하락·삭제 정책, 확률 단위, 보너스의 단계별 대체/누적 정책이 명시되지 않았다.
4. 현재 게임에 원본 성급 강화 달성 이력을 증명하는 장부가 없다. `earned_stage`는 미확정(null)이며 외형 선택이나 옵션/스킬 각성으로 0~3의 달성을 만들어 내지 않는다. 새 저장 필드를 쓰지 않는다.

이 근거가 해소되면 별도 진행 장부의 검증·백업/이전, 원자적 저장 성공 뒤의 재료·아데나·RNG 반영, 실패 처리, 단계 보상과 외형 자격을 이어야 한다. 현재의 차단을 단순 제거해 실행을 열어서는 안 된다.

## 재현

```bash
python3 tools/build_patch523_halphas_star_enchant.py \
  /workspace/halphas-source/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
  data/cards/patch523_halphas_star_enchant.json --verify
python3 tools/check_resource_integrity.py --root .
python3 tools/ci_core_map_pack.py --output /workspace/halphas-core-source-pack
TWILIGHT_SOURCE_MAP_PACK=/workspace/halphas-core-source-pack python3 tools/ci_core.py \
  --stage /workspace/halphas-core-project \
  --godot /workspace/tooling/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --logs /workspace/halphas-core-results
```

`tests/halphas_star_enchant_test.gd`는 실제 Main의 전 카드 범위 제한, 서버 집합 분리, 비용 원값, 직접 요청 거부, 두 해상도에서 마우스로 여는 UI와 조건 재확인 결과, 비활성 실행 버튼과 차단 결과, 정확한 저장 바이트·아데나·카드·외형·컬렉션·보스 상태 보존을 검사한다. 기존 핵심 게이트에 이 집중 검사 하나를 추가한다. `--capture-halphas`는 실제 OpenGL 실행에서만 `/tmp/halphas-1280.png`, `/tmp/halphas-960.png`를 남긴다.

## 검증 상태와 전달 범위

Godot **4.7.2**, 실제 Main/current source-map와 격리 XDG 저장소에서 다음을 확인했다. 게임 진행 타이머와 몬스터 처리는 UI 검사 동안 정지시키고 UI 입력은 유지했다.

| 검사 | 결과 | 로그 |
|---|---|---|
| 최종 할파스 headless 검사 | 755검사, 실패/엔진 오류 0 | `/workspace/halphas-core-results/halphas-verified-headless.txt` |
| 최종 OpenGL·마우스·2해상도 | 757검사, 실패/엔진 오류 0 | `/workspace/halphas-core-results/halphas-verified-gl.txt` |
| 최종 Main/current map·저장 이전/보존 재검사 | 32검사, 실패/엔진 오류 0 | `/workspace/halphas-core-results/core-main-verified.txt` |
| 동일 payload 저장 | 실패 0, 실제 쓰기 2, 동일 쓰기 건너뜀 1 | `/workspace/halphas-core-results/save_identical_payload_test.txt` |
| deferred save 게이트 | 실패/엔진 오류 0 | `/workspace/halphas-core-results/deferred_save_gate_test.txt` |
| Python staging 회귀 | 7테스트 통과 | `python3 tests/test_ci_core.py` |
| 원본523 재생성 일치 | 통과 | builder `--verify` |
| Git 리소스 무결성 | 723시트 / 41,442프레임 / 233,420,026바이트 SHA 일치 | `tools/check_resource_integrity.py --root .` |

최종 headless 로그 SHA256은 `ad9a24c50885b37c4a6ef04076821d37d2c68de1cb40b57ab6ea22e7a59985a1`, OpenGL 로그는 `d358b3a5b852b5e61c7a0eb660fda39a6cf3412821675f282275fb9a7b746c25`, 최종 Main 로그는 `94f972d8406f7072080306e79a8c161a7e6900402b605688e98eb47f0d79f2cd`다.

실제 OpenGL 4.5/Mesa llvmpipe에서 1280×720, 960×540 두 화면을 열고 비용 3단계·차단 결과·재조회와 비활성 강화 버튼의 표시를 직접 확인했다. 후속 수정 후의 최신 임시 확인용 캡처는 `/tmp/halphas-1280.png`(884,409바이트, SHA256 `8a40b5200341cdf27248aef7199bb324bcd8a75553b4e93d8a9fbf53d3ae02f6`)와 `/tmp/halphas-960.png`(367,514바이트, SHA256 `9c1fd6fb0dec50519f54368460377d0fe9d4986addb7fd52c38cdc0c5210ebd4`)다. 공개 저장소나 Library에 스크린샷/원본 맵을 새로 게시하지 않았다. 이는 화면 구조·입력 검사이며 원본 아트 전체 복원·Windows/Android 실기 검증이 아니다.

첫 cold import는 임포트 캐시 준비를 위해 중단됐고 이후 전체 임포트가 완료됐다. 초기 UI 검사에서 첫 프레임 대기/검색 신호와 JSON 숫자 비교의 검사 환경 문제를 고쳤으며, 그 뒤 발견한 실제 그리기 캐시 오류도 코드에서 해결했다. 초기 로그는 덮어쓰지 않고 같은 결과 폴더에 보존했다. 최종 GL은 오디오 장치가 없는 검사 환경에 맞춰 Dummy 오디오를 명시했다. 최종 검사에서 엔진 오류를 무시하지 않았다.

원격 CI는 사용자 지시에 따라 커밋의 **`[skip ci]`**로 실행을 억제하며 수동 실행/재실행하지 않는다. 원격 CI 통과를 주장하지 않는다. Android와 원본 외형 전체 렌더, 실제 성공/실패 강화는 미검증이다.

원본 ZIP과 현재맵의 별도 검사 팩은 현재 환경의 입력이며 새 게임 배포본으로 납품하지 않는다. 새 원본 아트·바이너리·대형 원본 표 전체를 공개 PR에 추가하지 않는다. 리소스 장부의 원본 미전달 상태를 승격하지 않는다. 역사적 `--source-dir` 검사는 이 환경에 `a1.zip`이 없어 실패했으며, 위 두523 ZIP은 별도 실제 바이트/전체CRC 검사로 확인했다.

## 후속 조사 — 활성화 조건과 기존 게임 규칙 대조

사용자의 실제 강화 실행 요구에 따라 원본 전체와 기존 게임 코드를 다시 대조했다. 단순히 UI만 남기려는 정책이 아니라 실행에 필요한 사실을 확인하려는 조사다. 새로 확인한 ContentsControl 원행을 빌더와 실행 스냅샷에 추가했으며, 직접 요청은 `source_feature_disabled`를 반환한다. 호출자가 반환된 표시용 사본의 Enable을 true로 바꿔도 원본과 다음 요청에는 영향을 주지 않는다. UI에도 기존의 포괄적인 대기 문구 대신 원본 비활성 사실을 표시한다.

- 원본의 274 참조는 총6,912행/25표이며 ContentsControl에는 false인4행이 있다. 하지만 ServerLimit의 집합274 정의는0행이다. 다수 참조만으로 서버 범위나 특수 허용 의미를 만들어낼 수 없다.
- `scripts/cards/native_option_combat.gd:roll()`은 Percentage(Unit3) 발동 효과에 백만분율을 사용한다. 이 코드는 재사용 후보지만 BuffCardStarEnchantRule.Probability가 그 Unit에 속한다는 별도 근거는 없다. 1000000/666000/333000을 100%/66.6%/33.3%라고 확정해 실제 카드를 소모하지 않는다.
- `data/cards/option_awakening_policy.json`은 `consume_duplicates_only=true`와 영구 보유 보호를 명시한다. 이 소유권 보존 원칙은 재사용 가능하다. 다만 성급 강화의 재료 덱 종류와 실패 후 대상/단계 처리를 정의하지 않으며, 옵션 각성의 유일 비용5,000,000을 원본 성급 비용5,500,000 대신 쓰지 않는다.
- `option_awakening_runtime.gd:_transact()`와 `skill_awakening_runtime.gd`의 staged RNG 및 `_save_game` 성공 후 반영 방식은 재사용 가능한 저장 기술이다. 아직 확정되지 않은 강화 결과를 만들거나 새 달성 장부를 쓰는 근거가 되지는 않는다. 이번 후속에서도 실제 소비·단계 저장 경로를 열지 않았다.
- 성장 개발실은 별도 저장 프로필과 명시적인 커스텀 규칙을 사용한다. 그 개발실 수치나 일반 카드 합성 확률을 원본 할파스의 규칙으로 옮기지 않는다.

공식 공개 자료도 2026-11-04에 확인했다. [리니지M 변신 시스템 가이드](https://lineagem.plaync.com/guidebook/view?title=%EB%B3%80%EC%8B%A0%20%EC%8B%9C%EC%8A%A4%ED%85%9C)의 공개 프런트엔드가 사용하는 [원문 API](https://lineagem.plaync.com/api/v2/lineagem/guide/%EB%B3%80%EC%8B%A0%20%EC%8B%9C%EC%8A%A4%ED%85%9C)는 HTTP200으로 읽었으며 갱신 시각은 2026-10-21이다. 본문에는 할파스와 스킬/옵션 각성 안내가 있지만 성급 강화의 시도·소비·실패 규칙은 확인하지 못했다. [공식 확률 공시](https://probability.plaync.com/lineagem/index)의 공개 [카테고리 API](https://probability.plaync.com/api/lineagem/categories)도 HTTP200으로 확인했다. 당시 변신 하위6항목은 합성·합성 시도 보상·미스터리 카드·스킬 각성·옵션 각성·옵션 각성 정보였으며 별도 성급 강화 항목은 없었다. 확인한 문서와 목록에 한정된 결과로, 게임 전체에 기능이 없다는 증명으로 확대하지 않는다. 공개 화면의 JavaScript에 명시된 GET 경로만 읽었고 인증 거부 우회는 하지 않았다.

실제 강화의 다음 단계에는 활성화·서버 집합274의 의미, 허용 재료 덱, Probability 단위, 실패 후 대상/단계 처리와 보너스 집계의 원문 근거가 필요하다. 별도 TWILIGHT 규칙으로 켜려면 원본 계약과 구분되는 명시적인 정책 결정이 필요하며, 기존의 실제 구현 요청을 임의 확률/결과 규칙까지 승인한 것으로 해석하지 않는다.

후속 검증은 실제 Main의 headless **759검사**와 두 해상도 OpenGL **761검사** 모두 실패/엔진 오류0이다. 원본 false, 그룹과 동일한 서버 범위, 카드 서버 충족만으로 활성화되지 않음, 반환된 표시 사본 변조로 활성화되지 않음을 추가로 검사했다. 비용 조회·실제 마우스 클릭·비활성 안내와 원본 저장 바이트·재화·카드·RNG·기존 외형·컬렉션·보스 상태 보존도 다시 통과했다. 로그는 `/workspace/halphas-core-results/halphas-followup-headless.txt`(SHA256 `d72dc5926d0bb0e718843b5457b6ec21091b9529c41bbcf5684d4ca4dfe5f4e8`)와 `halphas-followup-gl.txt`(SHA256 `a1893aedc5f90b06209575ad33a10107fd34e8bd7f2980205b1272ce49bce53a`)다. 앞 절의755/757은 초기 커밋의 검증 기록이다.

ContentsControl 원문은15,155바이트/SHA256 `1bc9a1d681db659e9f4347904f2aed80856209fbebcdc91ed57cec8247d7dfe8`이며 업데이트한 파생JSON은50,210바이트/SHA256 `de8122f39e437b41570d7940dd46faddacc186b54e368c44afef512947923121`다. 공개 가이드 API 응답은108,840바이트/SHA256 `ff38d11e8bcacba5b9d63d039cf7661cb0aaaf906f1631ec0a2cc9591de06ae8`, 공시 카테고리 응답은4,472바이트/SHA256 `62a325ecfa2a3e54807b3bebb9aeff115db39aa19422800d0022ab9bc3ab82f3`로 임시 조사 폴더 `/workspace/scratch/official-transform-guide.json`, `official-probability-categories.json`에 보존했다. 원문 전체를 공개 저장소에 추가하지 않는다.
