extends "res://enemy.gd"


func _init() -> void:
	base_health = 150.0
	base_damage = 20.0
	speed = 4.0
	separation_radius = 3.0
	token_reward = 5
	knockback_scale = 0.45
	attack_sources = ["res://orc.gltf", "res://orc.glb"]
	voice_pitch = 0.7
	walk_sound_path = "res://Audio/Characters/Big_Goblin/Walking/bannythecoolio-gentoix27s-bon-footsteps-loop-walk-424387.mp3"
	impact_sound_path = "res://Audio/Other/dragon-studio-heavy-boulder-thud-515257.mp3"
	color_high = Color("00d300ff")
	color_mid = Color("ff8600ff")
	color_low = Color("ff0000ff")
