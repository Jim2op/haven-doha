extends MeshInstance3D

const RING_SHADER := preload("res://vfx/ring.gdshader")
const CHARGE_TINT := Color(0.72, 0.57, 0.25)
const READY_TINT := Color(1.0, 0.9, 0.6)
const RADIUS := 0.62
const READY_TIME := 0.22

var _mat: ShaderMaterial
var _timer: Timer
var _tween: Tween


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	mesh = plane
	scale = Vector3.ONE * RADIUS
	_mat = ShaderMaterial.new()
	_mat.shader = RING_SHADER
	_mat.render_priority = 1
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	set_process(false)


func track(timer: Timer) -> void:
	_timer = timer
	if _tween and _tween.is_valid():
		_tween.kill()
	_mat.set_shader_parameter("color", CHARGE_TINT)
	_mat.set_shader_parameter("radius", 0.82)
	_mat.set_shader_parameter("thickness", 0.06)
	_mat.set_shader_parameter("alpha", 0.55)
	_mat.set_shader_parameter("fill", 0.0)
	visible = true
	set_process(true)


func ready_pulse() -> void:
	set_process(false)
	if _tween and _tween.is_valid():
		_tween.kill()
	_mat.set_shader_parameter("color", READY_TINT)
	_mat.set_shader_parameter("fill", 1.0)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_param.bind("radius"), 0.82, 0.98, READY_TIME)
	_tween.tween_method(_set_param.bind("thickness"), 0.12, 0.02, READY_TIME)
	_tween.tween_method(_set_param.bind("alpha"), 1.2, 0.0, READY_TIME)
	_tween.chain().tween_callback(hide)


func cancel() -> void:
	set_process(false)
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false


func _process(_delta: float) -> void:
	if _timer == null or _timer.wait_time <= 0.0:
		return
	_mat.set_shader_parameter("fill", 1.0 - _timer.time_left / _timer.wait_time)


func _set_param(v: float, param: String) -> void:
	_mat.set_shader_parameter(param, v)
