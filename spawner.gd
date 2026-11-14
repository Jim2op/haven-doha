extends Node3D
@onready var goblin = preload("res://small_goblin.tscn")
@export var Player := CharacterBody3D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func wave1():
	var goblinclone = goblin.instantiate()
	goblinclone.position = Player.x - randi_range(5,10)
