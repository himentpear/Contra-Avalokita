# 程序化泥浆人 · Godot 4.7 MVP

打开 `project.godot`，按 **F6** 运行 `scenes/test_arena.tscn`，或按 **F5** 运行项目。已在本机 Godot **4.7.1**、Compatibility / OpenGL 渲染器上运行验证。无插件、外部素材或额外依赖。

## 操作

攻击数值采用六进制白线象形字：0 天道·虚妄光茧，1 修罗道·交错争锋，2 人道·中道木铎，3 畜生道·无明闭环，4 饿鬼道·细颈枯腹，5 地狱道·沉沦重渊。多位数从左至右，高位在前（十进制 10 → 六进制 14，36 → 100）。格挡反馈采用减伤后的数值；小数最多保留两位六进制位，四舍五入只影响显示，不改变伤害结算。中央小点是小数分隔符，零仍使用完整天道符号。符号为原创程序化白线图形，未使用游戏原始素材；此套佛理对应作为本项目的艺术设定。

刀剑下半身使用 `blade_footwork` 增量资源（角色 Inspector 可展开）：Idle/Walk/Run 权重分别为 1/0.65/0.35，空中为 0。第一刀 0.4 秒、小踏步 4 px / 髋推进 5 px；第二刀后压 2.5 px、换重心并抬后跟；第三刀踏步 6.5 px / 髋推进 8 px，并有 0.05 秒上半身 impact hold，物理与移动相位不停。脚部目标在当前移动姿势上叠加后求解，不替换整套腿部动画。

固定解剖侧别：旧 `Front` 骨链 = 右手/右腿，`Back` = 左手/左腿。MainHandSlot 默认右手持剑；`RightForearmSlot`、`LeftForearmSlot` 独立装备，旧 `ForearmSlot` 为右手插槽别名。面向右时右侧靠前，面向左时左侧靠前；攻击可覆盖右手纵深，武器、护腕与泥浆手臂共用这一层级。渲染顺序为远侧泥浆(-6)、远侧饰品(-5)、远侧武器(-4)、躯干(0)、近侧泥浆(4)、近侧饰品(5)、近侧武器(6)、头部装备(10)。SDF 按相同轮廓分三遍绘制，以允许装备穿插遮挡。

跳跃使用独立 `Air` 动画库：JumpSquat → Takeoff → Rise → Apex → Fall → SoftLand/HardLand → Recovery。起跳预备默认 0.075 秒，顶点速度带为 ±35；落地只在空中转地面时触发，滞空不足 0.08 秒或下落速度不足 140 时跳过，达到 280 时使用重落地。相关阈值暴露在角色 Inspector，恢复时根据当前水平运动返回 Idle/Walk/Run，并保留地面循环相位。

移动与动作分层：`MudCharacter.state` 始终表示 Idle/Walk/Run/Jump/Fall（死亡除外），`action_state` 独立表示 None/Attack1/Attack2/Attack3。`MudPoseComposer` 先推进基础 AnimationPlayer，再按上半身骨骼遮罩采样 Blade 动画；腿部与骨盆位置不受攻击轨道影响。收招权重淡出到当前移动姿势，空中基础姿势由垂直速度驱动。`attack_movement_multiplier` 独立控制攻击时水平移速，默认 1。F1 可查看骨骼归属颜色、移动/动作状态、基础相位、攻击进度、落地状态与垂直速度。

| 操作 | 输入 |
| --- | --- |
| 步行 | A / D 或左右方向键 |
| 疾跑 | 按住 Shift + 移动，松开 Shift 恢复步行 |
| 跳跃 | Space |
| 刀剑三连击 | J / 鼠标左键；每段起手后再按一次缓存下一段，第三段后收招 |
| 头盔与护腕显隐 | E |
| 装备 Sword / 卸下武器 | 1 / 2 |
| Anchor 与辅助点可视化 | F1 |
| 2 / 10 / 30 人测试 | T |
| 玩家复位 | R |

走近右侧木桩挥剑，`HITS` 显示实际 Area2D 命中次数。攻击预备、有效和恢复阶段分离，同一目标每次挥剑只结算一次。空手动作仍可播放，但没有武器伤害。

刀剑类动画位于角色 AnimationPlayer 的 `Blade` 库：`Attack_1` 起手下斩（0.62 秒）、`Attack_2` 横斩（0.44 秒）、`Attack_3` 收尾上挑（0.76 秒）。每段包含预备、挥击、跟随和恢复；单次输入只出一段，后续输入在动作 15% 之后缓存。Sword 的 Inspector 中 `weapon_class = blade` 标记刀剑类别，`attack_animations` 与 `attack_windows` 分别配置动画和命中窗口。横斩使用 BACK/BODY/FRONT 纵深表现与独立的水平矩形判定，生效时间为 0.16–0.25 秒。`trail_width` 控制两端收尖的剑光宽度；剑光只作视觉显示。

## 已实现的范围

- Idle、Walk、Run、Jump（包含 Fall 过渡）、Attack；轻微落地压缩。
- 一把独立 Sword，HeadSlot、ForearmSlot、MainHandSlot。
- 浮点 FK Anchor、四肢辅助 Pre/Post 控制点、夹角压缩、限幅阻尼弹簧。
- 24 个可复用胶囊段组成整体 SDF，smooth union 保持连续轮廓。
- 单个身体 Shader，离散色阶、深色边缘、稀疏湿润高光；噪声不影响距离场。
- 独立眼睛绘制，眨眼、瞳孔跟随；暴露受击/闭眼视觉接口。
- 固定胶囊角色碰撞，独立 Hurtbox，独立武器 Hitbox。
- `set_intent()` 允许玩家、敌人、NPC 共用角色。测试中的 NPC 就是同一场景。

MVP 使用程序化状态与 FK 动画，不放置未连接的 AnimationPlayer / AnimationTree。Attack_2、Heavy_Attack、Hurt、Death、双手 IK、换枪等尚未实现；扩展参数/节点只是接口，不代表已实现对应动作。

## 节点与职责

`MudCharacter` 自身就是 CharacterBody2D，避免在普通根节点下另设一个独立移动的物理子节点。

```text
MudCharacter (CharacterBody2D / mud_character.gd)
├── CollisionShape2D       固定 CapsuleShape2D
├── Visual                仅最终显示位置取整、朝向翻转
│   ├── MudBodyRenderer    单个 ColorRect + ShaderMaterial
│   ├── Rig                运行时创建命名 Marker2D
│   ├── Eyes               独立锐利眼睛
│   ├── Equipment
│   │   ├── HeadSlot
│   │   └── ForearmSlot
│   └── WeaponSlots
│       └── MainHandSlot
│           └── Sword     Sprite2D / Hitbox / Grip / Effect 等
└── Hurtbox               固定 Area2D
```

- `mud_character.gd`：输入意图、物理移动、状态与系统更新顺序。
- `mud_rig.gd`：姿态、人体比例和 Marker2D。Marker 使用平铺命名，FK 显式计算，避免父子局部变换重复应用。`ArmFrontStart/Joint/End` 分别是肩/肘/手；`LegFrontStart/Joint/End` 分别是髋/膝/踝，Back 同理；`Pre/Post` 是辅助形体点。
- `mud_joint_solver.gd`：资源化弹簧，`target_position/current_position/velocity`，最大 1/120 秒积分子步。`stiffness/damping/mass/max_lag` 可通过 Rig 的 `spring_template` 配置。
- `mud_locomotion.gd`：距离驱动步态，支撑/摆动足部轨迹、脚跟着地/脚尖离地、走跑混合。Rig 用两段解析 IK 求髋膝角度，并驱动骨盆起伏、肩胯反向摆动、延迟屈肘与手腕跟随。
- `mud_segment.gd`：形体数据。段资源初始化后复用，不逐帧创建几何或资源。
- `mud_body_renderer.gd`：读取最终 Rig 并上传固定容量数组；装备与武器从不进入 SDF。
- `equipment_piece.gd`：独立贴图、偏移、旋转、比例、层级。示例 SVG 仅由整数像素形状构成，导入后作为贴图使用。
- `weapon.gd`：命中窗口、伤害和每次攻击去重，`struck` 信号便于接音效与特效。

## 参考关键帧校准

步行相位 0 / 0.25 / 0.5 / 0.75 / 1 对应参考 F1 / F7 / F13 / F19 / F25；经过姿态升高，跨步姿态降低。跑步每半周期按跨步 → 腾空 → 接触 → 经过 → 回收排列，接触位于 0.2 / 0.7，腾空位于约 0.1 / 0.6。

髋部不再固定压至腿长的 82%。`support_height()` 根据脚部目标与支撑腿可达长度调整骨盆高度；`walk_support_extension / run_support_extension` 控制承重腿伸展，`run_contact_compression` 只在接触期提供小幅缓冲。腾空同时抬起根部与两脚，回收腿先屈后伸，在落脚前展开小腿。步行脚尖离地角独立减小，避免持续踮脚蹲行。

弹簧惯性仅接收速度变化，不再持续按行进速度向后拉扯胸部与头部。匀速时骨骼回到姿态目标；软体阻尼仍负责起步、制动和跳落时的短暂跟随。

## 承重、蹬伸与质量滞后

当前步态在参考姿态上增加明确承重阶段：Walk 为 Contact → Down → Passing → Up；Run 为接触压缩 → 蹬伸 → 双脚腾空 → 再接触。`walk_down / run_down / acceptance_peak / acceptance_end` 控制承重包络，`drive_push` 控制骨盆蹬伸前送。下降只在承重阶段出现，随后支撑腿重新展开，不能再用“支撑腿全程近直”来约束动作。

默认 Walk 的 Contact→Down 实测约下降 2.06 逻辑像素（2 倍显示时约 4.12 像素），Passing 抬脚目标约 8 逻辑像素。Run 使用非对称足部轨迹，落点在骨盆前约 5.76 逻辑像素，后向蹬伸更长；两只脚底同时明显离地的区间约 0.1 秒。上述数值对应默认体型和速度。

`arm()` 独立输出上臂、肘部、手腕时序，肘部读取延迟的肩部角度，手腕再延迟；跑步肘角限制 70°–110°。胸与头通过 `chest_delay / head_delay` 的时间历史逐级跟随骨盆，再叠加限幅阻尼修正，保留短暂惯性并避免持续后拖。攻击层仍可覆盖手臂姿态，装备与武器仍跟随独立插槽。

## 像素化与遮挡

项目以 **640×360 的共享游戏 Viewport** 渲染，再以整数倍 Nearest 放大至默认 1280×720。它与每角色 SubViewport 的最终采样原则相同，但没有 30 份视口开销。所有身体、眼睛、装备、武器共用最终像素网格；物理及骨架不取整，只有 Visual 世界原点取整。若游戏需要高分辨率 UI，可将游戏场景放入一个共享 SubViewport，并把 UI 移到外层。

身体内部前后遮挡由 Shader 的段 `depth` 决定：后肢更暗，躯干居中，前肢覆盖。它们属于一个连续 SDF，并非多个分层透明身体 DrawCall。装备与武器使用真正的 CanvasItem z_index，剑在预备阶段降到身后、挥出时回到前方。若以后需要把装备夹在两个身体层之间，应扩展渲染分层，而不是把装备并入距离场。

## Inspector 调整与扩展

1. **体型**：Rig 的 `torso_length / upper_arm_length / forearm_length / thigh_length / shin_length` 与半径。常规小幅变化无需改代码；大幅改体型时同步调整独立 CollisionShape2D、Hurtbox 和 Renderer `render_bounds`，防止裁剪。碰撞始终是稳定简化形状。
2. **泥色**：Renderer `mud_color / fusion_softness / edge_width / surface_noise`。
3. **软度**：Rig `spring_template`、`inertia_response`、`auxiliary_distance`。脚不使用滞后弹簧。压缩从 40°开始，到 140°饱和，弯曲限制为 140°。
4. **形变与步态**：Rig `idle_squash / jump_stretch / landing_squash / attack_stretch`。`heavy_attack_stretch` 预留给后续重攻击。展开 Rig 的 `locomotion_profile`（默认 `resources/default_locomotion.tres`）可调整步幅、支撑比例、抬脚高度、肩胯幅度、前倾、屈肘和手腕延迟。每个角色复制配置并独立保存步态相位。平地匀速支撑阶段的脚部后移速度抵消角色位移；没有地形射线适配，加减速、转向或修改极端比例时仍可能产生滑步。
5. **装备**：复制一个 EquipmentPiece 场景并换 `texture`；`EquipmentManager.equip(slot, scene)` 替换指定槽。新槽在 Manager 注册并绑定对应 Anchor。
6. **武器**：复制 Sword 场景，保持 MudWeapon 脚本与 Hitbox、WeaponGrip 等节点；`WeaponManager.equip(scene)` 自动按 Grip 对齐。OffhandGrip、TrailOrigin、EffectOrigin、AudioOrigin 是扩展挂点。`grip_scale/stretch_multiplier` 目前是预留数据，尚未接入握持变形或双手 IK。
7. **动画**：`pose()` 是替换程序化 FK 的入口；可接入 AnimationPlayer 驱动角度参数，Renderer 仍只读取最终结果。当前 Attack 的窗口对应 0.62 秒动作，修改时要同步调整武器 `active_start/active_end`。
8. **AI**：关闭 `player_controlled`，由控制器调用 `set_intent(direction, jump, attack)`。

核心读取顺序：输入/状态 → 物理 → FK → 辅助弹簧 → SDF 数据 → 眼睛/插槽 → 最终像素输出。物理 Hurtbox 不受泥浆轮廓影响。

## 验证

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --import --quit
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/smoke_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/gait_test.gd
Godot_v4.7.1-stable_win64_console.exe --path . --script res://tests/visual_test.gd
```

`smoke_test.gd` 覆盖移动/起落、朝向、预备阶段禁用伤害、命中去重及下次挥剑重置、装备与身体拓扑解耦、深浅关节压缩、30/60 Hz 弹簧一致性和 30 人运行。`visual_test.gd` 使用真实 GPU，导出 `artifacts/` 下四种动作截图和 30 人截图，并打印 180 帧采样的中位及 P95 帧间隔；不要用 headless 执行此视觉测试。

新版步态另用 `gait_test.gd` 检查走/跑两种速度的完整周期：IK 可达性、主要承重腿伸展、持续躯干后拖、屈膝限制、脚尖穿地、支撑期位移抵消、脚部与骨盆边界连续性、参考姿态高低关系及停步过渡。`gait_visual.gd` 导出与参考编号对应的五张步行、十张跑步关键姿态；`gait_preview.gd` 导出用于合成预览动图的帧序列，成品为 `artifacts/locomotion_preview.gif`。

本机 RTX 4060 Laptop / OpenGL 新步态测试，30 人、640×360 内部分辨率、关闭垂直同步，帧间隔中位 1.29 ms / P95 5.83 ms。这是短时本机测试，不是低端硬件或完整游戏性能保证。每角色 24 段，Shader 数组上限 40；更改上限需同时更改 GDScript 与 Shader。没有流体、动态碰撞多边形或 CPU 网格重建。

技术参考：[Godot 官方 Shader 语言文档](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html)。具体兼容性以本地 4.7.1 实际编译和运行结果为准。
