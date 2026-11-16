extends Node

signal tokens_changed(amount: int)
signal ammo_changed(weapon: int, amount: int)
signal weapon_changed(weapon: int)

const HEALTH_STEP := 0.25
const DAMAGE_STEP := 0.25
const BASE_COST := 3
const COST_STEP := 2
const Weapons := preload("res://weapons/weapon_config.gd")
const WEAPON_SWORD := Weapons.SWORD
const WEAPON_BOW := Weapons.BOW
const WEAPON_FIRE_BOW := Weapons.FIRE_BOW

var health_multiplier := 1.0
var damage_multiplier := 1.0
var health_level := 0
var damage_level := 0
@export var tokens := 0
var weapon := WEAPON_SWORD
var unlocked := {WEAPON_BOW: false, WEAPON_FIRE_BOW: false}
var ammo := {WEAPON_BOW: 0, WEAPON_FIRE_BOW: 0}


func add_tokens(amount: int) -> void:
	tokens += amount
	tokens_changed.emit(tokens)


func health_cost() -> int:
	return BASE_COST + COST_STEP * health_level


func damage_cost() -> int:
	return BASE_COST + COST_STEP * damage_level


func upgrade_health() -> bool:
	if not _spend(health_cost()):
		return false
	health_level += 1
	health_multiplier += HEALTH_STEP
	return true


func upgrade_damage() -> bool:
	if not _spend(damage_cost()):
		return false
	damage_level += 1
	damage_multiplier += DAMAGE_STEP
	return true


func _spend(cost: int) -> bool:
	if tokens < cost:
		return false
	tokens -= cost
	tokens_changed.emit(tokens)
	return true




func give_weapon(w: int) -> bool:
	if not unlocked.has(w):
		return false
	var first: bool = not unlocked[w]
	unlocked[w] = true
	refill(w)
	return first


func refill(w: int) -> bool:
	if not unlocked.get(w, false) or ammo[w] >= Weapons.ammo_max(w):
		return false
	ammo[w] = Weapons.ammo_max(w)
	ammo_changed.emit(w, ammo[w])
	return true


func refill_owned() -> void:
	for w in unlocked:
		refill(w)


func ammo_full(w: int) -> bool:
	return not ammo.has(w) or ammo[w] >= Weapons.ammo_max(w)


func has_ranged_weapon() -> bool:
	for w in unlocked:
		if unlocked[w]:
			return true
	return false


func is_unlocked(w: int) -> bool:
	if w == WEAPON_SWORD:
		return true
	return unlocked.get(w, false)


func available_weapons() -> Array[int]:
	var list: Array[int] = []
	for w in Weapons.ORDER:
		if is_unlocked(w):
			list.append(w)
	return list


func next_weapon(from: int, step: int) -> int:
	var order: Array = Weapons.ORDER
	var count := order.size()
	var i := maxi(order.find(from), 0)
	for n in count:
		i = posmod(i + step, count)
		if is_unlocked(order[i]):
			return order[i]
	return from


func set_weapon(w: int) -> bool:
	if not is_unlocked(w) or w == weapon:
		return false
	weapon = w
	weapon_changed.emit(weapon)
	return true


func uses_bow(w: int) -> bool:
	return Weapons.uses_ammo(w)


func ammo_for(w: int) -> int:
	return int(ammo.get(w, 0))


func max_ammo_for(w: int) -> int:
	return Weapons.ammo_max(w)


func use_ammo(w: int) -> bool:
	if ammo_for(w) <= 0:
		return false
	ammo[w] -= 1
	ammo_changed.emit(w, ammo[w])
	return true
