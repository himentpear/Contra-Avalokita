# SDF Morph Renderer

SDF Morph 是基础泥浆人体与装甲/武器之间的独立视觉层：

```text
Skeleton2D
  → Base Anatomy capsules (MAX_SEGMENTS = 40)
  → Morph ADD
  → Morph SUBTRACT
  → impact / death
  → depth filtering
  → pixel lighting / outline
  → Armor / Weapon / VFX
```

Modifier 不修改 Bone2D、AnimationPlayer、IK、碰撞体或装备节点。所有角色共用同一个 shader；每个 Renderer 只复用固定长度为 16 的上传数组。

## Runtime API

```gdscript
var profile := preload("res://content/base/morphs/hungry_ghost.tres")
character.body_renderer.apply_morph_profile(profile)
character.body_renderer.remove_morph_profile(profile)
character.body_renderer.clear_morph_profiles()
```

重复添加同一个 Resource 是幂等操作。多个 Profile 的头、躯干、手臂与腿部倍率相乘；最后一个启用的颜色覆盖生效。超过 16 个 Modifier 时只上传前 16 个并输出警告。

## Modifier authoring

`SdfModifier` 支持：

- `ADD` / `SUBTRACT`
- `CIRCLE` / `CAPSULE`
- `anchor` 与可选 `anchor_b`
- 锚点局部偏移、半径、长度、旋转、softness 与 `-1 / 0 / 1` 深度

局部偏移会随锚点方向旋转。双锚点 capsule 会在每帧重新解析两个端点，适合沿前臂或腿部生长的结构。

常用锚点包括 `Head`、`Neck`、`Chest`、`Torso`、`Abdomen`、`Pelvis`、`ArmFrontStart/Joint/End`、`ArmBackStart/Joint/End`、`LegFrontStart/Joint/End` 与 `LegBackStart/Joint/End`，也可使用已有的 `Pre/Post/Heel/Foot/Toe` 辅助点。

## Development profiles

`resources/morphs/` 提供：

- `swollen_arm.tres`：前臂 ADD capsule
- `hungry_ghost.tres`：腹部 SUBTRACT circle
- `asura_shoulder.tres`：前肩 ADD circle + capsule
- `hollow_face.tres`：头部 SUBTRACT circle
- `spine_growth.tres`：后侧四点 ADD growth

运行 `res://tools/generate_test_morph_profiles.gd` 可重建这些开发资源。

## Debug and verification

测试场景按 F1 同时显示骨架和 Morph：ADD 为绿色、SUBTRACT 为红色、Anchor 为白点，并列出名称、锚点、操作与半径。

```powershell
godot --headless --path . --script res://tests/sdf_morph_test.gd
godot --path . --script res://tests/sdf_morph_preview.gd
```
