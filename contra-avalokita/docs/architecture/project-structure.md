# Project Structure

Contra-Avalokita uses a staged architecture. Dependencies point downward through boot, core, gameplay interfaces, and content; UI calls public Core or Gameplay APIs. Base game, DLC, and mods are packages rather than special cases in Core.

```text
bootstrap/              Early startup and package mounting
core/
  app/                  Application lifetime and version
  content/              Manifest, definition, dependency and registry APIs
  debug/                Shared command registry
  events/               Cross-system application events
  save/                 Schemas, serialization and migrations
  settings/             User settings
gameplay/
  world/                Session-owned world resolution
content/base/           Base content pack and stable definitions
extensions/dlc/         DLC contract examples (test package only)
ui/console/             Console and command-palette surface
tests/character/        Character integration arena
docs/media/             Maintained README media
```

Legacy `scripts/`, `scenes/`, `resources/`, `shaders/`, and most of `artifacts/` remain during the compatibility phase. High-coupling character and renderer files move only after their references and behavior have dedicated regression coverage.

## Startup

`project.godot` starts `bootstrap/boot.tscn`. Boot mounts package files, resolves manifest dependencies, initializes `ContentRegistry`, settings, and saves, then routes to `tests/character/test_arena.tscn` until a main menu exists.

Application Autoloads are `Game`, `EventBus`, `ContentRegistry`, `Settings`, `SaveManager`, `CommandRegistry`, and `Console`. Gameplay state is owned by `GameSession`, whose children are `WorldManager`, `RunManager`, and `CombatContext`; `ScoreSystem` is owned by `RunManager` and is no longer an Autoload.

## Dependency Rules

- Core contains no base-game, DLC, or mod identity checks.
- Gameplay depends on stable interfaces, not a particular content pack.
- Content definitions may reference Gameplay scenes/resources.
- Persisted content references use `StringName` IDs in `namespace:item` form.
- Local signals remain preferred within a subsystem; EventBus is for true cross-system lifecycle events.

## Content Packages

Every package provides a `ContentManifest`. Boot treats `content/base/manifest.tres` and extension manifests through one resolver. IDs are validated and duplicate IDs, missing dependencies, cycles, invalid namespaces, and null resources are rejected.

`base:sword` is the first production definition. `test_dlc:red_sword` exercises the same public path and is explicitly test-only. Runtime `.pck` files may be mounted from `user://dlc/` and `user://mods/`; scripted mods are executable code and are not a security sandbox. Data mods are reserved for declarative JSON/assets and must not execute GDScript.

## Save Ownership

A campaign is a world line. It owns exactly one authoritative WorldState and a WorldEventLedger plus independent CharacterState entries. Each character may own an ActiveRun. Characters publish world effects; they never edit another character's state.

All campaign files carry `schema_version`, `game_version`, `campaign_id`, and package versions. Missing content resolves to a structured placeholder rather than crashing. `SaveMigrator` is the only place that upgrades older schemas.

## Migration Sequence

1. Stabilize Boot/Core/Content/Save/Console while legacy gameplay stays intact.
2. Add regression coverage, then colocate character/combat/render groups one at a time.
3. Register remaining base weapons, equipment, morphs, enemies, and levels.
4. Bind campaign switching and persisted active runs to the session-owned WorldManager and RunManager.
5. Add main menu, save selection, content browser, and explicit executable-mod warnings.
