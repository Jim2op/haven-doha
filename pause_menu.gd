extends CanvasLayer
## Pause menu (Esc). Runs while the tree is paused; gameplay nodes keep their default
## process mode, so they simply freeze. Does not open while the end screen is showing.

const TITLE_SCENE := "res://title_screen.tscn"

@onready var root_control: Control = %PauseRoot
@onready var menu_panel: PanelContainer = %PausePanel
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var restart_button: Button = %RestartButton
@onready var title_button: Button = %TitleButton
@onready var settings_panel: PanelContainer = %SettingsPanel

var _blocked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control.hide()
	settings_panel.hide()
	resume_button.pressed.connect(close)
	settings_button.pressed.connect(_on_settings_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	title_button.pressed.connect(_on_title_pressed)
	settings_panel.closed.connect(_on_settings_closed)


## Called by the end screen so Esc cannot unpause a finished round.
func block() -> void:
	_blocked = true
	close()


func open() -> void:
	if _blocked:
		return
	get_tree().paused = true
	root_control.show()
	menu_panel.show()
	settings_panel.hide()
	resume_button.grab_focus()


func close() -> void:
	root_control.hide()
	if not _blocked:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if root_control.visible and settings_panel.visible:
			return # the settings panel handles its own Esc
		get_viewport().set_input_as_handled()
		if root_control.visible:
			close()
		else:
			open()


func _on_settings_pressed() -> void:
	menu_panel.hide()
	settings_panel.show()


func _on_settings_closed() -> void:
	menu_panel.show()
	settings_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	SceneLoader.reload_current_scene()


func _on_title_pressed() -> void:
	get_tree().paused = false
	SceneLoader.change_scene(TITLE_SCENE)
