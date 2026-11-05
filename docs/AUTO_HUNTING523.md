# 자동사냥 지역 선택과 같은 지도 이동

원본 규칙의80개 메뉴·87개 착지를 기존 자동사냥 창에 연결한다.
사냥 영역과 착지 영역은 구분하고, 영역ID0은 미지정 센티널로 보존한다.
원본 비용과 명시된 최소 레벨을 사용하며 추천 레벨을 입장 조건으로 바꾸지 않는다.

현재 아덴과 용의 계곡 던전5층의 같은 활성 지도 안에서 이동할 수 있다.
좌표 대응과 셀 선택은 TWILIGHT 자체 정책이다. M 원작의 좌표·충돌·운영 조건 동등성은 검증하지 않았다.
다른 지도 자동 진입과 아직 연결하지 않은 Land는 차단한다.

메뉴 → 자동사냥에서 자체 이동을 켜고 지역을 선택한다.
끝 셀 포함/제외, 중앙 우선/좌표 순서, Gem 잔액 연결, 입장점 주변 허용을 설정할 수 있다.
Gem과 입장점 옵션의 기본은 꺼짐이다. 지형·몸체·NPC·포탈·몬스터 및 저장 경로 검사는 유지한다.
이동 버튼은 조건을 다시 확인하고 목적지와 비용을 함께 원자적으로 저장한 뒤 실제 상태를 반영한다.
실패와 중복 요청은 위치·재화·아이템·저장 바이트를 보존한다.

원본 Gem은 CurrencyID4이며 한국어 이름은 다이아다.
기존 인벤토리 다이아를 잔액으로 쓰는 동작은 별도로 표시한 TWILIGHT 정책이다.
확인된 원본 금액을 소모하고 아데나 환산이나 재화 지급은 하지 않는다.

## 설치와 재현

코드와 리소스팩은 별도로 설치한다. 게임이 읽는 파일은 `auto_hunting523.json`이다.
설치한 규칙팩과 기존 게임 지도팩의 디렉터리를 지정하고 게임을 다시 시작한다.

```sh
python3 tools/build_auto_hunting523.py --source-zip "$SOURCE523_ZIP" --output "$AUTO_HUNT_PACK_DIR"
TWILIGHT_SOURCE_MAP_PACK="${SOURCE_MAP_PACK_DIR:?}" TWILIGHT_AUTO_HUNT523_DIR="${AUTO_HUNT_PACK_DIR:?}" godot --path .
```

규칙팩은 게임 인자 `-- --auto-hunt523-dir="$AUTO_HUNT_PACK_DIR"`으로도 지정할 수 있다.
실행 로더는 규칙팩의 크기와 해시를 확인한다. 설치나 보관만으로 실행 중 게임의 입력이 바뀌지는 않는다.

검사는 Godot4.7.2와 별도의 빈 시험 프로필에서 실행한다.

```sh
XDG_DATA_HOME="${TEST_PROFILE_DIR:?}" TWILIGHT_SOURCE_MAP_PACK="${SOURCE_MAP_PACK_DIR:?}" TWILIGHT_AUTO_HUNT523_DIR="${AUTO_HUNT_PACK_DIR:?}" godot --headless --path . --script tests/auto_hunting523_gem_main_test.gd
```

최종 같은 지도 아데나185검사·Gem79검사·Land35 OpenGL28검사가 통과했다.
각각 아데나20목적지·아덴 Gem3목적지·Land35 Gem1목적지의 실제 이동과 비용·저장을 포함한다.
렌더링 캡처 검사 포함 여부에 따라 검사 수는 달라질 수 있다.
UI 조작은 엔진 컨트롤 신호로 검증했으며 OS 포인터·터치 실기기 시험과 구분한다.

정책과 범위는 [이동 정책](auto_hunting523/LOCAL_POLICY.md),
[Gem 연결](auto_hunting523/GEM_WALLET_AND_DELIVERY.md),
[Land35와 점유 검사](auto_hunting523/SOURCE35_AND_ACTOR_CLEARANCE.md)를 따른다.
