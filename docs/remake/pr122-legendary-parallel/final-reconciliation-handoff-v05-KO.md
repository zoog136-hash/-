최종 대조 실행 준비

원본 확정 검토와 옛 보고서·요청·실패는 보존합니다. 이 도구는 JSON/SHA/실제 원격 영수증만 읽으며 PNG 재열람, 시각 재검토, 이미지 호출, 리소스 변경을 하지 않습니다. 내부 completion gate는 중복 실행과 미완성 근거를 막는 실행 조건이며 사용자 재승인을 요구하지 않습니다.

최종 생산 기준은 asset freeze `0fe2882e594dedd30b5ce74f172edf4aed545122`입니다. 교정 원화109개/신규604자세, 안전한 소유권 분리721개 원본, guard-only6건 중 자원수정2건·부모HOLD4건을 별도 단위로 유지합니다. 최초429실패7건은 한도해제 후 각각1회 성공했으며 과거 실패를 지우지 않았습니다. 최종 미호출15건은 camera부모7, identity부모3, IDLE-role부모5 HOLD입니다. 원래274 NE ATTACK moderation 미생성1건은 별도 BLOCKED입니다.

새109원화의 변경부 정적 검토는 각각1회입니다. 시각 잔여는37 issue/34 원화이며 원인별 발생건수는 camera24, identity_weapon_action9, idle_role3, articulation1입니다. 이 수치는 최종 활성 clip 중복 제거 수가 아닙니다. qc102는 FOREIGN8636px와 소유권 모호473px가 공존하므로 전체원화HOLD로 보존했습니다. camera정정 결과와 소유권HOLD를 분리합니다.

최종 전체 CI2는216 PASS /12 FAIL /5 SKIP이고, 최신 런타임 증거는1318 PASS /1 FAIL /1 BLOCKED입니다. 변경98개만 실제 재생한97 PASS /1 capture FAIL을 그대로 유지하며 정상1221개를 다시 재생하지 않았습니다. 177 NW HIT의 미캡처 원인은 QA환경 추정으로만 기록하고 원화 결함이나 통과로 바꾸지 않습니다. 기존402capture HOLD와176 S DEATH 중간 접지HOLD도 별도로 보존합니다. 176등록 기술PASS는 camera·동작 승인이 아닙니다. staging `.gdignore` 분리는 네이티브 import/export 게임통합 승인이 아닙니다.

실행 순서는 다음과 같습니다.

1. delivery가 새 코드·fixture·현재 잔여상태·정적 검토 증거를 docs-only 커밋하고 최종40자리 HEAD를 전달합니다.
2. root가 `remaining-findings-final-gate-prepared-v05.json`을 새 `remaining-findings-final-completion-gate-v05.json`으로 복사합니다. 준비 원본은 수정하지 않습니다.
3. 새 gate에 최종 HEAD를 설정하고 실제 GPU·최신 통합runtime·보존v02 JSON의 path/SHA를 `integration_receipts`에 추가합니다. `targeted-runtime-correction-capture-hold-v02.json` path/SHA를 `targeted_active_quality_followups`에 추가합니다. 두 completion bool은 검사 완료를 뜻하며 CI/GPU 성공을 뜻하지 않습니다.
4. root의 완료 통지 뒤 아래 명령을 정확히1회 실행합니다. 출력이 이미 존재하면 중복 실행을 거절합니다.

```bash
python /workspace/legendary_work/docs/remake/pr122-legendary-parallel/reconcile_remaining_findings_v05.py --finalize --gate /workspace/legendary_work/docs/remake/pr122-legendary-parallel/remaining-findings-final-completion-gate-v05.json
```

출력은 `remaining-findings-final-v05.json`, `remaining-findings-final-v05-KO.md`입니다. 역사 issue 발생건수, 현재 활성 clip/원화의 실제잔여, 대체된 원본의 불확실성, QA환경 HOLD를 분리합니다. 해결은 정확한 source+issue+proofSHA+원격저장+실제 Godot검사가 일치하는 원인만 인정합니다.

현재 준비 시점의 실제 최종 corpus 대조 실행은0입니다. 순수 fixture18개와 authored-phase mapping fixture3개를 통과했습니다.
