# 같은 브랜치에서 재개하기

## 코드와 원본의 보관 상태

- 저장소: https://github.com/zoog136-hash/-
- 브랜치: `feature/twilight-map-remake-20261015`, Draft 유지, main 병합 금지.
- 공통 구현 `a5d9031`, 폭젠 반경 보존/팩 재사용 `1c73a23`, main 갱신 통합 `dc787a9`.
- 원본 자료 Drive 폴더: https://drive.google.com/drive/folders/1QTl1U45iWuJeQcI9ljuV11Le8nkXK-39
- A3 정확한 분할 ZIP 폴더: https://drive.google.com/drive/folders/1KQ42RjHIfL3eMUhietgzQ8lru4smFoW0
- 기존 manifest Drive ID: `1RwcV6ZydFhbUw6IMlUKKRmnMs8Gvv0p0`. 분할 파일과 결합 ZIP 해시를 확인하고 재사용한다.
- 이번 환경의 A3: `/workspace/sources/a3.zip`. 다음 Work에도 남는다고 가정하지 않는다.
- 원본 격자와 임시 배치가 들어간 런타임 팩은 `data/map_remake/private`이며 공개 Git에 포함하지 않는다. **팩 외부 전송은 자동 승인 검토에 거절되어 승인 대기/미전달**이다. 원본 전체 아트 납품 장부를 완료로 바꾸지 않는다.

## 복원 명령

Godot는 공식 4.7.2를 사용한다. 실제 사용자 저장 경로와 다른 `XDG_DATA_HOME`/Windows `APPDATA`를 사용한다. `GODOT`에는 해당 실행 파일 경로를 지정한다. 아래 원본 경로는 현재 환경 예시이므로 다음 세션에서 존재 여부를 먼저 확인한다.

```bash
git switch feature/twilight-map-remake-20261015
git fetch origin
python3 tools/check_resource_integrity.py --root .
"$GODOT" --headless --path . --import
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

`--maps=oman_04,oman_07,oman_10`으로 변경 그룹만 다시 캡처할 수 있다. `--map=oman_01`은 실제 플레이 검사 1개 층에만 적용한다. `--legacy-map-layouts`는 비교/예전 배치 검사 옵션이며 새 격자 검증에 사용하지 않는다.

## 진행 상태와 남은 검증

- 10층 모두 개별 원본 격자와 해시가 있다. 25개 게임 ID는 그대로이며 추가 1,000개 맵을 게임 메뉴에 등록하지 않는다.
- 오만 위치/보스방은 provisional. 현재 M 기준점·원본 S32·층별 구조물 의미/아트가 미확정이다. 25개 완료 집계는 0이다.
- 수정 전 실패한 검사 로그와 수정 후의 로그를 구분한다. 합성 CI fixture 검사는 원본 이미지 통합 검증이 아니다.
- 기존 폴리곤 맵의 도로·배치·등록 bounds를 전제하는 검사는 기존 배치 모드에서 보존한다. 새 A3 격자의 실물 이동/충돌/전투/포털 검증은 `remake_source_runtime_test`와 `hunting_paths_test`의 원본 격자 분기로 수행한다. 예전 맵 검사 PASS를 새 아트 완료로 계산하지 않는다.
- 전체 테스트 도구는 과거 docs/evidence 경로에 화면을 덮어쓴다. 실행 결과를 새 날짜 증거 폴더에 복사한 뒤 과거 추적 증거는 복원한다. 사용자 변경 파일에 일괄 restore/clean을 사용하지 않는다.
- Android 장치/실행 환경, 대형 A3 아덴 장거리 이동, Windows GPU 성능, 전체 원작 시각 비교는 NOT_RUN/UNVERIFIED다.
- 모든 맵의 12가지 완료 조건이 충족되기 전 Draft 해제·자동 병합·정확 복원 완료 표시를 하지 않는다.
