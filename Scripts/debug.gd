extends Control

var isRight: bool

@onready var input: Label = $PanelContainer/VBoxContainer/Input
@onready var l1: Label = $PanelContainer/VBoxContainer/Label2
@onready var l2: Label = $PanelContainer/VBoxContainer/Label3
@onready var l3: Label = $PanelContainer/VBoxContainer/Label4
@onready var l4: Label = $PanelContainer/VBoxContainer/Label5
@onready var l5: Label = $PanelContainer/VBoxContainer/Label6

@onready var gearShifter: GearShifter = $"../GearShifter"

var throttle: float = 0

var target_speed: float
var drag: float
var desired_accel: float
var accel_limit: float
var drive_speed: float
var blended: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func T(number: float) -> String:
	if number >= 0:
		return " %.3f" % [abs(number)]
	else:
		return "-%.3f" % [abs(number)]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var power := Globals.throttle()
	var steer := Globals.steer(isRight)
	input.text = "%s %s %s" % [T(power), T(steer), T(throttle)]
	l1.text = "TrSpeed %s  Drag %s" % [T(target_speed), T(drag)]
	l2.text = "DrAcc %s  Turn %s" % [T(desired_accel), T(accel_limit)]
	l3.text = "DrSpeed %s  Blend %s" % [T(drive_speed), T(blended)]
	l4.text = "Gear %s Time %s" % [T(gearShifter.gear), T($"../GearShifter/Timer".wait_time)]
