# PR144 후속: 남은 Ground Alpha import 시간초과

- 검사 기준: PR144 `456bb3f927b0bc0d06e021eb37b38a21848fac20`, main `88b1773f90e9d5cc092d9423ef9e80407b102bf5`.
- 실패 실행: https://github.com/zoog136-hash/-/actions/runs/39687079707
- 작업 ID: `119523756737`, artifact `12387472343`.
- 로그는 2026-10-21 22:40:46 UTC에 import를 시작했고 22:44:46 UTC에 72%에서 `TIMEOUT`으로 종료됐다. 실제 드롭/픽셀 검사 실패와 구분한다.

## 수정

기존 verify.py의 모든 엔진 단계 공통 240초 제한을 정식 test_project_support의 시간 정책으로 연결했다. 전체 import는 900초, 일반 단계는 기존 240초, 기존의 긴 loot/interaction 검사는 공통 정책의 300초를 사용한다. 제한을 제거하거나 검사를 생략하지 않는다.

정식 run_isolated를 사용해 제한 초과 시 자식 프로세스까지 종료하고 stdout/stderr를 함께 보존한다. 시간초과(124), 실행 실패(125), 실제 엔진 종료 코드를 성공으로 처리하지 않는다. 보고서에 사용한 제한과 실제 checkout SHA를 기록하고 과거 고정 SHA는 historical_base_main으로 명확히 분리했다.

전체 workflow 제한은 15분에서 45분으로 조정했다. 기존 실제 Main 테스트 목록, OpenGL 캡처, 보호 파일/인벤토리/그림 무결성 검사는 모두 보존한다. 공통 실행기/캡처 helper 변경도 CI 경로 필터에 포함한다.

## 검증

- 원래 verify.py와 workflow를 역변환해 원본 Git blob SHA 일치를 확인했다.
- 정식 support 파일의 로컬 바이트도 원격 blob `97838f407c6af8fe48ef85c040cbec9cc89188d7`과 일치한다.
- 새 실행기 단위검사 10개 PASS: import/일반/긴 검사 시간, stderr/실패 코드/시간초과 보존, 실제 controlled subprocess 실행과 자식 프로세스 종료.
- Python 구문, workflow YAML 및 내장 shell 구문 검사 PASS.
- 이 단위검사는 Godot 실행/전체 CI 통과를 의미하지 않는다. 새 커밋의 실제 원격 결과로 판정한다.
- 게임 로직·아이템·스탯·맵·리소스·사용자 저장값은 수정하지 않는다. main 미병합 상태를 유지한다.
