# 할파스 성급 강화 — patch523 조건 조회 연결

기준 main: `7d550a78a8fd1a95a50ebb18b38c3134380c3fa6`.
별도 브랜치: `feature/patch523-halphas-star-enchant-20261104`.

게임의 변신 목록에서 **해방된 할파스 → 성급 강화**로 들어가 단계별 재료 수와 아데나 비용을 조회한다. 미보유 상태에서도 조회할 수 있고 **강화 조건 다시 확인** 버튼으로 현재 차단 결과를 표시한다. 다른 변신·인형·성물에는 이 진입 버튼과 규칙을 적용하지 않는다. 강화 조건이 해석되지 않아 실행 버튼은 잠겨 있으며, 직접 요청도 거절한다. 강화 완료, 확률 판정, 재료 소비, 단계 효과 적용은 구현 완료가 아니다.

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

실제 OpenGL 4.5/Mesa llvmpipe에서 1280×720, 960×540 두 화면을 열고 비용 3단계·차단 결과·재조회와 비활성 강화 버튼의 표시를 직접 확인했다. 임시 확인용 캡처는 `/tmp/halphas-1280.png`(881,094바이트, SHA256 `230d1416847665272d45996e1fb6a78b30369d7400998c919340728715ca8741`)와 `/tmp/halphas-960.png`(363,668바이트, SHA256 `faab9712f28b0d052f261830cc5ee1b371ea4305b36e963930b8b8fd15f3ee80`)다. 공개 저장소나 Library에 스크린샷/원본 맵을 새로 게시하지 않았다. 이는 화면 구조·입력 검사이며 원본 아트 전체 복원·Windows/Android 실기 검증이 아니다.

첫 cold import는 임포트 캐시 준비를 위해 중단됐고 이후 전체 임포트가 완료됐다. 초기 UI 검사에서 첫 프레임 대기/검색 신호와 JSON 숫자 비교의 검사 환경 문제를 고쳤으며, 그 뒤 발견한 실제 그리기 캐시 오류도 코드에서 해결했다. 초기 로그는 덮어쓰지 않고 같은 결과 폴더에 보존했다. 최종 GL은 오디오 장치가 없는 검사 환경에 맞춰 Dummy 오디오를 명시했다. 최종 검사에서 엔진 오류를 무시하지 않았다.

원격 CI는 사용자 지시에 따라 커밋의 **`[skip ci]`**로 실행을 억제하며 수동 실행/재실행하지 않는다. 원격 CI 통과를 주장하지 않는다. Android와 원본 외형 전체 렌더, 실제 성공/실패 강화는 미검증이다.

원본 ZIP과 현재맵의 별도 검사 팩은 현재 환경의 입력이며 새 게임 배포본으로 납품하지 않는다. 새 원본 아트·바이너리·대형 원본 표 전체를 공개 PR에 추가하지 않는다. 리소스 장부의 원본 미전달 상태를 승격하지 않는다. 역사적 `--source-dir` 검사는 이 환경에 `a1.zip`이 없어 실패했으며, 위 두523 ZIP은 별도 실제 바이트/전체CRC 검사로 확인했다.
