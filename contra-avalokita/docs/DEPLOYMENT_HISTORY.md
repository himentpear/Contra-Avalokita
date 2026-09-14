# Deployment History

This document records repository-level engineering deployments that change build, test, release, or runtime infrastructure. Git history remains the source of truth for exact diffs.

## 2026-09-14 — Godot 4.7 headless CI baseline

**Type:** QA / CI infrastructure  
**Status:** deployed to `main`  
**Baseline before deployment:** `e23951d080780abe71955703eb935298723f512b`

### Scope

Established the project's first formal automated regression gate for Godot 4.7.

Deployed components:

- `.github/workflows/headless-ci.yml`
- `contra-avalokita/ci/run_headless_tests.sh`
- `contra-avalokita/ci/headless_tests.txt`
- `contra-avalokita/docs/HEADLESS_CI.md`
- `contra-avalokita/docs/DEPLOYMENT_HISTORY.md`

### Gate behavior

The CI runs on pushes to `main`, pull requests targeting `main`, and manual workflow dispatch. It performs:

1. Godot 4.7.0 runtime setup on Ubuntu.
2. Headless resource import.
3. Headless project startup/editor parse check.
4. Five formal regression scripts executed sequentially.
5. Immediate failure propagation through process exit codes.

Initial formal suite:

- `smoke_test.gd`
- `hitstop_manager_test.gd`
- `movement_assist_test.gd`
- `wall_movement_test.gd`
- `ocean_wave_scene_test.gd`

### Risk reduction

This deployment converts existing regression scripts from passive repository assets into an enforced integration gate. It specifically protects the current gameplay foundation across smoke/startup behavior, hitstop, movement assists, wall traversal, and procedural-ocean scene integration.

### Known exclusions

The baseline intentionally does not run visual preview/capture scripts, screenshot comparison, Windows export validation, performance benchmarking, or playable-build packaging. Those belong to later CI layers and should not be mixed into the fast headless gate.

### Rollback

Revert the deployment commit. No project save data, gameplay resources, or runtime schemas are migrated by this change.
