extends Camera3D
## PREVIEW ONLY - stands in for the game's own 2.5D camera so the biome can be judged in context.
## Fixed pitch, no yaw: follows the target on X/Z with smoothing, like a side-scrolling 2.5D camera.

@export var target_path: NodePath
@export var offset := Vector3(0.0, 5.0, 16.0)
@export var pitch_degrees := -8.0
@export var smoothing := 5.0
@export var clamp_x := Vector2(-90.0, 92.0)

func _ready() -> void:
	rotation = Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0)
	snap()

func snap() -> void:
	var t := get_node_or_null(target_path) as Node3D
	if t:
		global_position = _goal(t)

func _goal(t: Node3D) -> Vector3:
	var g := t.global_position + offset
	g.x = clampf(g.x, clamp_x.x, clamp_x.y)
	return g

func _physics_process(delta: float) -> void:
	var t := get_node_or_null(target_path) as Node3D
	if t:
		global_position = global_position.lerp(_goal(t), 1.0 - exp(-smoothing * delta))
