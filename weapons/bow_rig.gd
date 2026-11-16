extends Node3D

signal released(arrow_transform: Transform3D)

const BOW_SCENE := preload("res://assets/weapons/bow_mess110/bow.glb")
const ARROW_MODEL := preload("res://assets/weapons/bow_mess110/arrow.glb")
const ARROW_SCALE := Vector3(0.55, 0.55, 0.29)
const ARROW_REAR := 1.5
const BOW_SCALE := Vector3(0.75, 0.34, 0.34)
const BOW_GRIP := Vector3(0.0, -0.34, -0.06)
const DRAW_HAND_OFFSET := Vector3(0.0, -0.34, 0.0)
const BOW_HAND := "arm_lower_left_bone"
const BOW_ARM := "arm_upper_left_bone"
const DRAW_HAND := "arm_lower_right_bone"
const DRAW_ARM := "arm_upper_right_bone"
const HIDDEN_WHILE_DRAWN := ["shield_tall", "shield_mid", "shield_wide", "shield_boss"]
const SWORD_PARTS := ["sword_grip", "sword_pommel", "sword_guard", "sword_blade", "sword_tip"]
const STRING_BONE := "string.bone"
const LOAD_TIME := 0.13
const DRAW_TIME := 0.16
const AIM_HOLD := 0.22
const RECOVER_SPEED := 6.0
const AIM_LIFT := 0.12
const AIM_REACH := 1.2
const CARRY_FORWARD := 0.4
const CARRY_DROP := 0.5
const CARRY_CANT := 0.62

enum Phase { IDLE, LOAD, DRAW, RECOVER }

var phase := Phase.IDLE
var explosive := false

var _model: Node3D
var _bow: Node3D
var _bow_anim: AnimationPlayer
var _draw_anim := ""
var _skeleton: Skeleton3D
var _string_bone := -1
var _grip: Node3D
var _draw_hand: Node3D
var _bow_arm: Node3D
var _bow_forearm: Node3D
var _draw_arm: Node3D
var _draw_forearm: Node3D
var _arrow: Node3D
var _arrow_meshes: Array[MeshInstance3D] = []
var _sword_parts: Array[Node3D] = []
var _drawn_hidden: Array[Node3D] = []
var _phase_time := 0.0
var _aim_weight := 0.0
var _draw_weight := 0.0
var _hold_left := 0.0
var _load_from := Transform3D()
var _pose_written := {}
var _pose_base := {}
var _shown := false
var _fire_overlay: StandardMaterial3D


func setup(model: Node3D, fire_overlay: StandardMaterial3D) -> void:
	_model = model
	_fire_overlay = fire_overlay
	top_level = true
	_bow_arm = model.find_child(BOW_ARM, true, false)
	_bow_forearm = model.find_child(BOW_HAND, true, false)
	_draw_arm = model.find_child(DRAW_ARM, true, false)
	_draw_forearm = model.find_child(DRAW_HAND, true, false)
	for part in SWORD_PARTS:
		var n: Node3D = model.find_child(part, true, false)
		if n:
			_sword_parts.append(n)
	for part in HIDDEN_WHILE_DRAWN:
		var n: Node3D = model.find_child(part, true, false)
		if n:
			_drawn_hidden.append(n)
	_grip = Node3D.new()
	_grip.name = "BowGrip"
	if _bow_forearm:
		_bow_forearm.add_child(_grip)
		_grip.position = BOW_GRIP
	else:
		model.add_child(_grip)
	_draw_hand = Node3D.new()
	_draw_hand.name = "DrawHand"
	if _draw_forearm:
		_draw_forearm.add_child(_draw_hand)
		_draw_hand.position = DRAW_HAND_OFFSET
	else:
		model.add_child(_draw_hand)
	_bow = BOW_SCENE.instantiate()
	_bow.name = "BowModel"
	add_child(_bow)
	_no_shadows(_bow)
	var players := _bow.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_bow_anim = players[0]
		var names := _bow_anim.get_animation_list()
		if not names.is_empty():
			_draw_anim = names[0]
			_bow_anim.get_animation(_draw_anim).loop_mode = Animation.LOOP_NONE
	var skeletons := _bow.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0]
		_string_bone = _skeleton.find_bone(STRING_BONE)
	_arrow = ARROW_MODEL.instantiate()
	_arrow.name = "NockedArrow"
	add_child(_arrow)
	_no_shadows(_arrow)
	for mi in _arrow.find_children("*", "MeshInstance3D", true, false):
		_arrow_meshes.append(mi)
	_arrow.visible = false
	_reset_string()
	set_shown(false)


func set_shown(shown: bool) -> void:
	_shown = shown
	_bow.visible = shown
	for part in _sword_parts:
		part.visible = not shown
	for part in _drawn_hidden:
		part.visible = not shown
	if not shown:
		cancel()
		_aim_weight = 0.0
		_draw_weight = 0.0


func is_busy() -> bool:
	return phase == Phase.LOAD or phase == Phase.DRAW


func begin_shot(fire: bool) -> bool:
	if not _shown or is_busy():
		return false
	explosive = fire
	_set_arrow_overlay(_arrow_meshes, fire)
	phase = Phase.LOAD
	_phase_time = 0.0
	_load_from = _hand_arrow_transform()
	_arrow.global_transform = _load_from
	_arrow.visible = true
	return true


func cancel() -> void:
	if is_busy():
		phase = Phase.RECOVER
		_hold_left = 0.0
	_arrow.visible = false
	_reset_string()


func set_arrow_overlay(meshes: Array, fire: bool) -> void:
	_set_arrow_overlay(meshes, fire)


func advance(delta: float) -> void:
	if not _shown or _model == null:
		return
	match phase:
		Phase.LOAD:
			_phase_time += delta
			var t := clampf(_phase_time / LOAD_TIME, 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			_aim_weight = maxf(_aim_weight, e)
			_draw_weight = maxf(_draw_weight, e)
			if t >= 1.0:
				phase = Phase.DRAW
				_phase_time = 0.0
				if _bow_anim and _draw_anim != "":
					var length := _bow_anim.get_animation(_draw_anim).length
					_bow_anim.play(_draw_anim, -1, length / DRAW_TIME)
		Phase.DRAW:
			_phase_time += delta
			_aim_weight = 1.0
			_draw_weight = 1.0
		Phase.RECOVER:
			_hold_left -= delta
			_draw_weight = move_toward(_draw_weight, 0.0, delta * RECOVER_SPEED)
			if _hold_left <= 0.0:
				_aim_weight = move_toward(_aim_weight, 0.0, delta * RECOVER_SPEED)
			if _aim_weight <= 0.0 and _draw_weight <= 0.0:
				phase = Phase.IDLE
		Phase.IDLE:
			_aim_weight = move_toward(_aim_weight, 0.0, delta * RECOVER_SPEED)
			_draw_weight = move_toward(_draw_weight, 0.0, delta * RECOVER_SPEED)


func update_pose() -> void:
	if _model == null:
		return
	if not _shown:
		_restore_arm(_bow_arm)
		_restore_arm(_bow_forearm)
		_restore_arm(_draw_arm)
		_restore_arm(_draw_forearm)
		return
	var forward := _forward()
	var shoulder := _shoulder(_bow_arm)
	var carry_target := shoulder + forward * CARRY_FORWARD + Vector3.DOWN * CARRY_DROP
	var aim_target := shoulder + forward * AIM_REACH + Vector3.UP * AIM_LIFT
	_pose_two_bone(_bow_arm, _bow_forearm, carry_target.lerp(aim_target, _aim_weight), 1.0)
	_place_bow()
	var nock := nock_position()
	_pose_two_bone(_draw_arm, _draw_forearm, nock, _draw_weight)
	if phase == Phase.LOAD:
		var t := clampf(_phase_time / LOAD_TIME, 0.0, 1.0)
		var e := t * t * (3.0 - 2.0 * t)
		var from := _hand_arrow_transform()
		var to := nocked_arrow_transform()
		_arrow.global_transform = Transform3D(from.basis.orthonormalized().slerp(to.basis.orthonormalized(), e).scaled(ARROW_SCALE), from.origin.lerp(to.origin, e))
	elif phase == Phase.DRAW:
		_arrow.global_transform = nocked_arrow_transform()
		if _phase_time >= DRAW_TIME:
			var t := nocked_arrow_transform()
			_arrow.visible = false
			_reset_string()
			phase = Phase.RECOVER
			_hold_left = AIM_HOLD
			released.emit(t)


func grip_position() -> Vector3:
	return _grip.global_position


func nock_position() -> Vector3:
	if _skeleton and _string_bone >= 0:
		return _skeleton.global_transform * _skeleton.get_bone_global_pose(_string_bone).origin
	return grip_position()


func nocked_arrow_transform() -> Transform3D:
	var nock := nock_position()
	var dir := grip_position() - nock
	if dir.length_squared() < 0.0001:
		dir = _forward()
	dir = dir.normalized()
	var center := nock + dir * ARROW_REAR * ARROW_SCALE.z
	return Transform3D(Basis.looking_at(dir, Vector3.UP).scaled(ARROW_SCALE), center)


func _hand_arrow_transform() -> Transform3D:
	var hand := _draw_hand.global_position
	var dir := (_forward() * 0.6 + Vector3.DOWN * 0.8).normalized()
	return Transform3D(Basis.looking_at(dir, _forward()).scaled(ARROW_SCALE), hand)


func _place_bow() -> void:
	var cant := Basis(Vector3.BACK, CARRY_CANT * (1.0 - _aim_weight))
	var basis := _model.global_basis.orthonormalized() * cant * Basis(Vector3.UP, PI) * Basis.from_scale(BOW_SCALE)
	_bow.global_transform = Transform3D(basis, _grip.global_position)


func _forward() -> Vector3:
	var f := -_model.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _shoulder(arm: Node3D) -> Vector3:
	return arm.global_position if arm else _model.global_position


func _pose_two_bone(upper: Node3D, lower: Node3D, target: Vector3, weight: float) -> void:
	if upper == null or lower == null:
		return
	var base_upper := _base_of(upper)
	var base_lower := _base_of(lower)
	if weight <= 0.0:
		_write(upper, base_upper)
		_write(lower, base_lower)
		return
	var parent := upper.get_parent() as Node3D
	var to_target := target - upper.global_position
	if to_target.length_squared() < 0.0001:
		return
	var local_dir := (parent.global_basis.orthonormalized().inverse() * to_target).normalized()
	var aim := Quaternion(Vector3.DOWN, local_dir)
	_write(upper, base_upper.slerp(aim, weight))
	_write(lower, base_lower.slerp(Quaternion.IDENTITY, weight))


func _base_of(node: Node3D) -> Quaternion:
	var current := node.quaternion
	var written: Variant = _pose_written.get(node)
	if written == null or not (written as Quaternion).is_equal_approx(current):
		_pose_base[node] = current
	return _pose_base.get(node, current)


func _write(node: Node3D, q: Quaternion) -> void:
	q = q.normalized()
	node.quaternion = q
	_pose_written[node] = node.quaternion


func _restore_arm(node: Node3D) -> void:
	if node == null or not _pose_written.has(node):
		return
	var current := node.quaternion
	if (_pose_written[node] as Quaternion).is_equal_approx(current):
		node.quaternion = _pose_base.get(node, current)
	_pose_written.erase(node)
	_pose_base.erase(node)


func _reset_string() -> void:
	if _bow_anim and _draw_anim != "":
		_bow_anim.play(_draw_anim)
		_bow_anim.seek(0.0, true)
		_bow_anim.pause()


func _set_arrow_overlay(meshes: Array, fire: bool) -> void:
	for mi in meshes:
		(mi as MeshInstance3D).material_overlay = _fire_overlay if fire else null


func _no_shadows(root: Node) -> void:
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
