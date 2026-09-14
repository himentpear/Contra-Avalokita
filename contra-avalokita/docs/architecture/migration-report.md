# 架构迁移完成报告 (Migration Report)

本报告详细记录 Godot 4.7 项目《反观世音：绝响》（Contra-Avalokita: The Dead Decibel）从原型系统向生产级工程架构重构的完整状态。

---

## 1. 新增目录

- `bootstrap/`：启动引导层，包含包挂载、依赖解析与初始场景路由。
- `core/`：核心应用系统基础层。
  - `core/app/`：游戏生命周期管理与版本定义。
  - `core/content/`：内容注册中心、清单规范与数据驱动依赖解析。
  - `core/events/`：全局跨域事件总线。
  - `core/save/`：因果世界线与多角色分层存档序列化与版本迁移。
  - `core/settings/`：用户设置管理。
  - `core/debug/`：命令注册表与调试标记。
- `gameplay/`：游戏规则与运行时域。
  - `gameplay/session/`：当前活动会话，聚合单局生命周期。
  - `gameplay/world/`：世界状态管理与场景因果解析器。
  - `gameplay/roguelike/`：局内状态、随机种子与六道计分系统。
  - `gameplay/combat/`：战斗上下文、命中事件与武器抽象。
  - `gameplay/character/`：角色渲染、SDF 肉身修饰与装备渲染。
- `content/base/`：本体内容包。
  - `weapons/sword/`：基础武器场景与定义。
  - `equipment/helmet/`、`equipment/bracer/`：基础装备场景与定义。
  - `morphs/`：五种肉身变异定义（阿修罗肩、空面、饿鬼、脊刺、肿臂）。
- `ui/console/`：开发者控制台与命令面板界面。
- `extensions/dlc/test_dlc/`：官方 DLC 接口验证测试包。
- `docs/architecture/`、`docs/save/`、`docs/modding/`、`docs/media/`：重构架构规范文档与多媒体展示。

---

## 2. 新增核心系统

1. **Boot Flow (`bootstrap/boot.gd`, `package_loader.gd`)**：统一引擎启动入口，早期扫描挂载 DLC/MOD PCK，解析 Package 依赖拓扑，按序注册到 `ContentRegistry`，加载设置与存档，再跳转游戏场景。
2. **Content Registry (`core/content/content_registry.gd`)**：强制实施 `namespace:item` 稳定 ID 机制；支持基于类型与标签的数据查询，内置循环依赖检测、非法命名空间保护与资源完整性验证。
3. **Save System & World Event Ledger (`core/save/`)**：
   - 5 层隔离模型：Account -> Campaign (世界线) -> WorldState -> CharacterState -> RunState。
   - 引入世界因果事件账本（`WorldEventLedger`），记录具体角色触发的因果事件（如击杀 Boss），实现多角色交叉因果溯源。
   - 缺失内容保护机制（`MissingContentReference`），保证缺失 MOD/DLC 时存档不崩。
   - 版本迁移器（`SaveMigrator`），规范处理 schema 升级。
4. **Session 域管理 (`gameplay/session/game_session.gd`)**：将非全局应用周期的 `WorldManager`、`RunManager`、`CombatContext`、`ScoreSystem` 降级内聚至当前 Session，消除污染。
5. **Command Registry & Console (`core/debug/command_registry.gd`, `ui/console/`)**：统一命令注册与自动补全引擎，支持反引号与 `Ctrl+Shift+P` 呼出。
6. **Data Mod Loader (`core/content/data_mod_loader.gd`)**：提供无代码（Non-executable JSON）安全数据模组机制，带有路径穿透与非法扩展名防护。

---

## 3. 移动文件

- `tests/character/test_arena.tscn`：从根目录场景升级为规范角色集成测试场景。
- `docs/media/`：将 README 的三个长期展示动图（`blade_attacks.gif`, `blade_footwork_layers.gif`, `block_preview.gif`）集中管理，避免污染根目录。
- `gameplay/character/sdf/sdf_modifier.gd` & `sdf_morph_profile.gd`：规范化入驻 `gameplay/character/sdf/`。
- `gameplay/character/render/equipment_piece.gd`：规范化入驻 `gameplay/character/render/`。
- `gameplay/combat/weapons/weapon.gd`：规范化入驻 `gameplay/combat/weapons/`。

---

## 4. 删除文件

- 删除了直接置于 `resources/morphs/` 中的临时硬编码变异资源（已由 `content/base/morphs/` 统一接管并通过 `tools/generate_test_morph_profiles.gd` 同步）。
- 删除了冲突的 `.uid` 缓存文件，避免 Godot 全局类索引冲突。

---

## 5. 修改 Autoload

`project.godot` 严格精简为应用生命周期核心系统：
- `Game` -> `res://core/app/game.gd`
- `EventBus` -> `res://core/events/event_bus.gd`
- `ContentRegistry` -> `res://core/content/content_registry.gd`
- `Settings` -> `res://core/settings/settings_manager.gd`
- `SaveManager` -> `res://core/save/save_manager.gd`
- `CommandRegistry` -> `res://core/debug/command_registry.gd`
- `Console` -> `res://ui/console/console.tscn`

*注：`KillScore` 原型服务已从 Autoload 移除，平滑重构为 `GameSession/RunManager/ScoreSystem`。*

---

## 6. 修改 Main Scene

- `run/main_scene` 统一修改为指向 `res://bootstrap/boot.tscn`。
- 启动后自动流转进入统一正式测试场 `res://scenes/test_arena.tscn`。

---

## 7. Content Registry 状态

- 已登记本体内容包 `base`（版本 0.2.0），包含：
  - 武器：`base:sword`
  - 装备：`base:helmet`, `base:bracer`
  - 肉身：`base:swollen_arm`, `base:hungry_ghost`, `base:asura_shoulder`, `base:hollow_face`, `base:spine_growth`
- 具备完整的非法 namespace、重复注册、依赖版本不满足与循环引用拦截。

---

## 8. Save 架构状态

- 实现世界线独立存储（`user://saves/{campaign_id}.json`）与账号通用存储（`user://account.json`）。
- 同一世界线中不同角色共享权威 `WorldState` 与 `WorldEventLedger`。
- 单局 Roguelite 进度独立于角色持久档案。
- 存档缺失内容时自动生成缺失引用结构体，不会抛出致命异常。

---

## 9. Console 状态

- 原生集成全局快捷键：
  - 反引号 `` ` ``：切换完整终端。
  - `Ctrl + Shift + P`：激活命令面板搜索。
- 已注册标准控制台指令：
  `help`, `content.list`, `content.info`, `give`, `save.info`, `save.force`, `sdf.show`, `sdf.morph`, `sdf.clear`, `mod.list`, `perf.fps`, `god`, `damage`, `kill`, `run.seed`。

---

## 10. DLC / MOD 接口状态

- 官方 DLC 采用早期 `.pck` 挂载 + `manifest.tres` 依赖驱动注入，以 `test_dlc:red_sword` 验证全流程。
- MOD 采用双轨制：
  - **Data Mod**：在 `user://mods/` 下通过 JSON / 贴图等无脚本数据热加载，杜绝恶意代码；
  - **Scripted Mod**：需经 PCK 注入并提示可执行代码风险。

---

## 11. 保留的兼容层

为确保既有场景与测试 100% 零修改零破坏，在原路径保留轻量向下兼容 Stubs：
- `scripts/sdf_modifier.gd` -> 继承 `gameplay/character/sdf/sdf_modifier.gd`
- `scripts/sdf_morph_profile.gd` -> 继承 `gameplay/character/sdf/sdf_morph_profile.gd`
- `scripts/equipment_piece.gd` -> 继承 `gameplay/character/render/equipment_piece.gd`
- `scripts/weapon.gd` -> 继承 `gameplay/combat/weapons/weapon.gd`
- `gameplay/combat/hit/hit_event.gd` -> 继承 `scripts/hit_event.gd`

---

## 12. 尚未迁移的旧结构

为避免“大爆炸式”引入偶发 bug，以下高耦合模块本阶段维持现有稳定运行路径：
- `scripts/mud_character.gd`、`scenes/mud_character.tscn`（单体复杂角色控制）
- `scripts/mud_locomotion.gd`、`scripts/mud_pose_composer.gd`、`scripts/mud_wall_pose_composer.gd`
- `scripts/mud_rig.gd`、`scripts/mud_joint_solver.gd`
将在未来次级阶段逐步配合专项覆盖测试拆分。

---

## 13. 已验证功能

所有自动化与核心场景测试全部通过：
1. `tests/integration/architecture_smoke.tscn`：**PASS (ARCHITECTURE_SMOKE_OK)**
2. `tests/save/save_architecture_test.tscn`：**PASS (SAVE_ARCHITECTURE_OK)**
3. `tests/content/data_mod_loader_test.tscn`：**PASS (DATA_MOD_LOADER_OK)**
4. `tests/smoke_test.gd`：**0 failures** (20项机动/攻击/受击冒烟)
5. `tests/wall_movement_test.gd`：**0 failures** (全套攀墙滑墙测试)
6. `tests/sdf_morph_test.gd`：**0 failures** (全套34项肉身SDF变异测试)
7. `tests/death_test.gd`：**0 failures** (崩解与像素飞升)
8. `tests/impact_feel_test.gd`：**0 failures** (打击感与定帧阻尼)
9. `tests/reaction_layer_test.gd`：**0 failures** (受击分层与韧性)
10. `tests/punch_attack_test.gd`：**0 failures** (徒手三连击)
11. `tests/kill_score_test.gd`：**PASS** (六道击杀得分结算)
12. `bootstrap/boot.tscn`：实机无缝进入 `test_arena.tscn`。

---

## 14. 已知风险

1. **测试 DLC 重用资源**：当前 `test_dlc:red_sword` 为验证挂载与装备流程，场景复用了基础大剑模型，未包含独立美术材质。
2. **Headless 模式下渲染服务器帧回调**：部分依赖 `frame_post_draw` 截屏比对的视觉测试（如 `body_depth_visibility_test.gd`）在 `--headless` 下不产生视口绘制，需在标准图形环境下运行。
