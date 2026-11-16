extends Node3D

const Sfx := preload("res://sfx.gd")
const BURST_SCENE := preload("res://weapons/explosion_burst.tscn")
const BOOM_SOUND_PATH := "res://Audio/Other/dragon-studio-heavy-boulder-thud-515257.mp3"
const POOL_SIZE := 3
const LIGHT_COLOR := Color(1.0, 0.6, 0.25)
const LIGHT_ENERGY := 4.0
const LIGHT_TIME := 0.28
const RING_TINT := Color(1.0, 0.55, 0.2)
const SPARK_TINT := Color(1.0, 0.65, 0.3)
const KNOCKBACK := 7.0
const HITSTOP := 0.07
const SHAKE_BASE := 0.22
const SHAKE_PER_HIT := 0.06
const LOS_LIFT := 0.15
const RING_SCALE := 1.05

var last_hits: Array[Node3D] = []

var _bursts: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _tweens: Array = []
var _next := 0
var _ray := PhysicsRayQueryParameters3D.new()
var _boom: AudioStream


func _ready() -> void:
	_boom = load(BOOM_SOUND_PATH)
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	for i in POOL_SIZE:
		var burst: Node3D = BURST_SCENE.instantiate()
		add_child(burst)
		_bursts.append(burst)
		var light := OmniLight3D.new()
		light.top_level = true
		light.light_color = LIGHT_COLOR
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)
		_tweens.append(null)


func explode(center: Vector3, blast: Dictionary, exclude: Array[RID]) -> void:
	var radius := float(blast.get("radius", 3.0))
	var damage := float(blast.get("damage", 0.0))
	var edge := float(blast.get("edge", 1.0))
	var slot := _next
	_next = (_next + 1) % POOL_SIZE
	_bursts[slot].play(center, Vector3.FORWARD, Color.WHITE)
	_flash_light(slot, center, radius)
	Vfx.impact_ring(center, RING_TINT, radius * RING_SCALE)
	global_position = center
	Sfx.play_at(self, _boom, -3.0, 0.08, 1.15)
	last_hits = _apply_damage(center, radius, damage, edge, exclude)
	if not last_hits.is_empty():
		Vfx.hit_stop(last_hits, HITSTOP)
	Vfx.shake(minf(SHAKE_BASE + SHAKE_PER_HIT * last_hits.size(), 0.5))


func _apply_damage(center: Vector3, radius: float, damage: float, edge: float, exclude: Array[RID]) -> Array[Node3D]:
	var hits: Array[Node3D] = []
	var targets: Array[Node3D] = []
	var ignore: Array[RID] = exclude.duplicate()
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e is CollisionObject3D:
			ignore.append((e as CollisionObject3D).get_rid())
		if e.is_in_group("player") or not e.has_method("take_damage") or e.get("is_dead"):
			continue
		targets.append(e)
	_ray.exclude = ignore
	var space := get_world_3d().direct_space_state
	var origin := center + Vector3.UP * LOS_LIFT
	for e in targets:
		var at: Vector3 = e.hit_center() if e.has_method("hit_center") else e.global_position + Vector3.UP * 0.5
		var dist := minf(center.distance_to(at), center.distance_to(e.global_position))
		if dist > radius:
			continue
		_ray.from = origin
		_ray.to = at
		if not space.intersect_ray(_ray).is_empty():
			continue
		var falloff := clampf(dist / radius, 0.0, 1.0)
		e.take_damage(damage * lerpf(1.0, edge, falloff))
		var push := at - center
		push.y = 0.0
		if push.length_squared() < 0.0001:
			push = Vector3.FORWARD
		Vfx.hit_spark(at, push, SPARK_TINT)
		if not e.get("is_dead") and e.has_method("knockback"):
			e.knockback(push.normalized(), KNOCKBACK * (1.0 - 0.5 * falloff))
		hits.append(e)
	return hits


func _flash_light(slot: int, at: Vector3, radius: float) -> void:
	var light := _lights[slot]
	var old: Tween = _tweens[slot]
	if old and old.is_valid():
		old.kill()
	light.global_position = at + Vector3.UP * 0.6
	light.omni_range = radius * 1.8
	light.light_energy = LIGHT_ENERGY
	light.visible = true
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, LIGHT_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(light.hide)
	_tweens[slot] = tw
