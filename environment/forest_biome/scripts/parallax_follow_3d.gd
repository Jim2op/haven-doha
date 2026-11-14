extends Node3D
## Parallax for far 3D layers in a side-scrolling 2.5D view.
## Follows the active camera on X by `follow_x` (0 = static world object, 1 = glued to camera),
## so distant ridges and mountains read as very far away and never scroll out of frame.
## Uses whatever Camera3D is current, so it works with the game's own camera unchanged.

@export_range(0.0, 1.0) var follow_x := 0.5
@export_range(0.0, 1.0) var follow_z := 0.0

var _base := Vector3.ZERO

func _ready() -> void:
	_base = position

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	position = _base + Vector3(c.x * follow_x, 0.0, c.z * follow_z)
