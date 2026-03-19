extends Marker3D

@export var t_name: String = "Tracker"
@export var facing: Vector3

var didRotate: bool = false

func _setup(_name: String, _facing = null):
	self.t_name = _name
	if _facing: 
		self.facing = _facing
		
	print("%s: Hello" % [_name])


func _ready() -> void:
	Globals.exporters.append(self)

func _exportProvider(export: Dictionary):
	if not didRotate:
		didRotate = true
		self.rotate_x(facing[0])
		self.rotate_y(facing[1])
		self.rotate_z(facing[2])
	
	export['bones'][ "%s" % [t_name] ] = Globals.configure(self)
	
	
	# export[ "%s" % [t_name] ] = Globals.configure(self.get_parent())
	
#
#func _exportProvider(export: Dictionary):
	#var ID = $Wheel.ID
	#export["TWheel %s.%s"  % [ID, side]] = Globals.configure($"Wheel")
	#export["TSpring %s.%s" % [ID, side]] = Globals.configure($"Wheel Base")
