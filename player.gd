extends CharacterBody3D

@onready var MeleeRange = $MeleeRange
@onready var CoolDownTimer = $CoolDown
@onready var HealthBar = $Camera3D/HUD/HealthBar
const BASE_HEALTH = 100
var MaxHealth = BASE_HEALTH
var Health = BASE_HEALTH
var HealthMultiplier = 1
@onready var sb = StyleBoxFlat.new()
@export var speed = 5
const BASEDAMAGE = 10
@export var DamageMultiplier = 1
var path = []
var cur_path_idx = 0
var threshold = .1

@onready var nav = get_parent()


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var can_attack = true

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
	
	if Input.is_action_just_pressed("attack") and can_attack:
		#play here animation
		can_attack = false
		CoolDownTimer.start()
		if MeleeRange.is_colliding():
			for i in MeleeRange.get_collision_count():
				var collider = MeleeRange.get_collider(i)
				if collider and collider.is_in_group("Enemies"):
						collider.take_damage(BASEDAMAGE*DamageMultiplier)

	#Health/HealthBar System
	if Health >= MaxHealth:
		Health = MaxHealth
	MaxHealth = BASE_HEALTH * HealthMultiplier
	
	HealthBar.max_value = MaxHealth
	HealthBar.value = Health 
	
	if Health >= 51:
		sb.bg_color = Color("00d300ff")
	elif Health <= 51 and Health >= 25:
		sb.bg_color = Color("ff8600ff") 
	elif Health <=26:
		sb.bg_color = Color("ff0000ff") 
		

	
	move_and_slide()

func _ready():
	HealthBar.add_theme_stylebox_override("fill", sb)

func take_damage(amt):
	Health -= amt
	print(Health)

func _on_cool_down_timeout() -> void:
	can_attack = true
