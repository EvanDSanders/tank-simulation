extends Node
class_name GearShifter


@export var track_L: Node3D
@export var track_R: Node3D

@onready var timer: Timer = $Timer
var timerRunning: bool = false

var gear: int = 1


var Gears: Dictionary = {
	1: {
		"max_accel": 50,
		"max_decel": 50,
		"max_speed": 30.0,
		"turn_rate": 1,
	},
	2: {
		"max_accel": 12,
		"max_decel": 60,
		"max_speed": 70.0,
		"turn_rate": 1.7,
	},
	3: {
		"max_accel": 8,
		"max_decel": 80,
		"max_speed": 140.0,
		"turn_rate": 3,
	},
	4: {
		"max_accel": 4,
		"max_decel": 90,
		"max_speed": 200.0,
		"turn_rate": 6,
	},
}
	


func _ready() -> void:
	pass


func loadGear() -> void:
	print("Loading gear %d" % [gear])
	track_L.max_accel = Gears[self.gear]["max_accel"]
	track_L.max_decel = Gears[self.gear]["max_decel"]
	track_L.max_speed = Gears[self.gear]["max_speed"]
	track_L.turn_rate = Gears[self.gear]["turn_rate"]

	track_R.max_accel = Gears[self.gear]["max_accel"]
	track_R.max_decel = Gears[self.gear]["max_decel"]
	track_R.max_speed = Gears[self.gear]["max_speed"]
	track_R.turn_rate = Gears[self.gear]["turn_rate"]


var frame: int = 0
func _process(_delta: float) -> void:
	frame += 1
	if frame % 30 == 0:
		print("Gear: %d, Track L: %f, Track R: %f" % [gear, track_L.drive_speed, track_R.drive_speed])

	match gear:
		1:
			# Initiate shift up
			if track_L.drive_speed >= 29.75 and track_R.drive_speed >= 29.75 and not timerRunning:
				timerRunning = true
				timer.start()
				print("Shift up to 2 initiated")

			# Cancel shift up: Too slow
			if timerRunning and ( track_L.drive_speed < 29.5 or track_R.drive_speed < 29.5 ):
				timerRunning = false
				timer.stop()
				print("Shift up to 2 cancelled")
		2:
			# Initiate shift up
			if track_L.drive_speed >= 69.75 and track_R.drive_speed >= 69.75 and not timerRunning:
				timerRunning = true
				timer.start()
				print("Shift up to 3 initiated")

			# Cancel shift up: Too slow
			if timerRunning and ( track_L.drive_speed < 69.5 or track_R.drive_speed < 69.5 ):
				timerRunning = false
				timer.stop()
				print("Shift up to 3 cancelled")

			# Shift down: Too slow
			if track_L.drive_speed < 29.5 and track_R.drive_speed < 29.5:
				gear = 1
				loadGear()
				print("Shifting down to 1")

		3:
			# Initiate shift up
			if track_L.drive_speed >= 139.75 and track_R.drive_speed >= 139.75 and not timerRunning:
				timerRunning = true
				timer.start()
				print("Shift up to 4 initiated")

			# Cancel shift up: Too slow
			if timerRunning and ( track_L.drive_speed < 139.5 or track_R.drive_speed < 139.5 ):
				timerRunning = false
				timer.stop()
				print("Shift up to 4 cancelled")

			# Shift down: Too slow
			if track_L.drive_speed < 69.5 and track_R.drive_speed < 69.5:
				gear = 2
				loadGear()
				print("Shifting down to 2")

		4:
			# Shift down: Too slow
			if track_L.drive_speed < 139.5 and track_R.drive_speed < 139.5:
				gear = 3
				loadGear()
				print("Shifting down to 3")



func _on_timer_timeout() -> void:
	timerRunning = false
	timer.stop()
	gear += 1
	loadGear()
	print("Shifted up to %d" % [gear])
