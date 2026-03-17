extends Node3D

# In-memory file both Godot and Blender use (Linux: /dev/shm is RAM)
const SHARED_STATE_PATH := "/dev/shm/tank_state.json"

var parts: Array[Node3D]
var c: int = 0
var frames: Dictionary[int, Dictionary]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for each in self.find_children("*"):
		if each.has_method("_exportProvider"):
			parts.append(each)

	Globals.set_camera($"Camera Track2/Camera Track3/Camera3D")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if not Input.get_action_strength("End"):
		if c % 4 == 0:
			var state = {}
			for each in parts:
				each._exportProvider(state)
			frames[round(c / 8)] = state
			# Write current state so Blender can read it
			var f := FileAccess.open(SHARED_STATE_PATH, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify({"0": state}))
				f.close()
		c += 1
	else:
		var f = FileAccess.open('/home/evans/OneDrive/Documents/Blender OneDrive/TankBake.json', FileAccess.WRITE)
		f.store_string(JSON.stringify(frames, "    "))
		
		get_tree().quit()
