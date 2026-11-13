extends CharacterBody3D

const DEF_HEALTH = 100
const DEF_DAMAGE = 10
const SPEED = 4.0
var health = DEF_HEALTH
var damage = DEF_DAMAGE
var can_hit = true

@onready var AttackRange = $ShapeCast3D
@onready var cool = $Timer
@export var target: Node3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	if target == null:
		target = get_tree().current_scene.get_node_or_null("Player")
	
	# Ensure the timer doesn't auto-loop and connect its signal
	cool.one_shot = true
	if not cool.timeout.is_connected(_on_timer_timeout):
		cool.timeout.connect(_on_timer_timeout)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if health <= 0:
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


func take_damage(amt):
	health -= amt


func _on_timer_timeout() -> void:
	# Reset the attack when the Timer node finishes
	can_hit = true
