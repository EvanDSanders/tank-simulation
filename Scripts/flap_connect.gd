extends Generic6DOFJoint3D

@export var mount : Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	self.node_a = self.get_path_to(mount.find_child("Track Base"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
