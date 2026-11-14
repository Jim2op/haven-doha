extends CanvasLayer
## Game-over and victory screen.
## Defeat: the player's `died` signal. Victory: no members of the "Enemies" group are left
## except the player (player.gd adds itself to that group, so it is excluded here).

const TITLE_SCENE := "res://title_screen.tscn"

@export var player_path: NodePath = ^"../Player"
@export var pause_menu_path: NodePath = ^"../PauseMenu"

@onready var root_control: Control = %EndRoot
@onready var heading: Label = %Heading
@onready var message: Label = %Message
@onready var retry_button: Button = %RetryButton
@onready var title_button: Button = %TitleButton

var _player: Node
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control.hide()
	retry_button.pressed.connect(_on_retry_pressed)
	title_button.pressed.connect(_on_title_pressed)
	_player = get_node_or_null(player_path)
	if _player and _player.has_signal("died"):
		_player.died.connect(_on_player_died)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_check_victory)
	add_child(timer)


func _check_victory() -> void:
	if _finished or get_tree().paused:
		return
	for n in get_tree().get_nodes_in_group("Enemies"):
		if n != _player and not n.is_queued_for_deletion():
			return
	_show("Victory", "The forest falls silent. No foe remains.", "Play Again")


func _on_player_died() -> void:
	_show("You Have Fallen", "The ancient wood claims another soul.", "Rise Again")


func _show(title: String, text: String, retry_text: String) -> void:
	if _finished:
		return
	_finished = true
	var pause_menu := get_node_or_null(pause_menu_path)
	if pause_menu and pause_menu.has_method("block"):
		pause_menu.block()
	heading.text = title
	message.text = text
	retry_button.text = retry_text
	get_tree().paused = true
	root_control.show()
	root_control.modulate.a = 0.0
	create_tween().tween_property(root_control, "modulate:a", 1.0, 0.6)
	retry_button.grab_focus()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
