extends Node3D

var T = preload("res://Senes/Track/Track.tscn")
var pos: Vector3

@export var base: RigidBody3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var prior = null
	
	pos = self.global_position
	
	for x in range(100):
		var this: Node3D = T.instantiate()
		
		self.add_child(this)
		this.global_position = pos
		pos = pos - Vector3(0, 0, 0.095)
		
		var joint = this.get_child(0)
		if not prior:
			joint.node_a = joint.get_path_to(base)
		else:
			joint.node_a = joint.get_path_to(prior.get_child(1))
		
		prior = this


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
