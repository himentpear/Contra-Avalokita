# Headless CI

## Purpose

The headless CI gate is the project's minimum automated regression barrier. Every push to `main` and every pull request targeting `main` runs the same deterministic suite used locally.

The first version intentionally covers logic and scene integration only. Visual capture, screenshot comparison, export validation, and platform-specific packaging are outside this gate.

## Runtime

- Godot: 4.7.0
- Runner: `ubuntu-latest`
- Project root: `contra-avalokita/`
- Workflow: `.github/workflows/headless-ci.yml`
- Local runner: `ci/run_headless_tests.sh`
- Suite manifest: `ci/headless_tests.txt`

The workflow installs Godot through `chickensoft-games/setup-godot@v2` without .NET or export templates.

## Gate order

1. Import project resources with `godot --headless --import`.
2. Open the editor headlessly and quit, catching project/startup/resource parsing failures.
3. Execute every script listed in `ci/headless_tests.txt` with `godot --headless --script`.
4. Stop on the first non-zero exit code.

The test scripts are responsible for returning `0` on success and non-zero on failure. Existing SceneTree regression tests already follow this contract through `quit(1 if failures else 0)` or an equivalent expression.

## Initial formal suite

- `res://tests/smoke_test.gd`
- `res://tests/hitstop_manager_test.gd`
- `res://tests/movement_assist_test.gd`
- `res://tests/wall_movement_test.gd`
- `res://tests/ocean_wave_scene_test.gd`

These tests cover the project smoke path, hitstop lifecycle, movement-assist behavior, wall traversal regression, and the current procedural-ocean scene/API contract.

## Local use

From the repository root:

```bash
bash contra-avalokita/ci/run_headless_tests.sh
```

To use another Godot executable:

```bash
GODOT_BIN=/path/to/godot bash contra-avalokita/ci/run_headless_tests.sh
```

## Adding a test

Only add tests that are deterministic in headless mode and return a meaningful exit code. Add the `res://` path to `ci/headless_tests.txt`; do not add preview, screenshot-capture, or manual visual-inspection scripts to this suite.

Later test layers should remain separate:

- headless logic / scene integration
- visual regression
- export / playable build validation

This separation keeps the fast CI gate trustworthy instead of turning it into a slow mixed-purpose test bucket.
