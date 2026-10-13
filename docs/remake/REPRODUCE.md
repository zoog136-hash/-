# TWILIGHT 수정본 복원/실행

전달은 기존 게임의 Git 소스와 추적 리소스다. 완성 실행파일/APK는 만들지 않았다. 원본 연구 ZIP/영상과 /workspace의 임시 캐시가 없어도 현재 게임의 대체 리소스 경로가 작동한다. clean GitHub clone의 Godot4.7.2 import, Main boot, 실제 게임 lifecycle을 검증했다. 게임 폴더 안의723개 생성 아틀라스는 기존 장부 해시로 확인한다.

## 가져오기

```sh
git clone --depth 1 --branch feature/twilight-remake-20261013 https://github.com/zoog136-hash/-.git twilight
cd twilight
git rev-parse HEAD
python3 tools/check_resource_integrity.py --root .
sha256sum -c docs/remake/evidence/SHA256SUMS
```

고정된 전달 commit은 PR/최종 전달 메시지의 SHA로 확인한다. 다른 main 또는 오래된 ZIP을 덮어쓰지 않는다. 별도 원본 pack을 설치하지 않아도 이 수정본의 현재 게임/대체 표시 경로는 실행된다. 원본 pack 요구 테스트는 미전달 오류/skip가 그대로 남는다.

## 게임 실행

공식 **Godot4.7.2**로 `project.godot`을 열고 Main(F6 또는 프로젝트 F5)을 실행한다. Compatibility를 유지한다. 기본 `godot` 명령이 다른 버전이면 정확한 실행파일 경로를 사용한다.

```sh
/path/to/Godot4.7.2 --headless --path . --import
/path/to/Godot4.7.2 --path .
```

클래스를 선택한 뒤 WASD/방향키 이동, Space 공격, T AUTO, I 인벤토리, M 메뉴, Tab 지도, F5 저장/F9 불러오기를 사용한다. 게임 진행에서 얻은 바닥 드랍은 선택/습득 또는 AUTO로 가져온다. 개발용 지급은 debug 빌드에 한정한다.

실제 사용자 세이브 검사를 할 때는 원본을 직접 로드/수정하지 않고 복사본과 별도 사용자 경로를 사용한다. Linux 검사 예:

```sh
TWILIGHT_TEST_DATA=$(mktemp -d)
mkdir -p "$TWILIGHT_TEST_DATA/data" "$TWILIGHT_TEST_DATA/config" "$TWILIGHT_TEST_DATA/cache"
XDG_DATA_HOME="$TWILIGHT_TEST_DATA/data" XDG_CONFIG_HOME="$TWILIGHT_TEST_DATA/config" XDG_CACHE_HOME="$TWILIGHT_TEST_DATA/cache" /path/to/Godot4.7.2 --headless --path . --script res://tests/remake_world_lifecycle_test.gd
```

## 같은 실제 게임 녹화/회귀

공통 Main/전투/렌더/드랍을 사용하는 검사 스크립트다. 원래 게임 DB 값을 쓰는 드레이크 체인 검사는 고정 seed/위치와 주변 population 정지만 사용한다. 성능 harness는 별도로 일정한24개체 부하를 만들기 위해 HP/ATK를 제어하며 피해/외형 코드 대체는 없다.

```sh
# 별도 새 XDG 사용자 경로를 위처럼 적용하고 실제 X 디스플레이에서 실행
/path/to/Godot4.7.2 --path . --rendering-driver opengl3 --audio-driver Dummy --script res://tests/capture_remake_play.gd --write-movie /tmp/twilight-play.avi --fixed-fps 30
```

PNG와 사건 JSON은 해당 격리 사용자 경로의 `remake-play`에 저장된다. `TWILIGHT_CAPTURE_DIR`로 증거 출력 폴더만 지정할 수 있다. 기록/임포트 동안의 wall time을 Android/일반 게임 FPS로 해석하지 않는다.

전체 시험은 이미 실행한 로그를 먼저 검토한다. 원인 변경 없이 전체 시험을 반복하지 않는다. 필요한 수정 뒤 해당 테스트만 실행한다. 현재 모든 시험이 성공하는 상태가 아니며 [실패 분류](VALIDATION.md)를 유지한다. 렌더 시험에는 실제 디스플레이 또는 Xvfb가 필요하고 headless에서 frame_post_draw를 기다리면 안 된다.

Android SDK/4.7.2 export templates/서명/실기기가 현재 환경에 없어 APK나 실기기 성공은 전달하지 않는다. 서명/플랫폼 도구를 확보한 뒤 기존 `export_presets.cfg`와 Android workflow에서 이어간다.
