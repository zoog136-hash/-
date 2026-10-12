# PR59 actual merge diagnostics

- Source PR59 head before attempt: `a53550b80ba4fc1217af1a397084c0c618996d5a`
- Target main: `cfbf0fb4307fbb6694163504eb49692f3e3391bf`
- Automatic merge exit code: 1

## Git merge output
~~~text
Auto-merging README.md
CONFLICT (content): Merge conflict in README.md
Auto-merging scripts/hud.gd
Auto-merging scripts/hud_v20.gd
Auto-merging scripts/monster.gd
Auto-merging scripts/world.gd
CONFLICT (content): Merge conflict in scripts/world.gd
Automatic merge failed; fix conflicts and then commit the result.
~~~

## Unmerged paths
~~~text
README.md
scripts/world.gd
~~~

## Conflict hunk text (first 300 lines per file)

### `README.md`
~~~text
<<<<<<< HEAD
원작 스킬 이행 작업은 별도 feature 브랜치의 검증 중인 변경입니다. [조사 도감](docs/skills/CATALOG.md), [검증·미완료 보고서](docs/skills/VALIDATION.md), [구현 구조와 재개 절차](docs/skills/IMPLEMENTATION.md)를 참고하세요. 2025-06-17의 전체 스킬 목록과 원작 이펙트 복원이 완료된 상태는 아닙니다. 원본 257개 스킬 DB는 보존하고, 활성 도감은 날짜가 확인된 자료를 바탕으로 실행을 연결한 별도 DB를 사용합니다.
=======
## 리소스 누락 방지 자동검사 (2026-10-11)

새 Work를 시작하기 전 [리소스 상태 장부](data/resource_delivery_ledger.json)와 [필수 리소스 확인 절차](docs/RESOURCE_INTEGRITY_POLICY.md)를 확인하십시오. `python3 tools/check_resource_integrity.py --root .`은 Git에 실제 포함된 시트 723개와 SHA/매핑을 전수 검사합니다. 업로드된 원본 ZIP이나 외부 팩이 자동으로 GitHub 또는 배포본에 포함되는 것은 **아닙니다**. 원본 전달은 별도 ZIP/영수증 및 깨끗한 환경 재검증이 있어야 완료로 보고합니다.
>>>>>>> origin/main
~~~

### `scripts/world.gd`
~~~text
<<<<<<< HEAD
=======
	file.store_string(JSON.stringify(data,"",true,true))
	file.close()
>>>>>>> origin/main
<<<<<<< HEAD
	if original_skills != null and not data.has("original_skill_state") and not FileAccess.file_exists(SAVE_PATH + ".pre-original-skills"):
		var backup_error := DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".pre-original-skills")
		if backup_error != OK:
			hud.append_log("스킬 저장 이전 중단 · 원본 백업 실패 · 오류 %d" % backup_error)
			if not quiet: hud.show_message("저장 이전 백업 실패")
			return
=======
	var saved_map_id: String = str(data.get("map_id", ""))
	if saved_map_id.begins_with("l1_"):
		var saved_field: OriginalPlayableField = SOURCE_TRAVEL.load_field(maps_by_id.get(saved_map_id,{}))
		if saved_field == null:
			source_save_blocked = true
			hud.show_message("원본 맵 팩 누락·손상: 기존 저장 보존 중")
			return
		saved_field.close()
	source_save_blocked = false
>>>>>>> origin/main
~~~
