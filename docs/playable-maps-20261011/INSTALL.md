# 원본 통행 맵 로컬 설치

이 브랜치는 최신 main의 기존 25개 지역을 유지합니다. 별도 원본 통행 팩을 설치하면 지도 메뉴에 A3 지역이 추가됩니다. 원본 지형 그래픽은 포함하지 않습니다. 원본 통행/좌표와 PC A3 판본을 사용하며, 현재 TWILIGHT의 리니지M 지역과 동일하다고 확정하지 않습니다.

Godot 4.7.2, Python 3 및 numpy가 필요합니다. 제공한 파일의 이름에 접두어가 있으면 실제 경로를 인자로 사용합니다.

```sh
python3 tools/map_restore/install_a3.py --a3 /path/to/a3.zip --viewer /path/to/L1MapViewer-main.zip
python3 tools/map_restore/verify_delivery.py --write
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/source_first_map_test.gd
```

설치기는 PR81의 기록에서 A3 통행 멤버 1,000개만 직접 열고 파일/멤버/행 우선 격자 SHA를 대조합니다. 기존 1,376개 복구 팩이 있으면 검증 후 그대로 재사용합니다. 다른 ZIP 전체나 중첩 파일을 다시 스캔하지 않습니다. 원본 통행 팩은 `data/l1j/recovered_maps/`, 게임 실행 팩은 `data/original_maps/`입니다. 두 경로는 공개 Git에서 제외되며, 코드 clone만으로 팩이 설치되는 것은 아닙니다. 설치 중단 시 기존 복구 격자는 보존됩니다. catalog.json이 아직 없으면 명령을 다시 실행하여 런타임 변환을 재개할 수 있습니다. catalog.json이 있으면 덮어쓰지 않으며 무결성 검사로 확인합니다.

게임에서 지도(Tab) → 지역 종류 → 우선 지역 → 본토 [4] → 선택 지역으로 이동. 좌표와 미니맵은 원본 통행 데이터를 사용합니다. 기존 TWILIGHT 지역은 첫 번째 종류에서 계속 접근할 수 있습니다.

- 지형: 통행 격자를 표시하는 임시 면. 벽/물의 원본 이미지 분류까지 복원한 상태가 아닙니다.
- NPC: A3 위치/이름. 상점·창고 등 서비스 내용은 기존 TWILIGHT 기능을 임시 연결했습니다. 미확인 대사는 미매핑으로 표시합니다.
- 몬스터: 명시된 ID 또는 정확한 이름 대응만 연결하며, 전투/드랍은 기존 TWILIGHT 규칙입니다. 연결 불가 종은 임의 대체하지 않습니다.
- 보스: 본토 커츠는 A3 spawnlist_boss 행 21의 좌표와 범위를 참고합니다. 원본 행은 비활성이므로 TWILIGHT 임시 오프라인 출현(1마리, 900초 재출현)을 별도로 표시했습니다. 원본 서버 시간표 구현이 아닙니다.
- 포털: A3 좌표와 목적지. 유효하지 않은 원본 목적지는 이동시키지 않습니다.
- 저장: 원본 맵 ID, 격자 SHA와 소수 좌표를 저장합니다. 팩이 빠지거나 손상된 저장은 자동 저장으로 덮어쓰지 않습니다. 팩 복원 후 게임을 다시 실행하고 불러오세요.

Linux 소프트웨어 OpenGL 검증은 Windows 기기 조작 검증과 다릅니다. 실제 렌더 검사는 `tools/run_visual_capture.py --script res://tests/source_first_map_test.gd`를 사용합니다. 사용자 저장을 건드리지 않도록 별도 `--data` 폴더를 지정합니다.

공개 CI에는 원본 팩이 없으므로 원본 팩 전용 검사는 SKIP으로 별도 집계합니다. 이는 PASS 또는 원본 복원 완료가 아닙니다. 원본 리소스 재배포 권리가 확인되지 않아 이 PR에는 맵 바이트/타일 팩을 업로드하지 않습니다. 사용자에게 이미 제공된 원본 ZIP으로 재구성하는 절차입니다.
