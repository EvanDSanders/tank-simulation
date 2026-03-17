extends RigidBody3D

var ID = 0
var track_hub: Node

@export var radius_ratio: float = 1.0

var accum_angle: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.



func _setup(_track_hub: Node, _ID: int) -> void:
	self.track_hub = _track_hub
	self.ID = _ID
	print(_track_hub, _ID)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not track_hub: return
	var spin_axis = state.transform.basis.x 
	var current_spin = state.angular_velocity.dot(spin_axis)

	accum_angle += current_spin * state.step

	track_hub.tell(ID, current_spin * radius_ratio, accum_angle * radius_ratio)

	var consensus = track_hub.get_consensus()  # surface speed units
	var master_angle = track_hub.get_master_angle()

	var error = master_angle - accum_angle * radius_ratio  # surface speed angle units
	var correction = error * 0.3                           # surface speed units

	# Both consensus and correction are in surface speed units — divide by radius_ratio once
	var other_rot = state.angular_velocity - spin_axis * current_spin
	state.angular_velocity = other_rot + spin_axis * ((consensus + correction) / radius_ratio)
