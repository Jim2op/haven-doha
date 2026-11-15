extends CanvasLayer

signal finished

const FADE_TIME := 0.25
const MIN_VISIBLE := 0.8
const SETTLE_FRAMES := 6
const FRAME_BUDGET_MS := 12
const DEFAULT_MESSAGE := "Entering the Ruin woods"
const FINAL_MESSAGE := "Awakening the ruins"
const MESSAGES := {
	"res://title_screen.tscn": "Returning to the ruins",
}
const TIPS := [
	"Strike as the blade swings through: your hit lands mid-arc.",
	"Big goblins hit harder but swing slower. Keep moving.",
	"Spend gems between rounds to grow stronger.",
	"Lower the Quality setting if the forest feels sluggish.",
	"The ruins remember those who fall. Do not linger.",
]

var busy := false
var _held: Array[Resource] = []
var _fade_tween: Tween

@onready var root_control: Control = %Root
@onready var bar: ProgressBar = %Bar
@onready var status: Label = %Status
@onready var tip: Label = %Tip


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control.visible = false
	root_control.modulate.a = 0.0


func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	get_viewport().gui_release_focus()
	status.text = MESSAGES.get(path, DEFAULT_MESSAGE)
	tip.text = TIPS.pick_random()
	bar.value = 0.0
	await _fade(1.0)
	await get_tree().process_frame
	var started := Time.get_ticks_msec()
	var packed := await _load(path)
	if packed == null:
		push_error("Loading screen could not load %s" % path)
		await _fade(0.0)
		busy = false
		return
	status.text = FINAL_MESSAGE
	await get_tree().process_frame
	get_tree().change_scene_to_packed(packed)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	_held.clear()
	bar.value = 100.0
	var left := MIN_VISIBLE - (Time.get_ticks_msec() - started) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left, true, false, true).timeout
	await _fade(0.0)
	busy = false
	finished.emit()


func reload_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != "":
		change_scene(scene.scene_file_path)
	else:
		get_tree().reload_current_scene()


func _load(path: String) -> PackedScene:
	if OS.has_feature("threads") and ResourceLoader.load_threaded_request(path, "PackedScene", false) == OK:
		var progress := []
		while true:
			var state := ResourceLoader.load_threaded_get_status(path, progress)
			if state == ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(path) as PackedScene
			if state != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				break
			bar.value = maxf(bar.value, float(progress[0]) * 90.0)
			await get_tree().process_frame
	return await _load_stepped(path)


func _load_stepped(path: String) -> PackedScene:
	var deps := ResourceLoader.get_dependencies(path)
	var frame_start := Time.get_ticks_msec()
	for i in deps.size():
		var dep: String = deps[i]
		var dep_path := dep.get_slice("::", dep.get_slice_count("::") - 1)
		if dep_path != "" and not ResourceLoader.has_cached(dep_path):
			var res := ResourceLoader.load(dep_path)
			if res:
				_held.append(res)
		bar.value = 90.0 * float(i + 1) / deps.size()
		if Time.get_ticks_msec() - frame_start > FRAME_BUDGET_MS:
			await get_tree().process_frame
			frame_start = Time.get_ticks_msec()
	status.text = FINAL_MESSAGE
	await get_tree().process_frame
	await get_tree().process_frame
	return ResourceLoader.load(path) as PackedScene


func _fade(to: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	root_control.visible = true
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(root_control, "modulate:a", to, FADE_TIME)
	await _fade_tween.finished
	if to <= 0.0:
		root_control.visible = false
