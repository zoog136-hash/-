# 포탈·지역 속성 실행 연결

927표 원본 대장의 `LandAttribute`(530), `LandAttributeType`(531), `LandTimeLimit`(539)·`LandTimeLimitGroup`(540), `Portal`(729), `Territories`(903)를 확인했다. 대장의 L5는 검색 당시의 조회 근거 분류다. 지금 게임에는 간접 호출 경로가 있다.

- Twm `pack-63fb1355`의 `twilight523-addon-world-links.zip`에서 CRC와 `world_links/manifest.json` SHA-256 고정값 `2de8cebb…ffa90`이 일치했다. `Source523Pack.selections/apply`가 설치 팩 경로를 정의 선택으로 저장하고, `World._prepare_current523_source_definitions_from_launch`가 검증된 provider를 지도 컨트롤러에 연결한다.
- `Current523AdenPlayController.portal_evidence`는 현재 Land와 정확한 AssetPath로 포탈을 열거한다. `portal_context`는 같은 provider에서 현재 캐릭터 상태로 원본 위치·도착 영역 및 양쪽 Land의 제한을 평가한다. 설정 화면 사용 버튼은 World를 거쳐 `use_source_portal`로 연결된다. Linux에서 실제 Main 노드의 World에 팩을 바인딩하고 Land/AssetPath만 설정한 상태로 컨트롤러까지 확인했다. Aden 목록 93개, 350 목적 좌표 (34275, 32222), 잘못된 별칭 4/ 거부가 기대와 일치했다. 원본 지도에서 캐릭터를 이동시키는 테스트는 수행하지 않았다. 원본 자동 발동, 트리거 지형, Android UI 이동은 이 검증 범위 밖이다.
- 실제 Aden Land 데이터는 포탈 93개, 생성 Territory 관계 1,343개, 클래스 뷰 3,105개를 반환했다. 클래스 뷰가 미해결인 팩 142개도 그대로 보존된다. 예를 들어 팩 172312에는 클래스 뷰가 없고 172402는 독립된 정의를 갖는다. 이 차이만으로 생성 인원·좌표·활성 시간을 추정하지 않는다.

## 조회 최적화

기존 provider는 포탈 양쪽 제한을 확인할 때마다 각각 `LandAttribute` 전체 8,903행을 복제한 뒤 Land로 거른다. 변경 후 검증된 Land 소유자가 최초 호출에서 자기 행의 참조를 선택하고, 다음 평가부터 해당 행만 복제한다. 별칭 검증, 원본 행 순서와 중복, 호출자 변경 격리, 파일 검증 경계와 보유 Land 상한은 유지된다. 팩을 다시 열 때 범위 목록도 초기화한다. Windows 복원 EXE의 소유자별 리소스 재사용과 Android 보고서의 요청·검증·소비 분리는 설계 참고이며, 두 원본에서 이 표의 캐시를 확인한 것은 아니다.

Godot 4.7.2 Linux headless에서 실제 팩으로 측정했다. 포탈 1101·350·18111 각각 두 정책에서 워밍업 후 전후 50회, 전후 실행 순서를 번갈아 측정했다. 조회 전체 중앙값은 **26.11–29.72ms에서 3.99–4.47ms** 범위로 줄었다. 3개 출발 Land에서 호출당 복사하는 행은 각각 2·87·4개다. 도착 Land도 별도로 범위를 적용했다. Aden 93개 포탈 × 정책 2개, 총 186개 컨텍스트가 기준과 완전히 동일했다. 같은 Main/World 하네스에서 기본 정책의 93개 목록을 통째로 조회하는 CPU 경로는 워밍업 후 전후 7회씩, 실행 순서를 번갈아 측정한 중앙값이 **4.934초에서 1.141초**였다. 모든 목록 결과가 일치했다.

- Godot world-links/게임 필드 검사 48개, 실제 팩 provider 검사 27개, 별도 지도 시간 충전 20개, 이동 트랜잭션 fixture 69개, 리소스 설치 설정 28개 통과. 기존 실패 검사는 두 정책을 명시해 실행했다. 원본 조건 모드에서는 시간 풀 소유자가 없으면 보류하고, 현재 기본 상시 오픈 모드에서는 시간 제한을 면제 내역에 기록하되 다른 제한을 유지하는지 확인한다.
- Linux에서 포탈 컨텍스트 조회만 측정했다. 전체 UI 프레임, 원본 자동 발동 및 Android 실기기 시간은 미검증이다.
