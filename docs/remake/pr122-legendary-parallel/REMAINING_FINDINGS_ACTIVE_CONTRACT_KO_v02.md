전설급 잔여 보고 v02 입력 계약

이 문서는 최종 실행 전 준비 자료입니다. PNG 재열람, 새 시각 검토, 이미지 생성, 최종 reconciliation 실행은 모두 0입니다. v01 코드와 확정 원본 검토는 보존합니다.

`reconcile_remaining_findings_v02.py`는 SHA로 고정한 v01 증거 판정 함수를 재사용하고, `active_findings_projection_v02.py`로 현재 선택된 clip과 역사 원본을 구분합니다. `--prepare-gate`는 완료 영수증의 경로·SHA만 수집하며 해결 건수를 계산하지 않습니다.

준비 gate는 `remaining-findings-final-gate-prepared-v02.json`입니다. 실제 `REMOTE_SAVED` 37개 배치(ownership 33, quality 4)와 176 별도 원격 영수증, 13개 변경 원화의 단일 시각/기술 검토 SHA를 연결했습니다. pending 영수증은 입력에서 제외합니다.

자산 기준은 `d8aefaeb3c47c211fa66d76d1950cbda3130ba1b`이며 staging SHA는 `1d64457811204c04f2ab9014b74d46158774fede412ebaf0199f1ec18c05f32b`, active manifest SHA는 `05dc2159db8cea02e4c9bdfe860eea62757db4b186281db06feb998756acfa9c`입니다. active revision 776은 중복 제거한 선택 슬롯 수이고, delta 71은 수정 event 수입니다. 서로 합산하지 않습니다.

Root가 최종 런타임·CI 결과를 받은 뒤 준비 gate를 새 파일에 복사하여 다음 필드만 완성합니다.

- `repository_head`: 보고 코드와 증거가 들어 있는 최종 40자리 commit.
- `integration_receipts`: 실제 마지막 런타임·CI 결과 JSON의 정확한 `{path, sha256}` 배열. 보고서에 staging/manifest SHA가 있으면 동결 입력과 일치해야 합니다. 실패 결과도 원문으로 보존하며 승인으로 확대하지 않습니다.
- `all_possible_corrections_complete`, `local_integration_checks_complete`: 모든 가능한 수정과 실제 검사가 끝난 후에만 `true`.
- `output_stem`: 처음 생성할 최종 보고 이름. 동일 보고 JSON/MD가 있으면 재실행하지 않습니다.
- `targeted_active_quality_followups`: 변경부 runtime 확인에서 새로 남은 HOLD/ERROR의 `{path,sha256}` 배열. 각 JSON의 `findings`에는 `slot`, `cause`, `status`, `detail`, `frames`, `active_record`, `active_record_sha256`, `rendered_evidence:{path,sha256}`를 둡니다. 현재 선택 record SHA가 일치한 잔여만 별도 추가하고, 이 입력으로 해결·승인하지 않습니다. 예를 들어176 S DEATH의 phase4 접지/연속성 HOLD를 기존 frozen 변경 없이 연결합니다.

그 뒤 한 번만 실행합니다.

```sh
python docs/remake/pr122-legendary-parallel/reconcile_remaining_findings_v02.py --finalize --gate /workspace/legendary_work/docs/remake/pr122-legendary-parallel/root-completed-final-gate-v02.json
```

최종 JSON의 역사 영역인 `visual_findings`, `technical_source_findings`, `technical_slot_findings`는 기존 `resolution_status`를 유지합니다. 별도 `active_annotation`에 선택된 record/source SHA, 정확한 이전 record의 revision 관계, 다른 동작에 빌려 쓴 원화의 활성 여부, quality 대체 여부를 붙입니다. 원본 source의 일부 프레임이 다른 clip에 계속 쓰이면 전체가 대체됐다고 표시하지 않습니다.

`SUPERSEDED_REQUIRES_QA`는 변경된 활성 clip에서 옛 결함의 잔존 여부를 확정하지 못한 상태입니다. 결함이 그대로 남았다는 확정과 구분합니다. 정확한 13개 변경 source 기술 index에서 같은 source-level 코드가 없거나 새 lossless proof로 그 코드의 모든 해당 phase가 해결된 경우에만 해당 원인의 활성 투영을 대체 처리합니다. 시각적 잘림, 카메라, 외형, 동작, 접지는 그 판정에 포함하지 않습니다. 카메라 정정 11건은 실제 새 source/그 lossless derivative가 선택됐을 때만 활성 해결로 이어집니다. 339 SW·275 SW 카메라와338 N IDLE 동작 HOLD는 별도 유지합니다.

176의 33구성/198프레임 등록 증거는 기술 범위입니다. 이전 scale/foot HOLD와 현재 revised record의 관계를 표시하고, 카메라·동작 승인으로 처리하지 않습니다.

`active_residual_issue_projections`는 현재 구성에 투영한 issue 발생건수입니다. `active_residual_clips_by_cause_and_severity`는 원인별 `ERROR/HOLD/BLOCKED`와 `key/direction/role`을 중복 제거한 정확 목록이고, `active_residual_unique_clips`는 원인 간에도 중복 제거한 전체 구성 목록입니다. 원인별 수를 합해 전체 clip 수로 사용하지 않습니다. 참조 source 파일 수는 확인된 불량 원화 수와 별도 단위입니다.

원래274 NE ATTACK moderation 미생성1개, 추가 교정 API한도 실패7개, 아예 호출하지 않은106개는 구분합니다. API한도 실패는 기존 clip의 유실을 뜻하지 않습니다. 정상 PNG 재생성, quota 재시도, 유료 API 호출, 신화급/카탈로그/저장 데이터/전투 변경은 없습니다.
