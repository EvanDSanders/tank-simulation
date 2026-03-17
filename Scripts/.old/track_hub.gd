extends Node3D

@export var mount: RigidBody3D
@onready var pivot: Generic6DOFJoint3D = $Generic6DOFJoint3D

@export var isRight: bool = false

var wheels: Array[RigidBody3D]
var wheel_speeds: Array[float]
var wheel_angles: Array[float]
var consensus: float = 0.0

# Called when the node enters the scene tree for the first time.
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
			
	for each in self.find_children("Wheel", "RigidBody3D"):
		if each.has_method("_setup"):
			each._setup(self, wheels.size())
			wheels.append(each)
			wheel_speeds.append(0.0)
			wheel_angles.append(0.0)

func tell(ID: int, speed: float, angle: float) -> void:
	self.wheel_speeds[ID] = speed
	self.wheel_angles[ID] = angle

func get_consensus() -> float:
	return self.consensus

func get_master_angle() -> float:
	return self.wheel_angles[0]

func _physics_process(delta: float) -> void:
	var measured = 0
	for s in wheel_speeds:
		measured += s
	measured /= wheel_speeds.size()
	
	var input = Globals.input(isRight)
	
	consensus = Globals.lerp(measured, input, 0.1)
