extends Node3D

var camera: Camera3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$SubViewport.reparent($Control)

	Globals.camera_changed.connect(func(_camera: Camera3D):
		self.camera = _camera
	)

	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if camera:
		look_at(camera.global_position, Vector3.UP)
		# Keep the object upright by zeroing out roll and pitch
		var euler = global_rotation
		euler.x = 0  # Remove pitch
		euler.z = 0  # Remove roll
		global_rotation = euler
