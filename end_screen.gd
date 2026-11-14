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
@onready var upgrades: HBoxContainer = %Upgrades
@onready var health_upgrade_button: Button = %HealthUpgradeButton
@onready var damage_upgrade_button: Button = %DamageUpgradeButton
@onready var token_label: Label = %TokenLabel

var _player: Node
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control.hide()
	upgrades.hide()
	retry_button.pressed.connect(_on_retry_pressed)
	title_button.pressed.connect(_on_title_pressed)
	health_upgrade_button.pressed.connect(_on_health_upgrade_pressed)
	damage_upgrade_button.pressed.connect(_on_damage_upgrade_pressed)
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
	_show("You Have Fallen", "The ancient wood claims another soul. Spend your tokens on boons, then rise again.", "Rise Again", true)


func _show(title: String, text: String, retry_text: String, offer_upgrades := false) -> void:
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
	retry_button.show()
	if offer_upgrades:
		_refresh_upgrades()
		upgrades.show()
		token_label.show()
	else:
		upgrades.hide()
		token_label.hide()
	retry_button.grab_focus()


func _refresh_upgrades() -> void:
	token_label.text = "Tokens: %d" % PlayerStats.tokens
	health_upgrade_button.text = "Vitality  x%.2f -> x%.2f  (%d tokens)" % [PlayerStats.health_multiplier, PlayerStats.health_multiplier + PlayerStats.HEALTH_STEP, PlayerStats.health_cost()]
	damage_upgrade_button.text = "Might  x%.2f -> x%.2f  (%d tokens)" % [PlayerStats.damage_multiplier, PlayerStats.damage_multiplier + PlayerStats.DAMAGE_STEP, PlayerStats.damage_cost()]
	health_upgrade_button.disabled = PlayerStats.tokens < PlayerStats.health_cost()
	damage_upgrade_button.disabled = PlayerStats.tokens < PlayerStats.damage_cost()


func _on_health_upgrade_pressed() -> void:
	PlayerStats.upgrade_health()
	_refresh_upgrades()


func _on_damage_upgrade_pressed() -> void:
	PlayerStats.upgrade_damage()
	_refresh_upgrades()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_title_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
