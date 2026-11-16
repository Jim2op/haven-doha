extends Control

const BASE_MARGIN := 36
const WEAPON_BUTTON_SIZE := Vector2(140, 120)
const WEAPON_ICON_SIZE := 52
const WEAPON_FONT_SIZE := 22
const ATTACK_ICON_SIZE := 76
const ATTACK_RADIUS := 44
const BUTTON_STATES := ["normal", "hover", "pressed", "disabled", "focus"]
const Weapons := preload("res://weapons/weapon_config.gd")
const SELECTED_TINT := Color(1.0, 0.85, 0.5)
const STICK_RADIUS := 110.0
const STICK_DEADZONE := 0.15
const STICK_ZONE_WIDTH := 0.45
const STICK_ZONE_TOP := 0.35
const STICK_REST_INSET := Vector2(170.0, 170.0)
const STICK_IDLE_ALPHA := 0.55
const STICK_ACTIVE_ALPHA := 0.95
const PRESS_SCALE := 0.92
const MOVE_ACTIONS := {"left": Vector2.LEFT, "right": Vector2.RIGHT, "forward": Vector2.UP, "back": Vector2.DOWN}

@export var force_visible := false

@onready var margin: MarginContainer = $Margin
@onready var attack_button: Button = %AttackButton
@onready var weapon_bar: HBoxContainer = %WeaponBar
@onready var stick_base: Panel = %JoystickBase
@onready var stick_knob: Panel = %JoystickKnob

var stick_vector := Vector2.ZERO

var _weapon_buttons: Array[Button] = []
var _group := ButtonGroup.new()
var _stick_finger := -1
var _stick_center := Vector2.ZERO
var _rest_center := Vector2.ZERO
var _safe := Rect2()
var _active := false


func _ready() -> void:
	_active = force_visible or DisplayServer.is_touchscreen_available()
	visible = _active
	set_process_input(_active)
	if not _active:
		return
	_group.allow_unpress = false
	for w in Weapons.ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _group
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.custom_minimum_size = WEAPON_BUTTON_SIZE
		b.text = Weapons.short_name(w)
		b.icon = load(Weapons.icon_path(w))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", WEAPON_ICON_SIZE)
		b.add_theme_font_size_override("font_size", WEAPON_FONT_SIZE)
		weapon_bar.add_child(b)
		_weapon_buttons.append(b)
	_style_attack_button()
	PlayerStats.weapon_changed.connect(_on_weapon_changed)
	PlayerStats.ammo_changed.connect(_on_ammo_changed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_VISIBILITY_CHANGED:
		_release_stick()


func _input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _press_at(touch.position):
				get_viewport().set_input_as_handled()
			elif _stick_finger < 0 and _in_stick_zone(touch.position):
				_start_stick(touch.index, touch.position)
				get_viewport().set_input_as_handled()
		elif touch.index == _stick_finger:
			_release_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_finger:
			_move_stick(drag.position)
			get_viewport().set_input_as_handled()


func _press_at(pos: Vector2) -> bool:
	if attack_button.is_visible_in_tree() and attack_button.get_global_rect().has_point(pos):
		_bump(attack_button)
		_call_player("request_attack")
		return true
	for i in _weapon_buttons.size():
		var b := _weapon_buttons[i]
		if b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			_bump(b)
			_call_player("select_weapon", Weapons.ORDER[i])
			_refresh.call_deferred()
			return true
	return false


func _in_stick_zone(pos: Vector2) -> bool:
	var view := get_viewport_rect().size
	return pos.x >= _safe.position.x and pos.x <= view.x * STICK_ZONE_WIDTH and pos.y >= view.y * STICK_ZONE_TOP and pos.y <= _safe.end.y


func _start_stick(finger: int, pos: Vector2) -> void:
	_stick_finger = finger
	_stick_center = pos
	_place_stick(_stick_center, Vector2.ZERO)
	stick_base.modulate.a = STICK_ACTIVE_ALPHA


func _move_stick(pos: Vector2) -> void:
	var offset := (pos - _stick_center).limit_length(STICK_RADIUS)
	_place_stick(_stick_center, offset)
	var v := offset / STICK_RADIUS
	if v.length() < STICK_DEADZONE:
		v = Vector2.ZERO
	else:
		v = v.normalized() * inverse_lerp(STICK_DEADZONE, 1.0, v.length())
	_set_stick_vector(v)


func _release_stick() -> void:
	if _stick_finger < 0 and stick_vector == Vector2.ZERO:
		return
	_stick_finger = -1
	_set_stick_vector(Vector2.ZERO)
	if is_node_ready():
		_place_stick(_rest_center, Vector2.ZERO)
		stick_base.modulate.a = STICK_IDLE_ALPHA


func _set_stick_vector(v: Vector2) -> void:
	stick_vector = v
	for action in MOVE_ACTIONS:
		var strength := maxf(v.dot(MOVE_ACTIONS[action]), 0.0)
		if strength > 0.0:
			Input.action_press(action, strength)
		else:
			Input.action_release(action)


func _place_stick(center: Vector2, offset: Vector2) -> void:
	stick_base.global_position = center - stick_base.size * 0.5
	stick_knob.position = stick_base.size * 0.5 - stick_knob.size * 0.5 + offset


func _bump(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * PRESS_SCALE
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _call_player(method: String, arg: Variant = null) -> void:
	var player := owner
	if player == null or not player.has_method(method):
		return
	if arg == null:
		player.call(method)
	else:
		player.call(method, arg)


func _on_weapon_changed(_w: int) -> void:
	_refresh()


func _on_ammo_changed(_w: int, _amount: int) -> void:
	_refresh()


func _refresh() -> void:
	var available := PlayerStats.available_weapons()
	weapon_bar.visible = available.size() > 1
	for i in _weapon_buttons.size():
		var b := _weapon_buttons[i]
		var w: int = Weapons.ORDER[i]
		b.visible = available.has(w)
		var selected := w == PlayerStats.weapon
		b.set_pressed_no_signal(selected)
		b.modulate = SELECTED_TINT if selected else Color.WHITE
	attack_button.text = "Shoot" if PlayerStats.uses_bow(PlayerStats.weapon) else "Attack"
	attack_button.icon = load(Weapons.icon_path(PlayerStats.weapon))


func _style_attack_button() -> void:
	attack_button.expand_icon = true
	attack_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	attack_button.add_theme_constant_override("icon_max_width", ATTACK_ICON_SIZE)
	for state in BUTTON_STATES:
		var base := attack_button.get_theme_stylebox(state)
		if base is StyleBoxFlat:
			var rounded := base.duplicate() as StyleBoxFlat
			rounded.set_corner_radius_all(ATTACK_RADIUS)
			attack_button.add_theme_stylebox_override(state, rounded)


func _apply_safe_area() -> void:
	var view := get_viewport_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	var left := 0.0
	var top := 0.0
	var right := 0.0
	var bottom := 0.0
	if window.x > 0.0 and window.y > 0.0:
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var scale := view / window
		if safe.size.x > 0.0 and safe.size.y > 0.0:
			left = maxf(safe.position.x, 0.0) * scale.x
			top = maxf(safe.position.y, 0.0) * scale.y
			right = maxf(window.x - safe.end.x, 0.0) * scale.x
			bottom = maxf(window.y - safe.end.y, 0.0) * scale.y
	margin.add_theme_constant_override("margin_left", BASE_MARGIN + int(left))
	margin.add_theme_constant_override("margin_top", BASE_MARGIN + int(top))
	margin.add_theme_constant_override("margin_right", BASE_MARGIN + int(right))
	margin.add_theme_constant_override("margin_bottom", BASE_MARGIN + int(bottom))
	_safe = Rect2(Vector2(left, top), view - Vector2(left + right, top + bottom))
	_rest_center = Vector2(_safe.position.x + STICK_REST_INSET.x, _safe.end.y - STICK_REST_INSET.y)
	if _stick_finger < 0:
		_place_stick(_rest_center, Vector2.ZERO)
		stick_base.modulate.a = STICK_IDLE_ALPHA
