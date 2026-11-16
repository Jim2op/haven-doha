extends Area3D

const Weapons := preload("res://weapons/weapon_config.gd")
const FIRE_OVERLAY := preload("res://weapons/fire_arrow_overlay.tres")
const SPIN_SPEED := 1.6
const BOB_HEIGHT := 0.12
const BOB_SPEED := 2.4
const RECHECK_TIME := 0.5

@export_enum("Bow:1", "Fire Bow:2") var weapon := Weapons.BOW

@onready var visual: Node3D = $Visual
@onready var label: Label3D = $Label3D

var _time := 0.0
var _base_y := 0.0
var _recheck_left := RECHECK_TIME


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = visual.position.y
	_update_label()
	if Weapons.is_explosive(weapon):
		for mi in visual.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = FIRE_OVERLAY


func _process(delta: float) -> void:
	_time += delta
	visual.rotation.y += SPIN_SPEED * delta
	visual.position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT
	_recheck_left -= delta
	if _recheck_left <= 0.0:
		_recheck_left = RECHECK_TIME
		if PlayerStats.is_unlocked(weapon) and not PlayerStats.ammo_full(weapon):
			for body in get_overlapping_bodies():
				_on_body_entered(body)


func _update_label() -> void:
	var def := Weapons.get_def(weapon)
	label.text = def["refill_label"] if PlayerStats.is_unlocked(weapon) else def["pickup_label"]


func _on_body_entered(body: Node3D) -> void:
	if is_queued_for_deletion():
		return
	if body.has_method("pick_up_weapon") and body.pick_up_weapon(weapon):
		set_deferred("monitoring", false)
		queue_free()
