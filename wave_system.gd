extends Node
signal Wave(num)
signal WaveOver()

var WaveNumber = 0
var WaveEnemies = 0
@export var tokens = 0
func Wave1():
	WaveNumber = 1
	WaveEnemies = 3
	Wave.emit(1)
func _ready() -> void:
	Wave1()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if WaveEnemies == 0:
		WaveOver.emit
		WaveEnemies = 1
