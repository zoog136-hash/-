# 같은 브랜치에서 재개하기

**최신 전 맵 확장:** `4dbc58f`까지 코드 푸시. [expansion25/README.md](expansion25/README.md), 맵별 최신 JSON·128 PNG를 확인한다. 25개 모두 공통 리메이크 경로에 연결되며 원작 복원 완료는 0/25다. 새 15개는 A3 서버 격자를 추측하지 않고 기존 폴리곤 좌표를 보존한다. PR100 최신 확인 `07bba22`이며 해당 브랜치/player/monster/animation은 수정하지 않았다. 아덴의 기존 impact_visuals 폴리곤 렌더 오류는 미해결이다. 기존 10층 격자·v2 팩·성공 결과를 다시 만들지 않는다.


## 코드와 원본의 보관 상태

- 저장소: https://github.com/zoog136-hash/-
- 브랜치: `feature/twilight-map-remake-20261015`, Draft 유지, main 병합 금지.
- 공통 구현 `a5d9031`, 폭젠 반경 보존/팩 재사용 `1c73a23`, main 갱신 통합 `dc787a9`.
- 원본 자료 Drive 폴더: https://drive.google.com/drive/folders/1QTl1U45iWuJeQcI9ljuV11Le8nkXK-39
- A3 정확한 분할 ZIP 폴더: https://drive.google.com/drive/folders/1KQ42RjHIfL3eMUhietgzQ8lru4smFoW0
- 기존 manifest Drive ID: `1RwcV6ZydFhbUw6IMlUKKRmnMs8Gvv0p0`. 분할 파일과 결합 ZIP 해시를 확인하고 재사용한다.
- 이번 환경의 A3: `/workspace/sources/a3.zip`. 다음 Work에도 남는다고 가정하지 않는다.
- 원본 격자와 임시 배치가 들어간 런타임 팩은 `data/map_remake/private`이며 공개 Git에 포함하지 않는다. 사용자가 기존 자료 폴더에 비공개 업로드를 승인하여 [수정된 v2 팩](https://drive.google.com/file/d/1Iwn4v9dJIne1UBrHJAe-jVX6lur7OlGu/view)을 보관했다. 공개 공유 설정을 생성하지 않았다.
- `TWILIGHT-map-remake-private-20261015-v2.zip`: **1,413,515바이트**, SHA-256 `9123660429fc06a9e88a3f7719f2121401f53dc57d71e1da543b085caa399708`. 업로드 후 재다운로드하여 SHA·ZIP CRC·10층 격자/배치를 독립 검증했다. 이미지 0개, 15개 엔트리, 배치 버전 `2026101502`. 초기 v1은 폭젠 반경 수정 전이므로 사용하지 않는다. 원본 전체 아트 납품 장부를 완료로 바꾸지 않는다.
- Drive 권한은 user writer/owner만 확인했으며 anyone/domain 권한은 없다. [새 체크아웃 복원 결과](evidence/fresh-restore/restoration.json)는 코드 `f0caf83` + 실제 재다운로드 ZIP + 새 임포트 + 실제 1층 플레이 180개 검사/PNG 3장 PASS다. 같은 호스트의 격리 테스트이며 실제 사용자 저장 폴더를 사용하지 않았다.

## 복원 명령

Godot는 공식 4.7.2를 사용한다. 실제 사용자 저장 경로와 다른 `XDG_DATA_HOME`/Windows `APPDATA`를 사용한다. `GODOT`에는 해당 실행 파일 경로를 지정한다. 아래 원본 경로는 현재 환경 예시이므로 다음 세션에서 존재 여부를 먼저 확인한다.

```bash
git switch feature/twilight-map-remake-20261015
git fetch origin
python3 tools/check_resource_integrity.py --root .
# 위 Drive v2 ZIP의 SHA를 확인한 뒤 저장소 루트에 압축 해제한다.
# 기존 팩이 있다면 해시를 비교하고 백업한 뒤 설치한다.
# ZIP에는 data/map_remake/private, effective_layouts.json, DELIVERY_MANIFEST.json이 있다.
python3 tools/map_restore/verify_remake.py --pack data/map_remake/private --layouts effective_layouts.json --report /workspace/private-validation.json
"$GODOT" --headless --path . --import
```

팩을 복원한 경우 아래 변환을 반복할 필요가 없다. 원본에서 다시 만들어야 할 때만 실행한다.

```bash
"$GODOT" --headless --path . --script res://tools/map_restore/export_current_layouts.gd -- /workspace/effective-layouts.json
python3 tools/map_restore/build_remake.py --a3 /workspace/sources/a3.zip --layouts /workspace/effective-layouts.json --output data/map_remake/private
python3 tools/map_restore/verify_remake.py --pack data/map_remake/private --layouts /workspace/effective-layouts.json --report /workspace/private-validation.json
```

기존 팩의 격자가 정확하지만 배치 생성기만 변경되었다면, 원본 ZIP 1,000개 재복구 대신 새 디렉터리로 reflow한다. 실패한 출력에는 유효 index를 남기지 않는다. 이전 팩은 보존한다.

```bash
python3 tools/map_restore/refresh_remake_gameplay.py --source /workspace/old-private-pack --layouts /workspace/effective-layouts.json --output /workspace/new-private-pack
python3 -m unittest discover -s tools/map_restore -p 'test_*.py'
"$GODOT" --headless --path . --script res://tests/remake_coordinates_and_state_test.gd
"$GODOT" --path . --rendering-driver opengl3 --script res://tests/remake_source_runtime_test.gd -- --output=/workspace/remake-play
"$GODOT" --path . --rendering-driver opengl3 --script res://tools/map_restore/capture_maps.gd -- --output=/workspace/remake-captures
"$GODOT" --path . --rendering-driver opengl3 --script res://tools/map_restore/capture_maps.gd -- --legacy-map-layouts --cameras=/workspace/remake-captures/captures.json --output=/workspace/legacy-captures
```

`--maps=oman_03,oman_07,oman_10`으로 변경 그룹만 다시 캡처할 수 있다. `--map=oman_01`은 실제 플레이 검사 1개 층에만 적용한다. `--legacy-map-layouts`는 비교/예전 배치 검사 옵션이며 새 격자 검증에 사용하지 않는다.

## 진행 상태와 남은 검증

- 현재 PR: https://github.com/zoog136-hash/-/pull/119 (Draft). Sol 6.1 전환 시 기존 `f7c0b3b`까지의 구현과 미커밋 진단·문서를 같은 브랜치에서 보존했다. 과거 경로에 생성된 282개 검사 산출물은 `evidence/regression-generated`에 원래 경로·SHA와 함께 옮겼으며 기존 날짜의 추적 증거는 복원했다.
- 성공 결과는 `evidence/checkpoint-logs`에 보존했다. 초기 전체 검사 `142 PASS / 15 FAIL / 3 SKIP`과 이후 대상별 수정 검사를 함께 남긴다. 이미 성공한 검사를 다시 처음부터 수행하지 않는다.
- **해결된 실패:** 검사 스크립트의 포털 코루틴이 물리 프레임 안에서 재개된 직후 아덴을 즉시 다시 로딩하던 문제를 `await process_frame`으로 해결했다. 실제 근접 포털 처리는 기존부터 deferred 전환을 사용한다. 충돌 엔진이나 actor/animation은 변경하지 않았다. 리치가 AUTO 추격 중 계속 후퇴하여 공격 관찰이 실패하던 검사는 정지한 플레이어를 상대로도 실제 AI 공격을 관찰하도록 수정했다. 공격 마커와 실제 피해 assertion은 유지했다.
- 수정된 배치 `2026101502`의 최종 실제 Main 실행은 `evidence/gameplay/runtime.json`: **10층 / 5,951 checks / failures 0 / 포털 50개 / PNG 30장**. `evidence/targeted-rechecks`에 수정 전 9층 실패와 830개 대상 재검사, 최종 전체 오만 그룹 로그를 따로 보존했다. 과거 `5841`은 구 배치 결과이며 현재 완료 근거로 사용하지 않는다.
- 제품 코드·아트 및 검증 도구 커밋은 `f0caf83`이다. PR100은 재확인 시 `53e17aee7371e0aac6eb6a7ab84ae3ff9681fb39`로 진행 중이다. 해당 브랜치를 수정·병합하지 않았으며, 새 PR100 전체와의 결합 검증은 미실시다. 제품 브랜치의 player/monster/animation 파일은 기준 main과 차이가 없다.
- 진단용 `/workspace/twilight-baseline`은 `dc787a9`에 그대로 있고 추적 출력용 미커밋 코드가 있다. 이 워크트리의 actor/animation 진단 편집을 제품 브랜치로 복사하거나 checkout/reset으로 지우지 않는다. 제품 브랜치의 PR100 애니메이션 파일은 수정하지 않았다.
- 10층 모두 개별 원본 격자와 해시가 있다. 25개 게임 ID는 그대로이며 추가 1,000개 맵을 게임 메뉴에 등록하지 않는다.
- 오만 위치/보스방은 provisional. 현재 M 기준점·원본 S32·층별 구조물 의미/아트가 미확정이다. 25개 완료 집계는 0이다.
- 수정 전 실패한 검사 로그와 수정 후의 로그를 구분한다. 합성 CI fixture 검사는 원본 이미지 통합 검증이 아니다.
- 기존 폴리곤 맵의 도로·배치·등록 bounds를 전제하는 검사는 기존 배치 모드에서 보존한다. 새 A3 격자의 실물 이동/충돌/전투/포털 검증은 `remake_source_runtime_test`와 `hunting_paths_test`의 원본 격자 분기로 수행한다. 예전 맵 검사 PASS를 새 아트 완료로 계산하지 않는다.
- `tools/test_project.py`는 기존 기하 구조를 고정해서 검사하는 7개 테스트에만 `--legacy-map-layouts`를 전달하며 로그/summary에 `validation_scopes`를 남긴다. 기존 테스트의 assertion은 유지한다. 일반 게임플레이·몬스터·저장·UI·새 A3 검사는 설치된 실제 맵을 사용한다. A3 팩이 없으면 새 격자 플레이 검사는 SKIP이며 전체 원본 검증 PASS가 아니다.
- 전체 테스트 도구는 과거 docs/evidence 경로에 화면을 덮어쓴다. 실행 결과를 새 날짜 증거 폴더에 복사한 뒤 과거 추적 증거는 복원한다. 사용자 변경 파일에 일괄 restore/clean을 사용하지 않는다.
- Android 장치/실행 환경, 대형 A3 아덴 장거리 이동, Windows GPU 성능, 전체 원작 시각 비교는 NOT_RUN/UNVERIFIED다.
- 모든 맵의 12가지 완료 조건이 충족되기 전 Draft 해제·자동 병합·정확 복원 완료 표시를 하지 않는다.
