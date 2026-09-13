# MudCharacter 姿势所有权

变换只允许由以下一层拥有：

- `CharacterBody2D`：游戏世界中的移动、碰撞与落点。
- `Visual/PoseRoot`：后坐、落地压缩、受击以及攻击突进等短时全身视觉偏移。
- `AnimationPlayer`：写入局部骨骼的作者动画基础姿势。
- `MudPoseComposer`：在当帧动画结果之上施加程序化覆盖或叠加，并在下一次动画求值前恢复上帧捕获的基础姿势。
- `Bone2D` 场景变换：不可变的标准参考姿势，以 `Bone2D.rest` 为唯一来源。

不要通过永久修改 Bone2D 场景节点来制作动画。所有作者姿势必须成为动画关键帧；保存 `mud_character.tscn` 前必须停止预览并返回 `RESET`。`RESET` 为根 AnimationLibrary 中的完整姿势，包含 `PoseRoot` 和每根骨骼的 position、rotation、scale。

现有动画的 Pelvis Y 保留为髋部升降、承重和压缩。Pelvis X 已迁移到 `PoseRoot.position.x`，它不再承担全身横向位移。角色真实位移仍完全属于 CharacterBody2D。

场景中的 `PoseValidation` 使用 `mud_pose_reference_validator.gd`。编辑器配置警告会逐属性比较 Bone2D 场景变换、`rest` 和 RESET；也可调用 `validate_reference_pose()` 立即输出 `[PoseValidation] Reference pose drift` 错误。

如需重新执行结构迁移，可运行 `Godot --headless --path . --script tools/refactor_mud_reference_pose.gd`。该工具只以现有 `rest` 为参考，不会把当前预览姿势定义成新基线。
