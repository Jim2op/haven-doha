extends CharacterBody3D

const Sfx := preload("res://sfx.gd")
const ATTACK_ANIM_SPEED := 1.5
const MOVE_ANIM_SPEED := 1.2
const ALERT_RANGE := 14.0
const ALERT_COOLDOWN_MS := 4000
const ATTACK_SOUND_PATH := "res://Audio/Characters/Goblin/Attacking/daviddumaisaudio-small-monster-attack-195712.mp3"
const DEATH_SOUND_PATH := "res://Audio/Characters/Goblin/Death/freesound_community-goblin-death-6729.mp3"
const ALERT_SOUND_PATH := "res://Audio/Characters/Goblin/Other/phatphrogstudio-monster-goblin-voice-excited-enemy-spotted-519428.mp3"

static var _last_alert_ms := -ALERT_COOLDOWN_MS

@export var base_health := 75.0
@export var HealthMultiplier := 1.0
@export var base_damage := 10.0
@export var damMultiplier := 1.0
@export var speed := 3.0
@export var hit_point := 0.5
@export var target: Node3D
@export var separation_radius := 2.0
@export var separation_strength := 1.5
@export var repath_interval := 0.25
@export var separation_interval := 0.15
@export var token_reward := 2
@export var attack_sources: PackedStringArray = ["res://goblin.gltf", "res://goblin.glb"]

const AnimUtils := preload("res://anim_utils.gd")

var voice_pitch := 1.0
var walk_sound_path := ""
var impact_sound_path := ""

var color_high := Color("3f8f5aff")
var color_mid := Color("c08a2eff")
var color_low := Color("9e2a22ff")

var MaxHealth := 0.0
var health := 0.0
var can_hit := true
var attacking := false
var attack_time := 0.0
var attack_length := 0.4
var hit_landed := false
var is_dead := false
var move_anim := ""
var attack_anim := ""

var _repath_left := 0.0
var _separation_left := 0.0
var _push := Vector3.ZERO
var _last_target_pos := Vector3.INF
var _bar_mat: ShaderMaterial
var _freeze_left := 0.0
var _alerted := false
var _attack_stream: AudioStream
var _alert_stream: AudioStream
var _death_stream: AudioStream
var _voice_sfx: AudioStreamPlayer3D
var _impact_sfx: AudioStreamPlayer3D
var _step_sfx: AudioStreamPlayer3D

@onready var health_bar: MeshInstance3D = $HealthBar
@onready var AttackRange: ShapeCast3D = $ShapeCast3D
@onready var cool: Timer = $Timer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim: AnimationPlayer = _find_anim_player()


func _ready() -> void:
	if target == null:
		target = get_tree().current_scene.get_node_or_null("Player")

	cool.one_shot = true
	if not cool.timeout.is_connected(_on_timer_timeout):
		cool.timeout.connect(_on_timer_timeout)

	_bar_mat = health_bar.material_override as ShaderMaterial
	MaxHealth = base_health * HealthMultiplier
	health = MaxHealth
	update_health_bar()

	_separation_left = randf() * separation_interval
	_setup_sounds()

	if anim:
		move_anim = _find_anim(["run", "walk"])
		attack_anim = AnimUtils.find_attack(anim, Array(attack_sources))
		if move_anim != "":
			anim.get_animation(move_anim).loop_mode = Animation.LOOP_LINEAR
		if attack_anim != "":
			anim.get_animation(attack_anim).loop_mode = Animation.LOOP_NONE
			attack_length = anim.get_animation(attack_anim).length / ATTACK_ANIM_SPEED


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _freeze_left > 0.0:
		_freeze_left -= delta
		if _freeze_left <= 0.0 and anim:
			anim.speed_scale = 1.0
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if not is_instance_valid(target):
		target = null

	if attacking:
		_update_attack(delta)
	elif can_hit and _target_in_range():
		_start_attack()

	_update_navigation_target(delta)

	_separation_left -= delta
	if _separation_left <= 0.0:
		_separation_left = separation_interval
		_push = _separation()

	if attacking:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		if target:
			_face(target.global_position)
	elif target == null or nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, _push.x * speed, speed)
		velocity.z = move_toward(velocity.z, _push.z * speed, speed)
		if target:
			_face(target.global_position)
	else:
		var direction := nav_agent.get_next_path_position() - global_position
		direction.y = 0
		direction = direction.normalized()
		if direction:
			look_at(global_position + direction, Vector3.UP)
		var move_dir := (direction + _push * separation_strength).normalized()
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed

	_update_animation()
	_update_sounds()
	move_and_slide()


func _update_navigation_target(delta: float) -> void:
	if target == null:
		return
	_repath_left -= delta
	if _repath_left > 0.0:
		return
	_repath_left = repath_interval
	var pos := target.global_position
	if pos.distance_squared_to(_last_target_pos) < 0.04:
		return
	_last_target_pos = pos
	nav_agent.target_position = pos


func _target_in_range() -> bool:
	if target == null or not AttackRange.is_colliding():
		return false
	for i in AttackRange.get_collision_count():
		if AttackRange.get_collider(i) == target:
			return true
	return false


func _start_attack() -> void:
	attacking = true
	can_hit = false
	hit_landed = false
	attack_time = 0.0
	if anim and attack_anim != "":
		anim.stop()
		anim.play(attack_anim, -1, ATTACK_ANIM_SPEED)
	Sfx.play(_voice_sfx, _attack_stream, 0.1, voice_pitch)


func _update_attack(delta: float) -> void:
	attack_time += delta
	if not hit_landed and attack_time >= attack_length * hit_point:
		hit_landed = true
		if _target_in_range() and target.has_method("take_damage"):
			target.take_damage(base_damage * damMultiplier)
			if _impact_sfx:
				Sfx.play(_impact_sfx, null, 0.05)
	if attack_time >= attack_length:
		attacking = false
		cool.start()


func _face(pos: Vector3) -> void:
	var flat := Vector3(pos.x, global_position.y, pos.z)
	if global_position.distance_squared_to(flat) > 0.0001:
		look_at(flat, Vector3.UP)


func _update_animation() -> void:
	if anim == null or attacking:
		return
	if Vector2(velocity.x, velocity.z).length_squared() > 0.01:
		if move_anim != "" and anim.current_animation != move_anim:
			anim.play(move_anim, -1, MOVE_ANIM_SPEED)
	elif anim.is_playing():
		anim.stop()


func update_health_bar() -> void:
	var ratio := health / MaxHealth if MaxHealth > 0.0 else 0.0
	var col := color_high
	if ratio <= 0.25:
		col = color_low
	elif ratio <= 0.5:
		col = color_mid
	_bar_mat.set_shader_parameter("fill", ratio)
	_bar_mat.set_shader_parameter("fill_color", col)


func take_damage(amt) -> void:
	if is_dead:
		return
	health = clampf(health - amt, 0.0, MaxHealth)
	update_health_bar()
	if health < 0.5:
		die()
	else:
		Vfx.flash(self)


func freeze_for(duration: float) -> void:
	if is_dead:
		return
	_freeze_left = maxf(_freeze_left, duration)
	if anim:
		anim.speed_scale = 0.0


func hit_center() -> Vector3:
	return health_bar.global_position.lerp(global_position, 0.55)


func die() -> void:
	is_dead = true
	PlayerStats.add_tokens(token_reward)
	Sfx.play_at(self, _death_stream, -4.0, 0.05, voice_pitch)
	Vfx.death_burst(hit_center())
	remove_from_group("Enemies")
	queue_free()


func _on_timer_timeout() -> void:
	can_hit = true


func _find_anim_player() -> AnimationPlayer:
	for p in find_children("*", "AnimationPlayer", true, false):
		if p.get_animation_list().size() > 0:
			return p
	return null


func _find_anim(keys: Array) -> String:
	for n in anim.get_animation_list():
		for k in keys:
			if k in String(n).to_lower():
				return n
	return ""


func _other_anim(skip: String) -> String:
	for n in anim.get_animation_list():
		if n != skip and n != "RESET":
			return n
	return ""


func _separation() -> Vector3:
	var push := Vector3.ZERO
	var r2 := separation_radius * separation_radius
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e == self or e == target or not e is Node3D:
			continue
		var offset: Vector3 = global_position - e.global_position
		offset.y = 0
		var d2 := offset.length_squared()
		if d2 > 0.0001 and d2 < r2:
			var dist := sqrt(d2)
			push += offset / dist * (1.0 - dist / separation_radius)
	return push.limit_length(1.0)


func _setup_sounds() -> void:
	_attack_stream = load(ATTACK_SOUND_PATH)
	_alert_stream = load(ALERT_SOUND_PATH)
	_death_stream = load(DEATH_SOUND_PATH)
	_voice_sfx = Sfx.make_player(self, _attack_stream, -6.0)
	if impact_sound_path != "":
		_impact_sfx = Sfx.make_player(self, load(impact_sound_path), -12.0)
	if walk_sound_path != "":
		_step_sfx = Sfx.make_player(self, load(walk_sound_path), -10.0, true)


func _update_sounds() -> void:
	if not _alerted and target and global_position.distance_to(target.global_position) < ALERT_RANGE:
		_alerted = true
		var now := Time.get_ticks_msec()
		if now - _last_alert_ms >= ALERT_COOLDOWN_MS and not _voice_sfx.playing:
			_last_alert_ms = now
			Sfx.play(_voice_sfx, _alert_stream, 0.1, voice_pitch)
	if _step_sfx == null:
		return
	var moving := not attacking and Vector2(velocity.x, velocity.z).length_squared() > 0.25
	if moving and not _step_sfx.playing:
		_step_sfx.pitch_scale = MOVE_ANIM_SPEED
		_step_sfx.play()
	elif not moving and _step_sfx.playing:
		_step_sfx.stop()
