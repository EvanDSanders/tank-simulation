extends Control

var can_write := false
 
@onready var throttle_panel: Panel = $PanelContainer/VBoxContainer/ThrottleBox/Throttle
@onready var throttle_overlay: Panel = $PanelContainer/VBoxContainer/ThrottleBox/ThrottleOverlay
@onready var brake_panel: Panel = $PanelContainer/VBoxContainer/ThrottleBox/Brake
@onready var steer_panel: Panel = $PanelContainer/VBoxContainer/SteerBox/Steer
@onready var textBox: Label = $PanelContainer/VBoxContainer/Input

@onready var gearBoxes: Array[Control] = [
	$"PanelContainer/VBoxContainer/HBoxContainer/Park",
	$"PanelContainer/VBoxContainer/HBoxContainer/Reverse",
	$"PanelContainer/VBoxContainer/HBoxContainer/Neutral",
	$"PanelContainer/VBoxContainer/HBoxContainer/Drive 1",
	$"PanelContainer/VBoxContainer/HBoxContainer/Drive 2",
	$"PanelContainer/VBoxContainer/HBoxContainer/Drive 3",
	$"PanelContainer/VBoxContainer/HBoxContainer/Drive 4",
]

func T(number: float) -> String:
	if number >= 0:
		return " %.3f" % [abs(number)]
	else:
		return "-%.3f" % [abs(number)]

func begin():
	if not can_write: return;
	textBox.text = ""

func close() -> void:
	if not can_write: return;
	if textBox.text.length() > 0:
		textBox.text = textBox.text.substr(0, textBox.text.length() - 1)
	
func write(_text:="", end:="\n") -> void:
	if not can_write: return;
	textBox.text += "%s%s" % [_text, end]

func writeStat(_name: String, _value: float, end:="\n") -> void:
	if not can_write: return;
	write("%s%s" % [_name,   T(_value)], end) 

func writeInt(_name: String, _value: int, end:="\n") -> void:
	if not can_write: return;
	write("%s%s" % [_name, str(_value)], end) 


func shift(gear: Dictionary) -> void:
	for each in gearBoxes:
		if each.name == gear['name']:
			each.modulate = gear['color']
		else:
			each.modulate = Color.DIM_GRAY

func throttle(t: float) -> void:
	var width = 492
	t = abs(t)
		
	throttle_panel.position.x = width * 0.5 - abs(t) * width * 0.5
	throttle_panel.size.x = abs(t) * width
	
	throttle_overlay.position.x = width * 0.5 - abs(t) * width * 0.5
	throttle_overlay.size.x = abs(t) * width
	

func brake(b: float) -> void:
	var width = 492
	b = abs(b)

	brake_panel.position.x = width * 0.5 - abs(b) * width * 0.5
	brake_panel.size.x = abs(b) * width


func steer(s: float) -> void:
	var width = 492
	if s > 0:
		steer_panel.position.x = width * 0.5
	else:
		steer_panel.position.x = width * 0.5 - width * 0.5 * -s
	steer_panel.size.x = abs(s) * width * 0.5


var frame: int = 0
func _physics_process(_delta: float) -> void:
	frame += 1
	if frame % (4*4) == 0:
		can_write = true
	else:
		can_write = false

# Measured (current) physics ticks per second.
# We measure how many physics frames advanced over a rolling time window,
# then smooth it a bit to reduce jitter.
var _last_physics_frames: int = 0
var _sample_elapsed_s: float = 0.0
var _sample_frames: int = 0
var _measured_tps: float = 0.0
var _tps_initialized: bool = false

const TPS_SAMPLE_INTERVAL_S: float = 0.25
const TPS_EMA_ALPHA: float = 0.25





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	shift({
			"name": "Drive 1",
			'color': Color.WHITE, 
		})

	# Initialize TPS measurement baselines.
	_last_physics_frames = Engine.get_physics_frames()

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var frames := Engine.get_physics_frames()
	var frames_delta := frames - _last_physics_frames
	_last_physics_frames = frames

	_sample_elapsed_s += delta
	_sample_frames += frames_delta

	# Only recompute occasionally to keep the measurement stable.
	if _sample_elapsed_s >= TPS_SAMPLE_INTERVAL_S:
		var tps_now := float(_sample_frames) / _sample_elapsed_s

		if not _tps_initialized:
			_measured_tps = tps_now
			_tps_initialized = true
		else:
			_measured_tps = lerp(_measured_tps, tps_now, TPS_EMA_ALPHA)

		_sample_elapsed_s = 0.0
		_sample_frames = 0

	$PanelContainer/VBoxContainer/HBoxContainer/FPS.text = "  %s FPS\n  %0.2f TPS" % [
		Engine.get_frames_per_second(),
		_measured_tps,
	]
