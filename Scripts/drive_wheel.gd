extends RigidBody3D

const ROAD_WHEEL_RADIUS: float = 0.2

## How much tread speed comes from road wheels (0 = drive only, 1 = road wheels only). Higher = forces on road wheels (hill, mud) push back on drive.
@export_range(0.0, 1.0) var road_wheel_influence: float = 0.7
## How strongly to correct road wheel spin per frame. Lower lets ground friction show through so drive wheel feels load.
@export_range(0.0, 1.0) var road_wheel_impulse_blend: float = 0.5

var _hub: Node3D


func _ready() -> void:
	_hub = get_parent()


func _get_spin_axis(body: RigidBody3D) -> Vector3:
	return body.global_transform.basis.x


func _get_surface_speed(body: RigidBody3D, radius: float) -> float:
	var axis := _get_spin_axis(body)
	return body.angular_velocity.dot(axis) * radius


func _compute_consensus(
	drive_target_speed: float,
	road_surface_speeds: Array
) -> float:
	if road_surface_speeds.is_empty():
		return drive_target_speed
	var measured: float = 0.0
	for s in road_surface_speeds:
		measured += s
	measured /= road_surface_speeds.size()
	# Tread speed = blend so road wheel forces propagate to drive (2-way).
	return lerpf(drive_target_speed, measured, road_wheel_influence)


func _apply_engine_torque(state: PhysicsDirectBodyState3D, spin_axis: Vector3, hub: Node) -> void:
	var engine_torque: float = 0.0
	if hub.has_method("take_engine_torque"):
		engine_torque = hub.take_engine_torque()
	if engine_torque == 0.0:
		return
	var torque_vec: Vector3 = spin_axis * engine_torque
	# Custom integrator: Jolt doesn't integrate apply_torque, so add torque effect ourselves.
	state.angular_velocity += (state.inverse_inertia_tensor * torque_vec) * state.step


func _constrain_road_wheels(road_wheels: Array, consensus_speed: float) -> void:
	var r: float = ROAD_WHEEL_RADIUS
	var I_axial: float = 0.5 * r * r  # cylinder I = 0.5*m*r^2, factor without m
	for body in road_wheels:
		if not is_instance_valid(body):
			continue
		var axis := _get_spin_axis(body)
		var current_spin: float = body.angular_velocity.dot(axis)
		var desired_spin: float = consensus_speed / r
		var delta_spin: float = desired_spin - current_spin
		var m: float = body.mass
		var inertia_axial: float = I_axial * m
		# Impulse (torque*dt) needed so delta_omega = impulse/I => impulse = I * delta_spin
		var impulse_mag: float = inertia_axial * delta_spin * road_wheel_impulse_blend
		body.apply_torque_impulse(axis * impulse_mag)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _hub or not _hub.has_method("get_road_wheels"):
		return

	var road_wheels: Array = _hub.get_road_wheels()
	var drive_radius: float = _hub.track_radius_drive if _hub.get("track_radius_drive") != null else 0.25

	var spin_axis := _get_spin_axis(self)
	var drive_surface_speed := _get_surface_speed(self, drive_radius)

	var road_speeds: Array = []
	for body in road_wheels:
		if is_instance_valid(body):
			road_speeds.append(_get_surface_speed(body, ROAD_WHEEL_RADIUS))

	var consensus: float = _compute_consensus(drive_surface_speed, road_speeds)

	var current_spin: float = state.angular_velocity.dot(spin_axis)
	var other_rot: Vector3 = state.angular_velocity - spin_axis * current_spin
	var target_spin_drive: float = consensus / drive_radius
	state.angular_velocity = other_rot + spin_axis * target_spin_drive

	# Apply engine torque (must integrate manually when using custom_integrator).
	_apply_engine_torque(state, spin_axis, _hub)

	_constrain_road_wheels(road_wheels, consensus)

	var reaction: float = (drive_surface_speed - consensus) * _hub.drive_damping
	if _hub.has_method("set_reaction_torque"):
		_hub.set_reaction_torque(reaction)

	state.apply_central_force(state.total_gravity * mass)
