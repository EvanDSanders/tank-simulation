extends AudioStreamPlayer3D

@onready var Idle	:= AudioStreamOggVorbis.load_from_file( "res://Sounds/Idle.ogg"   )
@onready var Low	:= AudioStreamOggVorbis.load_from_file( "res://Sounds/Low.ogg" 	  )
@onready var Medium	:= AudioStreamOggVorbis.load_from_file( "res://Sounds/Medium.ogg" )
@onready var High	:= AudioStreamOggVorbis.load_from_file( "res://Sounds/High.ogg"   )

const SILENT_DB := -80.0

var _pb: AudioStreamPlaybackPolyphonic
var _id_idle:   int
var _id_low:    int
var _id_medium: int
var _id_high:   int

var fade := 0.0
var fadeUp := 0.4125 / 120
var fadeDown := 0.35 / 120

var isPlaying := true
var _vol_mult := 1.0

func _ready() -> void:
	Globals.engineAudio = self
	Idle.loop   = true
	Low.loop    = true
	Medium.loop = true
	High.loop   = true

	play()
	_pb = get_stream_playback() as AudioStreamPlaybackPolyphonic

	# All 4 start from offset 0 simultaneously — they stay in sync as long as
	# their loop lengths match.
	_id_idle   = _pb.play_stream(Idle,   -2, SILENT_DB)
	_id_low    = _pb.play_stream(Low,    -2, SILENT_DB)
	_id_medium = _pb.play_stream(Medium, -2, SILENT_DB)
	_id_high   = _pb.play_stream(High,   -2, SILENT_DB)

	engineAudio(0.0)


func _pause() -> void:
	if not isPlaying:
		return
	isPlaying = false
	_vol_mult = 0.0


func _resume() -> void:
	if isPlaying:
		return
	isPlaying = true
	_vol_mult = 1.0


## pw 0..1 crossfades between engine stages:
##   0.00 – 0.25  Idle  → Low
##   0.25 – 0.50  Low   → Medium
##   0.50 – 0.75  Medium → High
##   0.75 – 1.00  High (full)
func engineAudio(pw: float, D: Control = null) -> void:


	fade += fadeUp if pw > fade else -fadeDown
	# if fade > pw:
	# 	fade = pw
	# if fade < pw:
	# 	fade = pw

	pw = fade

	if D != null:
		D.writeStat("pw: ", pw, ", A:");
	pw = Globals.remap(0.0, 1.0, 0.0, 0.75, pw);
	var t := clampf(pw, 0.0, 1.0)
	var idle_vol := 0.0
	var low_vol  := 0.0
	var med_vol  := 0.0
	var high_vol := 0.0

	if t < 0.25:
		var a := t / 0.25
		idle_vol = 1.0 - a
		low_vol  = a
	elif t < 0.5:
		var a := (t - 0.25) / 0.25
		low_vol = 1.0 - a
		med_vol = a
	elif t < 0.75:
		var a := (t - 0.5) / 0.25
		med_vol  = 1.0 - a
		high_vol = a
	else:
		high_vol = 1.0

	_pb.set_stream_volume(_id_idle,   linear_to_db(idle_vol  * _vol_mult) if idle_vol  * _vol_mult > 0.0 else SILENT_DB)
	_pb.set_stream_volume(_id_low,    linear_to_db(low_vol   * _vol_mult) if low_vol   * _vol_mult > 0.0 else SILENT_DB)
	_pb.set_stream_volume(_id_medium, linear_to_db(med_vol   * _vol_mult) if med_vol   * _vol_mult > 0.0 else SILENT_DB)
	_pb.set_stream_volume(_id_high,   linear_to_db(high_vol  * _vol_mult) if high_vol  * _vol_mult > 0.0 else SILENT_DB)

	if D != null:
		D.writeStat("", idle_vol, ", "); 	
		D.writeStat("", low_vol,  ", "); 	
		D.writeStat("", med_vol,  ", "); 	
		D.writeStat("", high_vol); 	 	 

		D.writeStat("", linear_to_db(idle_vol), ", ")
		D.writeStat("", linear_to_db(low_vol),  ", ")
		D.writeStat("", linear_to_db(med_vol),  ", ")
		D.writeStat("", linear_to_db(high_vol))
