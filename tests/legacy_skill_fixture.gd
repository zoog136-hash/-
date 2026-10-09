extends RefCounted

## These older suites verify preservation of the 257-entry archive and the old
## execution adapter. They are not evidence of original Lineage M correctness.
## Normal gameplay never calls this fixture. New original tests use real books.
static func install(world: Node) -> void:
	world.skills_db = world.legacy_skills_db.duplicate(true)
	world.hud.set_job_data(world.job_classes, world.skills_db)
