# MudCharacter 依赖与职责分析报告

**目标文件**：`scripts/mud_character.gd` (1421 行)  
**分析日期**：2026-09-14  
**架构目标**：解耦为 `MovementComponent`、`HealthComponent`、`CombatComponent`、`AnimationController`、`EquipmentController`、`SDFBodyController` 六大组件。

---

## 一、信号映射表 (Signals)

| 原始信号 | 所属职责 | 迁移目标组件 | 中继方式 / 外部调用方 |
|---|---|---|---|
| `state_changed(previous, current)` | 状态流转 | `AnimationController` / `MudCharacter` | 宿主监听后向外转发，测试和UI监听 |
| `damaged(amount)` | 生命受损 | `HealthComponent` | 宿主监听并向外发出，KillScore系统监听 |
| `footstep(side)` | 步态接触 | `MovementComponent` | 触发脚部粘滞和音效 |
| `landed(impact_speed, hard)` | 落地冲击 | `MovementComponent` | 触发落地硬直与特效 |
| `wall_action_changed(previous, current)` | 墙体动作状态 | `MovementComponent` | 墙体姿势合成器 (`MudWallPoseComposer`) 监听 |
| `wall_jumped(direction)` | 蹬墙跳 | `MovementComponent` | 特效与摄像机监听 |
| `unfallen_started(duration)` | 土偶滞空宽限 | `MovementComponent` | UI 与测试用例监听 |
| `unfallen_ended` | 宽限结束 | `MovementComponent` | UI 与测试用例监听 |
| `jump_executed(source)` | 跳跃执行 | `MovementComponent` | 动作统计与测试用例监听 |

---

## 二、状态变量与导出参数职责分布

### 1. 移动与跳跃 (Movement & Wall Movement)
- **参数**: `jump_squat_duration`, `takeoff_duration`, `minimum_landing_air_time`, `soft_landing_speed`, `hard_landing_speed`, `apex_threshold`, `landing_recovery_duration`, `base_coyote_time`, `base_jump_buffer_time`, `movement_assist_debug`, `move_speed`, `walk_speed_ratio`, `acceleration`, `gravity`, `jump_velocity`
- **墙体参数**: `wall_slide_speed`, `wall_hang_duration`, `wall_stick_speed`, `wall_grab_upward_limit`, `wall_climb_jump_velocity`, `wall_climb_detach_velocity`, `wall_jump_horizontal_speed`, `wall_jump_vertical_speed`, `wall_kick_horizontal_velocity`, `wall_kick_velocity`, `wall_push_duration`, `wall_release_duration`, `wall_coyote_time`, `wall_detach_time`, `wall_detach_grace`, `wall_jump_control_lock_time`, `wall_jump_air_control`, `wall_input_deadzone`, `same_wall_reset_time`, `wall_climb_decay`, `wall_max_foot_lag`, `wall_min_foot_below_hip`
- **运行时**: `air_time`, `last_air_velocity_y`, `jump_phase`, `jump_squat_left`, `landing_left`, `landing_animation`, `grounded_resume_phase`, `movement_assist`, `item_inventory`, `pending_jump_source`, `wall_action`, `wall_side`, `wall_action_time`, `wall_hang_left`, `wall_regrab_left`, `wall_coyote_left`, `wall_detach_left`, `wall_jump_control_lock_left`, `wall_detach_grace_left`, `wall_coyote_side`, `wall_coyote_collider_id`, `same_wall_jump_count`, `same_wall_collider_id`, `same_wall_side`, `same_wall_reset_left`, `pending_wall_jump_kind`, `pending_wall_launch`, `wall_surface_x`, `wall_hand_anchor_y`, `wall_foot_anchor_y`, `wall_slide_scrape_offset`, `wall_front_knee_sign`, `wall_back_knee_sign`
- **迁移目标**: `MovementComponent`

### 2. 生命与韧性 (Health & Poise)
- **参数**: `max_health`, `max_stability`, `stability_recovery_rate`, `stability_recovery_cooldown`
- **运行时**: `health`, `stability`, `stability_cooldown_timer`
- **迁移目标**: `HealthComponent`

### 3. 战斗与受击 (Combat & Reaction)
- **参数**: `attack_duration`, `allow_air_attack`, `attack_movement_multiplier`, `guard_movement_multiplier`, `punch_animations`, `punch_windows`, `punch_damages`, `punch_impacts`, `punch_combo_buffer_start`, `hit_flash_duration`, `hit_flash_peak`, `hit_flash_color`, `score_profile`, `score_credit_enabled`, `score_combat_power`
- **运行时**: `action_state`, `attack_time`, `combo_stage`, `combo_queued`, `attack_requested`, `block_requested`, `punch_hitbox`, `punch_collision_shape`, `punch_hit_targets`, `reaction_state`, `reaction_time`, `reaction_duration`, `reaction_direction`, `reaction_intensity`, `reaction_region`, `reaction_impact_local`, `hit_flash_remaining`, `_hit_flash_total`, `_hit_flash_active_peak`, `hit_drag_timer`, `hit_drag_ratio`, `reaction_push_offset`, `local_time_scale`, `score_life_id`, `score_attack_serial`
- **迁移目标**: `CombatComponent`

### 4. 动画与外观状态 (Animation & Locomotion State)
- **运行时**: `state`, `facing`, `move_intent`, `land_time`
- **迁移目标**: `AnimationController` 与 `MudCharacter` 状态调度

---

## 三、函数迁移全景清单

| 函数名 | 行号 | 当前职责 | 迁移目标组件 | 迁移后调用方式 / 门面设计 |
|---|---|---|---|---|
| `is_wall_attached()` | 88 | 判断是否处于挂墙或滑墙 | `MovementComponent` | `MudCharacter` 转发：`movement_component.is_wall_attached()` |
| `is_wall_jump_action()` | 91 | 判断是否处于墙面跳跃蹬伸/释放 | `MovementComponent` | `movement_component.is_wall_jump_action()` |
| `_set_wall_action(next)` | 94 | 切换墙体动作状态并触发信号 | `MovementComponent` | 内部状态流转，触发 `wall_action_changed` 信号 |
| `_contact_wall_side()` | 106 | 基于法线检测接触墙体方向 | `MovementComponent` | 内部物理查询 |
| `_can_hold_wall(side)` | 114 | 判定输入与脱离CD是否允许挂墙 | `MovementComponent` | 内部逻辑 |
| `_contact_wall_collider_id(side)` | 117 | 获取接触碰撞体 instance_id | `MovementComponent` | 内部物理查询 |
| `_same_wall_matches(id, side)` | 129 | 判断是否为同一面墙 | `MovementComponent` | 连续攀爬疲劳判定 |
| `_reset_same_wall_tracking(...)` | 136 | 重置同墙攀爬计数 | `MovementComponent` | 内部逻辑 |
| `_reset_wall_runtime()` | 142 | 重置全部墙体物理与计时状态 | `MovementComponent` | 内部逻辑 / `reset()` 接口 |
| `_detach_wall_pose_for_reaction()` | 157 | 受击时强制脱离墙面姿态 | `MovementComponent` | 供受击/反应模块通过宿主调用 |
| `_update_wall_memory(delta, grounded)` | 169 | 维护墙面Coyote时间与脱离计时 | `MovementComponent` | 内部每帧更新 |
| `_capture_wall_surface(side)` | 196 | 捕获墙面精确碰撞物理坐标X | `MovementComponent` | 内部物理查询 |
| `wall_plane_local_x()` | 206 | 计算视觉局部空间下的墙面X平面 | `MovementComponent` | `MudCharacter` 门面：姿势合成器 (`MudWallPoseComposer`) 必需 |
| `_enter_wall_hang(side)` | 212 | 进入挂墙状态并初始化锚点 | `MovementComponent` | 内部逻辑 |
| `_update_wall_before_move(delta)` | 227 | `move_and_slide()` 前物理速度与悬挂计算 | `MovementComponent` | 物理阶段调用 |
| `_update_wall_after_move()` | 287 | `move_and_slide()` 后二次吸附校验 | `MovementComponent` | 物理阶段调用 |
| `_can_start_wall_jump()` | 299 | 校验是否允许蹬墙跳 | `MovementComponent` | 内部判断 |
| `_start_wall_jump()` | 302 | 执行爬墙跳、蹬离跳或标准跳 | `MovementComponent` | 内部物理逻辑 |
| `update_jump_animation()` | 341 | 将空中/墙体相位同步至动画播放器 | `AnimationController` | 动画组件根据移动相位驱动 |
| `has_reaction()` | 432 | 判断当前是否有生效受击硬直 | `CombatComponent` | `MudCharacter` 门面转发 |
| `is_blocking()` | 438 | 判断当前是否处于格挡防守中 | `CombatComponent` | `MudCharacter` 门面转发 |
| `is_attacking()` | 441 | 判断当前是否处于攻击动作中 | `CombatComponent` | `MudCharacter` 门面转发 |
| `set_local_time_scale(scale)` | 446 | 统一局部时间缩放 (Hitstop 接口) | `CombatComponent` / `MudCharacter` | 影响动画与物理速度 |
| `attack_animation()` | 451 | 评估当前应该播放的攻击剪辑名 | `CombatComponent` | 向动画组件请求播放 |
| `start_attack(stage)` | 462 | 启动特定连段攻击 | `CombatComponent` | 发出 `attack_started` 信号 |
| `cancel_attack_pose()` | 476 | 打断并重置攻击与 Hitbox | `CombatComponent` | 供受击或落地打断 |
| `clear_transient_pose_state(...)` | 488 | 清除攻击、受击、IK所有瞬态 | `MudCharacter` | 协调调用各组件的重置接口 |
| `get_arm_extension_ratio(back)` | 507 | 计算手臂伸展比例 | `CombatComponent` | 拳击范围判定 |
| `advance_attack(delta)` | 519 | 推进攻击计时与连招缓冲阶段 | `CombatComponent` | 战斗逻辑步进 |
| `calculate_punch_reach()` | 536 | 计算出拳距离归一化比值 | `CombatComponent` | 拳击有效碰撞判定 |
| `_update_punch_attack(delta)` | 544 | 激活拳击判定框并对齐拳头骨骼 | `CombatComponent` | 战斗逻辑步进 |
| `_on_punch_area_entered(area)` | 562 | 拳击命中处理与生成 HitEvent | `CombatComponent` | 发出 `hit_confirmed` 信号 |
| `get_local_fx_socket(channel)` | 628 | 获取局部特效插槽节点 | `MudCharacter` / `SDFBodyController` | 表现层查询 |
| `set_intent(dir, jump, atk, blk)` | 781 | 统一输入缝 (AI/玩家控制) | `MudCharacter` | 分发至 `MovementComponent` & `CombatComponent` |
| `_recompute_movement_modifiers()` | 794 | 道具属性加成汇算 | `MovementComponent` | 监听背包变化自动汇算 |
| `obtain_item(item)` | 797 | 获得土偶辅助道具 | `MovementComponent` | 背包逻辑 |
| `remove_item(item_id)` | 800 | 移除土偶辅助道具 | `MovementComponent` | 背包逻辑 |
| `obtain_content_item(id)` | 803 | 从内容注册表获取道具 | `MovementComponent` | 道具加载桥接 |
| `is_unfallen()` | 811 | 查询是否处于不堕宽限状态 | `MovementComponent` | `MudCharacter` 门面转发 |
| `has_active_coyote_window()` | 819 | 查询是否有可用的Coyote跳跃窗口 | `MovementComponent` | `MudCharacter` 门面转发 |
| `get_effective_coyote_time()` | 822 | 查询当前生效 Coyote 时间 | `MovementComponent` | `MudCharacter` 门面转发 |
| `get_effective_jump_buffer_time()` | 825 | 查询当前生效跳跃缓冲时间 | `MovementComponent` | `MudCharacter` 门面转发 |
| `_is_coyote_source(source)` | 828 | 检查跳跃来源是否属于 Coyote | `MovementComponent` | 内部逻辑 |
| `_perform_jump(source)` | 831 | 施加垂直与水平跳跃初速度 | `MovementComponent` | 内部物理计算 |
| `_try_start_assisted_jump(grounded)` | 846 | 触发辅助起跳流程 | `MovementComponent` | 内部逻辑 |
| `damage(amount)` | (待补全) | 扣除生命值 | `HealthComponent` | 统一生命操作接口 |
| `heal(amount)` | (待补全) | 恢复生命值 | `HealthComponent` | 统一生命操作接口 |
| `die()` | 861 | 角色死亡流程 | `HealthComponent` + `MudCharacter` | `HealthComponent` 发出 `died` 信号驱动各组件关闭 |
| `rise()` | 886 | 角色起身恢复流程 | `HealthComponent` + `MudCharacter` | 恢复满血满韧性 |
| `revive(animated)` | 911 | 角色复活与重置状态 | `HealthComponent` + `MudCharacter` | 恢复生命并通知各组件 `reset()` |
| `is_armed()` | 960 | 检查是否持有武器 | `EquipmentController` / `CombatComponent` | `MudCharacter` 门面转发 |
| `is_retreating()` | 963 | 判断是否在攻击时后撤步 | `MovementComponent` / `CombatComponent` | 步态判定 |
| `get_state_animation(state)` | 972 | 解析状态对应的动画名 | `AnimationController` | 动画映射逻辑 |
| `sync_weapon_animation()` | 982 | 切换武器时无缝对齐动画 | `AnimationController` | 动画与装备同步 |
| `transition(next)` | 997 | 切换基础状态并播放对应过渡剪辑 | `AnimationController` | 状态机流转 |
| `receive_hit(hit_data)` | 1220 | 受击结算（伤害、格挡、硬直、击退、顿帧） | `CombatComponent` + `HealthComponent` | 战斗受击统一入口 |
| `_request_confirmed_hitstop(event)` | 1372 | 向全局管理器申请顿帧 | `CombatComponent` | 战斗顿帧逻辑 |
| `_clear_managed_hitstop()` | 1379 | 清理自身顿帧状态 | `CombatComponent` | 战斗顿帧逻辑 |
| `trigger_hit_flash(event)` | 1387 | 触发受击闪白视觉效果 | `CombatComponent` / `SDFBodyController` | 表现逻辑 |
| `_update_hit_flash(delta)` | 1403 | 步进受击闪白衰减 | `CombatComponent` / `SDFBodyController` | 表现逻辑 |
| `_clear_hit_flash()` | 1415 | 重置受击闪白 | `CombatComponent` / `SDFBodyController` | 表现逻辑 |

---

## 四、外部调用与自动化测试覆盖点

- **`tests/wall_movement_test.gd`**:
  - `actor.set_intent(1.0)`
  - `actor.wall_action` (`&"WallHang"`, `&"WallSlide"`, `&"WallPush"`, `&"WallRelease"`)
  - `actor.wall_side`, `actor.wall_surface_x`, `actor.wall_plane_local_x()`
  - `actor.is_wall_attached()`
  - `actor.anim_player.current_animation`
- **`tests/movement_assist_test.gd`**:
  - `actor.movement_assist`, `actor.item_inventory`
  - `actor.get_effective_coyote_time()`
  - `actor.obtain_item()`, `actor.obtain_content_item()`
- **`tests/punch_attack_test.gd`**:
  - `p.weapons.equip(null)`, `p.sync_weapon_animation()`
  - `p.attack_animation()`, `p.action_state`, `p.is_attacking()`
  - `p.punch_hitbox.monitoring`, `p.punch_hitbox.global_position`
  - `p.is_retreating()`
- **`tests/reaction_layer_test.gd`**:
  - `p.health`, `p.stability`, `p.receive_hit()`
  - `p.has_reaction()`, `p.reaction_state`, `p.revive()`
- **`tests/smoke_test.gd`**:
  - 覆盖角色全状态流转、着地、奔跑、武器挥砍、SDF形变、Dummy击中
- **`tests/unified_test_arena_test.gd` & `scenes/test_arena.tscn`**:
  - 覆盖实战竞技场中玩家控制、怪物生成、道具拾取、墙面攀爬交互

**结论**：重构后 `MudCharacter` 必须维持上述字段与方法的兼容访问（通过属性 getter/setter 或同名转发方法），确保上层测试完全零改动通过。
