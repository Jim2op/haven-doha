extends Node

signal tokens_changed(amount: int)

const HEALTH_STEP := 0.25
const DAMAGE_STEP := 0.25
const BASE_COST := 3
const COST_STEP := 2

var health_multiplier := 1.0
var damage_multiplier := 1.0
var health_level := 0
var damage_level := 0
@export var tokens := 0


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
