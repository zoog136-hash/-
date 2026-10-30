# 이전 partial locomotion CI 실패 추적

원격 run 40173677539 / HEAD `637e9e1256093c40ac800ea6289924cc9e9cf320`의
6개 job 모두 `Three-speed native playback and real keyboard movement` 단계에서
실패했다. doguri-N 원격 로그는 `PR100_GAMEPLAY_FAIL: real map clearing exists`,
18 checks, player/monster/boss rows 모두 0이다. 그 HEAD 이후 PR122 d76a098b까지
변경 파일은 4개의 다른 workflow뿐이다. 테스트나 게임 수정 근거는 없다.

코드 순서상 이 실패는 `find_clearing()` 직후, `preview_frames()` 및 후보
프로필 주입 이전이다. 따라서 정확한 분류는 **공간 확보 fixture gate 실패 / 후보
애니메이션 연결·재생 NOT_EVALUATED**이다. 실제 애니메이션 결함으로 확정하지도,
문제가 고쳐졌다고 승인하지도 않는다. 기존 assertion/반경/LOS/발 조건은 유지한다.

## 동일한 맵/조건의 대표 로컬 재현

`pr122_approval_clearing_probe.gd`는 실제 Main에 사신/도구리 변신과 기존 무기를
설정하고 원본 `find_clearing()` 함수를 그대로 호출한다. 기존 맵/데이터를 수정하지
않으며 후보를 주입하지 않는다. 원래의 150px 8방향 LOS 및 50px 이동·4px 발 검사를
재사용했다. 4.7.2, 원본 PNG 번들, Xvfb OpenGL에서:

- field: `res://scripts/maps/native_png_field.gd`.
- 원본 find_clearing: PASS; 동일 helper에서 도달 가능한 위치를 찾음.
- 조사 표본 4658셀, walkable 4658, point_clear 4614, non-safe 4658.
- 150px 전 방향 조건 및 50px 발 이동 조건 동시 만족 1523셀.
- 후보 주입 0, 품질 승인 0, 엔진 오류 0.

이 결과는 **CI 실패가 로컬에서 재현되지 않았다는 것**이다. 이전 CI 실패의 근본
원인은 아직 확정하지 못했다. 특히 CI의 native import 환경과 raw-byte 로컬 로더의
차이가 남으므로 전체 6사례 CI 성공으로 바꾸지 않는다. 기존 실행은 그대로 보존하고
중복 전체 CI나 6-case workflow를 실행하지 않았다. 다음 재개 시 해당 CI 환경에서
대표 doguri-N 하나의 field 종류, spawn 후보 수, 반경 조건, 실제 입력 이후 결과를
수집해야 한다. 맵·안전 구역·문턱을 바꾸어 통과시키지 않는다.

## 별도 승인 runner에서 확인·수정한 fixture 누락

조사 중 승인 runner의 격리 프로젝트에서 `external_map_packs` symlink 누락을
확인했다. 기존 보스 Main 검사는 실제 Main/기본 보스 프로필을 사용했지만,
번들 PNG 맵 대신 기존 RemakePlayableField로 실행되었다. 이 결과를 원래 PNG 맵
검증으로 인용하면 안 된다. runner에 실제 디렉터리를 연결하고 Main harness에
번들 설치 및 NativePngField 여부 assertion을 추가했다. **게임 맵은 변경하지 않았다.**

수정 후 보스 6종만 해당 맵에서 다시 확인했다. 원본 전체 리소스 스캔 및 전체 CI는
반복하지 않았다. 결과: 288/288 요청, 48/48 공격 마커, 41760틱 anchor/충돌/캔버스
검사, 플레이어 상태 보존, 엔진 오류 0. `main-six-bosses-native-pack/report.json`과
원본 대표 캡처 6장에 저장했다. 이것도 최종 해부학/전 방향 원화 승인과 다르다.

진단 최초 `clearing-probe`는 raw font loader를 typed preload 이후에 설치해
컴파일 오류가 발생했다. 그 보고서의 arena PASS는 **무효**이고 판단 근거에서 제외한다.
bootstrap을 먼저 설치한 `clearing-probe-loader-fixed`는 오류 0이나 맵 번들 누락 상태여서
CI 재현 근거로 쓰지 않는다. 최종 `clearing-probe-native-pack`만 해당 맵의 재현 결과다.
각 실패/조건 변경을 기록했으며 같은 조건으로 실패를 반복하지 않았다.

후속 변경은 테스트·격리 runner·증거뿐이다. 기존 제작물과 PR122는 수정하지 않았다.
전체 Godot Validate run 40187062534는 이전 제출 SHA 9ac7b16b에서 1회 실행한 것이며,
이 후속 SHA의 전체 CI 성공으로 승격하지 않는다. 최종 원격 상태는 PR 본문에 기록한다.
