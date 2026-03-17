extends Node3D

@onready var track: Node3D = $"../Frame/Camera Track"
@onready var speed: Node3D = $"../Camera Track3"

var pastPos: Vector3 = Vector3()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	#speed.global_position = pastPos
	
	#var pos = track.global_position
	
	var a = self.global_position
	var b = track.global_position
	self.global_position = a * 0.7 + b * 0.3
	
	self.rotate_y( Input.get_axis("Camera R", "Camera L")/30/4 )

	
	
	#self.global_position = (pos - pastPos)*25 + pos
	
	#pastPos = pos
