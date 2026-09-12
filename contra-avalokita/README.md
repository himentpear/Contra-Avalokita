# Contra-Avalokita: The Dead Decibel

**《反观世音：绝响》**

> 科幻禅派 2D 动作 RPG / Roguelite
> A sci-fi Buddhist-inspired 2D action RPG built with Godot.

《反观世音：绝响》是一款以废土、轮回、意识与机械宗教为核心意象的 2D 横版动作游戏。

项目目前处于 **核心角色控制、战斗与程序化渲染系统原型阶段**。现阶段开发重点不是关卡内容量，而是建立可持续扩展的角色运动、SDF 肉身渲染、战斗、装备以及 Roguelite 构筑基础。

---

## Current Status

> **Development Stage: Prototype / Core Systems**

目前已完成或正在工作的核心模块包括：

* 2D 横版角色基础移动
* Idle / Walk / Run / Jump / Fall
* 扒墙、滑墙与蹬墙跳
* Skeleton2D 骨骼驱动角色
* FK / IK 混合姿态控制
* 上下半身动画分层
* 刀剑三段攻击
* 武器 Hitbox / Hurtbox
* 格挡与受击反馈
* 前后肢体动态纵深
* 装备挂点系统
* 程序化 SDF 泥身 Renderer
* SDF 受击凹陷、膨胀与波纹
* SDF 死亡坍塌与像素飞升
* 六道数字伤害显示
* 击杀评分系统
* 多角色压力测试

目前仓库中的测试场景主要用于验证角色、战斗、Renderer 与动画系统，并不代表最终游戏关卡。

---

## Core Concept

游戏中的角色并非传统 Sprite Sheet 人物。

基础角色由：

```text
Skeleton2D
    ↓
Bone Pose
    ↓
SDF Capsules
    ↓
Smooth Union
    ↓
Pixel Shader
    ↓
Mud Body
```

实时生成身体轮廓。

骨骼决定动作，SDF 重新生成肉身。

这使角色能够在保持统一动画系统的同时发生：

* 肢体压缩
* 身体膨胀
* 受击变形
* 肉身缺损
* 程序化死亡
* Roguelite 形态异化

普通武器与硬质装甲不会并入肉身 SDF，而作为独立视觉层进行渲染。

---

## Character Rendering

当前角色视觉结构：

```text
Rear Mud
Rear Equipment
Rear Weapon

Body

Front Mud
Front Equipment
Front Weapon

Head Equipment
Eyes
VFX
```

Mud Body 使用多层 SDF Render Pass，使前后肢体、武器和装备可以在 2D 环境中产生稳定的空间遮挡关系。

角色最终视觉由四类内容组成：

```text
SDF Body     肉身
Equipment    装甲 / 饰品
Weapon       武器
VFX          粒子 / 技能 / 异象
```

未来 Roguelite Morph 系统将在这一结构上继续扩展。

---

## Combat

当前近战系统以刀剑为第一套验证武器。

已实现：

```text
Attack 1
   ↓
Attack 2
   ↓
Attack 3
```

每次攻击包含：

```text
Anticipation
Active
Follow-through
Recovery
```

攻击动作与移动动画分层处理，因此角色能够在：

* 行走
* 奔跑
* 跳跃
* 下落

过程中继续执行上半身攻击动作。

武器伤害由独立 Hitbox 结算，剑光和视觉 Trail 不参与实际伤害判定。

---

## Controls

当前测试场景默认操作：

| Action              | Input          |
| ------------------- | -------------- |
| Move                | `A / D` 或方向键   |
| Run                 | `Shift + Move` |
| Jump                | `Space`        |
| Wall Hang / Slide   | 空中持续朝墙输入       |
| Wall Jump           | 扒墙状态下 `Space`  |
| Attack              | `J` / 鼠标左键     |
| Toggle Equipment    | `E`            |
| Equip Sword         | `1`            |
| Unequip Weapon      | `2`            |
| Debug Visualization | `F1`           |
| Crowd Test          | `T`            |
| Reset Player        | `R`            |

测试输入会随开发阶段调整，不视为最终键位设计。

---

## Tech Stack

### Engine

* **Godot 4.7.x**
* GDScript
* 2D Renderer
* Compatibility / OpenGL-compatible rendering path
* Pixel-snapped 640 × 360 reference viewport

### Character Technology

* CharacterBody2D
* Skeleton2D / Bone2D
* FK / analytic IK
* AnimationPlayer
* Procedural locomotion
* Signed Distance Field rendering
* Runtime ShaderMaterial
* Layered 2D depth rendering

项目目前不依赖第三方 Godot 插件。

---

## Quick Start

### Requirements

推荐使用：

```text
Godot 4.7.x
```

Clone：

```bash
git clone https://github.com/himentpear/Contra-Avalokita.git
```

打开：

```text
contra-avalokita/project.godot
```

当前开发阶段可以直接运行：

```text
scenes/test_arena.tscn
```

或者使用项目默认 Main Scene。

---

## Project Structure

当前工程正在逐步从原型目录迁移为更明确的游戏工程结构。

主要目录：

```text
contra-avalokita/
│
├── assets/             # 美术、字体与公共资源
├── scenes/             # Godot Scene
├── scripts/            # Gameplay / Runtime scripts
├── shaders/            # SDF 与视觉 Shader
├── resources/          # Animation / Theme / Resource
├── docs/               # 技术与设计文档
│
├── project.godot
└── README.md
```

随着项目进入正式内容开发阶段，系统将逐步拆分为：

```text
bootstrap/              游戏启动与内容挂载

core/                   应用生命周期、存档、事件、内容注册

gameplay/
├── character/
├── combat/
├── roguelike/
├── world/
└── ai/

content/
├── base/
└── shared/

ui/
├── hud/
├── menu/
├── content_browser/
└── console/

extensions/
├── dlc/
└── mod_sdk/

tests/
tools/
docs/
```

原则：

> **Gameplay 定义规则，Content 定义游戏里有什么。**

具体武器、角色、敌人和关卡不应成为 Gameplay Core 的硬编码依赖。

---

## Architecture

目标运行结构：

```text
Boot
 │
 ▼
Core
 │
 ├───────────────┐
 ▼               ▼
Gameplay         UI
 │
 ▼
Content Registry
 │
 ├── Base Game
 ├── DLC
 └── Mods
```

所有游戏内容未来统一使用命名空间 ID，例如：

```text
base:sword
base:mudborn

dlc01:vajra_blade

example_mod:red_sword
```

Gameplay 系统只通过 Content Registry 获取内容，而不直接依赖具体 DLC 或 MOD。

---

## Planned Systems

以下系统属于规划或架构预留阶段，不代表当前版本已经完成。

### Roguelite

计划包含：

* Run Seed
* 随机事件
* 武器与装备构筑
* SDF Morph
* 六道 / 业力系统
* Build Synergy
* 隐藏角色
* Boss 路线
* 多结局

### DLC

官方扩展内容计划采用独立 Content Pack：

```text
Base Game
+
Official DLC
```

Core Gameplay 不直接依赖具体 DLC。

DLC 可以注册：

* 角色
* 武器
* Morph
* 敌人
* Boss
* 关卡
* 剧情
* UI 内容

### Modding

计划提供两类 MOD：

**Data Mod**

```text
JSON
Texture
Audio
Level Data
Item Data
Dialogue
Morph Profile
```

**Scripted Mod**

```text
Godot PCK
Scene
Resource
Shader
GDScript
```

MOD 内容将在独立命名空间运行，避免直接修改 Core Gameplay。

### Developer Console

计划提供运行时开发者控制台与 Command Registry，例如：

```text
spawn
give
damage
god

run.seed
loot.spawn

sdf.show
sdf.morph
sdf.clear

content.list
content.info

mod.list

perf.fps
perf.entities
perf.sdf
```

Console 与自动化测试计划共用同一套 Command API。

---

## Development Guidelines

### Runtime Assets

正式游戏会加载的资源放入对应：

```text
assets/
resources/
scenes/
content/
```

开发过程截图、GIF 和临时导出结果不要作为 Runtime Asset。

建议使用：

```text
tests/reference/
docs/images/
```

保存真正需要长期保留的参考资料。

---

### Character Responsibilities

角色系统尽量保持职责分离：

```text
Movement
Animation
Rig
Renderer
Equipment
Weapon
Combat
VFX
```

不要将视觉逻辑、物理移动和攻击结算全部堆入单一角色脚本。

---

### Rendering Responsibilities

```text
SDF
=
肉身 / 形变 / 生物异化

Sprite
=
装甲 / 武器 / 硬质装备

Shader
=
材质 / 色阶 / 局部状态

VFX
=
技能 / 粒子 / 异象
```

不要使用 SDF 代替所有美术层。

---

### Content IDs

正式游戏内容不应通过绝对资源路径成为存档 ID。

避免：

```text
res://weapons/sword.tscn
```

推荐：

```text
base:sword
```

以确保未来 DLC、MOD 与存档迁移能够共存。

---

## Documentation

随着系统稳定，README 中的具体实现细节会逐步迁移至：

```text
docs/
├── architecture/
├── animation/
├── combat/
├── renderer/
├── roguelike/
└── modding/
```

README 只维护：

* 项目定位
* 当前状态
* 快速运行
* 核心架构
* 开发入口

具体动画参数、Shader 数学、IK 阈值和技术实验不应长期堆积在仓库首页。

---

## Roadmap

近期开发重点：

```text
Character Core
      ↓
Combat Core
      ↓
Renderer / Morph
      ↓
Roguelite Runtime
      ↓
Content Pipeline
      ↓
World / Level
      ↓
Game Loop
```

当前优先级：

* [x] 基础移动
* [x] 程序化角色 Renderer
* [x] 刀剑基础战斗
* [x] 墙面移动
* [x] 基础装备挂点
* [x] 死亡视觉
* [ ] SDF Morph System
* [ ] Armor Renderer
* [ ] Roguelite Run Manager
* [ ] Content Registry
* [ ] 正式 Boot Flow
* [ ] Main Menu / HUD
* [ ] 基础敌人体系
* [ ] 第一套正式关卡
* [ ] Save System
* [ ] Developer Console
* [ ] DLC Content Interface
* [ ] Mod SDK

---

## Repository Status

本项目目前仍处于主动开发阶段。

API、节点结构、Resource 格式和游戏规则均可能发生较大变化。

现阶段仓库的首要目标是验证核心玩法与技术架构，而非提供稳定的公共开发 API。

---

## License

项目代码、美术、音频及其他内容的最终授权方式尚待确定。

在正式许可证发布前，请勿默认本仓库内容属于可自由再分发、商用或二次发布的开源资产。


