extends SceneTree
## Guards the boot-time spawn admission speedups:
## 1. source_v1_grid.mask() (3x3 snapshot) equals the reference can_step() bits,
##    including borders, open/closed doors, clips and artwork restriction.
## 2. The persistent admission cache round-trips and rejects foreign or corrupt files.
const GRID = preload("res://scripts/maps/source_v1_grid.gd")
const SPAWNS = preload("res://scripts/maps/source_map_spawns.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SPAWN_ADMISSION_CACHE_FAIL: ", label)

func grid_case(seed_value: int, artwork: bool) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var size := Vector2i(130, 70)
	var raw := PackedByteArray()
	raw.resize(size.x * size.y)
	for i: int in raw.size():
		raw[i] = rng.randi_range(0, 255)
	var grid = GRID.new()
	if not grid.configure(77, [100, 200, 100 + size.x - 1, 200 + size.y - 1], size, raw):
		return -1
	if artwork:
		grid.restrict_to_artwork([{"world_bounds": [100, 200, 163, 263]}, {"world_bounds": [164, 200, 227, 263]}])
	for i: int in 160:
		var c := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		match i % 3:
			0: grid.open_doors[c] = true
			1: grid.closed_doors[c] = true
			2: grid.clipped_cells[c] = true
	var mismatches := 0
	for y: int in range(-1, size.y + 1):
		for x: int in range(-1, size.x + 1):
			var c := Vector2i(x, y)
			grid.masks.clear()
			if grid.mask(c) != grid.mask_reference(c):
				mismatches += 1
	return mismatches

func run() -> void:
	for seed_value: int in [1, 7, 20261105]:
		check(grid_case(seed_value, false) == 0, "fast mask equals can_step reference, seed %d" % seed_value)
		check(grid_case(seed_value + 1, true) == 0, "fast mask equals reference with artwork restriction, seed %d" % seed_value)
	var key := "test_" + str(Time.get_ticks_usec())
	var rows := {"source3:a": {"bounds": [1.0, 2.0, 3.0, 4.0], "cells": PackedInt32Array([5, 9]), "minimum": Vector2(1, 2), "maximum": Vector2(3, 4), "rejected": {"portal_clearance": 2}}}
	SPAWNS._write_disk_cache(key, rows)
	var loaded: Dictionary = SPAWNS._read_disk_cache(key)
	check(loaded.has("source3:a") and loaded["source3:a"].cells == PackedInt32Array([5, 9]) and loaded["source3:a"].maximum == Vector2(3, 4), "admission cache round-trips cells and bounds")
	check(SPAWNS._read_disk_cache("missing_" + key).is_empty(), "absent cache file is a miss")
	check(SPAWNS._read_disk_cache("").is_empty(), "uncacheable inputs never read a file")
	var path: String = SPAWNS.DISK_CACHE_DIR + "/" + key + ".bin"
	var valid: PackedByteArray = FileAccess.get_file_as_bytes(path)
	SPAWNS._write_disk_cache("other_" + key, rows)
	var other_path: String = SPAWNS.DISK_CACHE_DIR + "/other_" + key + ".bin"
	DirAccess.copy_absolute(other_path, path)
	check(SPAWNS._read_disk_cache(key).is_empty(), "a file stored under another key is rejected")
	DirAccess.remove_absolute(other_path)
	SPAWNS._write_disk_cache(key, {"source3:a": {"cells": [1, 2]}})
	check(SPAWNS._read_disk_cache(key).is_empty(), "malformed rows are rejected")
	var flipped := valid.duplicate()
	flipped[flipped.size() - 3] ^= 0x5A
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(flipped)
	file.close()
	check(SPAWNS._read_disk_cache(key).is_empty(), "a flipped payload byte fails the digest")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(valid.slice(0, valid.size() - 10))
	file.close()
	check(SPAWNS._read_disk_cache(key).is_empty(), "a truncated file is a miss")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a cache file at all, just text padding to pass size")
	file.close()
	check(SPAWNS._read_disk_cache(key).is_empty(), "foreign bytes are rejected")
	DirAccess.remove_absolute(path)
	print("SPAWN_ADMISSION_CACHE_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
