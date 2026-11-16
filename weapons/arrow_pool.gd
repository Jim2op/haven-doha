extends Node3D

const ARROW_SCENE := preload("res://weapons/arrow.tscn")
const EXPLOSION := preload("res://weapons/explosion.gd")
const SIZE := 8

var _free: Array[Node3D] = []
var _active: Array[Node3D] = []
var _explosion: Node3D


func _ready() -> void:
	for i in SIZE:
		var arrow: Node3D = ARROW_SCENE.instantiate()
		add_child(arrow)
		arrow.finished.connect(_on_arrow_finished)
		arrow.exploded.connect(_on_arrow_exploded)
		_free.append(arrow)
	_explosion = EXPLOSION.new()
	_explosion.name = "Explosions"
	add_child(_explosion)


func fire(from: Vector3, velocity: Vector3, damage: float, exclude: Array[RID], blast := {}) -> void:
	if _free.is_empty() and not _active.is_empty():
		_active[0].retire()
	if _free.is_empty():
		return
	var arrow: Node3D = _free.pop_back()
	_active.append(arrow)
	arrow.launch(from, velocity, damage, exclude, blast)


func active_count() -> int:
	return _active.size()


func _on_arrow_finished(arrow: Node3D) -> void:
	_active.erase(arrow)
	if not _free.has(arrow):
		_free.append(arrow)


func _on_arrow_exploded(at: Vector3, blast: Dictionary, exclude: Array[RID]) -> void:
	_explosion.explode(at, blast, exclude)
