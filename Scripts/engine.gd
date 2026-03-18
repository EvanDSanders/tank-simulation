class_name TankEngine
extends Node

@export var diagnostics: Control
@onready var D := diagnostics

@export var left_track_hub: Node
@export var right_track_hub: Node
## Scale input (-1..1) to torque in N·m. Increase if the tank doesn't move.
@export var torque_scale: float = 50


func set_track_torque(left_torque: float, right_torque: float) -> void:
	var left := left_torque * torque_scale
	var right := right_torque * torque_scale
	if left_track_hub and left_track_hub.has_method("apply_engine_torque"):
		left_track_hub.apply_engine_torque(left)
	if right_track_hub and right_track_hub.has_method("apply_engine_torque"):
		right_track_hub.apply_engine_torque(right)


## Returns reaction torque from both drives: x = left, y = right (from get_reaction_torque on each hub).
func get_drive_reaction() -> Vector2:
	var left: float = 0.0
	var right: float = 0.0
	if left_track_hub and left_track_hub.has_method("get_reaction_torque"):
		left = left_track_hub.get_reaction_torque()
	if right_track_hub and right_track_hub.has_method("get_reaction_torque"):
		right = right_track_hub.get_reaction_torque()
	return Vector2(left, right)

func _physics_process(_delta: float) -> void:
	D.begin()

	var throttle := Globals.throttle()
	var steer := Globals.steer(false)

	D.throttle(throttle)
	D.steer(steer)


	var reaction := get_drive_reaction()
	D.writeStat("Reaction", reaction.x, ", ")
	D.writeStat("Reaction", reaction.y)

	var left_torque := throttle + steer
	var right_torque := throttle - steer
	set_track_torque(left_torque, right_torque)
	D.writeStat("Left Torque", left_torque, ", ")
	D.writeStat("Right Torque", right_torque)
