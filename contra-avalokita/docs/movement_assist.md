# 未堕移动辅助

`MudMovementAssist` 只拥有地面跳权限、未堕计时、输入缓冲和跳跃来源。`MudCharacter` 仍拥有唯一的 `_perform_jump()` 物理入口、速度、重力和动画状态；墙跳继续使用独立的墙体流程。

运行顺序：

```text
Input edge → Jump Buffer → Ground / UNFALLEN permission
           → JumpSource → _perform_jump() → existing locomotion / animation
```

内容管线：

```text
CoyoteItem Resource → base ContentDefinition / ContentRegistry
                    → MudItemInventory
                    → modifier aggregation
                    → MudMovementAssist effective values
                    → gameplay query
```

时长加成为加法叠加，跳跃倍率为乘法叠加，初始重力持续时间取最大值。移除物品时从不可变基础值重新聚合。角色代码不检查本地化物品名称。

本地 hit stop 在 `_physics_process()` 更新 MovementAssist 之前返回，因此暂停期间未堕和输入缓冲计时不会流逝。`HeavyHit` 与 `Knockdown` 导致的离地会禁止创建新的地面未堕窗口；墙面离开与墙跳也不会授予地面未堕权限。

测试场按 `F1` 显示未堕剩余、输入缓冲、重力倍率和最近跳跃来源，按 `F6` 显示五张物品卡。角色启用 `movement_assist_debug` 后会在未堕期间于脚边绘制白线与空心圆。
