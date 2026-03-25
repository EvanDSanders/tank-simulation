class_name DualSenseCtl
extends Node

var Gears := {
	"Park": 
		[
			'player-leds 5',
			'lightbar 200 50 50',
            'trigger right off'
		],
	"Reverse": 
		[
			'player-leds 6',
			'lightbar 255 0 0',
            'trigger right feedback-raw 0 1 1 2 2 3 4 5 6 8'
		],
	"Neutral": 
		[
			'player-leds 0',
			'lightbar 0 100 255',
            'trigger right off'
		],
	"Drive 1": 
		[
			'player-leds 1',
			'lightbar 200 255 255',
            'trigger right feedback-raw 0 1 1 2 2 3 4 5 6 8'
		],
	"Drive 2": 
		[
			'player-leds 2',
			'lightbar 200 255 255',
            'trigger right feedback-raw 3 4 4 5 5 6 6 7 7 8'

		],
	"Drive 3": 
		[
			'player-leds 3',
			'lightbar 200 255 255',
            'trigger right feedback-raw 4 4 5 5 6 6 7 7 8 8'

		],
	"Drive 4": 
		[
			'player-leds 4',
			'lightbar 250 255 10',
            'trigger right feedback-raw 6 6 7 7 7 7 8 8 8 8'

		],
}

func response(gear: String) -> void:
	for each in Gears[gear]:
		var code = OS.execute("dualsensectl", each.split(" "))
		print(code, " -> ", "dualsensectl ", each)

func _ready() -> void:
	response("Drive 1")

	var code = OS.execute("dualsensectl", "trigger left feedback-raw 0 1 1 2 2 3 4 5 6 8".split(" "))
	print(code, " -> ", "dualsensectl ", "trigger left feedback-raw 0 1 1 2 2 3 4 5 6 8")

	code = OS.execute("dualsensectl", "microphone-led on".split(" "))
	print(code, " -> ", "dualsensectl ", "microphone-led on")
