class_name TankEngine
extends Node

@export var diagnostics: Control
@onready var D := diagnostics

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
@export var brake_scale: float = 75.0

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
			'max_speed': 10 
		},
	-1: 
		{
			"name": "Reverse",
			'color': Color.RED, 
			'torque_high': 100,
			'torque_low': 100,
			'low_speed': 0,
			'max_speed': 10 
		},
	 0: 
		{
			"name": "Neutral",
			'color': Color(.2, .7, 1), 
			'torque_high': 0,
			'torque_low': 0,
			'low_speed': 0,
			'max_speed': 10 
		},
	 1: 
		{
			"name": "Drive 1",
			'color': Color.WHITE, 
			'torque_high': 100,
			'torque_low': 100,
			'low_speed': 0,
			'max_speed': 10 
		},
	 2: 
		{
			"name": "Drive 2",
			'color': Color.WHITE, 
			'torque_high': 100,
			'torque_low': 75,
			'low_speed': 10,
			'max_speed': 40 
		},
	 3: 
		{
			"name": "Drive 3",
			'color': Color.WHITE, 
			'torque_high': 75,
			'torque_low': 30,
			'low_speed': 40,
			'max_speed': 90 
		},
	 4: 
		{
			"name": "Drive 4",
			'color': Color.YELLOW, 
			'torque_high': 35,
			'torque_low': 10,
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


## Apply braking torque like car brakes.
## `brake` should be 0.0 (no brake) to 1.0 (full brake).
## Braking torque always opposes current track motion.
func apply_brake(brake: float) -> void:
	var b := clampf(brake, 0.0, 1.0)
	if b <= 0.0:
		return

	var speeds := get_track_speed()
	var left_sign := 0.0
	var right_sign := 0.0

	if absf(speeds.x) > 0.001:
		left_sign = signf(speeds.x)
	if absf(speeds.y) > 0.001:
		right_sign = signf(speeds.y)

	if left_sign == 0.0 and right_sign == 0.0:
		return

	var brake_torque_Nm: float = b * brake_scale

	# Oppose current motion: apply raw N·m so braking is not scaled by gear torque.
	var left_brake := -left_sign * brake_torque_Nm
	var right_brake := -right_sign * brake_torque_Nm
	_apply_track_torque_raw(left_brake, right_brake)


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

	D.throttle(abs(throttle) - brake)
	D.steer(steer)


	var left_torque := throttle + steer
	var right_torque := throttle - steer


	set_track_torque(left_torque, right_torque)
	D.writeStat("Torque: ", left_torque, ", ")
	D.writeStat("", right_torque)

	var track_speed := get_track_speed()
	D.writeStat("Track Speed: ", track_speed.x, " m/s, ")
	D.writeStat("", track_speed.y, " m/s\n")

	var avg_speed_ms := (track_speed.x + track_speed.y) / 2.0
	var avg_speed_kmh := avg_speed_ms * 3.6
	var avg_speed_mph := avg_speed_ms * 2.23694
	
	D.writeStat("Speed: ", avg_speed_ms, " m/s, ")
	D.writeStat("", avg_speed_kmh, " KPH, ")
	D.writeStat("", avg_speed_mph, " MPH\n")


	D.writeStat("Max Speed: ", Gears[gear]['max_speed'], " m/s\n")
	D.writeStat("Torque: ", Gears[gear]['torque_low'], " -")
	D.writeStat("", torque, " -")
	D.writeStat("", Gears[gear]['torque_high'], " Nm\n")


	if brake > 0.0:
		apply_brake(brake)


	if Input.is_action_just_pressed("Gear Up"):
		shiftUp()

	if Input.is_action_just_pressed("Gear Down"):
		shiftDown()

	D.close()
