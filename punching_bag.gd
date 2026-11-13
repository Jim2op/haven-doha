extends CharacterBody3D

const DEF_HEALTH = 100 
var health = DEF_HEALTH

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if health <= 0:
		queue_free()

	move_and_slide()
func take_damage(amt):
	health -= amt 
