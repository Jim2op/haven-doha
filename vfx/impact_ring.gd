extends MeshInstance3D

const RING_SHADER := preload("res://vfx/ring.gdshader")

var busy := false
var time_left := 0.0

var _mat: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	mesh = plane
	_mat = ShaderMaterial.new()
	_mat.shader = RING_SHADER
	_mat.render_priority = 1
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func play(at: Vector3, color: Color, max_radius: float, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	global_position = at
	scale = Vector3.ONE * max_radius
	_mat.set_shader_parameter("color", color)
	_mat.set_shader_parameter("fill", 1.0)
	busy = true
	time_left = duration
	visible = true
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_param.bind("radius"), 0.12, 0.92, duration)
	_tween.tween_method(_set_param.bind("thickness"), 0.22, 0.03, duration)
	_tween.tween_method(_set_param.bind("alpha"), 1.0, 0.0, duration).set_trans(Tween.TRANS_QUAD)
	_tween.chain().tween_callback(stop)


func _process(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)


func stop() -> void:
	busy = false
	time_left = 0.0
	visible = false


func _set_param(v: float, param: String) -> void:
	_mat.set_shader_parameter(param, v)
