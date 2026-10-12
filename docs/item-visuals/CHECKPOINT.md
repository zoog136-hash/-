# 아이템 이미지·등급 효과 작업 체크포인트

- 기준 main: `434b904d957fd2146b6d2e73325693a402028035` (2026-10-12 원격 직접 조회).
- 브랜치: `feature/item-visual-link-rarity-effects`. Draft PR [#97](https://github.com/zoog136-hash/-/pull/97) 하나만 계속 사용. 사용자 승인 전 main 병합 금지.
- 사전 규칙: AGENTS.md, TWILIGHT_PROJECT_RULES.md, docs/RESOURCE_INTEGRITY_POLICY.md 읽음.
- 사전 검사: `python3 tools/check_resource_integrity.py --root .` 성공. 723 WebP / 41,442 프레임 / 233,420,026 바이트. 원본 전체 전달 완료를 뜻하지 않음.
- 현재 카탈로그: 2,129 sourceId / 2,085 이름 / 1,442 이미지 경로. 2,129행 모두 기존 PNG 존재. 별도 runtime_manifest 아이템 매핑 467 = 카탈로그 420 + legacy 47. 원본 정확성·권리는 별도 검증 대상.
- 첨부 `TWILIGHT_item_visual_patch_434b904.zip`, `TWILIGHT_item_visual_status_KO.md`는 이 세션의 업로드 참조 및 `/workspace/library-files`, `/workspace/shared`, `/workspace/scratch`에서 찾지 못함. 해당 패치 비교는 미실행. main 기반 작업은 계속 진행.
- 사용자 원본 ZIP 6종도 현재 환경에 없음. `--source-dir`/`--release-dir` 검증 또는 원본 팩 전달 완료를 주장하지 않음.
- Godot 공식 `4.7.2.stable.official.ed1daf0bf`, Compatibility / Mesa llvmpipe 실기동. 8개 실제 UI × 2해상도 + 64 연속 프레임 캡처 성공. 실제 렌더 픽셀 검사 성공. Windows/Android 실기기는 미검증.
- 진행: 2,129개 정확한 상세 페이지 ID/이름/이미지 URL과 1,442개 원격 PNG SHA를 모두 확인. 실제 런타임 2,576행: 원본 확인 2,129 / 원본 확인 대기 10 / 자체 대체 437 / 표시 이미지 누락 0. 대체 수는 개별 원본 제작 수가 아닌 공유 심볼 사용 레코드 수.
- 검증 자료: `evidence/audit.json`, `audit.csv`, `summary.json`, `source-verification.json`. 모든 카탈로그 및 L1J 467 매핑의 실제 파일·추적·해시·디코드 검사.
- 공통 ID 조회/셰이더/가시성 스케줄러 구현. 원본 픽셀과 게임 DB 보존. 단위 검사 6건 성공, 아이템 Godot 검사 6,445회 성공. 잘못된 ID의 바닥 이름 우회 차단 및 루비→물약 같은 오래된 UI 자리표시자 6개를 명시적 계열 대체로 정리.
- 전체 main/feature 회귀 실행 중. main 포인터 테스트의 기존 Dictionary 오류 등은 숨기지 않고 최종 비교에 기록.
- 다음: 최종 런타임 덤프 재생성, 전체 회귀 비교, 단독 성능 측정, 캡처/로그 Git 전달, 동일 PR CI 확인.
- 직전 원격 구현 체크포인트: `653d77dac55ce5ba6a33a5af98f8d8836def1c37`. 이 문서를 포함하는 구현 커밋은 `git log -1 --format=%H`로 확인; 다음 검증 커밋에서 실제 SHA 갱신.
- 원본 바이너리 추가 없음. 기존 게임 수치·저장 ID·드랍/강화/장착 규칙 변경 금지.

최종 검증 수치·실패 목록·커밋 SHA·PR URL은 이 파일과 동일 PR 설명에 갱신한다.
