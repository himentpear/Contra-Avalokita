# Unified Test Arena Package

`res://scenes/test_arena.tscn` is the only interactive/manual test arena.

Canonical test-arena-only implementation resources live under `res://scenes/test_arena/resources/`:

- `test_arena.gd`
- `training_dummy.gd`
- `test_dummy_target.gd`
- `training_enemy_controller.gd`

Shared gameplay and production-capable resources stay in their domain directories (for example `mud_character.tscn`, rendering systems, Coyote items, and reusable environment art) so production content never depends on this test package.

The matching files under `res://scripts/` are compatibility shims only. They contain no test implementation and exist temporarily so legacy automated tests and scene references continue to resolve while paths are migrated incrementally.

The obsolete `res://scenes/wall_movement_test.tscn` was removed. Wall mechanics are exercised inside the unified arena and by automated test scripts instead of a second interactive scene.
