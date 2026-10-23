확정 오류 목록의 SHA256은 `bce7e7260712a27515627806a88690158f47bf8ddf4cd172dba5b5ba3eee00c6`입니다. 보고 코드는 PNG를 열거나 원화·리소스를 변경하지 않습니다. `remaining-findings-pending-draft-v01.json`과 `remaining-findings-pending-draft-v01-KO.md`는 CI 전 미수정·보류 목록 준비 자료이며 최종 해결 집계가 아닙니다.

최종 실행은 모든 가능한 수정과 실제 런타임·CI 결과가 나온 뒤 root가 완료 gate JSON을 채워 한 번 수행합니다. `remaining-findings-final-gate-template-v01.json`의 두 완료 값을 true로 설정하고 최종 Git HEAD40자와 각 증거의 실제 SHA256을 기록합니다. pending-remote 영수증과 예상 누적치는 사용할 수 없습니다.

- `ownership_batches`: 각 완료 배치의 `manifest`, `validations` 목록, `remote_receipt`. 각 증거는 `{path, sha256}` 형식입니다.
- `targeted_technical_artifacts`: 새 quality 원화만 검사한 source_findings JSON의 `{path, sha256}` 목록. proof의 `source_review_sha256`은 해당 JSON SHA와 같아야 합니다. 원래 frozen 기술목록은 바꾸지 않습니다.
- `quality`: 변경부 `review`, 실제 원화·record SHA를 고정한 `exact_receipt`, `quota_checkpoint`, 각 완료 배치의 `batches` 증거입니다.
- `native176`: `library`, `review_input`, `validations`, `remote_receipt`. 실패 후 회복한 검사 보고는 순서대로 넣어 같은 record의 마지막 결과를 적용합니다. 기술등록 결과는 별도로 기록하며 카메라·외형·동작을 승인하지 않습니다.
- `integration_receipts`: 최종 실제 런타임·CI 결과 JSON의 `{path, sha256}` 목록입니다. PASS뿐 아니라 실제 FAIL/BLOCKED 결과도 그대로 보존합니다.
- 선택적인 `visual_issue_adjudications`: 정확한 frozen issue에 대한 기술 겹침 해결 판정입니다. `claims`의 각 행은 `issue_id`, `source`, `source_sha256`, `proof_sha256`, `affected_phases`, `resolution_scope: TECHNICAL_OWNERSHIP_ONLY`를 가집니다. 이 매핑이 없으면 복합 시각 finding의 잘림·외부 몸 문제는 기술 proof coverage가 있어도 HOLD로 남습니다.

```bash
python3 /workspace/legendary_work/docs/remake/pr122-legendary-parallel/reconcile_remaining_findings_v01.py --finalize --gate /workspace/legendary_work/docs/remake/pr122-legendary-parallel/remaining-findings-final-gate-v01.json
```

출력은 전용 WORK docs 경로의 `remaining-findings-final-v01.json`과 `remaining-findings-final-v01-KO.md`입니다. 파일이 이미 있으면 두 번째 최종 집계를 시작하지 않습니다. 누락274 NE ATTACK1건, API한도 교정 실패7건, 미호출106건, 변경 원화의 잔여 HOLD를 서로 다른 목록으로 유지합니다. 각 원인에는 정확한 actor·방향·동작·source·issue·SHA·proof가 연결됩니다. 원본 frozen 집계, 새 quality 후속 기술 finding, 구성·프레임 수는 합산하지 않습니다.
