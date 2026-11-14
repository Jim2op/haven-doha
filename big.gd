extends "res://enemy.gd"


func _init() -> void:
	base_health = 150.0
	base_damage = 20.0
	speed = 4.0
	separation_radius = 3.0
	token_reward = 5
	color_high = Color("00d300ff")
	color_mid = Color("ff8600ff")
	color_low = Color("ff0000ff")
