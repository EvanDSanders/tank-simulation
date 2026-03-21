class_name TankEngine
extends Node

@export var diagnostics: Control
@onready var D := diagnostics
@onready var tankFrame: RigidBody3D = $"../Frame"

@export var left_track_hub: Node
@export var right_track_hub: Node

## Scale input (-1..1) to drive acceleration at the tread (tuned for feel).
@export var accel_low: float = 0
@export var accel_high: float = 50
@export var max_speed: float = 10
@export var low_speed: float = 0

@onready var controller: DualSenseCtl = $DualSenseCtl
@onready var soundEmitter := $"../Frame/AudioStreamPlayer3D"

var accel: float = 0

## Brake torque in N·m when brake = 1.0. Not scaled by gear.
@export var brake_scale: float = 250

var isShifting := false

var gear := 1

func _ready() -> void:
	_apply_current_gear()

const GearsBox = {   #  -2   -1     0    1       2       3       4
	  'accel_high':  [	0,	400,	0,	400,	250, 	250,	200	]
	, 'accel_low' :  [	0,	200,	0,	200,	300, 	150,	100	]
	, 'low_speed' :  [	0,	0,		0,	0,		15, 	40,		90	]
	, 'max_speed' :  [	0,	15,		0,	15,		40, 	90,		150	]
}				     #  0   1       2    3       4       5       6


var Gears := {
	-2: 
		{
			"name": "Park",
			'color': Color.RED, 
			'accel_high': GearsBox['accel_high'][0],
			'accel_low':  GearsBox['accel_low' ][0],
			'low_speed':  GearsBox['low_speed' ][0],
			'max_speed':  GearsBox['max_speed' ][0] 
		},
	-1: 
		{
			"name": "Reverse",
			'color': Color.RED, 
			'accel_high': GearsBox['accel_high'][1],
			'accel_low':  GearsBox['accel_low' ][1],
			'low_speed':  GearsBox['low_speed' ][1],
			'max_speed':  GearsBox['max_speed' ][1] 
		},
	 0: 
		{
			"name": "Neutral",
			'color': Color(.2, .7, 1), 
			'accel_high': GearsBox['accel_high'][2],
			'accel_low':  GearsBox['accel_low' ][2],
			'low_speed':  GearsBox['low_speed' ][2],
			'max_speed':  GearsBox['max_speed' ][2] 
		},
	 1: 
		{
			"name": "Drive 1",
			'color': Color.WHITE, 
			'accel_high': GearsBox['accel_high'][3],
			'accel_low':  GearsBox['accel_low' ][3],
			'low_speed':  GearsBox['low_speed' ][3],
			'max_speed':  GearsBox['max_speed' ][3] 
		},
	 2: 
		{
			"name": "Drive 2",
			'color': Color.WHITE, 
			'accel_high': GearsBox['accel_high'][4],
			'accel_low':  GearsBox['accel_low' ][4],
			'low_speed':  GearsBox['low_speed' ][4],
			'max_speed':  GearsBox['max_speed' ][4] 
		},
	 3: 
		{
			"name": "Drive 3",
			'color': Color.WHITE, 
			'accel_high': GearsBox['accel_high'][5],
			'accel_low':  GearsBox['accel_low' ][5],
			'low_speed':  GearsBox['low_speed' ][5],
			'max_speed':  GearsBox['max_speed' ][5] 
		},
	 4: 
		{
			"name": "Drive 4",
			'color': Color.YELLOW, 
			'accel_high': GearsBox['accel_high'][6],
			'accel_low':  GearsBox['accel_low' ][6],
			'low_speed':  GearsBox['low_speed' ][6],
			'max_speed':  GearsBox['max_speed' ][6] 
		},
}

func set_track_accel(left_accel_mult: float, right_accel_mult: float) -> void:
	var left := left_accel_mult * accel
	var right := right_accel_mult * accel
	if left_track_hub and left_track_hub.has_method("apply_engine_accel"):
		left_track_hub.apply_engine_accel(left)
	if right_track_hub and right_track_hub.has_method("apply_engine_accel"):
		right_track_hub.apply_engine_accel(right)


## Apply raw torque in N·m to both tracks (no gear scaling). Used for braking.
func _apply_track_torque_raw(left_Nm: float, right_Nm: float) -> void:
	if left_track_hub and left_track_hub.has_method("apply_engine_torque"):
		left_track_hub.apply_engine_torque(left_Nm)
	if right_track_hub and right_track_hub.has_method("apply_engine_torque"):
		right_track_hub.apply_engine_torque(right_Nm)


## Returns reaction torque from both drives: x = left, y = right (from get_reaction_torque on each hub).
func get_drive_reaction() -> Vector2:
	var left: float = 0.0
	var right: float = 0.0
	if left_track_hub and left_track_hub.has_method("get_reaction_torque"):
		left = left_track_hub.get_reaction_torque()
	if right_track_hub and right_track_hub.has_method("get_reaction_torque"):
		right = right_track_hub.get_reaction_torque()
	return Vector2(left, right)


## Returns current track surface speed in m/s: x = left, y = right.
func get_track_speed() -> Vector2:
	var left: float = 0.0
	var right: float = 0.0
	if left_track_hub and left_track_hub.has_method("get_track_speed"):
		left = left_track_hub.get_track_speed()
	if right_track_hub and right_track_hub.has_method("get_track_speed"):
		right = right_track_hub.get_track_speed()
	return Vector2(left, right)


## Apply braking torque per track (0–1 each). Opposes that side's current motion; raw N·m, not gear-scaled.
func apply_brake(left_brake: float, right_brake: float) -> void:
	var bl := clampf(left_brake, 0.0, 1.0)
	var br := clampf(right_brake, 0.0, 1.0)
	if bl <= 0.0 and br <= 0.0:
		return

	var speeds := get_track_speed()
	var left_sign := 0.0
	var right_sign := 0.0

	if absf(speeds.x) > 0.001:
		left_sign = signf(speeds.x)
	if absf(speeds.y) > 0.001:
		right_sign = signf(speeds.y)

	var left_Nm := 0.0
	var right_Nm := 0.0
	if bl > 0.0 and left_sign != 0.0:
		left_Nm = -left_sign * bl * brake_scale
	if br > 0.0 and right_sign != 0.0:
		right_Nm = -right_sign * br * brake_scale

	if left_Nm == 0.0 and right_Nm == 0.0:
		return

	_apply_track_torque_raw(left_Nm, right_Nm)


func apply_brake_left(brake: float) -> void:
	apply_brake(brake, 0.0)


func apply_brake_right(brake: float) -> void:
	apply_brake(0.0, brake)


func _apply_current_gear() -> void:
	_apply_gear(gear)

func _apply_gear(loadGear: int) -> void:
	var data = Gears.get(loadGear, null)
	if data == null:
		return
	accel_low = data["accel_low"]
	accel_high = data["accel_high"]
	low_speed = data["low_speed"]
	max_speed = data["max_speed"]
	controller.response(data["name"])
	accel = 0.0
	D.shift(Gears[gear])



func _compute_accel(avg_speed: float) -> float:
	var buffer: float = 5.0
	var drop_factor: float = 0.2

	# Below low_speed - 5: drop acceleration significantly.
	if avg_speed <= low_speed - buffer:
		return accel_high * drop_factor

	# From low_speed - 5 up to low_speed: ramp back up to accel_high.
	if avg_speed < low_speed:
		return Globals.remap(low_speed - buffer, low_speed, accel_high * drop_factor, accel_high, avg_speed)

	# Between low_speed and max_speed: fade from accel_high to accel_low.
	if avg_speed <= max_speed:
		return Globals.remap(low_speed, max_speed, accel_high, accel_low, avg_speed)

	# From max_speed up to max_speed + 5: fade accel_low down to zero.
	if avg_speed < max_speed + buffer:
		return Globals.remap(max_speed, max_speed + buffer, accel_low, 0.0, avg_speed)

	# Above max_speed + 5: stop acceleration.
	return 0.0

func shiftUp() -> void:
	if gear >= 4:
		print("Max Gear")
		return
	gear += 1
	shiftByDelay()
	print("Shift Up to Gear ", gear)

func shiftDown() -> void:
	if gear <= -2:
		print("Min Gear")
		return
	gear -= 1
	shiftByDelay()
	print("Shift Down to Gear ", gear)

func shiftByDelay() -> void:
	_apply_gear(0)
	isShifting = true
	$Timer.start()

func shiftTimout() -> void:
	isShifting = false
	_apply_current_gear()


func _physics_process(_delta: float) -> void:
	D.begin()

	var track_speed := get_track_speed()
	var avg_speed : float = (abs(track_speed.x) + abs(track_speed.y)) / 2.0


	var throttle := Globals.throttle()
	var steer := Globals.steer(false)
	var brake := Globals.brake()





	var reaction := get_drive_reaction()
	D.writeStat("Reaction: ", reaction.x, ", ")
	D.writeStat("", reaction.y)

	if gear == 0 or gear == -2 and not isShifting:
		soundEmitter.engineAudio(throttle, D)
	elif not isShifting:
		soundEmitter.engineAudio( clampf( Globals.remap(low_speed, max_speed+5, 0.0, .75, avg_speed), 0.0, 1.0 ) 
				* (throttle + abs(steer)*.7) 
				+ throttle*0.25
				# - (abs(reaction.x) + abs(reaction.y))*0.25
				, D)
	else:
		soundEmitter.engineAudio(0.0, D)


	if gear >= 1:
		pass
	elif gear == 0:
		throttle = 0.0
	elif gear == -1:
		throttle = -throttle
	elif gear == -2:
		throttle = 0.0
		brake = 1.0

	D.throttle(throttle)
	D.brake(brake)
	D.steer(steer)

	accel = _compute_accel(avg_speed)

	# Steering as a constant left/right speed offset (keeps total accel symmetric).
	var steer_offset: float = steer * 0.75

	# Yaw-rate counter-steering (local Y axis angular velocity).
	var yaw_omega_y: float = tankFrame.angular_velocity.dot(tankFrame.global_transform.basis.y)
	var yaw_counter: float = clampf(yaw_omega_y * 0.25, -1.0, 1.0) * abs(steer)

	var left_accel_mult: float = throttle + steer_offset - yaw_counter
	var right_accel_mult: float = throttle - steer_offset + yaw_counter

	set_track_accel(left_accel_mult, right_accel_mult)


	var left_accel_cmd: float = left_accel_mult * accel
	var right_accel_cmd: float = right_accel_mult * accel
	D.writeStat("Accel: ", left_accel_cmd, ", ")
	D.writeStat("", right_accel_cmd)

	D.writeStat("Track Speed: ", track_speed.x, " m/s, ")
	D.writeStat("", track_speed.y, " m/s\n")

	var avg_speed_kmh := avg_speed * 3.6
	var avg_speed_mph := avg_speed * 2.23694
	
	D.writeStat("Speed: ", avg_speed, " m/s, ")
	D.writeStat("", avg_speed_kmh, " KPH, ")
	D.writeStat("", avg_speed_mph, " MPH\n")


	D.writeStat("Max Speed: ", Gears[gear]['max_speed'], " m/s\n")
	D.writeStat("Accel: ", Gears[gear]['accel_high'], " -")
	D.writeStat("", accel, " -")
	D.writeStat("", Gears[gear]['accel_low'], " m/s\n")


	if brake > 0.0:
		apply_brake(brake, brake)

	if not isShifting:
		if Input.is_action_just_pressed("Gear Up"):
			shiftUp()

		if Input.is_action_just_pressed("Gear Down"):
			shiftDown()

	D.close()
