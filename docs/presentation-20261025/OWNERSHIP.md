# PR 소유 범위와 후속 연결

2026-10-25 조회 시 PR122/152/153/154/155는 모두 미병합이다. 다른 PR의 브랜치/CI를 시작·취소·병합하지 않았다. 이후 지시에 따라 이 신규 PR도 전체 CI를 보류하고 `[skip ci]` 저장과 국소 검사만 한다.

| 소유 | 실제 확인한 연결 | 이번 변경과 경계 |
|---|---|---|
| PR122 (`d76a098b`) | world의 `_directional_image_path` 별칭, 원화/프레임/모션 공유 규약 | 모두 미변경. world 수정은 별도 음향 관찰과 AUTO 후보 탐색 표현 밖 성능 범위로 한정. 공격 마커·발 기준·방향 선택 변경 없음 |
| PR152 (`96a13abe`) | `option_awakening_view.gd`가 `renewal_theme.gd`의 label/section/box를 사용; 전용 border/reveal/aura | 전용 파일/자산 미이식·미수정. 추후 통합 시 기본 Theme를 상속하는 컨트롤만 공통 버튼 재질 적용; 전용 각성 효과는 별도 담당 |
| PR153 (`504f96b3`) | `skill_vfx.gd`가 독립 라이브러리/SPX bridge/shader와 기존 skill_audio pool 사용 | 본 PR에서 스킬 VFX·오디오 풀 미변경. 일반 공격/생활 피드백만 별도 한정. source/marker/frame 계약 보존 |
| PR154 (`a0a303d1`) | `growth_view.gd`가 공통 label/tab_frame와 전용 growth art/card/diagram 사용 | tab_frame 인자 계약 유지. 문양/수호성 카드/별자리 자체 제작·흐름 미수정. HUD/window 연결은 별도 함수/최소 훅만 변경 |
| PR155 (`9e7adf4e`) | 미니맵 보스 MultiMesh, native renderer 신규 아덴 source/scale/streaming | 보스 배칭·아덴 PNG·배치·생성팩 미이식. 정적 polygon 캐시와 `_process` 정지 카메라 요청 비교만 별도 변경 |

GitHub 대형 PR의 파일 목록 API가 앞부분만 반환해, 공통 파일은 해당 HEAD의 실제 텍스트를 추가로 읽어 비교했다. 참고 원격 텍스트는 `/tmp`에서 검토했으며 외부 브랜치 원화나 전용 코드의 런타임 설치에 사용하지 않았다. 대형 읽기용 fetch는 불필요한 자산 전송을 피하려고 중단했으며 어떤 PR 브랜치도 checkout하지 않았다.

이 표는 충돌 가능 지점을 정리한 것으로 미병합 기능의 실제 본게임 실행 검증을 뜻하지 않는다. 세 전용 기능의 최신 리니지M 시각 고증은 별도 담당자가 계속 처리한다.
