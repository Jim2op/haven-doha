extends CharacterBody3D

## Emitted once when Health reaches 0 (used by the end screen).
signal died

@onready var MeleeRange = $MeleeRange
@onready var CoolDownTimer = $CoolDown
@onready var HealthBar = $Camera3D/HUD/HealthBar
@onready var model: Node3D = $knight
@onready var anim: AnimationPlayer = _find_anim_player()
const BASE_HEALTH = 100
var MaxHealth = BASE_HEALTH
var Health = BASE_HEALTH
var HealthMultiplier = 1
@onready var sb = StyleBoxFlat.new()
@export var speed = 5
const BASEDAMAGE = 10
@export var DamageMultiplier = 1
@export var turn_speed := 12.0
@export var hit_point := 0.5
var path = []
var cur_path_idx = 0
var threshold = .1

@onready var nav = get_parent()


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var can_attack = true
var is_dead = false

func _physics_process(delta: float) -> void:
	add_to_group("Enemies")
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
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

	#Health/HealthBar System
	if Health >= MaxHealth:
		Health = MaxHealth
	MaxHealth = BASE_HEALTH * HealthMultiplier

	HealthBar.max_value = MaxHealth
	HealthBar.value = Health

	if Health >= 51:
		sb.bg_color = Color("3f8f5aff") # emerald
	elif Health <= 51 and Health >= 25:
		sb.bg_color = Color("c08a2eff") # antique amber
	elif Health <=26:
		sb.bg_color = Color("9e2a22ff") # dark crimson
		

	move_and_slide()

func _ready():
	HealthBar.add_theme_stylebox_override("fill", sb)
	melee_offset = MeleeRange.position

	if anim:
		walk_anim = _find_anim(["walk", "run"])
		attack_anim = _find_anim(["attack"])
		if walk_anim != "":
			anim.get_animation(walk_anim).loop_mode = Animation.LOOP_LINEAR
		if attack_anim != "":
			anim.get_animation(attack_anim).loop_mode = Animation.LOOP_NONE
			attack_length = anim.get_animation(attack_anim).length

func _start_attack() -> void:
	attacking = true
	hit_landed = false
	attack_time = 0.0
	if anim and attack_anim != "":
		anim.stop()
		anim.play(attack_anim)

func _update_attack(delta: float) -> void:
	attack_time += delta
	if not hit_landed and attack_time >= attack_length * hit_point:
		hit_landed = true
		MeleeRange.force_shapecast_update()
		if MeleeRange.is_colliding():
			for i in MeleeRange.get_collision_count():
				var collider = MeleeRange.get_collider(i)
				if collider and collider != self and collider.is_in_group("Enemies"):
					collider.take_damage(BASEDAMAGE*DamageMultiplier)
	if attack_time >= attack_length:
		attacking = false

func _update_animation() -> void:
	if anim == null or attacking:
		return
	if Vector2(velocity.x, velocity.z).length() > 0.1:
		if walk_anim != "" and anim.current_animation != walk_anim:
			anim.play(walk_anim)
	elif anim.is_playing():
		anim.stop()

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

func take_damage(amt):
	Health -= amt
	print(Health)
	if Health <= 0 and not is_dead:
		is_dead = true
		HealthBar.value = 0 # the game pauses on death, so refresh the bar now
		died.emit()

func _on_cool_down_timeout() -> void:
	can_attack = true
