extends CharacterBody3D
## PREVIEW ONLY - a stand-in body (1.8 m) to walk the biome with arrow keys / WASD.
## It is NOT a replacement for the game's player; drop the biome into the real level instead.

@export var speed := 7.0

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.z += 1
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()
