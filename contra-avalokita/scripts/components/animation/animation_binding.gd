class_name AnimationBinding
extends RefCounted

var animation_player: AnimationPlayer
var skeleton: Skeleton2D

func bind(player: AnimationPlayer, target_skeleton: Skeleton2D = null) -> AnimationBinding:
	animation_player = player
	skeleton = target_skeleton
	return self

func has_animation(animation: StringName) -> bool:
	return animation_player != null and animation_player.has_animation(animation)

func play(animation: StringName, blend_time := -1.0) -> bool:
	if animation == &"" or animation_player == null or not animation_player.has_animation(animation):
		return false
	animation_player.play(animation, blend_time)
	return true
