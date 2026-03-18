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
var _track_speed: float = 0.0

## Cumulative rotation of the track (radians), from integrating get_track_speed().
var _track_angle: float = 0.0

## Current gear max speed limit (m/s). Set by engine each frame. INF = no limit.
var _max_speed_limit: float = INF


func _ready() -> void:
	if pivot:
		pivot.node_a = pivot.get_path_to(mount)
		
	var c = 0;
	for each in self.find_children("*"):
		if each.has_method('_set_isRight'):
			each._set_isRight(isRight, c)
			c += 1;
	
	var side = "R" if isRight else "L"
	$Wheel/TrackingPoint._setup("Drive Wheel.%s" % [side], Vector3(0, 1.571 if isRight else -1.571, 0))
	$"Track Base/TrackingPoint"._setup("Track Hub.%s" % [side])


func _physics_process(delta: float) -> void:
	# Integrate track speed (m/s) / radius -> angular velocity; accumulate angle.
	var omega: float = get_track_speed() / track_radius_drive
	_track_angle += omega * delta


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


func set_track_speed(speed: float) -> void:
	_track_speed = speed


func get_track_speed() -> float:
	return _track_speed


func get_track_angle() -> float:
	return _track_angle


func set_max_speed_limit(limit_m_s: float) -> void:
	_max_speed_limit = limit_m_s


func get_max_speed_limit() -> float:
	return _max_speed_limit
