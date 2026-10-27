# 옵션 각성 검토용 증거 인덱스

이 디렉터리는 변신·마법인형·성물 **옵션 각성**의 실제 Godot 실행 캡처와 검증 범위를 정리한다. 기능 범위, 공식 수치와 TWILIGHT 정책값의 구분, 미적용 특수효과는 [옵션 각성 구현 문서](../OPTION_AWAKENING.md)를 따른다.

- 검토 PR: [#152](https://github.com/zoog136-hash/-/pull/152)
- 구현 코드 SHA: [`10e3ad3986327790e1f642cf6d19c6d6bb64c854`](https://github.com/zoog136-hash/-/commit/10e3ad3986327790e1f642cf6d19c6d6bb64c854)
- 증거 작성 기준일: 2026-10-23
- 캡처 환경: Linux, Godot **4.7.2**, OpenGL Compatibility, Mesa **llvmpipe**. 실제 Main 장면과 별도로 격리한 테스트 보유 카드·저장 데이터를 사용했다.

## 캡처 6장

| 캡처 | 실제 이미지 크기 | 확인할 내용과 범위 |
|---|---:|---|
| [각성 성공](awakening_success.png) | 1280 × 720 | 실제 Main의 각성 요청을 처리하고 **저장 파일에 성공 상태가 기록된 뒤** 표시한 결과창. 중앙 카드·성공 문구·해당 카드의 추가 옵션을 확인한다. 필드 검사 원본 파일명은 `main_committed_awakening_success.png`다. |
| [각성 실패](awakening_failure.png) | 1280 × 720 | 실제 Main/HUD에서 재료 주입과 아데나 소모 확인을 거쳐 표시한 실패 결과. 대상 카드 유지와 경험치 환급 안내를 확인한다. UI 검사 원본 파일명은 `saved_result_1280x720.png`다. |
| [필드 — 각성 전](field_before.png) | 1280 × 720 | 같은 Main 필드에 세 종류의 카드를 장착한 상태의 비교 기준. 각성 오라가 없는 모습을 확인한다. |
| [필드 — 각성 후](field_awakened.png) | 1280 × 720 | 격리된 테스트 진행에서 세 카드의 각성 상태를 활성화한 비교 화면. 변신·인형·성물의 오라가 각 그림의 중심을 따라 표시되는지 확인한다. 세 번의 실제 확률 추첨을 연속 성공시켰다는 증거는 아니다. |
| [재료 선택](materials.png) | 1280 × 720 | 실제 Main/HUD의 중복 재료 선택·수량·경험치 표시. 재료 주입과 각성 시도가 별도 동작으로 제공되는지 확인한다. |
| [작은 활성 뷰포트](compact_viewport_540x303.png) | **540 × 303** | 540 × 960 창에서 기존 16:9 비율 유지 설정을 적용했을 때의 **실제 게임 렌더 영역**. 재료 탭·목록·수량·소모 버튼의 접근성을 확인한다. 540 × 960 전체 세로 화면을 채우는 UI를 검증했다는 의미가 아니다. |

위 이미지는 실행 중 렌더한 정지 화면이다. 애니메이션 전체 타이밍이나 장시간 성능은 한 장의 이미지로 입증하지 않는다. 성공·실패 결과는 저장된 결과를 표시하며, 연출 자체가 판정이나 소비를 수행하지 않는다.

## 캡처 무결성

[capture_manifest.json](capture_manifest.json)에 각 PNG의 저장소 경로, 바이트 수와 SHA-256을 기록했다. **manifest 파일 자체의 SHA-256**은 다음과 같다.

```text
47194a00c5273e0a43b94d148af7a3acd5288e282071f6f8af12be7dbe781a77
```

이 해시는 현재 제출한 캡처 파일을 식별한다. 재실행 시 렌더 타이밍·드라이버 등에 따라 새 PNG의 해시가 달라질 수 있으므로, 위 해시를 모든 재실행 이미지의 예상값으로 사용하지 않는다.

## 개별 검사 결과

아래는 이번 기능의 개별 실행에서 확인한 assertion 합계다. **133 + 138 + 112 + 39 + 65 = 487개 통과**이며, 뒤의 전체 회귀 검사 263개와는 집계 단위와 실행 범위가 다르다.

| 검사 | 통과 수 | 주요 검증 범위 |
|---|---:|---|
| [서비스](../../tests/option_awakening_service_test.gd) | 133 / 133 | 공식 데이터 연결, 확률 경계, 재료·아데나 검증, 저장 실패 시 진행·RNG 보존, 이전 저장 백업·복원, 컬렉션 조건 |
| [실제 World](../../tests/option_awakening_world_test.gd) | 138 / 138 | 실제 Main의 소비·저장·재로드·능력치 경로, 장착 옵션과 상시 컬렉션 합산, 실패 보호 |
| [실제 HUD·터치](../../tests/option_awakening_ui_test.gd) | 112 / 112 | 네이티브 터치, 확인·취소, 중복 요청 방지, 실제 소비와 결과창, 창 크기별 재료·버튼 접근성 |
| [연출 컴포넌트](../../tests/option_awakening_vfx_test.gd) | 39 / 39 | 성공·실패 표시, 카드 테두리·오라, 연출 제어와 입력, 렌더 캡처. 이 검사는 독립 컴포넌트 fixture를 포함한다. |
| [Main 필드 렌더](../../tests/option_awakening_field_render_test.gd) | 65 / 65 | 세 종류의 몸체 중심·발 기준 위치, 이동 추적, 모션 축소 설정, 장착 해제, 실제 저장 후 성공 결과 표시 |

112·39·65는 캡처를 활성화한 실행의 수치다. 캡처 없이 실행하면 파일 저장·이미지 크기 검사가 생략되어 assertion 수가 달라질 수 있다.

증거 파일:

- [field_results.json](field_results.json)은 캡처를 활성화한 Main 필드 검사의 원본 기계 판독 결과다. 65개 검사, 빈 실패 배열, OpenGL 방식과 캡처별 오라 위치를 보존한다.
- [validation.json](validation.json)은 전체 등록 검사, 최초 실패와 필요한 재확인, 건너뜀, 기존 main 비교를 구분한다. [validation_logs.zip](validation_logs.zip)에 실제 stdout 로그와 각 실행 summary를 보존한다.
- 초기 연출 컴포넌트의 39개 통과는 도구 stdout으로 확인했으며 해당 실행의 별도 로그 파일은 없다. 성공 표식 보정 후 캡처 없이 실행한 29개 검사는 원본 로그로 보존한다. 전체 검사 수와 캡처 assertion 수를 서로 바꾸어 계산하지 않는다.
- [hunting_baseline_comparison.json](hunting_baseline_comparison.json)은 기존 main과 구현 버전의 경로 검사 실패 92줄이 일치함을 기록한다. 두 원본 로그는 위 ZIP에 포함한다.
- [door_baseline_comparison.json](door_baseline_comparison.json)은 기존 main과 구현 버전의 문 경계 표시 검사 결과가 일치함을 기록한다. 양쪽 모두 14개 assertion 중 같은 표시 조건 2개가 실패했으며, 원본 로그는 위 ZIP에 포함한다.

## 전체 회귀·CI 상태

전체 **263개 등록 검사**를 실행해 필요한 재확인까지 마친 결과는 **247 PASS / 2 FAIL / 14 SKIP / 0 미실행**이다. FAIL을 PASS로 바꾸어 계산하지 않는다. 최종 실패 2종은 독립된 기존 main `e0a14f0`에서 같은 실패 결과가 재현됐다.

| 검사 | 구현 버전과 기존 main의 동일 결과 | 근거 |
|---|---|---|
| `hunting_paths_test` | 7,115개 assertion 중 실패 92줄이 순서까지 일치 | [비교 기록](hunting_baseline_comparison.json), ZIP의 `shard-3/`·`baseline-hunting/` 로그 |
| `remake_door_runtime_test` | 14개 assertion 중 문 경계 표시 조건 2개 실패, 구조화 결과도 일치 | [비교 기록](door_baseline_comparison.json), ZIP의 `shard-2/`·`baseline-door/` 로그 |

SKIP 14개는 선택적 원본 팩이나 별도 검수 실행 조건을 요구하는 검사다. 이름과 실제 사유는 [validation.json](validation.json) 및 각 원본 로그에 보존한다. 모든 실행은 합성 CI fixture 자동 설치를 끈 상태에서 수행했다.

최초 실패 중 4개는 원인을 한정해 재확인했다. 아덴 몬스터 검사는 기존 150초 제한을 넘겨, assertion을 그대로 둔 채 300초 예산에서 1,261개를 166.5초에 통과했다. 사냥터 캡처 검사는 sparse checkout에서 빠진 **기존 추적 카메라 파일**을 복원한 뒤 75장 캡처를 통과했다. 새 필드·연출 검사는 assertion은 통과했지만 runner 성공 표식이 빠져 있어, 구조화 결과와 성공 조건부 표식만 보정한 뒤 기존 판정기로 다시 통과했다. 최초 실패 로그도 ZIP에 보존한다.

기존 변신 temporal Main 배치 10종은 **607,712개 assertion / 실패 0**을 기록했다. runner 단위 검사는 **27개 통과**했다. 추적 리소스 무결성 검사는 **723개 시트 / 41,442개 프레임 / 233,420,026바이트**를 확인했다.

전체 회귀의 실제 런타임 코드·데이터는 구현 커밋 `10e3ad3`와 동일하며 파일별 SHA-256을 `validation.json`에 기록했다. 후속 커밋은 두 새 검사의 출력 표식, 특정 기존 검사의 시간 예산, CI 실행 조건 및 이 검증 자료를 보완한다. 정확한 최종 제출 SHA는 [PR #152](https://github.com/zoog136-hash/-/pull/152)에 기록한다.

**GitHub Actions 통과는 아직 확인하지 않았다.** 구현 커밋에서 생성된 46개 실행은 확인 시점에 대기 상태였다. 최종 커밋의 CI 상태와 링크는 PR 본문에 별도로 기록하며, 개별 487 assertion 통과나 위 로컬 회귀 결과를 GitHub CI 통과로 대체하지 않는다.

## 재현 명령

저장소 루트에서 실행한다. `TWILIGHT_GODOT`에는 Godot 4.7.2 실행 파일의 절대 경로를 지정한다. 기본 테스트 runner는 검사마다 별도 Linux·Windows 사용자 데이터 디렉터리를 만들며, 렌더가 필요한 검사는 실제 OpenGL 화면 또는 Xvfb를 사용한다.

```bash
TWILIGHT_GODOT=/absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
TWILIGHT_EVIDENCE=$(mktemp -d /tmp/twilight-option-evidence.XXXXXX)

python3 tools/test_project.py \
  --godot "$TWILIGHT_GODOT" \
  --no-ci-synthetic-fixtures \
  --only option_awakening_service_test,option_awakening_world_test,option_awakening_ui_test,option_awakening_vfx_test,option_awakening_field_render_test \
  --logs "$TWILIGHT_EVIDENCE/targeted-logs"
```

캡처와 별도 로그까지 다시 생성할 때는 다음 명령을 사용한다. 각 실행은 서로 다른 저장 디렉터리를 사용한다. UI 검사의 `TWILIGHT_UI_TEST_ISOLATED=1`은 실제 카드 소비 입력을 테스트용 저장에서만 허용하기 위한 값이다.

```bash
mkdir -p "$TWILIGHT_EVIDENCE/field-user" "$TWILIGHT_EVIDENCE/ui-user" "$TWILIGHT_EVIDENCE/vfx-user"

XDG_DATA_HOME="$TWILIGHT_EVIDENCE/field-user" LIBGL_ALWAYS_SOFTWARE=1 \
  xvfb-run -a -s "-screen 0 1280x1920x24" \
  "$TWILIGHT_GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
  --script res://tests/option_awakening_field_render_test.gd \
  -- --option-field-capture="$TWILIGHT_EVIDENCE/field" \
  > "$TWILIGHT_EVIDENCE/field.log" 2>&1

XDG_DATA_HOME="$TWILIGHT_EVIDENCE/ui-user" LIBGL_ALWAYS_SOFTWARE=1 \
  TWILIGHT_UI_TEST_ISOLATED=1 TWILIGHT_AWAKENING_UI_CAPTURE_DIR="$TWILIGHT_EVIDENCE/ui" \
  xvfb-run -a -s "-screen 0 1280x1920x24" \
  "$TWILIGHT_GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
  --script res://tests/option_awakening_ui_test.gd \
  -- --capture-option-awakening-ui \
  > "$TWILIGHT_EVIDENCE/ui.log" 2>&1

XDG_DATA_HOME="$TWILIGHT_EVIDENCE/vfx-user" LIBGL_ALWAYS_SOFTWARE=1 \
  xvfb-run -a -s "-screen 0 1280x1920x24" \
  "$TWILIGHT_GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
  --script res://tests/option_awakening_vfx_test.gd \
  -- --option-vfx-capture="$TWILIGHT_EVIDENCE/vfx" \
  > "$TWILIGHT_EVIDENCE/vfx.log" 2>&1
```

전체 회귀 검사는 `--only` 없이 실행한다.

```bash
python3 tools/test_project.py \
  --godot "$TWILIGHT_GODOT" \
  --no-ci-synthetic-fixtures --timeout 300 \
  --logs "$TWILIGHT_EVIDENCE/full-regression-logs"
```

## 환경과 결론의 한계

캡처의 Mesa llvmpipe는 CPU 기반 소프트웨어 OpenGL이다. Linux에서 실제 화면을 렌더했다는 근거이며, Windows·Android GPU의 프레임률·전력·발열·기기별 터치 동작을 보장하지 않는다. 이 증거만으로 Android APK나 최종 실행본이 배포됐다고 판단하지 않는다.

테스트 fixture는 검증용 획득·각성 상태를 명시적으로 준비하며 정상 플레이 저장을 사용하지 않는다. 원작의 모든 카드·컬렉션·특수효과 또는 원본 이미지·맵·이펙트 전체를 통합했다는 증거도 아니다. 구현한 기능과 제외 항목은 [옵션 각성 구현 문서](../OPTION_AWAKENING.md)에 구분되어 있다.
