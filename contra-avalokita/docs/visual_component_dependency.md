# Visual Component Dependency Analysis (MudBodyRenderer, MudPoseComposer, EquipmentManager, WeaponManager)

本文档详细梳理 Contra-Avalokita 渲染与姿态表现层四大子系统（`MudBodyRenderer`、`MudPoseComposer`、`EquipmentManager`、`WeaponManager`）与角色主控、逻辑组件之间的依赖与拓扑关系，为重构提取 `SDFBodyComponent`、`CharacterStateComponent` 与 `EquipmentController` 提供设计依据。

---

## 1. 架构总览与调用拓扑

```mermaid
graph TD
    subgraph MudCharacter["MudCharacter (Facade)"]
        MovementComponent[MovementComponent]
        HealthComponent[HealthComponent]
        CombatComponent[CombatComponent]
        AnimationController[AnimationController]
    end

    subgraph PoseIK["姿态与骨骼计算层"]
        PoseComposer[MudPoseComposer]
        WallComposer[MudWallPoseComposer]
        SpineCtrl[MudSpineController]
        PoseComposer --> WallComposer
        PoseComposer --> SpineCtrl
    end

    subgraph VisualTree["Visual 场景树分支 ($Visual)"]
        PoseRoot[Visual/PoseRoot/Skeleton2D]
        BodyRenderer[Visual/MudBodyRenderer (SDF)]
        EyeController[Visual/Eyes]
        EquipmentMgr[Visual/Equipment]
        WeaponSlots[Visual/WeaponSlots (WeaponManager)]
    end

    MudCharacter --> PoseComposer
    MudCharacter --> BodyRenderer
    MudCharacter --> EquipmentMgr
    MudCharacter --> WeaponSlots

    PoseComposer -.读取状态与骨骼.-> MudCharacter
    PoseComposer -.写入骨骼Transform.-> PoseRoot

    MudCharacter -.驱动逐帧绘制.-> BodyRenderer
    BodyRenderer -.读取骨骼GlobalPosition.-> PoseRoot
    EquipmentMgr -.跟随骨骼插值.-> PoseRoot
    WeaponSlots -.跟随手部骨骼.-> PoseRoot
```

---

## 2. 子系统依赖明细分析

### 2.1 MudBodyRenderer (SDF 泥浆体态渲染器)
- **挂载位置**：`MudCharacter/Visual/MudBodyRenderer` (Node2D)
- **Shader 材质**：`res://shaders/mud_pixel_shader.gdshader`，维护 `RearSurface` (Z=-6) 和 `FrontSurface` (Z=4) 双通道材质。
- **数据输入**：
  1. **骨骼拓扑**：缓存 `Skeleton2D` 中 16 根核心骨骼（Pelvis, Torso, Head, Spine, 四肢），按肢体段连接计算胶囊几何体 `endpoints` / `properties`。
  2. **受击形变参数**：
     - 凹陷中心：`impact_center` (Vector2, 本地坐标)
     - 凹陷深度与半径：`impact_depth`, `impact_radius`
     - 对向鼓包：`impact_bulge_center`, `impact_bulge_radius`, `impact_bulge_height`
     - 水波纹相：`impact_ripple_phase`
  3. **击打白闪 (Hit Flash)**：`set_hit_flash(amount, color)`，直接写入 Shader Uniform。
  4. **死亡崩解 (Death Collapse)**：`death_progress`, `death_dissolve`, `puddle_spread_ratio`, `limb_retraction_strength` 生成泥浆摊平段（Puddle）。
  5. **六道异化修饰器 (SDF Morph / Six Realms Modifiers)**：
     - 通过 `SdfMorphProfile` 与 `SdfModifier` 动态附加胶囊、球体形变修饰，打包写入 `modifier_a`, `modifier_b`, `modifier_meta` 并上传 GPU。
- **对外暴露接口 (供测试与 RigAdapter 访问)**：
  - `compressions` (各关节压缩率)
  - `angles` (关节弯曲角度)
  - `segments` (渲染段几何数据)
  - `point(id)` (查询关节点与辅助点本地坐标，如 `ArmFrontPre`, `Head` 等)

### 2.2 MudPoseComposer (分层姿态与反向动力学融合器)
- **挂载方式**：动态作为 `MudCharacter` 的子节点实例。
- **驱动机制**：
  - 在 `_physics_process(delta)` 早期执行 `restore_base()`，并在所有运动与状态判定完成后执行 `evaluate(delta)`。
- **输入依赖**：
  - 角色骨骼：`character.skeleton`
  - 动画播放器：`character.anim_player`（负责采样 `character.attack_animation()`）
  - 核心状态查询：
    - `character.state` (`Idle`, `Walk`, `Run`, `Jump`, `Fall`, `Dead`)
    - `character.wall_action` (`WallHang`, `WallSlide`, `WallPush`, `WallRelease`)
    - `character.is_attacking()`, `character.is_blocking()`
    - `character.has_reaction()`, `character.reaction_state`
    - `character.attack_time`, `character.combo_stage`
  - 武器状态读写：`character.weapons.blade_projection`, `character.weapons.blade_depth`
- **输出**：直接覆写 `character.pose_root` 和各 `Bone2D.transform`。

### 2.3 EquipmentManager (装备外观管理器)
- **挂载位置**：`MudCharacter/Visual/Equipment` (Node2D)
- **槽位结构**：
  - `HeadSlot` (跟随 `_head_bone`)
  - `RightForearmSlot` / `ForearmSlot` (跟随主手小臂与手腕插值)
  - `LeftForearmSlot` (跟随副手小臂与手腕插值)
- **交互接口**：
  - `equip(slot, scene)`：动态实例化头盔、护臂等装备。
  - `toggle()`：开关整体装备显隐（`smoke_test.gd` 中测试）。
  - `sync_bones(head_bone, forearm_bone, hand_bone)`：同步主侧骨骼变换。
  - `sync_handedness(left_forearm, left_hand, right_depth, left_depth)`：根据前后手深度调整 Z-Index 并插值副侧。
  - `sync_death(death_progress, embed)`：死亡时装备陷落泥潭的渐变动画。

### 2.4 WeaponManager (武器挂载与动作管理器)
- **挂载位置**：`MudCharacter/Visual/WeaponSlots` (Node2D)
- **主要职责**：
  - 挂载主手武器 `current: MudWeapon`，管理刀剑握柄偏移。
  - 驱动剑姿与挥砍旋转：
    - 格挡剑姿（向敌侧倾斜 7°，带弹簧回弹）
    - 挥砍与跑动时的手腕滞后跟随
  - 驱动武器 Hitbox 与挥砍轨迹（`update_attack(t, attacking)`）
  - 武器脱手掉落模拟（`drop_weapon_to_ground()`）
  - 受击格挡撞击闪光（`impact_flash_point`, `impact_flash_timer`）

---

## 3. 当前耦合痛点与解耦重构方案

### 痛点 1: CombatComponent 越权直连 MudBodyRenderer
- **现状**：`CombatComponent` 中的 `trigger_hit_flash()` 和 `update_hit_flash()` 内部直接调用 `character.get_node_or_null("Visual/MudBodyRenderer")`。
- **解耦要求**：**CombatComponent 绝不允许直接访问 SDF 节点**。
- **方案**：
  1. `CombatComponent` 仅维护打击逻辑与打击强度。当发生受击或造成伤害时，通过信号发出白闪请求（如 `hit_flash_requested(intensity, color)`）。
  2. `MudCharacter` 监听该信号，将其转交新创建的 `SDFBodyComponent`。

### 痛点 2: SDF 渲染逻辑散落在 MudCharacter 中
- **现状**：`MudCharacter._sync_visual()` 承担了大量的泥浆形变衰减、反向鼓包计算、深度同步、六道修饰器与死亡扩散计算。
- **方案**：提取 `SDFBodyComponent` 作为独立组件挂载在 `Components/` 下，代理和驱动 `MudBodyRenderer` 的所有形变计算、着色器参数同步及六道修饰器接口。

### 痛点 3: 状态分散在各个组件中，缺乏集中协调器
- **现状**：`action_state`、`wall_action`、`reaction_state`、`state` 分散在 `CombatComponent`、`MovementComponent` 和 `MudCharacter` 中，`MudPoseComposer` 需要分别读取。
- **方案**：创建 `CharacterStateComponent`，统一聚合 Locomotion、Wall、Attack、Reaction 四大维度的状态机，对外提供一致查询接口，并与子组件保持强同步。

### 痛点 4: WeaponManager 缺乏配置化 Resource 支持
- **现状**：`WeaponManager.equip(scene: PackedScene)` 仅接受 `PackedScene`，武器攻击参数、伤害倍率、动画配置无法作为资产配置。
- **方案**：
  1. 引入 `WeaponData` Resource，支持定义场景、攻击段数、伤害、冲击力、连击缓冲时间等。
  2. 创建 `EquipmentController` 组件，迁移 `WeaponManager` 的核心管理能力，使 `equip()` 既兼容原有的 `PackedScene`，又支持 `WeaponData`。
