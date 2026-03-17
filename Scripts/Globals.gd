extends Node

var camera: Camera3D
signal camera_changed(camera: Camera3D)

func set_camera(camera: Camera3D) -> void:
	self.camera = camera
	camera_changed.emit(camera)

func lerp(a: float, b: float, t: float) -> float:
	"""Linear interpolate on the scale given by a to b, using t as the point on that scale.
	Examples
	--------
		50 == lerp(0, 100, 0.5)
		4.2 == lerp(1, 5, 0.8)
	"""
	return (1 - t) * a + t * b


func inv_lerp(a: float, b: float, v: float) -> float:
	"""Inverse Linar Interpolation, get the fraction between a and b on which v resides.
	Examples
	--------
		0.5 == inv_lerp(0, 100, 50)
		0.8 == inv_lerp(1, 5, 4.2)
	"""
	return (v - a) / (b - a)


func remap(i_min: float, i_max: float, o_min: float, o_max: float, v: float) -> float:
	"""Remap values from one linear scale to another, a combination of lerp and inv_lerp.
	i_min and i_max are the scale on which the original value resides,
	o_min and o_max are the scale to which it should be mapped.
	Examples
	--------
		45 == remap(0, 100, 40, 50, 50)
		6.2 == remap(1, 5, 3, 7, 4.2)
	"""
	return lerp(o_min, o_max, inv_lerp(i_min, i_max, v))


func EaseIOCubic(x: float) -> float:
	"""Cubic easing in/out - acceleration until halfway, then deceleration.
	Examples
	--------
		0.5 == easeInOutCubic(0.5)
		0.896 == easeInOutCubic(0.8)
	"""
	if x < 0.5:
		return 4 * x * x * x
	else:
		return 1 - pow(-2 * x + 2, 3) / 2


func input(isRight: bool) -> float:
	"""Get the input for the tank track.
	Examples
	--------
		1.0 == input(true)
		-1.0 == input(false)
	"""
	var sideL = "R" if     isRight else "L"
	var sideR = "R" if not isRight else "L"
	#var power = Input.get_axis("Forward " + side, "Backward " + side) * -25

	var power = Input.get_axis("Drive", "Reverse") * -30
	var stear = Input.get_axis("Turn " + sideL, "Turn " + sideR) * 20
	
	return power + stear


func throttle() -> float:
	return -Input.get_axis("Drive", "Reverse")


func steer(isRight: bool) -> float:
	var sideL = "R" if     isRight else "L"
	var sideR = "R" if not isRight else "L"
	return Input.get_axis("Turn " + sideL, "Turn " + sideR)
	
	
func configure(object: Node3D):
	return [
		[
			object.global_position.x,
			object.global_position.y,
			object.global_position.z
		],
		[
			object.global_transform.basis.get_rotation_quaternion().x,
			object.global_transform.basis.get_rotation_quaternion().y,
			object.global_transform.basis.get_rotation_quaternion().z,
			object.global_transform.basis.get_rotation_quaternion().w
		]
	]
