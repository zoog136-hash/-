# TWILIGHT 원작 스킬 이행 도감 — 검증 중

기준일: 2025-06-17. 기준일의 전체 원작 목록과 전 효과를 확정한 도감이 아닙니다. 현재 DB 후보는 과거 목록으로 간주하지 않습니다.

- 현재 Inven 13직업: 662 직업 배정, 486 고유 ID의 상세 메타데이터 확보.
- 조사 인벤토리: 695 직업·이름 레코드. 날짜가 확인되는 과거 기록과 현재 후보를 구분합니다.
- 실행 연결: 125개, 모두 PARTIAL. 실제 전투 경로를 연결했지만 원작 전체 효과의 일치 검증은 남아 있습니다.
- 기존 257개 DB 보존: 원작 이름 후보 41개 / 자체 제작 분류 216개.
- 원작 미확인 수치는 balance.json의 CUSTOM_BALANCE. 내부 lm_ ID는 NC의 공식 ID가 아닙니다.

## 직업별 실행 연결

| 직업 | 이름 | 등급 | 동작 | 레벨 | 선행 조건 | 강화 대상 | 출처 |
|---|---|---|---|---:|---|---|---|
| 군주 | 브레이브 멘탈 | 영웅 | buff | 60 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/5) |
| 군주 | 브레이브 스피드 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/5) |
| 군주 | 브레이브 바이탈 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/5) |
| 군주 | 브레이브 크리티컬 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/5) |
| 군주 | 브레이브 아머 | 영웅 | stats | 60 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/5) |
| 군주 | 브레이브 웨폰 | 영웅 | stats | 60 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/5) |
| 군주 | 글로잉 오라(1단계) | 일반 | stats | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/5) |
| 군주 | 엑스칼리버 | 영웅 | status | 60 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/5) |
| 기사 | 쇼크 스턴 | 일반 | status | 50 | UNKNOWN | — | [2024-09-25](https://lineagem.plaync.com/board/update/view?articleId=66f31338a6acf62e167e4e3f) |
| 기사 | 카운터 배리어 | 일반 | counter | 30 | UNKNOWN | — | [2024-09-25](https://lineagem.plaync.com/board/update/view?articleId=66f31338a6acf62e167e4e3f) |
| 기사 | 카운터 배리어(베테랑) | 영웅 | upgrade | 60 | UNKNOWN | 카운터 배리어 | [2024-09-25](https://lineagem.plaync.com/board/update/view?articleId=66f31338a6acf62e167e4e3f) |
| 기사 | 카운터 배리어(마스터) | 전설 | upgrade | 80 | UNKNOWN | 카운터 배리어(베테랑) | [2024-09-25](https://lineagem.plaync.com/board/update/view?articleId=66f31338a6acf62e167e4e3f) |
| 기사 | 리덕션 아머 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-24](https://mysmallplace.tistory.com/2) |
| 기사 | 바이탈 아머 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-24](https://mysmallplace.tistory.com/2) |
| 기사 | 솔리드 아머 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-24](https://mysmallplace.tistory.com/2) |
| 기사 | 타운트 | 일반 | taunt | 30 | UNKNOWN | — | [2024-09-25](https://lineagem.plaync.com/board/update/view?articleId=66f31338a6acf62e167e4e3f) |
| 기사 | 클리어 | 영웅 | heal | 60 | UNKNOWN | — | [2024-09-25](https://lineagem.plaync.com/board/update/view?articleId=66f31338a6acf62e167e4e3f) |
| 요정 | 트리플 애로우 | 일반 | attack | 30 | UNKNOWN | — | [2024-10-27](https://mysmallplace.tistory.com/20) |
| 요정 | 블러드 투 소울 | 일반 | convert | 30 | UNKNOWN | — | [2024-10-27](https://mysmallplace.tistory.com/20) |
| 요정 | 네이쳐스 터치 | 일반 | stats | 30 | UNKNOWN | — | [2024-10-27](https://mysmallplace.tistory.com/20) |
| 요정 | 아이언 스킨 | 일반 | stats | 30 | UNKNOWN | — | [2024-10-27](https://mysmallplace.tistory.com/20) |
| 마법사 | 힐 | 일반 | heal | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 블레스 웨폰 | 일반 | buff | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 어드밴스 스피릿 | 일반 | buff | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 아이스 스파이크 | 일반 | attack | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 이럽션 | 일반 | attack | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 슬로우 | 일반 | status | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 사일런스 | 일반 | status | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 인비지블리티 | 일반 | stealth | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 이뮨 투 함 | 영웅 | buff | 60 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 풀 힐 | 영웅 | heal | 60 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 파이어스톰 | 영웅 | attack | 60 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 미티어 스트라이크 | 전설 | attack | 80 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 디스인트그레이트 | 전설 | attack | 80 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 블랙 핸드 | 영웅 | attack | 60 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 앱솔루트 배리어 | 전설 | buff | 80 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 멘탈 포커스 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 홀리 스위프트 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 디스인트그레이트(에이션트) | 전설 | upgrade | 80 | UNKNOWN | 디스인트그레이트 | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 미티어 스트라이크(에이션트) | 전설 | upgrade | 80 | UNKNOWN | 미티어 스트라이크 | [2023-05-27](https://mysmallplace.tistory.com/6) |
| 마법사 | 서먼 가디언 | 신화 | summon | 80 | UNKNOWN | — | [2023-03-22](https://lineagem.plaync.com/board/update/view?articleId=641a05b8c19a0110e2d3edf4) |
| 마법사 | 턴 언데드 | 일반 | turn_undead | 30 | UNKNOWN | — | [2022-02-09](https://lineagem.plaync.com/board/update/view?articleId=6202c4b88a33a923b33364dc) |
| 마법사 | 턴 언데드(에이션트) | 영웅 | upgrade | 70 | UNKNOWN | 턴 언데드 | [2022-02-09](https://lineagem.plaync.com/board/update/view?articleId=6202c4b88a33a923b33364dc) |
| 다크엘프 | 무빙 악셀레이션 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 다크엘프 | 쉐도우 팽 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 다크엘프 | 언케니 이베이젼 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 다크엘프 | 쉐도우 콤비네이션 | 일반 | stats | 30 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 다크엘프 | 쉐도우 아머 | 일반 | buff | 30 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 다크엘프 | 언케니 닷지 | 일반 | buff | 30 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 다크엘프 | 더블 브레이크 | 일반 | buff | 30 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 다크엘프 | 쉐도우 하이딩 | 일반 | stealth | 30 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 다크엘프 | 쉐도우 리커버리 | 영웅 | heal | 60 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 총사 | 래피드 샷 | 일반 | attack | 30 | UNKNOWN | — | [2025-03-08](https://mysmallplace.tistory.com/21) |
| 총사 | 마나 체인지 | 일반 | convert | 30 | UNKNOWN | — | [2025-03-08](https://mysmallplace.tistory.com/21) |
| 총사 | 세팅 업 | 일반 | stats | 30 | UNKNOWN | — | [2025-03-08](https://mysmallplace.tistory.com/21) |
| 총사 | 스피드 마스터 | 일반 | buff | 30 | UNKNOWN | — | [2025-03-08](https://mysmallplace.tistory.com/21) |
| 투사 | 포우 슬레이어 | 일반 | attack | 30 | UNKNOWN | — | [2023-06-11](https://mysmallplace.tistory.com/9) |
| 투사 | 블러드 러스트 | 일반 | buff | 30 | UNKNOWN | — | [2023-06-11](https://mysmallplace.tistory.com/9) |
| 투사 | 드래곤 스킨 | 일반 | stats | 30 | UNKNOWN | — | [2023-06-11](https://mysmallplace.tistory.com/9) |
| 투사 | 드래곤 실드 | 영웅 | stats | 60 | UNKNOWN | — | [2023-06-11](https://mysmallplace.tistory.com/9) |
| 투사 | 리플렉팅 실드 | 영웅 | stats | 60 | UNKNOWN | — | [2023-06-11](https://mysmallplace.tistory.com/9) |
| 투사 | 썬더 그랩 | 일반 | status | 30 | UNKNOWN | — | [2023-06-11](https://mysmallplace.tistory.com/9) |
| 투사 | 드래곤 포스 | 전설 | heal | 80 | UNKNOWN | — | [2023-06-11](https://mysmallplace.tistory.com/9) |
| 암흑기사 | 다크 아머 | 일반 | stats | 30 | UNKNOWN | — | [2023-06-17](https://mysmallplace.tistory.com/10) |
| 암흑기사 | 다크 가드 | 일반 | stats | 30 | UNKNOWN | — | [2023-06-17](https://mysmallplace.tistory.com/10) |
| 암흑기사 | 다크 크리티컬 | 일반 | stats | 30 | UNKNOWN | — | [2023-06-17](https://mysmallplace.tistory.com/10) |
| 암흑기사 | 다크 소울 | 일반 | proc | 30 | UNKNOWN | — | [2023-06-17](https://mysmallplace.tistory.com/10) |
| 암흑기사 | 다크 스턴 | 일반 | status | 30 | UNKNOWN | — | [2023-06-17](https://mysmallplace.tistory.com/10) |
| 암흑기사 | 다크 핸드 | 영웅 | status | 60 | UNKNOWN | — | [2023-06-17](https://mysmallplace.tistory.com/10) |
| 암흑기사 | 다크 라이즈 | 전설 | heal | 80 | UNKNOWN | — | [2023-06-17](https://mysmallplace.tistory.com/10) |
| 신성검사 | 세인트 이뮨 | 영웅 | buff | 60 | UNKNOWN | — | [2023-07-05](https://mysmallplace.tistory.com/14) |
| 신성검사 | 세인트 스턴 | 일반 | status | 30 | UNKNOWN | — | [2023-06-24](https://mysmallplace.tistory.com/12) |
| 신성검사 | 세인트 브레이브 | 일반 | stats | 30 | UNKNOWN | — | [2023-06-24](https://mysmallplace.tistory.com/12) |
| 신성검사 | 세인트 바이탈 | 일반 | stats | 30 | UNKNOWN | — | [2023-06-24](https://mysmallplace.tistory.com/12) |
| 광전사 | 기간틱 | 일반 | stats | 30 | UNKNOWN | — | [2023-06-22](https://mysmallplace.tistory.com/11) |
| 광전사 | 퀵 스피드 | 일반 | stats | 30 | UNKNOWN | — | [2023-06-22](https://mysmallplace.tistory.com/11) |
| 광전사 | 애로우 가드 | 일반 | stats | 30 | UNKNOWN | — | [2023-06-22](https://mysmallplace.tistory.com/11) |
| 광전사 | 크래쉬 | 일반 | proc | 30 | UNKNOWN | — | [2023-06-22](https://mysmallplace.tistory.com/11) |
| 광전사 | 하울 | 일반 | attack | 30 | UNKNOWN | — | [2023-06-22](https://mysmallplace.tistory.com/11) |
| 광전사 | 파워 그립 | 일반 | status | 30 | UNKNOWN | — | [2023-06-22](https://mysmallplace.tistory.com/11) |
| 사신 | 고스트 바이탈 | 일반 | stats | 30 | UNKNOWN | — | [2023-07-19](https://mysmallplace.tistory.com/15) |
| 사신 | 데스 크리티컬 | 일반 | stats | 30 | UNKNOWN | — | [2023-07-19](https://mysmallplace.tistory.com/15) |
| 사신 | 고스트 이베이젼 | 일반 | stats | 30 | UNKNOWN | — | [2023-07-19](https://mysmallplace.tistory.com/15) |
| 사신 | 헬 사이드 | 일반 | attack | 30 | UNKNOWN | — | [2023-07-19](https://mysmallplace.tistory.com/15) |
| 사신 | 사이드 그랩 | 영웅 | status | 60 | UNKNOWN | — | [2023-07-19](https://mysmallplace.tistory.com/15) |
| 사신 | 데스 핸드 | 영웅 | status | 60 | UNKNOWN | — | [2023-07-19](https://mysmallplace.tistory.com/15) |
| 뇌신 | 플라즈마 부스트 | 일반 | stats | 20 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 라이트닝 어택 | 일반 | stats | 20 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 썬더 가드 | 일반 | stats | 30 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 썬더 바이탈 | 일반 | stats | 50 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 라이트닝 크리티컬 | 일반 | stats | 40 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 썬더 프로텍션 | 영웅 | stats | 60 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 썬더 볼트 | 일반 | proc | 1 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 썬더 마크 | 일반 | mark | 1 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 체인 라이트닝 | 일반 | toggle_proc | 1 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 썬더 아머 | 일반 | buff | 20 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 스태틱 필드 | 일반 | attack | 30 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 썬더 스턴 | 일반 | status | 50 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 라이트닝 스트라이크 | 일반 | proc | 50 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 썬더 아머(미스틱) | 영웅 | upgrade | 60 | UNKNOWN | 썬더 아머 | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 라이트닝 스트라이크(미스틱) | 영웅 | upgrade | 70 | UNKNOWN | 라이트닝 스트라이크 | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 뇌신 | 플라즈마 다이브 | 전설 | heal | 80 | UNKNOWN | — | [2022-08-24](https://lineagem.plaync.com/board/update/view?articleId=63052ab89d59e3180628d0e4) |
| 마검사 | 룬 마스터리 | 일반 | stats | 1 | UNKNOWN | — | [2024-06-19](https://lineagem.plaync.com/board/update/view?articleId=6671e038a12ede529779c000) |
| 마검사 | 에테르 부스트 | 일반 | stats | 20 | UNKNOWN | — | [2024-06-19](https://lineagem.plaync.com/board/update/view?articleId=6671e038a12ede529779c000) |
| 마검사 | 에테르 바이탈 | 일반 | stats | 20 | UNKNOWN | — | [2024-06-19](https://lineagem.plaync.com/board/update/view?articleId=6671e038a12ede529779c000) |
| 마검사 | 에테르 아머 | 일반 | stats | 30 | UNKNOWN | — | [2024-06-19](https://lineagem.plaync.com/board/update/view?articleId=6671e038a12ede529779c000) |
| 마검사 | 룬 버스트 | 일반 | attack | 1 | UNKNOWN | — | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 라이프 서클 | 일반 | proc | 1 | UNKNOWN | — | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 룬 블로우 | 일반 | amplify | 20 | UNKNOWN | — | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 룬 스턴 | 일반 | status | 50 | UNKNOWN | — | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 일루전 카운터 | 일반 | counter | 40 | UNKNOWN | — | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 팔랑크스 | 일반 | stack_defense | 50 | UNKNOWN | — | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 에테르 웨폰 | 일반 | stack_attack | 40 | UNKNOWN | — | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 노마드 | 일반 | recovery | 30 | UNKNOWN | — | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 라이프 스트림 | 전설 | heal | 80 | UNKNOWN | — | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 룬 버스트(에이스) | 전설 | upgrade | 80 | UNKNOWN | 룬 버스트 | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 라이프 서클(에이스) | 영웅 | upgrade | 60 | UNKNOWN | 라이프 서클 | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 마검사 | 일루전 카운터(에이스) | 영웅 | upgrade | 70 | UNKNOWN | 일루전 카운터 | [2024-06-30](https://mysmallplace.tistory.com/17) |
| 공용 | 에너지 볼트 | 일반 | attack | 1 | UNKNOWN | — | [2023-05-24](https://mysmallplace.tistory.com/2) |
| 공용 | 라이트 | 일반 | buff | 1 | UNKNOWN | — | [2023-05-24](https://mysmallplace.tistory.com/2) |
| 공용 | 실드 | 일반 | buff | 1 | UNKNOWN | — | [2023-05-24](https://mysmallplace.tistory.com/2) |
| 공용 | 텔레포트 | 일반 | teleport | 1 | UNKNOWN | — | [2023-05-24](https://mysmallplace.tistory.com/2) |
| 공용 | 큐어 포이즌 | 일반 | cleanse | 10 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 공용 | 디크리즈 웨이트 | 일반 | buff | 10 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |
| 공용 | 어스 재일 | 일반 | attack | 10 | UNKNOWN | — | [2023-05-30](https://mysmallplace.tistory.com/7) |

## 보류와 다음 단계

research_inventory.json과 original-vs-twilight.csv에 보류 항목을 모두 남겼습니다. 다음 단계는 보류 항목의 2025 직전 설명·등급·PvE 대상 확인, 전후 리부트 계보 확정, 그 결과를 사용한 고유 효과 추가입니다. 그랜드 마스터: 카운터, 리포스트, 카운터 리벤지, 타이탄, 콤보·돌진·소환·마법 복사·버프 제거를 일반 피해나 공통 버프로 대체하지 않습니다.

원작 영상별 업로드 날짜·타임스탬프·프레임 대조는 아직 UNKNOWN입니다. vfx.json은 자체 제작 프리셋이며 원작 시각 일치 완료를 뜻하지 않습니다. Windows·Android 실기기 성능은 별도 검증이 필요합니다.

## 파일

- data/skills/master.json: 실행 스킬 필수 필드와 상태
- research_inventory.json: 역사·현재 후보 및 보류 상태
- curation.json / source_seed.json: 재생성 가능한 수작업 검증 기록
- balance.json / relations.json / status_rules.json: 수치·계승·상태 규칙
- equipment_links.json: 기존 아이템·변신·인형·성물 설명의 발동 옵션 연결 및 BLOCKED 옵션
- vfx.json / assets/skills: ID별 자체 벡터 아이콘·효과 프리셋·합성 WAV
- original-vs-twilight.csv / legacy-disposition.csv: 비교·기존 데이터 처리
