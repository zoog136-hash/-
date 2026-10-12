# 아이템 이미지·등급 효과 작업 체크포인트

- 기준 main: `434b904d957fd2146b6d2e73325693a402028035` (2026-10-12 원격 직접 조회).
- 브랜치: `feature/item-visual-link-rarity-effects`. 아이템 전용 열린 PR 없음 확인. 생성 후 같은 Draft PR만 사용하며 사용자 승인 전 main 병합 금지.
- 사전 규칙: AGENTS.md, TWILIGHT_PROJECT_RULES.md, docs/RESOURCE_INTEGRITY_POLICY.md 읽음.
- 사전 검사: `python3 tools/check_resource_integrity.py --root .` 성공. 723 WebP / 41,442 프레임 / 233,420,026 바이트. 원본 전체 전달 완료를 뜻하지 않음.
- 현재 카탈로그: 2,129 sourceId / 2,085 이름 / 1,442 이미지 경로. 2,129행 모두 기존 PNG 존재. 별도 runtime_manifest 아이템 매핑 467 = 카탈로그 420 + legacy 47. 원본 정확성·권리는 별도 검증 대상.
- 첨부 `TWILIGHT_item_visual_patch_434b904.zip`, `TWILIGHT_item_visual_status_KO.md`는 이 세션의 업로드 참조 및 `/workspace/library-files`, `/workspace/shared`, `/workspace/scratch`에서 찾지 못함. 해당 패치 비교는 미실행. main 기반 작업은 계속 진행.
- 사용자 원본 ZIP 6종도 현재 환경에 없음. `--source-dir`/`--release-dir` 검증 또는 원본 팩 전달 완료를 주장하지 않음.
- Godot 공식 `4.7.2.stable.official.ed1daf0bf` 확보. Compatibility 소프트웨어 OpenGL 화면 준비. 기준 main 전체 회귀 실행 중.
- 다음: 실제 런타임 DB 덤프와 전수 감사, ID 우선 공통 조회, 원본 픽셀 보존, 공통 셰이더, 실제 UI·입력·저장 회귀 및 렌더 측정.
- 원본 바이너리 추가 없음. 기존 게임 수치·저장 ID·드랍/강화/장착 규칙 변경 금지.

최종 검증 수치·실패 목록·커밋 SHA·PR URL은 이 파일과 동일 PR 설명에 갱신한다.
