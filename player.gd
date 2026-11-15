extends CharacterBody3D

signal died

const BASE_HEALTH := 100.0
const BASEDAMAGE := 25.0
const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const ATTACK_LIBRARY := "player_fx"
const ATTACK_DURATION := 0.45
const AnimUtils := preload("res://anim_utils.gd")
const ATTACK_ANIM_SPEED := 1.6
const WALK_ANIM_SPEED := 1.2
const Sfx := preload("res://sfx.gd")
const SWING_SOUND_PATHS := [
	"res://Audio/Characters/Knight/Attacking/dragon-studio-sword-slice-393847.mp3",
	"res://Audio/Characters/Knight/Attacking/dragon-studio-sword-slice-2-393845.mp3",
]
const HIT_SOUND_PATH := "res://Audio/Characters/Knight/Attacking/dragon-studio-sword-clashhit-393837.mp3"
const HURT_SOUND_PATH := "res://Audio/Other/prmodrai-damage-blowhole-402072.mp3"
const SLASH_SCENE := preload("res://vfx/slash_arc.tscn")
const SLASH_HEIGHT := -0.25
const SLASH_LEAD := 0.08
const HITSTOP_HIT := 0.06
const HITSTOP_KILL := 0.1
const STEP_SOUND_PATH := "res://Audio/Characters/Knight/Walking/freesound_community-footsteps-in-forest-83834.mp3"

@export var turn_speed := 12.0
@export var hit_point := 0.55

@onready var MeleeRange: ShapeCast3D = $MeleeRange
@onready var CoolDownTimer: Timer = $CoolDown
@onready var HealthBar: ProgressBar = $Camera3D/HUD/HealthBar
@onready var model: Node3D = $knight
@onready var anim: AnimationPlayer = _find_anim_player()
@onready var tokenbar = $Camera3D/HUD/Label
@onready var tokens = PlayerStats.tokens
var HealthMultiplier := 1.0
var DamageMultiplier := 1.0
var MaxHealth := BASE_HEALTH
var Health := BASE_HEALTH
var can_attack := true
var is_dead := false
var attacking := false
var attack_time := 0.0
var attack_length := ATTACK_DURATION
var hit_landed := false
var walk_anim := ""
var attack_anim := ""
var melee_offset := Vector3.ZERO
var sb := StyleBoxFlat.new()
var _swing_streams: Array[AudioStream] = []
var _swing_sfx: AudioStreamPlayer3D
var _hit_sfx: AudioStreamPlayer3D
var _hurt_sfx: AudioStreamPlayer3D
var _step_sfx: AudioStreamPlayer3D
var _slash: MeshInstance3D
var _slash_played := false
var _freeze_left := 0.0


func _ready() -> void:
	add_to_group("Enemies")

	HealthMultiplier = PlayerStats.health_multiplier
	DamageMultiplier = PlayerStats.damage_multiplier
	MaxHealth = BASE_HEALTH * HealthMultiplier
	Health = MaxHealth

	HealthBar.add_theme_stylebox_override("fill", sb)
	_update_health_bar()

	melee_offset = MeleeRange.position
	_setup_sounds()
	CoolDownTimer.one_shot = true
	_slash = SLASH_SCENE.instantiate()
	add_child(_slash)
	_slash.position = Vector3(0.0, SLASH_HEIGHT, 0.0)
	_warm_up_vfx.call_deferred()

	if anim:
		walk_anim = _find_anim(["walk", "run"])
		if walk_anim != "":
			anim.get_animation(walk_anim).loop_mode = Animation.LOOP_LINEAR
		attack_anim = AnimUtils.find_attack(anim, ["res://knight.gltf", "res://knight.glb"])
		if attack_anim == "":
			attack_anim = _build_attack_animation()
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

	tokenbar.text = str(tokens)
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if input_dir:
		var yaw := atan2(-input_dir.x, -input_dir.y)
		model.rotation.y = lerp_angle(model.rotation.y, yaw, turn_speed * delta)
	MeleeRange.position = melee_offset.rotated(Vector3.UP, model.rotation.y)
	MeleeRange.rotation.y = model.rotation.y

	if Input.is_action_just_pressed("attack") and can_attack and not attacking:
		can_attack = false
		CoolDownTimer.start()
		_start_attack()

	if attacking:
		_update_attack(delta)

	_update_animation()
	_update_footsteps()
	move_and_slide()


func _update_health_bar() -> void:
	HealthBar.max_value = MaxHealth
	HealthBar.value = Health
	var percent := Health / MaxHealth * 100.0
	if percent > 50.0:
		sb.bg_color = Color("3f8f5aff")
	elif percent > 25.0:
		sb.bg_color = Color("c08a2eff")
	else:
		sb.bg_color = Color("9e2a22ff")


func _start_attack() -> void:
	attacking = true
	hit_landed = false
	_slash_played = false
	attack_time = 0.0
	if anim and attack_anim != "":
		anim.stop()
		anim.play(attack_anim, -1, ATTACK_ANIM_SPEED)
	if not _swing_streams.is_empty():
		Sfx.play(_swing_sfx, _swing_streams.pick_random(), 0.1)


func _update_attack(delta: float) -> void:
	attack_time += delta
	if not _slash_played and attack_time >= attack_length * hit_point - SLASH_LEAD:
		_slash_played = true
		_slash.play(model.rotation.y)
	if not hit_landed and attack_time >= attack_length * hit_point:
		hit_landed = true
		MeleeRange.force_shapecast_update()
		var hits := []
		for i in MeleeRange.get_collision_count():
			var collider = MeleeRange.get_collider(i)
			if collider and collider != self and not hits.has(collider) and collider.is_in_group("Enemies") and collider.has_method("take_damage"):
				hits.append(collider)
		var killed := false
		for enemy in hits:
			enemy.take_damage(BASEDAMAGE * DamageMultiplier)
			var at: Vector3 = enemy.hit_center() if enemy.has_method("hit_center") else enemy.global_position + Vector3.UP * 0.5
			Vfx.hit_spark(at, at - global_position)
			if enemy.get("is_dead"):
				killed = true
		if not hits.is_empty():
			Sfx.play(_hit_sfx, null, 0.1)
			Vfx.shake(0.3 if killed else 0.18)
			Vfx.hit_stop([self] + hits, HITSTOP_KILL if killed else HITSTOP_HIT)
	if attack_time >= attack_length:
		attacking = false


func _update_animation() -> void:
	if anim == null or attacking:
		return
	if Vector2(velocity.x, velocity.z).length_squared() > 0.01:
		if walk_anim != "" and anim.current_animation != walk_anim:
			anim.play(walk_anim, -1, WALK_ANIM_SPEED)
	elif anim.is_playing():
		anim.stop()


func _build_attack_animation() -> String:
	var a := Animation.new()
	a.length = ATTACK_DURATION
	a.loop_mode = Animation.LOOP_NONE
	var times := [0.0, 0.12, 0.26, ATTACK_DURATION]
	var tracks := {
		"arm_upper_left_bone": [Vector3.RIGHT, [0.0, -150.0, -50.0, 0.0]],
		"arm_lower_left_bone": [Vector3.RIGHT, [0.0, -30.0, 0.0, 0.0]],
		"arm_upper_right_bone": [Vector3.RIGHT, [0.0, -25.0, 15.0, 0.0]],
		"torso_bone": [Vector3.UP, [0.0, 25.0, -20.0, 0.0]],
	}
	for bone_name in tracks:
		var path := _anim_path_to(bone_name)
		if path.is_empty():
			continue
		var axis: Vector3 = tracks[bone_name][0]
		var angles: Array = tracks[bone_name][1]
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, path)
		for k in times.size():
			a.rotation_track_insert_key(t, times[k], Quaternion(axis, deg_to_rad(angles[k])))
	if a.get_track_count() == 0:
		return ""
	var lib := AnimationLibrary.new()
	lib.add_animation("attack", a)
	anim.add_animation_library(ATTACK_LIBRARY, lib)
	return ATTACK_LIBRARY + "/attack"


func _anim_path_to(node_name: String) -> NodePath:
	var node := model.find_child(node_name, true, false)
	var root := anim.get_node_or_null(anim.root_node)
	if node == null or root == null:
		return NodePath()
	return root.get_path_to(node)


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


func take_damage(amt) -> void:
	if is_dead:
		return
	Health = maxf(Health - amt, 0.0)
	_update_health_bar()
	Sfx.play(_hurt_sfx, null, 0.1)
	Vfx.hurt(model, global_position)
	if Health <= 0.0:
		is_dead = true
		_step_sfx.stop()
		died.emit()


func _warm_up_vfx() -> void:
	_slash.warm_up()
	var targets: Array = [model]
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e != self and e.has_method("hit_center"):
			targets.append(e)
			break
	Vfx.warm_up(targets)


func freeze_for(duration: float) -> void:
	if is_dead:
		return
	_freeze_left = maxf(_freeze_left, duration)
	if anim:
		anim.speed_scale = 0.0


func _on_cool_down_timeout() -> void:
	can_attack = true


func _setup_sounds() -> void:
	for path in SWING_SOUND_PATHS:
		var stream := load(path) as AudioStream
		if stream:
			_swing_streams.append(stream)
	_swing_sfx = Sfx.make_player(self, null, -4.0)
	_hit_sfx = Sfx.make_player(self, load(HIT_SOUND_PATH), -6.0)
	_hurt_sfx = Sfx.make_player(self, load(HURT_SOUND_PATH), -10.0)
	_step_sfx = Sfx.make_player(self, load(STEP_SOUND_PATH), -14.0, true)


func _update_footsteps() -> void:
	var moving := is_on_floor() and Vector2(velocity.x, velocity.z).length_squared() > 0.25
	if moving and not _step_sfx.playing:
		_step_sfx.pitch_scale = WALK_ANIM_SPEED
		_step_sfx.play()
	elif not moving and _step_sfx.playing:
		_step_sfx.stop()
