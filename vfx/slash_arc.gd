extends MeshInstance3D

@export var inner_radius := 0.8
@export var outer_radius := 2.5
@export var arc_degrees := 150.0
@export var segments := 20
@export var duration := 0.17
@export var roll_degrees := -14.0

var _mat: ShaderMaterial
var _tween: Tween
var _trail := 0.5


func _ready() -> void:
	mesh = _build_mesh()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = material_override as ShaderMaterial
	_trail = float(_mat.get_shader_parameter("trail"))
	visible = false


func play(yaw: float) -> void:
	rotation = Vector3(0.0, yaw, deg_to_rad(roll_degrees))
	if _tween:
		_tween.kill()
	_set_progress(0.0)
	visible = true
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0 + _trail, duration)
	_tween.tween_callback(hide)


func warm_up() -> void:
	_set_progress(0.0)
	visible = true
	for i in 3:
		await get_tree().process_frame
	if _tween == null or not _tween.is_running():
		visible = false


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)


func _build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var half := deg_to_rad(arc_degrees) * 0.5
	for i in segments + 1:
		var t := float(i) / segments
		var a := lerpf(half, -half, t)
		var dir := Vector3(sin(a), 0.0, -cos(a))
		verts.append(dir * inner_radius)
		verts.append(dir * outer_radius)
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		if i < segments:
			var b := i * 2
			indices.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
