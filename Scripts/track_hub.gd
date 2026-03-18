extends Node3D

@export var mount: RigidBody3D
@onready var pivot: Generic6DOFJoint3D = $Generic6DOFJoint3D

@export var isRight: bool = false

@export var max_speed: float = 30.0
@export var track_radius_drive: float = 0.25
const ROAD_WHEEL_RADIUS: float = 0.2
@export var drive_inertia: float = 50.0
@export var drive_damping: float = 5.0

var _engine_torque: float = 0.0
var _reaction_torque: float = 0.0


func _ready() -> void:
	if pivot:
		pivot.node_a = pivot.get_path_to(mount)


func get_drive_wheel() -> RigidBody3D:
	var w = get_node_or_null("Wheel")
	return w as RigidBody3D if w else null


func get_road_wheels() -> Array[RigidBody3D]:
	var list: Array[RigidBody3D] = []
	for child in get_children():
		if child.has_method("_rigidBodyProvider"):
			var body = child._rigidBodyProvider()
			if body is RigidBody3D:
				list.append(body)
	return list


func apply_engine_torque(torque: float) -> void:
	_engine_torque += torque


func take_engine_torque() -> float:
	var t = _engine_torque
	_engine_torque = 0.0
	return t


func set_reaction_torque(torque: float) -> void:
	_reaction_torque = torque


func get_reaction_torque() -> float:
	return _reaction_torque
