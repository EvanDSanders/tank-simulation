extends Node3D

@onready var spring: Generic6DOFJoint3D = $Spring
@onready var motor:  Generic6DOFJoint3D = $Axel
@export var mount: RigidBody3D

@onready var SPR:= $TrackingPoint

var side: String
var is_unlocked: bool = false

func _set_isRight(isRight: bool, ID: int) -> void:
	side = "R" if isRight else "L"

	$Wheel/TrackingPoint._setup("Wheel.%d.%s" % [ID, side], Vector3(0, 1.571 if isRight else -1.571, 0))
	$"Wheel Base/TrackingPoint"._setup("Spring.%d.%s" % [ID, side])
	SPR._setup("Mount.%d.%s" % [ID, side])

func _ready() -> void:

	if spring:
		spring.node_a = spring.get_path_to(mount)
		
	SPR.reparent(mount, true)
		
	
func _rigidBodyProvider():
	return $Wheel


	#motor.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_MOTOR, true)

#func _physics_process(_delta: float) -> void:
	#if Input.is_action_just_pressed("Toggle N"):
		#is_unlocked = not is_unlocked
		#motor.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_MOTOR, is_unlocked)
#
	#var speed := Input.get_axis("Forward " + side, "Backward " + side)
	#motor.set_param_x( Generic6DOFJoint3D.PARAM_ANGULAR_MOTOR_TARGET_VELOCITY, speed * 75.0)
	#
