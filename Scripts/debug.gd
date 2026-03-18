extends Control

var can_write := false
 
@onready var throttle_panel: Panel = $PanelContainer/VBoxContainer/ThrottleBox/Throttle
@onready var steer_panel: Panel = $PanelContainer/VBoxContainer/SteerBox/Steer

func T(number: float) -> String:
	if number >= 0:
		return " %.3f" % [abs(number)]
	else:
		return "-%.3f" % [abs(number)]

func begin():
	if not can_write: return;
	$PanelContainer/VBoxContainer/Input.text = ""
	
func write(_text:="", end:="\n") -> void:
	if not can_write: return;
	$PanelContainer/VBoxContainer/Input.text += "%s%s" % [_text, end]

func writeStat(_name: String, _value: float, end:="\n") -> void:
	if not can_write: return;
	write("%s: %s" % [_name,   T(_value)], end) 

func writeInt(_name: String, _value: int, end:="\n") -> void:
	if not can_write: return;
	write("%s: %s" % [_name, str(_value)], end) 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func throttle(t: float) -> void:
	var width = 492
	if t > 0:
		throttle_panel.modulate = Color.GREEN
	else:
		throttle_panel.modulate = Color.RED
		
	throttle_panel.position.x = width / 2 - abs(t) * width / 2
	throttle_panel.size.x = abs(t) * width
	

func steer(s: float) -> void:
	var width = 492
	if s > 0:
		steer_panel.position.x = width/2
	else:
		steer_panel.position.x = width/2 - width/2*-s
	steer_panel.size.x = abs(s) * width/2

var frame: int = 0
func _physics_process(_delta: float) -> void:
	frame += 1
	if frame % (4*4) == 0:
		can_write = true
	else:
		can_write = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
