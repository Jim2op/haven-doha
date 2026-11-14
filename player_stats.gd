extends Node

const HEALTH_STEP := 0.25
const DAMAGE_STEP := 0.25

var health_multiplier := 1.0
var damage_multiplier := 1.0
@export var tokens = 0

func upgrade_health() -> void:
	health_multiplier += HEALTH_STEP


func upgrade_damage() -> void:
	damage_multiplier += DAMAGE_STEP
