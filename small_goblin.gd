extends CharacterBody3D

const DEF_DAMAGE = 10
const SPEED = 3.0
var BASE_HEALTH = 75 # starting health before the multiplier
@export var HealthMultiplier = 1
var MaxHealth = BASE_HEALTH
var health = BASE_HEALTH
var damage = DEF_DAMAGE
@export var damMultiplier = 1
var can_hit = true
var attacking := false
var attack_time := 0.0
var attack_length := 0.4
var hit_landed := false
@export var hit_point := 0.5

var sb := StyleBoxFlat.new()
@onready var HealthBar: ProgressBar = $Sprite3D/SubViewport/ProgressBar
@onready var AttackRange = $ShapeCast3D
@onready var cool = $Timer
@export var target: Node3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim: AnimationPlayer = _find_anim_player()
@export var separation_radius := 2.0
@export var separation_strength := 1.5
var move_anim := ""
var attack_anim := ""


func _ready() -> void:
	if target == null:
		target = get_tree().current_scene.get_node_or_null("Player")

	cool.one_shot = true
	if not cool.timeout.is_connected(_on_timer_timeout):
		cool.timeout.connect(_on_timer_timeout)

	HealthBar.add_theme_stylebox_override("fill", sb)

	MaxHealth = BASE_HEALTH * HealthMultiplier
	health = MaxHealth
	HealthBar.max_value = MaxHealth
	update_health_bar()

	if anim:
		move_anim = _find_anim(["run", "walk"])
		attack_anim = _find_anim(["attack"])
		if attack_anim == "":
			attack_anim = _other_anim(move_anim)
		if move_anim != "":
			anim.get_animation(move_anim).loop_mode = Animation.LOOP_LINEAR
		if attack_anim != "":
			anim.get_animation(attack_anim).loop_mode = Animation.LOOP_NONE
			attack_length = anim.get_animation(attack_anim).length


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if health <= 1:
		queue_free()
		return

	# Check attack range
	if attacking:
		_update_attack(delta)
	elif can_hit and _target_in_range():
		_start_attack()

	# Pathfinding: keep the destination on the player and walk to the next point on the path.
	if target:
		nav_agent.target_position = target.global_position

	var push := _separation()
	if attacking:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if target:
			_face(target.global_position)
	elif target == null or nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, push.x * SPEED, SPEED)
		velocity.z = move_toward(velocity.z, push.z * SPEED, SPEED)
		if target:
			_face(target.global_position)
	else:
		var next_point := nav_agent.get_next_path_position()
		var direction := next_point - global_position
		direction.y = 0
		direction = direction.normalized()
		if direction:
			look_at(global_position + direction, Vector3.UP)
		var move_dir := (direction + push * separation_strength).normalized()
		velocity.x = move_dir.x * SPEED
		velocity.z = move_dir.z * SPEED

	_update_animation()
	move_and_slide()


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
		anim.play(attack_anim)


func _update_attack(delta: float) -> void:
	attack_time += delta
	if not hit_landed and attack_time >= attack_length * hit_point:
		hit_landed = true
		if _target_in_range():
			target.take_damage(damage * damMultiplier)
	if attack_time >= attack_length:
		attacking = false
		cool.start()


func _face(pos: Vector3) -> void:
	var flat := Vector3(pos.x, global_position.y, pos.z)
	if global_position.distance_to(flat) > 0.01:
		look_at(flat, Vector3.UP)


func _update_animation() -> void:
	if anim == null or attacking:
		return
	if Vector2(velocity.x, velocity.z).length() > 0.1:
		if move_anim != "" and anim.current_animation != move_anim:
			anim.play(move_anim)
	elif anim.is_playing():
		anim.stop()


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
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e == self or e == target or not e is Node3D:
			continue
		var offset: Vector3 = global_position - e.global_position
		offset.y = 0
		var dist := offset.length()
		if dist > 0.01 and dist < separation_radius:
			push += offset.normalized() * (1.0 - dist / separation_radius)
	return push.limit_length(1.0)
