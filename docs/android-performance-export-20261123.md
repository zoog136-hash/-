# Android 종료 성능 보고서

지원되는 Android 10 이상에서 게임 종료 시 파일 관리자 **다운로드 → TWILIGHT**에 `TWILIGHT-performance-<UTC 시각>-<세션 ID>.json`을 저장한다. 기존 Android 내보내기 설정의 Godot 기본 셸이 제공하는 `AndroidRuntime`과 `JavaClassWrapper`로 앱 소유 `MediaStore.Downloads` 항목을 만든다. 일반 저장소 권한이나 별도의 Java 플러그인을 추가하지 않았다. 쓰기가 끝날 때까지 MediaStore 항목을 대기 상태로 두고 스트림을 닫은 뒤 공개한다. 지원 근거는 [Godot Android 브리지](https://docs.godotengine.org/en/4.7/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html) 및 [Android 공유 저장소](https://developer.android.com/training/data-storage/shared/media)다.

## 종료와 복구

- 정상 창 닫기, 실제로 게임을 종료하는 Android 뒤로가기, 게임에서 요청한 종료는 `regular_exit`을 기록한다. UI를 닫거나 백그라운드로 전환하는 동작은 종료로 기록하지 않는다. Android가 종료 콜백을 실행하지 않는 강제 종료·크래시에서는 그 순간 공개 파일을 만들 수 없다.
- 로딩 화면에서 세션을 열고 실제 게임에 진입하면 상세 프레임 샘플이 쌓인다. 중간 보고서는 15초마다 비공개 `user://performance_reports/`에 작업 스레드에서 원자적으로 교체한다. 앱이 일시정지되면 쓰기가 진행 중이 아닐 때 추가 체크포인트를 요청한다. 오래 멈춘 동안 엔진이 새 프레임을 끝내거나 작업 스레드가 저장을 완료하지 못한 경우 그 구간은 유실될 수 있다.
- 재실행은 이전에 완료된 중간 파일을 `recovered_checkpoint`로 공개한다. 이전 정상 종료의 공개 저장만 실패했다면 `regular_exit`를 유지해 재시도한다. 현재 세션의 중간 파일과 섞지 않는다. 성공하지 못한 보고서는 최신 파일을 우선하여 비공개에 최대 4개를 유지한다. Android 9 이하, 브리지 누락, 저장소 오류에서는 공개 파일이 생성되지 않을 수 있다.
- 파일에는 빌드·세션 ID, 느린 프레임 최대 12개, 작업 시간, 스폰 단계, 콜백 경계, 물리·앱 상태, 최근 FPS와 메모리 샘플을 담는다. 세이브·계정·토큰·기기 식별자·비공개 경로는 내보내지 않는다.

## 523.813 지연에서 읽을 값

523.813@56f5843f 사진에서 최장 11,076ms 중 11,057ms가 미계측 잔여이고, 그리기 후 신호에서 다음 프레임 탐침까지 11,063ms다. 저장 쓰기·계정 저장·NPC 73681 투영 등의 상세는 같은 최장 **탐침 간격**의 기록이다. 서로 중첩될 수 있으며 기존 데이터에는 이 작업들의 위치가 없다. 마지막 565초 시점의 FPS와 메모리는 별도 표본이다.

- `next_scene_dispatch`는 그리기 후 신호부터 다음 SceneTree 물리/처리 신호까지와, 그 신호부터 프레임 탐침까지를 구분한다. 여러 그리기 신호가 겹치거나 전달 방식이 별도 스레드면 구간을 추정하지 않는다. 이 경계는 [SceneTree의 신호 규약](https://docs.godotengine.org/en/4.7/classes/class_scenetree.html#signals)을 따른다. 첫 구간에는 엔진·드라이버·OS 대기와 프레임 페이싱이 함께 있을 수 있다.
- `detail_spans`는 긴 작업의 최장 호출이 탐침 시작을 기준으로 어디서 시작하고 끝났는지 기록한다. `diag.heartbeat`, `diag.touch`, `logger_usec`는 진단 출력 자체를 확인하는 데 쓴다. 순위 목록과 세부 구간은 중첩될 수 있다. GPU 계측값으로 해석하지 않는다.
- 기존 Android의 5초 주기 프레임 로그 쓰기는 워커로 이동했다. Android 메모리 수집의 동기 `/system/bin/cat` 호출도 백그라운드에서 실행하고 최근 완료 결과를 사용한다. 기존 부팅 로그의 기록과 제한된 메모리 샘플 수집은 별도로 계측한다. 어느 경로도 523.813의 11초 멈춤 원인으로 재현되지는 않았다.

## 기존 빌드에서 확인 가능한 파일

기존 523.813에는 다운로드 내보내기가 없다. 게임 기록 경로는 현재 실행 `user://frame_hitch.json`, 다음 실행이 시작된 뒤에는 `user://frame_hitch.prev.json`이다. 업데이트된 앱에서 공개 내보내기가 실패한 보고서는 `user://performance_reports/TWILIGHT-performance-*.json`에 남을 수 있다. `user://`는 설치된 앱의 비공개 데이터이고 파일 관리자 다운로드 폴더와 별개다.

디버그 가능 빌드에서는 ADB가 연결된 상태에서 `adb shell run-as org.twilightoffline.playtest ls files`로 실제 위치와 접근 가능 여부를 확인하고, 해당 파일이 있을 때만 `adb exec-out run-as org.twilightoffline.playtest cat files/frame_hitch.prev.json > frame_hitch.prev.json`을 쓸 수 있다. 일반 릴리스에서 `run-as`는 허용되지 않을 수 있다. 그 경우 앱이 출력하는 `FRAME_HITCH` logcat 기록 또는 새 빌드의 공개 보고서를 사용한다. 다음 신호 이전의 긴 공백이 재현되면 [Android 시스템 트레이스](https://developer.android.com/tools/agents/android-cli/commands/profiler_systemtrace)로 스케줄링 및 프레임 생명주기를 비교할 수 있다.

## 검증 범위

Godot 4.7.2 Linux headless의 격리 프로필에서 종료 보고서 20개, 프레임 경계·비동기 로그 쓰기 226개, 기존 프레임 로그 26개, 프로브 18개, 스폰 추적 12개, 부팅 로그 66개, 로딩 74개, 실제 Main 저장·재로드 33개 검사가 통과했다. 보고서 시험은 실제 GDScript의 비공개 원자 쓰기·복구·수명주기를 실행하고 MediaStore 호출만 모의 객체로 대체한다. Android SDK·연결 기기가 없어 JNI 호출, Android 공개 파일 생성, 실제 강제 종료는 아직 검증하지 못했다. APK를 빌드하거나 배포하지 않았다.
