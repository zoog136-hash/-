# TWILIGHT 전 지역 충돌 통로·자연 경계 적용 (2026-10-12)

PR #84의 `feature/twilight-reference-expansion-20261011` 최신 저장점
`bab7ba5aa1a074bc1d37c6b2500e2c0fcd11bc91`에서 이어 작업했다.
실제 기존 25개 맵 전체에 기존 바위·나무·벽·기둥을 배치하여 충돌 통로를
만들었다. 바닥 텍스처와 셰이더 파일은 변경하지 않았다.

## 요청한 세 가지 변경

1. **사냥터의 실제 통로:** 마을 주변 숲에는 수목·바위, 오만과 신념에는
   벽·열주, 알비노에는 굽은 암석·수정 군집으로 갈림길과 우회 통로를 만들었다.
   에스카로스 5구역은 기존 이동 경로 양쪽에 긴 암벽 군집과 측면 출입구를
   추가했다. 객체 발밑의 실제 충돌체가 AStar와 CharacterBody2D 양쪽을 막는다.
2. **경계의 형상:** 기존 방과 통로의 연결을 보존하면서 사각형 벽 덮개를
   굴곡 있는 바닥 외곽·동굴 벽으로 바꾸었다. 바닥을 같은 외곽으로 잘라
   경계 밖에 방 바닥이 삐져나오지 않게 했다. 바위와 벽은 해당 외곽을 따라
   배치했다. 아덴의 긴 직선 절벽 4개는 굽은 암릉과 도로가 통과하는 틈으로
   바꾸었고, 오만 1층의 기존 참고 지도 외곽과 두 구덩이는 보존했다.
3. **나머지 전체 맵:** 아덴 1, 오만 10, 신념 4, 지배 정상 1,
   에스카로스 5, 알비노 4개 맵 모두에 적용했다. 기존 층별 연결 그래프,
   맵 ID, 크기, 모든 기존 객체와 NPC·포털·스폰·귀환 좌표를 보존했다.

## 실행 증거

- Godot **4.7.2**, 실제 Main 씬, Linux Compatibility/OpenGL의 llvmpipe.
- `hunting_paths_test.gd`: **19,139 검사 통과 / 0 실패**. 25개 맵 각각에서
  수동 직진이 벽을 통과하지 못하고 실제 플레이어가 반대편까지 우회했다.
  290개 장애물 우회 경로를 확인했고 실제 몸체의 이동 궤적을 기록했다.
- `hunting_navigation_cache_test.gd`: **225 검사 통과 / 0 실패**.
  25개 맵의 모든 충돌 셀·도달 셀·스폰 셀을 캐시 없는 계산과 비교했다.
  인스턴스 사이 AStar/스폰 목록 변경이 전파되지 않으며 지형 수정 시 캐시를
  무효화한다. 캐시는 별도 카탈로그와 SHA-256으로 검증하고 없으면 재계산한다.
- `verify_hunting_navigation_pack.gd`: **25개 캐시의 실제 PCK 생성·마운트·읽기
  통과**. 내보내기 포함 필터에 `.nav`를 추가했다. Android/Windows 실기기
  실행은 이 검사 범위에 포함되지 않는다. 이번 전후 화면·검증 문서는
  게임 내보내기에서 제외하여 실행 패키지에 불필요한 화면 파일을 추가하지 않는다.
- [전후 150장 매니페스트](evidence/manifest.json): 25개 맵 × 전체/사냥터/경계
  3시점 × 전/후. 실제 카메라 중심과 실제 zoom까지 동일함을 검사했다.
  변경 전은 부모 커밋의 분리된 worktree에서 실제 실행했다.
- [이동·충돌 결과 및 실제 궤적](evidence/validation.json),
  [25개 사냥터 전후 Contact Sheet](evidence/hunting-all-25-before-after.jpg),
  [전체 지도 화면](evidence/after-whole-all-25.jpg),
  [경계 화면](evidence/after-boundary-all-25.jpg).
- `capture_hunting_maps.gd`: 25개 맵의 실제 HUD/미니맵과 상세 지도 **50장**.
  [UI 캡처 목록](evidence/ui/captures.json).
- 전체 프로젝트 회귀 검사의 최종 결과와 Git 저장 SHA는
  [CHECKPOINT](CHECKPOINT.md)에 기록한다. 상세 로그는 `evidence/validation-logs/`.
- 723개 시트 / 41,442 프레임 / 233,420,026 bytes의 기존 무결성 검사 통과.
  기존 맵 그래픽·효과·셰이더 28개는 부모 커밋의 실제 바이트와 일치한다.
  새 그래픽 파일은 **0개**다. 기존 객체 배열과 주요 좌표 배열의 보존도
  부모 커밋과 실제 데이터 비교로 검사했다.

## 전 지역 비교

| 실제 맵 ID | 배치·경계 방식 | 같은 카메라 비교 | 충돌·실제 이동 궤적 |
|---|---|---|---|
| aden_world | 수목 통로·암릉·도로 출입 틈 | [사냥터](evidence/pairs/aden_world-hunting.jpg) · [경계](evidence/pairs/aden_world-boundary.jpg) | [지도](evidence/collision/aden_world.svg) |
| oman_01 | 기존 참고 외곽 유지·내부 폐벽 통로 | [사냥터](evidence/pairs/oman_01-hunting.jpg) · [경계](evidence/pairs/oman_01-boundary.jpg) | [지도](evidence/collision/oman_01.svg) |
| oman_02 | 고유 연결 유지·벽 우회로 | [사냥터](evidence/pairs/oman_02-hunting.jpg) · [경계](evidence/pairs/oman_02-boundary.jpg) | [지도](evidence/collision/oman_02.svg) |
| oman_03 | 고유 연결 유지·벽 우회로 | [사냥터](evidence/pairs/oman_03-hunting.jpg) · [경계](evidence/pairs/oman_03-boundary.jpg) | [지도](evidence/collision/oman_03.svg) |
| oman_04 | 고유 연결 유지·벽 우회로 | [사냥터](evidence/pairs/oman_04-hunting.jpg) · [경계](evidence/pairs/oman_04-boundary.jpg) | [지도](evidence/collision/oman_04.svg) |
| oman_05 | 고유 연결 유지·벽 우회로 | [사냥터](evidence/pairs/oman_05-hunting.jpg) · [경계](evidence/pairs/oman_05-boundary.jpg) | [지도](evidence/collision/oman_05.svg) |
| oman_06 | 고유 연결 유지·벽 우회로 | [사냥터](evidence/pairs/oman_06-hunting.jpg) · [경계](evidence/pairs/oman_06-boundary.jpg) | [지도](evidence/collision/oman_06.svg) |
| oman_07 | 고유 연결 유지·벽 우회로 | [사냥터](evidence/pairs/oman_07-hunting.jpg) · [경계](evidence/pairs/oman_07-boundary.jpg) | [지도](evidence/collision/oman_07.svg) |
| oman_08 | 고유 연결 유지·벽 우회로 | [사냥터](evidence/pairs/oman_08-hunting.jpg) · [경계](evidence/pairs/oman_08-boundary.jpg) | [지도](evidence/collision/oman_08.svg) |
| oman_09 | 고유 연결 유지·벽 우회로 | [사냥터](evidence/pairs/oman_09-hunting.jpg) · [경계](evidence/pairs/oman_09-boundary.jpg) | [지도](evidence/collision/oman_09.svg) |
| oman_10 | 고유 연결 유지·벽 우회로 | [사냥터](evidence/pairs/oman_10-hunting.jpg) · [경계](evidence/pairs/oman_10-boundary.jpg) | [지도](evidence/collision/oman_10.svg) |
| domination_summit | 성문·기존 성벽 유지·내부 우회벽 | [사냥터](evidence/pairs/domination_summit-hunting.jpg) · [경계](evidence/pairs/domination_summit-boundary.jpg) | [지도](evidence/collision/domination_summit.svg) |
| escaros_01 | 암벽 협곡·측면 출입구 | [사냥터](evidence/pairs/escaros_01-hunting.jpg) · [경계](evidence/pairs/escaros_01-boundary.jpg) | [지도](evidence/collision/escaros_01.svg) |
| escaros_02 | 습지 통로·다리·암벽 군집 | [사냥터](evidence/pairs/escaros_02-hunting.jpg) · [경계](evidence/pairs/escaros_02-boundary.jpg) | [지도](evidence/collision/escaros_02.svg) |
| escaros_03 | 기존 전초기지 성벽·암벽 통로 | [사냥터](evidence/pairs/escaros_03-hunting.jpg) · [경계](evidence/pairs/escaros_03-boundary.jpg) | [지도](evidence/collision/escaros_03.svg) |
| escaros_04 | 기존 수역·다리 유지·암벽 통로 | [사냥터](evidence/pairs/escaros_04-hunting.jpg) · [경계](evidence/pairs/escaros_04-boundary.jpg) | [지도](evidence/collision/escaros_04.svg) |
| escaros_05 | 기존 수역·다리 유지·암벽 통로 | [사냥터](evidence/pairs/escaros_05-hunting.jpg) · [경계](evidence/pairs/escaros_05-boundary.jpg) | [지도](evidence/collision/escaros_05.svg) |
| albino_01 | 둥근 동굴 외곽·암석·수정 통로 | [사냥터](evidence/pairs/albino_01-hunting.jpg) · [경계](evidence/pairs/albino_01-boundary.jpg) | [지도](evidence/collision/albino_01.svg) |
| albino_02 | 둥근 동굴 외곽·암석·수정 통로 | [사냥터](evidence/pairs/albino_02-hunting.jpg) · [경계](evidence/pairs/albino_02-boundary.jpg) | [지도](evidence/collision/albino_02.svg) |
| albino_03 | 둥근 동굴 외곽·암석·수정 통로 | [사냥터](evidence/pairs/albino_03-hunting.jpg) · [경계](evidence/pairs/albino_03-boundary.jpg) | [지도](evidence/collision/albino_03.svg) |
| albino_04 | 둥근 동굴 외곽·암석·수정 통로 | [사냥터](evidence/pairs/albino_04-hunting.jpg) · [경계](evidence/pairs/albino_04-boundary.jpg) | [지도](evidence/collision/albino_04.svg) |
| faith_01 | 열주·폐벽 사이 갈림길 | [사냥터](evidence/pairs/faith_01-hunting.jpg) · [경계](evidence/pairs/faith_01-boundary.jpg) | [지도](evidence/collision/faith_01.svg) |
| faith_02 | 열주·폐벽 사이 갈림길 | [사냥터](evidence/pairs/faith_02-hunting.jpg) · [경계](evidence/pairs/faith_02-boundary.jpg) | [지도](evidence/collision/faith_02.svg) |
| faith_03 | 열주·폐벽 사이 갈림길 | [사냥터](evidence/pairs/faith_03-hunting.jpg) · [경계](evidence/pairs/faith_03-boundary.jpg) | [지도](evidence/collision/faith_03.svg) |
| faith_04 | 열주·폐벽 사이 갈림길 | [사냥터](evidence/pairs/faith_04-hunting.jpg) · [경계](evidence/pairs/faith_04-boundary.jpg) | [지도](evidence/collision/faith_04.svg) |

충돌 지도: 금색은 새 사냥 통로의 실제 객체 발밑, 어두운 색은 기존 장애물과
외곽 벽, 청록은 포털이다. 점선은 막힌 직선 경로이며 밝은 선은 실제
CharacterBody2D 이동 기록이다. 원과 선은 이 검증 그림의 기호다.

## 자료의 정확도와 재개 지점

- 아덴의 상대 지리: [2019 공개 월드 지도](https://games.app-liv.jp/archives/397568).
- 오만 1층 기존 외곽과 폐벽 공간 참고:
  [2018 전체 층 지도](https://www.gamechosun.co.kr/webzine/article/view.php?no=145842).
- 에스카로스의 길을 따라 이어진 암벽 군집 참고:
  [공개 실제 지도·사냥 동선](https://www.inven.co.kr/board/powerbbs.php?come_idx=5056&l=19989&vtype=pc).
- 신념·알비노는 저장소에 이미 있는 `faith1.png`, `faith3.png`, `faith4.png`,
  `albino12.png`, `albino3.png` 지도 화면을 참고했다.
- 지배: [공식 일본 가이드](https://lineagem-jp.com/guides/lm/guides/dungeon_TowerofDomination).
  이 가이드는 입장·정상 안내 근거이며 현재 한국 서버의 내부 배치를 증명하지 않는다.

현재 배치는 **기존 TWILIGHT 구조에서 참고 화면의 통로 방식을 적용한 지역별
근사 배치**다. 오만 2~10층·신념 1~4층·지배 정상 등의 기존 전체 구조와
원작의 정확한 객체·보스 좌표는 추가 검증 대상이다. 정확한 원작 좌표,
전체 원본 타일 복원, 상용 게임 그래픽 동등성, 실기기 성능을 완료로 계산하지 않는다.
상용 원본 그래픽을 새로 복제하거나 편입하지 않았다.

다음 작업은 최신 원격 HEAD를 확인하고 실제 지역별 참고 지도에 맞춰 기존
근사 구조의 차이를 줄이는 것이다. `hunting_paths.version=1`과 각 보강 버전은
중복 배치를 막는다. 생성 도구를 다시 처음부터 돌리지 말고 해당 지역의
형상·통로와 짝지어진 충돌 데이터만 수정하여 연결·이동 검사를 이어간다.
바뀐 이동 데이터의 캐시는 `tools/bake_hunting_navigation.gd`로 재생성할 수 있다.
밀집 리젠 구역을 침범한 이번 수목 통로 9개는 비우고 전체 밀집 구역을
새 장애물의 보호 영역으로 지정했다. 스폰 좌표·몬스터 수·리젠 규칙은 보존했으며
318종/25맵/4밀집 구역/27보스 구역 검사 9,323 항목을 다시 통과했다.

작업 중 발생했던 오만 출구 폐쇄, 초기 압축 방식, 반올림 저장, 비교용 worktree의
누락된 font import 문제는 해결했고 최초 실패 로그도 별도로 보존한다.
