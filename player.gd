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
const COOLDOWN_RING := preload("res://vfx/cooldown_ring.gd")
const COOLDOWN_RING_HEIGHT := -0.78
const SWING_VOLUME_DB := -4.0
const SWING_FADE := 0.18
const KNOCKBACK := 5.0
const TOKEN_BUMP := 1.3
const STEP_SOUND_PATH := "res://Audio/Characters/Knight/Walking/freesound_community-footsteps-in-forest-83834.mp3"
const ARROW_SCRIPT := preload("res://weapons/arrow.gd")
const ARROW_POOL := preload("res://weapons/arrow_pool.gd")
const BOW_RIG := preload("res://weapons/bow_rig.gd")
const FIRE_OVERLAY := preload("res://weapons/fire_arrow_overlay.tres")
const BOW_SOUND_PATH := "res://Audio/Weapons/Bow/Bow.wav"
const WHOOSH_SOUND_PATH := "res://Audio/Weapons/Bow/swish_2.wav"
const CLICK_SOUND_PATH := "res://Audio/UI/Buttons/u_u4pf5h7zip-click-345983.mp3"
const Weapons := preload("res://weapons/weapon_config.gd")
const BOW_COOLDOWN := 0.55
const ARROW_SPEED := 14.0
const ARROW_RANGE := 15.0
const ARROW_DROP := 1.0
const MAX_LEAD := 2.0
const AIM_CONE := 0.82
const SWITCH_LOCK := 0.15
const TOAST_TIME := 1.8
const AMMO_LOW_TINT := Color(1.0, 0.55, 0.45)
const HUD_RADIUS := 24
const FIRE_TINT := Color(1.0, 0.7, 0.4)

@export var turn_speed := 12.0
@export var hit_point := 0.55

@onready var MeleeRange: ShapeCast3D = $MeleeRange
@onready var CoolDownTimer: Timer = $CoolDown
@onready var HealthBar: ProgressBar = $Camera3D/HUD/HealthBar
@onready var model: Node3D = $knight
@onready var anim: AnimationPlayer = _find_anim_player()
@onready var tokenbar: Label = $Camera3D/HUD/TokenBox/Row/TokenLabel
@onready var weapon_label: Label = $Camera3D/HUD/WeaponInfo/Row/Lines/WeaponLabel
@onready var ammo_label: Label = $Camera3D/HUD/WeaponInfo/Row/Lines/AmmoLabel
@onready var weapon_icon: TextureRect = $Camera3D/HUD/WeaponInfo/Row/WeaponIcon
@onready var toast_label: Label = $Camera3D/HUD/ToastArea/Toast
@onready var weapon_info: Control = $Camera3D/HUD/WeaponInfo
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
var _cooldown_ring: MeshInstance3D
var _swing_fade: Tween
var _token_tween: Tween
var _rig: Node3D
var _bow_timer: Timer
var _bow_ready := true
var _bow_sfx: AudioStreamPlayer3D
var _whoosh_sfx: AudioStreamPlayer3D
var _click_sfx: AudioStreamPlayer3D
var _arrow_pool: Node3D
var _attack_queued := false
var _weapon_requests: Array[int] = []
var _pending_weapon := -1
var _equip_pending := false
var _equip_target := -1
var _switch_lock := 0.0
var _toast_tween: Tween


func _ready() -> void:
	add_to_group("Enemies")
	add_to_group("player")
	process_priority = 10

	HealthMultiplier = PlayerStats.health_multiplier
	DamageMultiplier = PlayerStats.damage_multiplier
	MaxHealth = BASE_HEALTH * HealthMultiplier
	Health = MaxHealth

	sb.set_corner_radius_all(HUD_RADIUS)
	HealthBar.add_theme_stylebox_override("fill", sb)
	_update_health_bar()

	melee_offset = MeleeRange.position
	_setup_sounds()
	CoolDownTimer.one_shot = true
	_slash = SLASH_SCENE.instantiate()
	add_child(_slash)
	_slash.position = Vector3(0.0, SLASH_HEIGHT, 0.0)
	_cooldown_ring = COOLDOWN_RING.new()
	add_child(_cooldown_ring)
	_cooldown_ring.position = Vector3(0.0, COOLDOWN_RING_HEIGHT, 0.0)
	_warm_up_vfx.call_deferred()
	tokenbar.text = str(PlayerStats.tokens)
	PlayerStats.tokens_changed.connect(_on_tokens_changed)
	_setup_bow()

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

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("left", "right", "forward", "back")
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

	_update_weapons(delta)

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
		_play_swing_sound()


func _play_swing_sound() -> void:
	if _swing_fade and _swing_fade.is_valid():
		_swing_fade.kill()
	_swing_sfx.volume_db = SWING_VOLUME_DB
	Sfx.play(_swing_sfx, _swing_streams.pick_random(), 0.1)
	var cooldown := CoolDownTimer.wait_time
	_swing_fade = create_tween()
	_swing_fade.tween_interval(maxf(cooldown - SWING_FADE, 0.0))
	_swing_fade.tween_property(_swing_sfx, "volume_db", -40.0, SWING_FADE).set_ease(Tween.EASE_IN)
	_swing_fade.tween_callback(_swing_sfx.stop)


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
			if enemy.has_method("knockback"):
				enemy.knockback(at - global_position, KNOCKBACK)
			if enemy.get("is_dead"):
				killed = true
			else:
				Vfx.impact_ring(at, Vfx.RING_TINT, 1.2)
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
	Vfx.damage_number(global_position, amt, 2)
	if Health <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	attacking = false
	_cancel_draw()
	velocity = Vector3.ZERO
	_step_sfx.stop()
	_cooldown_ring.cancel()
	_freeze_left = 0.0
	if anim:
		anim.speed_scale = 1.0
	var wait := AnimUtils.play_death(anim)
	await get_tree().create_timer(wait).timeout
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


func _on_tokens_changed(amount: int) -> void:
	tokenbar.text = str(amount)
	tokenbar.pivot_offset = tokenbar.size * 0.5
	if _token_tween and _token_tween.is_valid():
		_token_tween.kill()
	tokenbar.scale = Vector2.ONE * TOKEN_BUMP
	tokenbar.modulate = Color(1.4, 1.3, 1.0)
	_token_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_token_tween.tween_property(tokenbar, "scale", Vector2.ONE, 0.3)
	_token_tween.tween_property(tokenbar, "modulate", Color.WHITE, 0.4)


func _on_cool_down_timeout() -> void:
	can_attack = true
	if not is_dead:
		_cooldown_ring.ready_pulse()


func _setup_sounds() -> void:
	for path in SWING_SOUND_PATHS:
		var stream := load(path) as AudioStream
		if stream:
			_swing_streams.append(stream)
	_swing_sfx = Sfx.make_player(self, null, SWING_VOLUME_DB)
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


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed("attack") and not _is_emulated_touch(event):
		_attack_queued = true
	elif event.is_action_pressed("weapon_next") or event.is_action_pressed("switch_weapon"):
		_weapon_requests.append(1)
	elif event.is_action_pressed("weapon_prev"):
		_weapon_requests.append(-1)


func _is_emulated_touch(event: InputEvent) -> bool:
	return event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION


func request_attack() -> void:
	if not is_dead:
		_attack_queued = true


func request_switch() -> void:
	cycle_weapon(1)


func cycle_weapon(step: int) -> void:
	if is_dead:
		return
	var from := _pending_weapon if _pending_weapon >= 0 else PlayerStats.weapon
	var next := PlayerStats.next_weapon(from, step)
	if next == from:
		if not PlayerStats.has_ranged_weapon():
			_toast("No other weapon yet")
		return
	select_weapon(next)


func select_weapon(w: int) -> void:
	if is_dead or not PlayerStats.is_unlocked(w):
		return
	if attacking or _equip_pending:
		_pending_weapon = w
		return
	_pending_weapon = -1
	if w == PlayerStats.weapon:
		return
	_rig.cancel()
	PlayerStats.set_weapon(w)
	_switch_lock = SWITCH_LOCK
	_play_click()


func pick_up_weapon(w: int) -> bool:
	if is_dead or not Weapons.uses_ammo(w):
		return false
	var name := Weapons.display_name(w)
	if PlayerStats.give_weapon(w):
		_equip_pending = true
		_equip_target = w
		_switch_lock = SWITCH_LOCK
		_play_click()
		_toast(name + " acquired  ·  scroll or Q to change weapon")
		return true
	if PlayerStats.refill(w):
		_play_click()
		_toast(String(Weapons.get_def(w)["refill_label"]) + " refilled")
		return true
	_toast(name + " ammo is full")
	return false


func _setup_bow() -> void:
	_rig = BOW_RIG.new()
	_rig.name = "BowRig"
	add_child(_rig)
	_rig.setup(model, FIRE_OVERLAY)
	_rig.released.connect(_on_arrow_released)
	_bow_timer = Timer.new()
	_bow_timer.one_shot = true
	_bow_timer.wait_time = BOW_COOLDOWN
	_bow_timer.timeout.connect(_on_bow_ready)
	add_child(_bow_timer)
	_bow_sfx = Sfx.make_player(self, load(BOW_SOUND_PATH), -3.0)
	_whoosh_sfx = Sfx.make_player(self, load(WHOOSH_SOUND_PATH), -14.0)
	_click_sfx = Sfx.make_player(self, load(CLICK_SOUND_PATH), -10.0)
	toast_label.hide()
	PlayerStats.refill_owned()
	if not PlayerStats.is_unlocked(PlayerStats.weapon):
		PlayerStats.weapon = PlayerStats.WEAPON_SWORD
	PlayerStats.weapon_changed.connect(_on_weapon_changed)
	PlayerStats.ammo_changed.connect(_on_ammo_changed)
	_apply_weapon()
	_spawn_arrow_pool.call_deferred()


func _spawn_arrow_pool() -> void:
	if is_instance_valid(_arrow_pool):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	_arrow_pool = ARROW_POOL.new()
	_arrow_pool.name = "Arrows"
	scene.add_child(_arrow_pool)


func _update_weapons(delta: float) -> void:
	if _switch_lock > 0.0:
		_switch_lock -= delta
	var wants_attack := _attack_queued
	_attack_queued = false
	if _equip_pending and not attacking:
		_equip_pending = false
		if _equip_target >= 0:
			PlayerStats.set_weapon(_equip_target)
		_equip_target = -1
	if not _weapon_requests.is_empty():
		var steps := _weapon_requests.duplicate()
		_weapon_requests.clear()
		for step in steps:
			cycle_weapon(step)
	if _pending_weapon >= 0 and not attacking and not _equip_pending:
		select_weapon(_pending_weapon)
	if not wants_attack or _switch_lock > 0.0 or _equip_pending:
		return
	if PlayerStats.uses_bow(PlayerStats.weapon):
		_try_shoot()
	elif can_attack and not attacking:
		can_attack = false
		CoolDownTimer.start()
		_cooldown_ring.track(CoolDownTimer)
		_start_attack()


func _on_weapon_changed(_w: int) -> void:
	_apply_weapon()


func _apply_weapon() -> void:
	_rig.set_shown(PlayerStats.is_unlocked(PlayerStats.weapon) and Weapons.uses_ammo(PlayerStats.weapon))
	_update_weapon_hud()


func _try_shoot() -> void:
	if not _bow_ready or _rig.is_busy():
		return
	var w := PlayerStats.weapon
	if PlayerStats.ammo_for(w) <= 0:
		_toast("Out of " + String(Weapons.get_def(w)["ammo_name"]))
		_play_click()
		_flash_ammo_label()
		return
	_rig.begin_shot(Weapons.is_explosive(w))


func _cancel_draw() -> void:
	if _rig:
		_rig.cancel()


func _on_arrow_released(arrow_transform: Transform3D) -> void:
	if is_dead:
		return
	var w := PlayerStats.weapon
	if not PlayerStats.uses_bow(w) or not PlayerStats.use_ammo(w):
		return
	_bow_ready = false
	_bow_timer.start()
	_cooldown_ring.track(_bow_timer)
	var from := arrow_transform.origin
	_spawn_arrow_pool()
	if is_instance_valid(_arrow_pool) and _arrow_pool.is_inside_tree():
		var exclude: Array[RID] = [get_rid()]
		var def := Weapons.get_def(w)
		var damage := roundi(Weapons.roll_damage(w) * DamageMultiplier)
		var blast := {}
		if Weapons.is_explosive(w):
			blast = {
				"radius": float(def["blast_radius"]),
				"damage": damage,
				"overlay": FIRE_OVERLAY,
			}
		_arrow_pool.fire(from, _aim_velocity(from, float(def["projectile_speed"])), damage, exclude, blast)
	Sfx.play(_bow_sfx, null, 0.08)
	Sfx.play(_whoosh_sfx, null, 0.1)
	Vfx.shake(0.05)


func _facing() -> Vector3:
	var f := -model.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _aim_velocity(from: Vector3, speed := ARROW_SPEED) -> Vector3:
	var facing := _facing()
	var target := _find_target(from, facing)
	var aim_point: Vector3
	if target:
		aim_point = target.hit_center() if target.has_method("hit_center") else target.global_position + Vector3.UP * 0.5
		var flight := Vector2(aim_point.x - from.x, aim_point.z - from.z).length() / speed
		if target is CharacterBody3D:
			var v: Vector3 = (target as CharacterBody3D).velocity
			aim_point += (Vector3(v.x, 0.0, v.z) * flight).limit_length(MAX_LEAD)
	else:
		aim_point = from + facing * ARROW_RANGE + Vector3.DOWN * ARROW_DROP
	var flat := aim_point - from
	var rise := flat.y
	flat.y = 0.0
	var dist := flat.length()
	if dist < 0.5:
		flat = facing * 0.5
		dist = 0.5
	var t := dist / speed
	var vy := (rise + 0.5 * ARROW_SCRIPT.GRAVITY * t * t) / t
	return flat / dist * speed + Vector3.UP * vy


func _find_target(from: Vector3, facing: Vector3) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e == self or not e is Node3D or e.get("is_dead"):
			continue
		var to: Vector3 = (e as Node3D).global_position - from
		to.y = 0.0
		var dist := to.length()
		if dist < 0.01 or dist > ARROW_RANGE:
			continue
		var dot := to.dot(facing) / dist
		if dot < AIM_CONE:
			continue
		var score := dist * (2.0 - dot)
		if score < best_score:
			best_score = score
			best = e
	return best


func _process(delta: float) -> void:
	if _rig == null:
		return
	if _freeze_left <= 0.0:
		_rig.advance(delta)
	_rig.update_pose()


func _on_bow_ready() -> void:
	_bow_ready = true
	if not is_dead and PlayerStats.uses_bow(PlayerStats.weapon):
		_cooldown_ring.ready_pulse()


func _on_ammo_changed(w: int, _amount: int) -> void:
	if w == PlayerStats.weapon:
		_update_weapon_hud()


func _update_weapon_hud() -> void:
	var w := PlayerStats.weapon
	weapon_label.text = Weapons.display_name(w)
	weapon_icon.texture = load(Weapons.icon_path(w))
	var bow_weapon := PlayerStats.is_unlocked(w) and Weapons.uses_ammo(w)
	ammo_label.visible = bow_weapon
	if not bow_weapon:
		ammo_label.text = ""
		weapon_info.reset_size()
		return
	var amount := PlayerStats.ammo_for(w)
	ammo_label.text = "%d / %d" % [amount, PlayerStats.max_ammo_for(w)]
	if amount == 0:
		ammo_label.modulate = AMMO_LOW_TINT
	elif Weapons.is_explosive(w):
		ammo_label.modulate = FIRE_TINT
	else:
		ammo_label.modulate = Color.WHITE
	weapon_info.reset_size()


func _flash_ammo_label() -> void:
	if not ammo_label.visible:
		return
	ammo_label.pivot_offset = ammo_label.size * 0.5
	var tw := create_tween()
	ammo_label.scale = Vector2.ONE * 1.2
	tw.tween_property(ammo_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.show()
	toast_label.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(toast_label.hide)


func _play_click() -> void:
	Sfx.play(_click_sfx, null, 0.05)
