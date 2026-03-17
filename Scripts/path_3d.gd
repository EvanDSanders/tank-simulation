extends Path3D

var T = preload("res://Senes/Track.tscn")

@export var link_spacing: float = 0.095

func _ready() -> void:
	var length = curve.get_baked_length()
	var count  = int(length / link_spacing)
	var segments: Array[Node3D] = []

	# Pre-sample every link position first (equivalent to "convert curve to edges"
	# in Blender). Each link's tangent is then the vector to the *next* link's
	# position rather than a tiny epsilon step, so adjacent links share the same
	# reference points and orientations are guaranteed 
	var positions: Array[Vector3] = []
	for i in range(count):
		positions.append(curve.sample_baked((float(i) / float(count)) * length))

	for i in range(count):
		var pos      = positions[i]
		var next_pos = positions[(i + 1) % count]  # wraps around for the last link
		var tangent  = (next_pos - pos).normalized()
		var up       = Vector3.RIGHT.cross(tangent).normalized()  # outward from loop
		var right    = tangent.cross(up).normalized()             # along tank width
		var local_t  = Transform3D(Basis(right, up, -tangent), pos)

		var seg: Node3D = T.instantiate()
		add_child(seg)
		seg.global_transform = global_transform * local_t

		var joint = seg.get_child(0)
		if i > 0:
			joint.node_a = joint.get_path_to(segments[i - 1].get_child(1))

		segments.append(seg)

	# Close the loop: first segment links back to last segment's body
	if segments.size() > 1:
		var first_joint = segments[0].get_child(0)
		first_joint.node_a = first_joint.get_path_to(segments[-1].get_child(1))
