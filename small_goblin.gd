extends CharacterBody3D

const DEF_DAMAGE = 10
const SPEED = 4.0
var BASE_HEALTH = 75 # starting health before the multiplier
@export var HealthMultiplier = 1
var MaxHealth = BASE_HEALTH
var health = BASE_HEALTH
var damage = DEF_DAMAGE
@export var damMultiplier = 1
var can_hit = true

var sb := StyleBoxFlat.new()
@onready var HealthBar: ProgressBar = $Sprite3D/SubViewport/ProgressBar
@onready var AttackRange = $ShapeCast3D
@onready var cool = $Timer
@export var target: Node3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	if target == null:
		target = get_tree().current_scene.get_node_or_null("Player")

	cool.one_shot = true
	if not cool.timeout.is_connected(_on_timer_timeout):
		cool.timeout.connect(_on_timer_timeout)

	HealthBar.add_theme_stylebox_override("fill", sb)

	# Start health is 75, scaled by HealthMultiplier (e.g. 2 -> 150), and the goblin starts full.
	MaxHealth = BASE_HEALTH * HealthMultiplier
	health = MaxHealth
	HealthBar.max_value = MaxHealth
	update_health_bar()


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if health <= 1:
		queue_free()
		return

	# Check attack range
	if AttackRange.is_colliding() and can_hit:
		for i in AttackRange.get_collision_count():
			var collider = AttackRange.get_collider(i)
			if collider and collider.name == "Player":
				collider.take_damage(damage)
				can_hit = false
				cool.start() # Starts the cooldown timer
				break # Stop checking other collisions this frame

	# Pathfinding: keep the destination on the player and walk to the next point on the path.
	if target:
		nav_agent.target_position = target.global_position

	if target == null or nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	else:
		var next_point := nav_agent.get_next_path_position()
		var direction := next_point - global_position
		direction.y = 0
		direction = direction.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		if direction:
			look_at(global_position + direction, Vector3.UP)

	move_and_slide()


func update_health_bar() -> void:
	HealthBar.value = health


	var percent: float = float(health) / MaxHealth * 100.0
	if percent > 50:
		sb.bg_color = Color("3f8f5aff") # emerald
	elif percent > 25:
		sb.bg_color = Color("c08a2eff") # antique amber
	else:
		sb.bg_color = Color("9e2a22ff") # dark crimson


func take_damage(amt):
	health = clamp(health - amt, 0, MaxHealth)
	update_health_bar()


func _on_timer_timeout() -> void:
	can_hit = true
