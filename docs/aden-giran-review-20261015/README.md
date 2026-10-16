# PR #120 — 기란 첫 검수 초안

**아덴 월드 최종 완성 상태가 아니다. 기란 외형 일치 판정은 FAIL이며,
다음 지역 제작과 main 병합은 진행하지 않는다.**

기준은 기존 PR #120 `f707eccb215cfa580875ad1df806da13ba39b79f`,
브랜치는 `feature/aden-source-topology-20261015`다. 확인한 main은
`e2119c37293a783e93b421ee0055d1318271b071`이며 원본 PR의 기준과 같다.
PR #121의 신규 14개 맵 작업은 하지 않았다.

## 실제로 바뀐 것

- 원본 아덴 팩 5개 파일, 전체 2048×1536 격자, 768청크, 원본 이동 마스크를
  바이트 변경 없이 보존했다. 기존 NPC 9·포털 3·사냥/보스 구역 18도 유지했다.
- 기란의 소스 셀 `[928,672,128,192]`에만 새 텍스처와 오브젝트를 표시한다.
  절대 좌표로는 `[33376,32736]`부터 `[33503,32927]`까지다. 전체 지형을
  잘라낸 것이 아니라 해당 구역의 시각 레이어만 별도로 추가한 것이다.
- 독자 생성 PNG 아틀라스 2개와 별도 시각 데이터, 전용 청크 스크립트를
  추가했다. 기존 아덴 그래픽 파일·기존 맵 정의·오만 아트는 보존했다.
- S32의 3611–3614 바닥 ID가 놓인 광장 주변 띠 모양 패치를 읽어 화단 재질의
  후보로 연결했다. **배치 패치는 관찰값이고, 해당 ID의 원본 그림은 미확보다.**
- 원본 통행 데이터의 막힌 영역을 바탕으로 71개 시각 오브젝트를 배치했다.
  29개 건물·33개 나무·기념주 1·식재 2·장식 5·열린 문 1이다. 이것은
  식별된 원작 오브젝트 71개라는 뜻이 아니다. 연결 성분/화면 참조를 사용한
  해석이며, 건물 이름·외형·원작 좌표 일치는 아직 검수 대상이다.
- 공통 `RemakeSourceRenderer`에는 기란 청크를 선택하는 분기만 추가했다.
  다른 아덴 구역과 오만은 기존 청크를 사용한다. 이동·충돌·배치 시스템을
  새 폴리곤 내비게이션으로 교체하지 않았다.

실제 엔진에서 기존 정상 팩을 로드하지 못하던 문제도 수정했다.
Godot JSON 숫자는 float인데 origin/dimensions/basis 배열을 int 배열과
직접 비교해 정상 데이터를 거절했다. 숫자별 유한 정수/정확한 값 검증으로
수정했고, 소수 좌표·잘못된 크기·basis·해시를 계속 거절하는 검사를 추가했다.
원본 팩을 이 오류에 맞춰 재생성하지 않았다.

## 제출 화면과 원작 비교

[원작과 신규 화면을 나란히 보는 비교 문서](COMPARISON.md) ([16:9 HTML 보기](comparison.html)),
[건물·도로·장식 차이와 원작 조사](REFERENCES_AND_DIFFERENCES.md)를 함께 본다.
원작 공개 화면은 출처 URL로 연결하며 게임 아틀라스에 넣지 않았다.
이 세션에서 별도로 생성해 제출한 비교 PNG는 화면을 비율 유지로 나란히
배치한 문서 이미지다. 1280×720 출력 크기만 같으며, 원작 카메라의 좌표와
줌을 정확하게 정합했다는 증거는 없다. **정확한 동일 카메라 검사는 NOT_RUN**이다.

| 실제 Godot 화면 | 용도 |
| --- | --- |
| [기란 광장](evidence/giran-plaza-play.png) | 캐릭터·기념주·화단·상인 |
| [건물 거리](evidence/giran-buildings-play.png) | 지붕·벽·출입구·가림 |
| [북쪽 접근로](evidence/giran-north-gate-play.png) | 열린 문 후보와 기존 통행 경계 |
| [남쪽 주변 필드](evidence/giran-south-field-play.png) | 잔디·흙·나무, 재질 해석의 한계 |
| [동일 TWILIGHT 카메라의 원본 충돌 격자](evidence/giran-source-collision.png) | 원본 통행 셀과의 대조 |

PNG는 **Godot 4.7.2 official / X11 / OpenGL Compatibility / Mesa llvmpipe**에서
실제 `Main.tscn`을 실행해 저장했다. 이미지 생성 도구로 만든 조감도나
이전 PR의 PNG를 엔진 실행 증거로 사용하지 않았다. 카메라/위치/해상도는
[실행 JSON](evidence/runtime.json)에 있다.

## 현재 판정

| 항목 | 판정 | 범위 |
| --- | --- | --- |
| 전체 원본 격자·팩 보존 | PASS | 기준 커밋과 해시 대조; 별도 보존 감사 |
| A3 파일 SHA·전체 ZIP CRC | PASS | 159,837,941 bytes, 7,472 entries |
| 기란 S32 읽기/왕복 | PASS | 12세그먼트; 바닥/배치 참조 분석 |
| 실제 Main·이동·충돌·NPC UI/거래·창고·포털·저장 | PASS | 최종 전용 스크립트 45검사, 실패 0 |
| 기존 몬스터/보스 피해·사망·재출현 경로 | PASS | 기존 배치 구역, 테스트에서 타이머/마감 시각 진행 |
| 원작과 같은 기란 건물·재질·장식 | FAIL | 아래 차이 보고서, 사용자 승인 없음 |
| 최신 M의 기란 필드 스폰/보스 구역 동일성 | NOT_RUN | 기존 TWILIGHT 구역 유지; 기란에 새 스폰을 발명하지 않음 |
| 실제 조작으로 장시간 보스 전투 | NOT_RUN | 피해 콜백/재출현 검사가 수동 전투를 대신하지 않음 |
| 원작 카메라 정확한 정합 | NOT_RUN | 원작 좌표/배율 메타데이터 없음 |
| Android 실기기 기능·GPU 성능 | NOT_RUN | 연결 기기, adb, 에뮬레이터, Android SDK 없음 |
| Android형 터치 입력 | PASS | Linux에서 1280×720·960×540 이벤트 검사; 실기기 검사가 아님 |
| 기존 기능 회귀 | FAIL | 기존 49개 검사: 41 PASS, 8 FAIL; 선택한 나머지 110개 NOT_RUN |

최초 팩 로드 실패, 첫 충돌 검사 실패, 중간 시각 데이터 해시 실패 로그를
보존했다. 첫 충돌 검사의 물리 질의는 청크 교체 후 서버 동기화 전에
실행되었고, 이동 거리를 한 축으로만 제한한 검사는 벽 옆 미끄러짐을
실패로 판정했다. 후속 검사에서는 물리 서버 동기화를 기다리고 32틱의
실제 이동 셀을 모두 확인했다. [독립 물리 경계 질의](evidence/physics-boundary-probe.log)는
원본 경계 선분 1개와 그 위치의 실제 ray hit를 확인한다. 원래 FAIL 기록을
삭제하거나 PASS로 덮어쓰지 않았다.

기존 회귀의 실패 8개는 `aden_building_test`, `aden_courtyard_test`,
`aden_shoreline_test`, `aden_terrain_polish_test`, `animation_restore_test`,
`field_world_test`, `monster_world_test`, `remake_world_lifecycle_test`다.
고정된 과거 지형/저장 발 위치, 아덴 폭젠까지의 긴 길찾기와 radius=0의
구역 해석, 공격 콜백 수에 관한 실패가 포함된다. **전부 기존 테스트의
실제 FAIL로 유지한다.** 기존 테스트의 assertion이나 PR #100 파일을
수정하여 통과시키지 않았다. 최초 광범위 실행에서 같은 과거 좌표를 쓰는
검사의 실패가 이어져 장시간 실행을 중단했고, 미완료였던 바닥 드랍 종합
검사와 남은 항목은 NOT_RUN으로 남겼다. 이후 상점/포털/저장/창고/몬스터
등 미실행 관련 검사 8개를 따로 실행해 6 PASS, 2 FAIL을 기록했다.
[전체 항목과 중단 이유](REGRESSIONS.json), [개별 로그](evidence/regressions/),
[완료 조건별 판정](VALIDATION.json)을 참조한다.

## 재현

실제 사용자 저장 데이터와 다른 디렉터리를 사용한다. Godot 4.7.2가 필요하다.
기존 원본 격자를 다시 생성하거나 다른 아덴/오만 팩을 설치할 필요가 없다.

```bash
python3 tools/check_resource_integrity.py --root .
XDG_DATA_HOME=/tmp/giran-import "$GODOT" --headless --path . --editor --import
XDG_DATA_HOME=/tmp/giran-save "$GODOT" --path . --rendering-driver opengl3 \
  --audio-driver Dummy --script res://tests/aden_giran_review_test.gd -- \
  --output=/tmp/giran-evidence --capture
```

Linux에 디스플레이가 없으면 Xvfb 등을 사용한다. 헤드리스 이미지로
대체하지 않는다. CI 재현은 `.github/workflows/aden-giran-review.yml`이다.
일반 플레이에서는 기존 기란 이동석으로 이동하면 새 시각 레이어가 나타난다.

`build_giran_review.py`는 S32를 분석해 **시각 해석 데이터만** 새 디렉터리에
생성하는 보조 도구다. 기존 출력이 있으면 거절한다. 원본 내비게이션을
만들거나 갱신하지 않는다. 검증된 팩 5개를 다시 생성하는 명령은 필요 없다.

## 다음 검수 전 남은 작업

1. 최신 M의 기란 건물/성벽/문/주변 필드에 대한 더 정확한 화면·좌표 대응.
2. S32 ID의 실제 이미지 대응 또는 대응이 확인된 독자 아트 교체.
3. 건물 크기·지붕·기념주·화단의 원작 비율/위치 보완과 충돌 외형 대조.
4. 정확한 카메라 정합, Android 실기기/성능, 기존 회귀 FAIL 정리.

사용자 승인 전 다른 지역의 그래픽 제작은 확대하지 않는다. main 병합은
별도의 명시적 사용자 승인이 있을 때만 검토한다.
