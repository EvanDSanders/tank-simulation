class_name TankEngine
extends Node

@export var diagnostics: Control
@onready var D := diagnostics
@onready var tankFrame: RigidBody3D = $"../Frame"

@export var left_track_hub: Node
@export var right_track_hub: Node

## Scale input (-1..1) to drive torque in N·m. Increase if the tank doesn't move.
@export var torque_low: float = 0
@export var torque_high: float = 50
@export var max_speed: float = 10
@export var low_speed: float = 0

@onready var controller: DualSenseCtl = $DualSenseCtl

var torque: float = 0

## Brake torque in N·m when brake = 1.0. Not scaled by gear.
@export var brake_scale: float = 250

var gear := 1

func _ready() -> void:
	_apply_current_gear()

var Gears := {
	-2: 
		{
			"name": "Park",
			'color': Color.RED, 
			'torque_high': 0,
			'torque_low': 0,
			'low_speed': 0,
			'max_speed': 20 
		},
	-1: 
		{
			"name": "Reverse",
			'color': Color.RED, 
			'torque_high': 200,
			'torque_low': 150,
			'low_speed': 0,
			'max_speed': 20 
		},
	 0: 
		{
			"name": "Neutral",
			'color': Color(.2, .7, 1), 
			'torque_high': 0,
			'torque_low': 0,
			'low_speed': 0,
			'max_speed': 20 
		},
	 1: 
		{
			"name": "Drive 1",
			'color': Color.WHITE, 
			'torque_high': 200,
			'torque_low': 150,
			'low_speed': 0,
			'max_speed': 20 
		},
	 2: 
		{
			"name": "Drive 2",
			'color': Color.WHITE, 
			'torque_high': 150,
			'torque_low': 90,
			'low_speed': 20,
			'max_speed': 45 
		},
	 3: 
		{
			"name": "Drive 3",
			'color': Color.WHITE, 
			'torque_high': 90,
			'torque_low': 40,
			'low_speed': 45,
			'max_speed': 90 
		},
	 4: 
		{
			"name": "Drive 4",
			'color': Color.YELLOW, 
			'torque_high': 40,
			'torque_low': 15,
			'low_speed': 90,
			'max_speed': 150 
		},
}

func set_track_torque(left_torque: float, right_torque: float) -> void:
	var left := left_torque * torque
	var right := right_torque * torque
	if left_track_hub and left_track_hub.has_method("apply_engine_torque"):
		left_track_hub.apply_engine_torque(left)
	if right_track_hub and right_track_hub.has_method("apply_engine_torque"):
		right_track_hub.apply_engine_torque(right)


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
	var data = Gears.get(gear, null)
	if data == null:
		return
	torque_low = data["torque_low"]
	torque_high = data["torque_high"]
	low_speed = data["low_speed"]
	max_speed = data["max_speed"]
	controller.response(data["name"])
	var s: float = ( abs(get_track_speed().x) + abs(get_track_speed().y) ) / 2.0
	# Clamp so torque stays in [torque_low, torque_high]; beyond max_speed we don't add more drive.
	s = clampf(s, low_speed, max_speed)
	torque = Globals.remap(low_speed, max_speed, torque_low, torque_high, s)

func shiftUp() -> void:
	if gear >= 4:
		print("Max Gear")
		return
	gear += 1
	_apply_current_gear()
	D.shift(Gears[gear])
	print("Shift Up to Gear ", gear)


func shiftDown() -> void:
	if gear <= -2:
		print("Min Gear")
		return
	gear -= 1
	_apply_current_gear()
	D.shift(Gears[gear])
	print("Shift Down to Gear ", gear)


func _physics_process(_delta: float) -> void:
	D.begin()

	var track_speed := get_track_speed()
	var avg_speed : float = (abs(track_speed.x) + abs(track_speed.y)) / 2.0

	# Update torque from current speed every frame so the gear torque curve applies (e.g. gear 2+ can pull past 10 m/s).
	# _apply_current_gear()

	# Enforce current gear max speed on both tracks.
	if left_track_hub and left_track_hub.has_method("set_max_speed_limit"):
		left_track_hub.set_max_speed_limit(max_speed)
	if right_track_hub and right_track_hub.has_method("set_max_speed_limit"):
		right_track_hub.set_max_speed_limit(max_speed)

	var throttle := Globals.throttle()
	var steer := Globals.steer(false)
	var brake := Globals.brake()



	var reaction := get_drive_reaction()
	D.writeStat("Reaction: ", reaction.x, ", ")
	D.writeStat("", reaction.y)

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

	var steer_fac       := clampf( Globals.remap(5, 10, 1, 0, avg_speed), 0, 1 )
	var steer_fac_brake := clampf( Globals.remap(5, 10, 0, 1, avg_speed), 0, 1 )

	
	
	
	
	var left_torque  := throttle + steer * 0.75 * steer_fac
	var right_torque := throttle - steer * 0.75 * steer_fac
	
	set_track_torque(left_torque, right_torque)

	apply_brake_left	( -steer * steer_fac_brake * .99 )
	apply_brake_right	( +steer * steer_fac_brake * .99 )


	D.writeStat("Torque: ", left_torque, ", ")
	D.writeStat("", right_torque)

	D.writeStat("Track Speed: ", track_speed.x, " m/s, ")
	D.writeStat("", track_speed.y, " m/s\n")

	var avg_speed_kmh := avg_speed * 3.6
	var avg_speed_mph := avg_speed * 2.23694
	
	D.writeStat("Speed: ", avg_speed, " m/s, ")
	D.writeStat("", avg_speed_kmh, " KPH, ")
	D.writeStat("", avg_speed_mph, " MPH\n")


	D.writeStat("Max Speed: ", Gears[gear]['max_speed'], " m/s\n")
	D.writeStat("Torque: ", Gears[gear]['torque_low'], " -")
	D.writeStat("", torque, " -")
	D.writeStat("", Gears[gear]['torque_high'], " Nm\n")


	if brake > 0.0:
		apply_brake(brake, brake)


	if Input.is_action_just_pressed("Gear Up"):
		shiftUp()

	if Input.is_action_just_pressed("Gear Down"):
		shiftDown()

	D.close()
