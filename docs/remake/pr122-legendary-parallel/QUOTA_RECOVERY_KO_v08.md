# 원래 HTTP429 누락 7건의 한도 해제 후 1회 복구

이는 root가 명시한 bounded exception만 구현한 내부 실행 guard다. 사용자에게 새 승인을 요구하지 않는다. 기존 원본20 checkpoint/요청/claim/receipt/실패 원문은 수정하지 않는다.

대상은 qc021(274SW IDLE),qc023(273E IDLE),qc024(273SE IDLE),qc025(245NW IDLE),qc026(245NE IDLE),qc031(227SW IDLE),qc032(226SW IDLE)뿐이다. 일곱 원본 모두 HTTP429 usage_limit_reached·generated=null·최초시도1이라는 실제 원문을 검증한다. 한도 해제 뒤 qc033의 실제 성공 receipt/request/PNG provenance SHA를 계획에 고정한다. 이 근거는 도구 가용성만 입증하며 아트 승인 근거가 아니다.

계획: `quality-v02/quota-recovery-plan-v08.json`. producer `quality-v02/generate_quota_recovery_once_v05.js`를 `qualityQuotaRecoveryOnceV05` store 키에 로드하고, queue `quality-v02/quota_recovery_queue_v07.js`에 이 plan과 root 실행 flag를 전달한다. 기본 concurrency5다. helper는 `prepare_quota_recovery_v08.py`다. 기존 의존10개 batch309/310과 겹치지 않게 batch311에4행,312에3행을 저장한다. 이후 batch313부터 사용한다.

원래 READY71의 실제 tool receipt가 모두 있어야 claim할 수 있다. client 총시도는 기존 거절1+복구1=최대2, 성공 PNG는 최대1이다. source별 별도 `quota-recovery-once.lock`과 새 실제request stem으로 recovery claim/receipt/tool-result를 저장한다. 기존 PNG 성공이나 복구 claim/result가 있으면 호출을 막는다. 복구 중429가 하나라도 기록되면 같은 계획의 남은 신규 claim도 중지한다. 이미 시작된 정상 요청은 보존한다. 실패한 복구를 다시 호출하지 않는다.

기존13 성공, 모든 카메라/역할 HOLD,274NE ATTACK moderation은 이 계획에 없다. 245NW/NE 복구가 성공하고 새 카메라·대기guard·원격저장 근거가 검증된 경우에만 후속 별도 의존 계획에서 부모 조건을 해제할 수 있다. 338N 역할 HOLD는 계속 남는다. 실제 이미지는 root만 생성한다. 전용 helper 준비·순수fixture·계획 작성에서는 이미지/claim/전체 corpus audit이 모두0이다.
