extends Label3D

const FONT := preload("res://CinzelDecorative-Regular.ttf")

var busy := false
var time_left := 0.0

var _tween: Tween


func _ready() -> void:
	font = FONT
	font_size = 64
	pixel_size = 0.006
	outline_size = 14
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	render_priority = 3
	outline_render_priority = 2
	shaded = false
	double_sided = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func play(at: Vector3, value: String, color: Color, size: float, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	text = value
	modulate = color
	outline_modulate = Color(0.08, 0.04, 0.02, 1.0)
	global_position = at
	scale = Vector3.ONE * size * 0.4
	busy = true
	time_left = duration
	visible = true
	var rise := at + Vector3(randf_range(-0.35, 0.35), 0.9, 0.0)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector3.ONE * size * 1.25, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_property(self, "scale", Vector3.ONE * size, 0.1)
	_tween.tween_property(self, "global_position", rise, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	_tween.tween_property(self, "outline_modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	_tween.chain().tween_callback(stop)


func _process(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)


func stop() -> void:
	busy = false
	time_left = 0.0
	visible = false
