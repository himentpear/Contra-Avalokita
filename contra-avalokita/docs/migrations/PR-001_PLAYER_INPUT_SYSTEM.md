# PR-001 Migration Report: PlayerInputSystem

日期：2026-09-14  
阶段：ECS Migration Phase 1  
状态：Implemented and verified

## Scope

本 PR 只迁移 Player 输入采样的所有权：

- 从 `scripts/mud_character.gd` 移除全部直接 `Input.*` / `InputMap.*` 轮询；
- 新增纯数据 `IntentComponent`；
- 新增集中式 `PlayerInputSystem`；
- PlayerInputSystem 继续调用原有 `MudCharacter.set_intent()`；
- AI、Enemy、测试和脚本控制器继续直接调用同一个 `set_intent()`；
- 装备切换、武器切换和 rig debug 输入只迁移路由位置，原处理逻辑不变。

本 PR 没有修改 AnimationPlayer、攻击/伤害计算、Hitbox/Hurtbox、Rogue/Karma、移动公式或墙跳公式。

## Files

| 文件 | 变更 |
|---|---|
| `gameplay/components/movement/intent_component.gd` | 新增纯数据输入意图组件 |
| `gameplay/systems/input/player_input_system.gd` | 新增 Player 输入轮询与 legacy forwarding System |
| `scripts/mud_character.gd` | 注册为输入实体；持有 entity-local IntentComponent；删除直接 Input polling；`set_intent()` 同步组件 |
| `project.godot` | 注册 `PlayerInput` Autoload，保证独立角色测试和正式 Level 使用同一 System |
| `tests/player_input_system_test.gd` | 新增 Player/Enemy intent 和无直接轮询回归测试 |

## Runtime flow

迁移前：

```text
MudCharacter._physics_process
  -> Input polling
  -> set_intent
  -> existing movement/wall/combat/animation pipeline
```

迁移后：

```text
PlayerInputSystem._physics_process
  -> query player_input_entities
  -> sample Input into IntentComponent
  -> MudCharacter.set_intent
  -> existing movement/wall/combat/animation pipeline (unchanged)

Enemy/AI controller
  -> MudCharacter.set_intent
  -> same IntentComponent + existing pipeline
```

`IntentComponent` 在本阶段是 shadow/transport data。移动仍读取 legacy `move_intent`、`jump_requested`、`attack_requested` 和 `block_requested`，避免在输入抽离 PR 中同时切换 Movement/Combat writer。

## Behavior preservation

- 非 Sprint 输入仍乘 `walk_speed_ratio`；Sprint 输入仍为完整轴值；
- jump/attack 仍使用 `is_action_just_pressed`；block 仍使用 held 状态；
- 本地 Hitstop (`local_time_scale <= 0`) 和 Dead 状态下不采样，保持原 `_physics_process` early-return 语义；
- `player_controlled == false` 时 System 不写 intent，Enemy/测试可继续调用 `set_intent()`；
- 多个 `player_controlled` Entity 的行为与迁移前一致：它们都会接收同一设备输入；
- 移动、墙跳、攻击、动画和装备内部实现没有更改。

## Verification

使用 Godot 4.7.1 stable 执行：

| 验证 | 结果 |
|---|---|
| Headless editor project parse | PASS |
| Main project boot, 120 frames | PASS, exit code 0 |
| `tests/player_input_system_test.gd` | PASS, 0 failures |
| `tests/smoke_test.gd` | PASS, 0 failures |
| `tests/movement_assist_physics_test.gd` | PASS, 0 failures |
| `tests/wall_jump_integration_test.gd` | PASS, 0 failures |
| `tests/wall_jump_system_test.gd` | PASS, 0 failures |
| `tests/block_test.gd` | PASS, 0 failures |

覆盖内容包括：Player Walk/Sprint 输入、普通移动、jump/coyote/buffer、左右墙的 Climb/Standard/Kick、wall coyote、同墙衰减、双墙 Z 跳、Enemy/scripted `set_intent()`、Player block held/release。

## Known existing warnings

测试仍会报告迁移前已存在的 Sword script UID fallback warning。部分完整场景/Smoke 退出时仍报告 ObjectDB/resource cleanup warning；所有相关命令的退出码为 0，且本 PR 没有修改这些资源或生命周期逻辑。

## Rollback boundary

回滚只需：

1. 从 `project.godot` 移除 `PlayerInput` Autoload；
2. 恢复 `MudCharacter._physics_process()` 中原输入分支；
3. 移除输入 group 注册和 IntentComponent mirror；
4. 删除新增 component/system/test。

无需回滚任何 movement、wall jump、combat、animation、hitbox 或 rogue 数据。

## Next phase guardrail

下一 PR 不应顺便把 Movement 改为读取 IntentComponent。Movement writer 的切换必须是独立 PR，并继续保留 Player/Enemy 共用 `set_intent()` 的兼容 facade，直到所有控制器与测试完成迁移。
