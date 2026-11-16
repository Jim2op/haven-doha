extends Node3D

signal finished(arrow: Node3D)
signal exploded(at: Vector3, blast: Dictionary, exclude: Array[RID])

const Sfx := preload("res://sfx.gd")
const GRAVITY := 14.0
const RADIUS := 0.1
const HALF_LENGTH := 0.43
const EMBED := 0.12
const LIFETIME := 3.0
const STUCK_TIME := 2.5
const KILL_Y := -40.0
const KNOCKBACK := 2.5
const HITSTOP := 0.04
const FLESH_SOUND_PATH := "res://Audio/Other/prmodrai-damage-blowhole-402072.mp3"
const THUD_SOUND_PATH := "res://Audio/Other/dragon-studio-heavy-boulder-thud-515257.mp3"

static var _flesh_sound: AudioStream
static var _thud_sound: AudioStream

var damage := 0.0
var _blast := {}
var _exclude: Array[RID] = []
var _meshes: Array[MeshInstance3D] = []
var _velocity := Vector3.ZERO
var _age := 0.0
var _stuck_left := 0.0
var _flying := false
var _active := false
var _shape := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	if _flesh_sound == null:
		_flesh_sound = load(FLESH_SOUND_PATH)
		_thud_sound = load(THUD_SOUND_PATH)
	_shape.radius = RADIUS
	_query.shape = _shape
	_query.collide_with_areas = false
	_query.collide_with_bodies = true
	for mi in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mi)
	visible = false
	set_physics_process(false)


func is_active() -> bool:
	return _active


func launch(from: Vector3, velocity: Vector3, amount: float, exclude: Array[RID], blast := {}) -> void:
	damage = amount
	_blast = blast
	_exclude = exclude
	var overlay: Material = blast.get("overlay", null)
	for mi in _meshes:
		mi.material_overlay = overlay
	_velocity = velocity
	_age = 0.0
	_stuck_left = 0.0
	_flying = true
	_active = true
	_query.exclude = exclude
	global_position = from
	_orient(velocity)
	visible = true
	set_physics_process(true)


func retire() -> void:
	if not _active:
		return
	_active = false
	_flying = false
	visible = false
	set_physics_process(false)
	finished.emit(self)


func _physics_process(delta: float) -> void:
	if not _flying:
		_stuck_left -= delta
		if _stuck_left <= 0.0:
			retire()
		return
	_age += delta
	var from := global_position
	_velocity.y -= GRAVITY * delta
	var motion := _velocity * delta
	var space := get_world_3d().direct_space_state
	_query.transform = Transform3D(Basis.IDENTITY, from)
	_query.motion = motion
	var fractions := space.cast_motion(_query)
	if fractions.size() == 2 and fractions[1] < 1.0:
		_query.transform = Transform3D(Basis.IDENTITY, from + motion * fractions[1])
		_query.motion = Vector3.ZERO
		var info := space.get_rest_info(_query)
		global_position = from + motion * fractions[0]
		_orient(_velocity)
		_impact(info)
		return
	global_position = from + motion
	_orient(_velocity)
	if _age > LIFETIME or global_position.y < KILL_Y:
		retire()


func _orient(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var dir := direction.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD
	look_at(global_position + dir, up)


func _impact(info: Dictionary) -> void:
	var dir := _velocity.normalized()
	var point: Vector3 = info.get("point", global_position)
	if not _blast.is_empty():
		var normal: Vector3 = info.get("normal", -dir)
		var blast := _blast
		_blast = {}
		retire()
		exploded.emit(point + normal * 0.25, blast, _exclude)
		return
	var collider: Object = instance_from_id(info["collider_id"]) if info.has("collider_id") else null
	if collider is Node3D and collider.is_in_group("Enemies") and collider.has_method("take_damage") and not collider.get("is_dead"):
		var enemy := collider as Node3D
		var at: Vector3 = enemy.hit_center() if enemy.has_method("hit_center") else point
		enemy.take_damage(damage)
		Vfx.hit_spark(at, dir)
		if enemy.get("is_dead"):
			Vfx.shake(0.16)
		else:
			Vfx.impact_ring(at, Vfx.RING_TINT, 0.9)
			if enemy.has_method("knockback"):
				enemy.knockback(dir, KNOCKBACK)
			Vfx.hit_stop([enemy], HITSTOP)
			Vfx.shake(0.08)
		Sfx.play_at(enemy, _flesh_sound, -9.0, 0.1, 1.15)
		retire()
		return
	_flying = false
	_stuck_left = STUCK_TIME
	global_position = point - dir * (HALF_LENGTH - EMBED)
	_orient(dir)
	Vfx.hit_spark(point, -dir, Color(0.85, 0.75, 0.55))
	Sfx.play_at(self, _thud_sound, -22.0, 0.1, 2.2)
