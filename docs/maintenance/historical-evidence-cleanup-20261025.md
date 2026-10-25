# 과거 검증 캡처 정리 — 2026-10-25

기준 main: `f24c0a8372adc33dda4dcf76735b90ec7e537aba`. 참조·생성 규칙을 확인한 과거 캡처 6개, **6,705,766 bytes**를 일반 삭제 커밋으로 제거한다. 정확한 경로·크기·Git blob SHA·SHA-256은 같은 이름의 JSON에 있다. 별도 백업을 만들지 않으며 기존 Git 이력에서 복구할 수 있다. 파일 수/바이트는 최신 원격 트리 47,433개 blob으로 계산했다. Git 이력 및 기존 clone의 객체 크기는 줄어들지 않는다.

## 조사 및 삭제 판단

- AGENTS.md, TWILIGHT_PROJECT_RULES.md, RESOURCE_INTEGRITY_POLICY.md, README/버전 기록, project.godot, world/HUD 및 export 설정을 읽었다. 최신 main 트리에 추가 AGENTS.md 또는 .agents/skills는 없다.
- sparse worktree에 텍스트를 가져와 scripts/scenes/assets TRES/data JSON/manifest/tools/tests/CI/docs를 조사했다. 초기 22,216개 텍스트 입력 약544MB 및 누락 확장자 jsonl/mjs/conf/old/bak/diff/gdshader를 추가 확인했다. 대용량 증거 바이너리는 checkout하지 않았다. 필수 무결성 검사 대상 723 WebP와 연결 원본만 가져왔다.
- 전체 경로와 상대 경로, 동일 파일명 충돌을 구분했다. `batch17-stop-remote-tree.json`은 과거 특정 SHA의 저장소 전체 관측 스냅샷이며 현재 자산 소비자나 복원 manifest가 아니다. 그 기록은 수정하지 않았다. 해당 스냅샷에 이름이 있다는 사실만으로 모든 파일을 실행 의존성으로 분류하지 않았다.
- hunting-paths의 JPG 4개는 `tools/build_hunting_path_evidence.py`의 phase/label 규칙으로 생성되는 최종 contact sheet 출력이다. 입력은 before/after 원시 캡처이며 이 JPG들을 읽지 않는다. 문서가 연결하는 after-whole/after-boundary 및 before-after 비교판, 원시 PNG/JPG·manifest·제작 도구는 보존한다.
- docs/screenshots의 PNG 2개는 실제 게임 화면인 과거 결과물이다. 코드·문서·manifest의 소비 경로가 없다. 다른 폴더의 `01-village.png`/`03-bridge.png`는 출처/비교에 연결되므로 보존한다.
- 단순 검색 0으로 런타임 자산을 삭제하지 않았다. assets/data/scenes/scripts와 캐릭터·맵·스킬 원본, 연결 초안은 삭제 0개다.

## 보존 및 불확실 후보

| 경로/분류 | 추적 bytes 또는 근거 | 처리 |
|---|---:|---|
| docs/remake/evidence/pr122-remaining106 | 7,965,539,742 | 현재 PR158 및 원화/복원 의존성, 보존 |
| docs/remake/evidence/pr122-mythic-detailed | 5,023,913,304 | source-manifest, 선택/초안 TRES, 실제 원화와 제작 자료, 보존 |
| docs/remake/evidence/pr100-direction-fix | 4,567,260,778 | 승인·복원·시각 증거 연결, 보존 |
| docs/remake/evidence/pr122-monsters-20261023 | 2,542,928,300 | 보스·몬스터 선택/수정/검토 자료, 보존 |
| batch17 authoring-stop 162분할 | archive 4,751,840,049 | 원화4606개 포함 6205개 멤버, 전체 묶음 보존 |
| tomb269 base/delta·unicorn base05 | CI pr122-tomb269-actual-main/pr122-unicorn-alpha-microrepair 및 복원기 직접 사용 | 묶음과 작은 manifest/restore 도구 모두 보존 |
| PR100 runtime-evidence 분할 | pending-runtime-manifest·restore_pending_bundle.py 연결 | 멤버별 원화/재검증 의존성 분리 불확실, 보존 |
| animation-expansion PNG 18개 | bow/staff/sword 보고서의 무접두사 캡처 이름과 저장된 접두사 파일의 간접 연결 | 삭제 후보에서 제외, 보존 |
| 그 밖의 과거 압축·PNG | 출처/manifest/제작·재검증 연결 또는 현재 작업 범위 내 불확실성 | 삭제하지 않음 |

최신 조사에서는 assets TRES 525개가 `res://docs/`를 참조한다. Android scope 검사에서도 docs-backed archived review clip 525개를 확인했다. 사용자 초기 조사 473개보다 늘었으며 docs 통삭제는 안전하지 않다. 압축 내부 원화가 불필요하다고 입증하지 못한 묶음은 일부 조각만 삭제하지 않는다. 이번에 영상·압축 삭제는 0개다. 이 보고서는 대용량 미참조 자료 전체가 제거되었다는 주장이 아니다.

PR152/153/154/155/157/158의 읽기 전용 PR 본문과 전체 changed-file patch를 확인했다. 변경 대상 6개와 해당 PR 변경 파일의 교집합은 0이다. PR158의 pr122-final-approval 및 PR157의 presentation-20261025 증거는 보존하며 기존 PR을 수정하지 않는다. 대형 PR122 범위의 미확실 후보는 현재 승인 작업과 분리해 추가 의존성 증명 전까지 보존한다.

## 검증

- 변경 전/후 `python3 tools/check_resource_integrity.py --root .`: 723 atlases, 41,442 frames, 233,420,026 bytes, PASS. 외부 원본 전체 전달을 뜻하지 않는다.
- `python3 tools/android_animation_export_scope.py --root .`: 525 review clips, runtime closure 5,159 files, production excluded 0, PASS. export_presets.cfg/project.godot/CI는 수정하지 않았다.
- 삭제 경로와 파일명/동적 생성 규칙, 열린 PR 패치, docs-backed TRES 참조 국소 재확인. 삭제 목록의 Git blob/SHA-256을 기존 checkout 바이트와 대조했다.
- staged 경로 범위·추적 바이트 합계·보호된 runtime 및 archive 트리 동일성·`git diff --cached --check` 확인.
- 변경이 과거 캡처 삭제 및 이 보고서에 한정되어 전체 Godot import/boot/전체 회귀와 CI는 실행하지 않았다. sparse checkout은 전체 런타임 부팅 환경이 아니다. 커밋은 `[skip ci]`.

정확한 보고서 추가 바이트와 삭제 후 순 추적 바이트는 JSON의 accounting_totals에 기록한다.

## 보존 참조 유형별 집계와 추가 결정 범위

이번 삭제를 제외한 docs 이미지·영상·ZIP/GZ/분할압축에 대한 관측 분류다. 전체 저장소 스냅샷 언급은 제외했다. 동일 파일을 중복 집계하지 않는다.

| 관측 유형 | 파일 | bytes | 판단 |
|---|---:|---:|---|
| 오래된 문서·캡처 목록 등 기록상 언급만 관측 | 1646 | 1173964313 | 보존 |
| 실행/제작/복원 도구 또는 자산 참조 관측 | 2379 | 4801612626 | 보존 |
| 현재 승인·원화·복원 범위, 개별 필요성 미확정 | 13865 | 14663271575 | 보존 |

첫 유형에는 도구의 출력 경로 언급도 포함될 수 있으므로 실제 입력 의존성의 확정 합계가 아닌 보수적 상한이다. 두 번째 유형은 실제 실행 의존성과 구분하며, 연결된 과거 기록까지 삭제할지 사용자 추가 결정이 필요한 범위다. 현재 지시는 참조 없는 파일만 삭제하므로 이를 임의 삭제하지 않았다. 세 번째 유형은 현재 작업과 겹쳐 멤버별 소비 경로의 추가 입증이 필요하다. 분할 묶음의 대체 원본도 확인했으나, 선택된 런타임 자산은 원화·중간 제작물 전체의 무손실 대체본으로 입증되지 않았다. 멤버별 SHA가 일치하는 완전한 다른 영구 원본은 확인하지 못해 압축은 모두 보존했다. 상세 그룹별 바이트는 JSON에 있다.
