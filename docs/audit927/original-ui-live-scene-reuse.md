# U03 원본 UI의 실행 연결과 장면 읽기

Twm의 `pack-63fb1355` 릴리스에서 `twilight523-addon-ui.zip`을 받았다. ZIP CRC를 확인하고 `original_ui.json`의 SHA-256 `335af82d2794bafa4a9273cb309cde3a59f06a764467e66b58e29321c98eebaa`가 수령증과 일치함을 확인했다. 매니페스트에 장면 662개와 파일 1,955개가 선언돼 있다.

## 실제 게임 소비 지점

1. Android 설치 경로의 `source523_pack.gd::selections/apply`가 원본 UI 폴더와 매니페스트 핀을 환경에 넣는다.
2. Linux 검증에서 같은 설정을 주고 실제 `Main.tscn`을 시작했다. `RenewalHUD._bind_selected_original_main_ui`가 팩을 검증해 `OriginalMainGameHUD`를 정상 연결했다. 클래스 확인 뒤 게임 HUD의 `open_currency_info()`를 실행했다.
3. 팩의 `Gem_All.csb`가 실제 트리에 올라갔고, `Gem_List.csb`로 구성한 여섯 행에 게임의 보유액이 연결됐다. Linux OpenGL Compatibility llvmpipe에서 게임 프레임을 읽고 그 창의 텍스처가 달린 스프라이트 102개를 확인했다. 수정 전후 첫 원본 텍스처의 픽셀 SHA-256이 일치했다. 별도 팩 검사에서 원본 텍스트 노드가 변경된 금액을 표시하는 것도 확인했다.

## 변경과 측정

`source_main_window_kit.gd`가 한 창을 만드는 동안 노드 바인딩, 목록 크기, 행 배치를 계산하면서 같은 CSB에서 파생된 장면을 반복 읽었다. 이제 해당 단계에서만 읽기 전용 트리를 최대 8개 재사용한다. 화면을 새로 만들 때마다 다시 읽으며 실제 장면 구성, 바인딩 검증과 렌더러의 기존 범위 캐시는 그대로 사용한다. 원본 리소스, 게임 데이터 및 화질은 동일하다.

| Linux 실제 Main에서 재화 창 재열기 | 기준 | 변경 |
| --- | ---: | ---: |
| `pack.scene()` 전체 호출 | 23 | 4 |
| `Gem_List.csb` 읽기 | 12 | 1 |
| HUD 열기 호출 중앙값 | 28.422ms | 17.114ms |

동일한 팩과 Linux 렌더러에서 첫 열기를 제외한 전후 각 7회의 중앙값이다. 전체 프레임 시간이나 Android 성능 수치가 아니다. Windows 원본의 리소스 소유자 내 재사용 및 Android 원본의 텍스처 캐시 확인은 설계의 참고다. 이 변경은 Godot의 CSB 소비 경로에 적용했다. 원본 아이템 아이콘용 이미지 팩, 지도, 몬스터 및 Android 실기기까지 확인한 것은 아니다.

Godot 관련 검사 237개 통과: 실제 팩 재화 창 14, 버프 창 17, 필드 HUD 24, 합성 기능 창·행 드래그 182. 기준 코드에 새 재화 검사를 실행하면 재화 표시 검사는 통과하고 장면 읽기 횟수 검사 두 건에서만 실패했다.
