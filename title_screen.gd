extends Control
## Title screen: the game's entry scene. "Play" loads the existing level unchanged.

const LEVEL_SCENE := "res://environment/forest_biome/forest_biome.tscn"

@onready var menu: VBoxContainer = %Menu
@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var settings_panel: PanelContainer = %SettingsPanel


func _ready() -> void:
	preload("res://settings_panel.gd").apply_saved()
	get_tree().paused = false
	# Browsers cannot close the tab from a game, so Quit is only shown on desktop builds.
	quit_button.visible = not OS.has_feature("web")
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(func(): get_tree().quit())
	settings_panel.closed.connect(_on_settings_closed)
	settings_panel.hide()
	play_button.grab_focus()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _on_settings_pressed() -> void:
	menu.hide()
	settings_panel.show()


func _on_settings_closed() -> void:
	menu.show()
	settings_button.grab_focus()
