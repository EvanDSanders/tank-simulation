extends Node3D

@export var mount: RigidBody3D
@onready var pivot: Generic6DOFJoint3D = $Generic6DOFJoint3D

@export var isRight: bool = false

var wheels: Array[RigidBody3D]
var wheel_speeds: Array[float]
var wheel_angles: Array[float]
var consensus: float = 0.0


@export var drive_speed: float = 0.0   # commanded track surface speed
@export var max_accel: float = 50
@export var max_decel: float = 50
@export var max_speed: float = 30.0
@export var drag_coeff: float = 0.4
@export var coast_when_neutral: bool = true  # when true, releasing throttle keeps current speed instead of braking
@export var turn_rate: float = 1.0



@export var debug: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	debug.isRight = isRight
		
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


var frame: int = 0
func _physics_process(delta: float) -> void:
	var measured = 0.0
	for s in wheel_speeds:
		measured += s
	if wheel_speeds.size() > 0:
		measured /= wheel_speeds.size()

	# Input in [-1, 1] as throttle
	var power := Globals.throttle()
	var steer := Globals.steer(isRight)
	
	var throttle := power * 1 # + steer * 0.2


	# Target speed from throttle (simple linear “gear” model)
	var target_speed := throttle * max_speed
	if coast_when_neutral and abs(throttle) < 0.01:
		target_speed = drive_speed  # maintain current speed — coast

	# Drag/rolling resistance (opposes current speed); use drive_speed so both tracks get same drag and stay in sync
	var drag: float = -drive_speed * Globals.remap(0, 1, drag_coeff, 0, abs(power))

	# Desired change in speed
	var desired_accel := (target_speed - drive_speed) * 4.0   # "engine" trying to reach target
	desired_accel += drag

	# Clamp accel for realism: decel when slowing down (reducing |speed|), accel when speeding up
	# Slowing down = accel opposes current direction (drive_speed * desired_accel < 0)
	var slowing_down := drive_speed * desired_accel < 0.0
	var accel_limit := max_decel if slowing_down else max_accel
	desired_accel = clamp(desired_accel, -accel_limit, accel_limit)

	# Integrate to get new drive_speed
	drive_speed += desired_accel * delta
	drive_speed = clamp(drive_speed, -max_speed, max_speed)

	# Steer adds differential: target speed for this track = base + steer offset
	var steer_amount: float = steer * 10.0 * (1.0 + abs(drive_speed) / max_speed) * turn_rate
	var target_consensus := drive_speed + steer_amount
	# Blend toward target so flipping steer immediately pulls consensus the right way
	consensus = lerpf(measured, target_consensus, 0.35)




	if frame % 4 == 0:
		# Debug
		debug.throttle = throttle
		debug.target_speed = target_speed
		debug.drag = drag
		debug.desired_accel = desired_accel
		debug.accel_limit = accel_limit
		debug.drive_speed = drive_speed
		debug.blended = consensus

	frame += 1
