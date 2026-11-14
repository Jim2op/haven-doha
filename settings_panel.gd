extends PanelContainer
## Settings panel shared by the title screen and the pause menu.
## Settings are stored in user://settings.cfg (IndexedDB on HTML5) and applied with apply_saved().

signal closed

const SETTINGS_PATH := "user://settings.cfg"

@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var back_button: Button = %BackButton


static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	return {
		"volume": float(cfg.get_value("audio", "master_volume", 80.0)),
		"fullscreen": bool(cfg.get_value("video", "fullscreen", false)),
	}


static func apply_saved() -> void:
	var s := load_settings()
	_apply_volume(s["volume"])
	_apply_fullscreen(s["fullscreen"])


static func _apply_volume(percent: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(percent / 100.0))
	AudioServer.set_bus_mute(bus, percent <= 0.0)


static func _apply_fullscreen(on: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _ready() -> void:
	var s := load_settings()
	volume_slider.value = s["volume"]
	fullscreen_toggle.button_pressed = s["fullscreen"]
	_update_volume_label(s["volume"])
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_pressed)
	visibility_changed.connect(func(): if visible: volume_slider.grab_focus())


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_update_volume_label(value)
	_save()


func _on_fullscreen_toggled(on: bool) -> void:
	# On HTML5 this runs inside the click handler, which browsers require for fullscreen.
	_apply_fullscreen(on)
	_save()


func _update_volume_label(value: float) -> void:
	volume_value.text = "%d" % int(value)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", volume_slider.value)
	cfg.set_value("video", "fullscreen", fullscreen_toggle.button_pressed)
	cfg.save(SETTINGS_PATH)


func _on_back_pressed() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
