extends Node

signal quality_changed(level: int)

enum Quality { LOW, MEDIUM, HIGH }

const SETTINGS_PATH := "user://settings.cfg"
const HIT_SPARK := preload("res://vfx/hit_spark.tscn")
const DEATH_BURST := preload("res://vfx/death_burst.tscn")
const FLASH_SHADER := preload("res://vfx/hit_flash.gdshader")
const IMPACT_RING := preload("res://vfx/impact_ring.gd")
const DAMAGE_NUMBER := preload("res://vfx/damage_number.gd")
const MIST_SHADER := preload("res://environment/forest_biome/shaders/mist_card.gdshader")

const PROFILES := {
	Quality.LOW: {
		"render_scale": 0.7, "ambient": 0.35, "burst": 0.45, "max_bursts": 4, "max_rings": 2, "max_numbers": 6,
		"shadows": false, "shadow_size": 1024, "glow": false, "mist_octaves": 2, "vignette": false,
	},
	Quality.MEDIUM: {
		"render_scale": 0.85, "ambient": 0.65, "burst": 0.75, "max_bursts": 6, "max_rings": 3, "max_numbers": 10,
		"shadows": true, "shadow_size": 2048, "glow": true, "mist_octaves": 3, "vignette": true,
	},
	Quality.HIGH: {
		"render_scale": 1.0, "ambient": 1.0, "burst": 1.0, "max_bursts": 10, "max_rings": 4, "max_numbers": 14,
		"shadows": true, "shadow_size": 4096, "glow": true, "mist_octaves": 4, "vignette": true,
	},
}

const SPARK_TINT := Color(1.0, 0.86, 0.6)
const HURT_TINT := Color(1.0, 0.32, 0.25)
const ENEMY_FLASH := Color(1.0, 1.0, 1.0, 1.0)
const PLAYER_FLASH := Color(1.0, 0.2, 0.15, 0.7)
const TELL_FLASH := Color(1.0, 0.35, 0.1, 0.55)
const FLASH_HOLD := 0.05
const FLASH_TIME := 0.1
const RING_TINT := Color(1.0, 0.78, 0.4)
const KILL_RING_TINT := Color(0.55, 0.95, 0.9)
const NUMBER_TINT := Color(1.0, 0.93, 0.72)
const KILL_NUMBER_TINT := Color(1.0, 0.62, 0.22)
const HURT_NUMBER_TINT := Color(1.0, 0.36, 0.3)
const TOKEN_TINT := Color(0.45, 0.9, 1.0)
const NUMBER_TIME := 0.7
const RING_TIME := 0.32
const GROUND_PROBE := 4.0
const SHAKE_MAX_OFFSET := Vector2(0.32, 0.22)
const SHAKE_DECAY := 3.0
const SHAKE_FREQUENCY := 22.0
const VIGNETTE_TIME := 0.35
const CAMERA_PULL := 0.6

var quality: int = Quality.HIGH

var _pools := {}
var _trauma := 0.0
var _shake_time := 0.0
var _shake_cam: Camera3D
var _noise := FastNoiseLite.new()
var _vignette: TextureRect
var _vignette_tween: Tween


func _ready() -> void:
	_noise.frequency = 1.0
	_noise.seed = randi()
	quality = _load_quality()
	_build_vignette()
	for key in [HIT_SPARK, DEATH_BURST, IMPACT_RING, DAMAGE_NUMBER]:
		_pools[key] = []
	get_tree().node_added.connect(_on_node_added)
	_apply_quality()


static func default_quality() -> int:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return Quality.MEDIUM
	return Quality.HIGH


func set_quality(level: int) -> void:
	level = clampi(level, Quality.LOW, Quality.HIGH)
	if level == quality:
		return
	quality = level
	_apply_quality()
	quality_changed.emit(quality)


func profile() -> Dictionary:
	return PROFILES[quality]


func hit_spark(at: Vector3, facing: Vector3, tint := SPARK_TINT) -> void:
	_spawn(HIT_SPARK, at, facing, tint)


func death_burst(at: Vector3, tint := Color.WHITE) -> void:
	_spawn(DEATH_BURST, at, Vector3.FORWARD, tint)
	impact_ring(at, KILL_RING_TINT, 2.4)
	shake(0.18)


func impact_ring(at: Vector3, tint := RING_TINT, size := 1.6) -> void:
	var ring = _acquire(IMPACT_RING, profile()["max_rings"])
	ring.play(_ground_below(at), tint, size, RING_TIME)


func damage_number(at: Vector3, amount: float, kind := 0) -> void:
	var tint := NUMBER_TINT
	var size := 1.0
	if kind == 1:
		tint = KILL_NUMBER_TINT
		size = 1.45
	elif kind == 2:
		tint = HURT_NUMBER_TINT
		size = 0.85
	var label = _acquire(DAMAGE_NUMBER, profile()["max_numbers"])
	label.play(at + Vector3.UP * 0.6, str(roundi(amount)), tint, size, NUMBER_TIME)


func token_popup(at: Vector3, amount: int) -> void:
	var label = _acquire(DAMAGE_NUMBER, profile()["max_numbers"])
	label.play(at + Vector3(0.0, 1.75, 0.0), "+%d" % amount, TOKEN_TINT, 1.1, NUMBER_TIME * 1.4)


func punch_scale(node: Node3D, strength := 1.0) -> void:
	if not is_instance_valid(node):
		return
	if not node.has_meta(&"vfx_base_scale"):
		node.set_meta(&"vfx_base_scale", node.scale)
	var base: Vector3 = node.get_meta(&"vfx_base_scale")
	if node.has_meta(&"vfx_punch_tween"):
		var old: Tween = node.get_meta(&"vfx_punch_tween")
		if old and old.is_valid():
			old.kill()
	var k := 0.18 * strength
	node.scale = base * Vector3(1.0 + k, 1.0 - k, 1.0 + k)
	var tw := node.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, 0.28)
	node.set_meta(&"vfx_punch_tween", tw)


func hurt(target: Node3D, at: Vector3) -> void:
	_spawn(HIT_SPARK, at, Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)), HURT_TINT)
	flash(target, PLAYER_FLASH, 0.18)
	shake(0.4)
	if profile()["vignette"]:
		_pulse_vignette()


func warm_up(targets: Array) -> void:
	var at := Vector3.ZERO
	var anchor: Node3D = null
	for t in targets:
		if is_instance_valid(t):
			anchor = t
			break
	if anchor == null:
		return
	at = anchor.global_position
	var hidden := Color(1.0, 1.0, 1.0, 0.0)
	var warmed: Array = []
	for key in [HIT_SPARK, DEATH_BURST]:
		if not _pools[key].is_empty():
			var fx = _pools[key][0]
			fx.play(at, Vector3.FORWARD, hidden)
			warmed.append(fx)
	var ring = _acquire(IMPACT_RING, 1)
	ring.play(at, Color(0.0, 0.0, 0.0, 0.0), 1.0, 0.1)
	warmed.append(ring)
	var label = _acquire(DAMAGE_NUMBER, 1)
	label.play(at, "0", hidden, 1.0, 0.1)
	warmed.append(label)
	var meshes: Array = []
	for t in targets:
		if is_instance_valid(t):
			var mat := _flash_material(t)
			mat.set_shader_parameter("amount", 0.0)
			for m in t.get_meta(&"vfx_flash_meshes"):
				m.material_overlay = mat
				meshes.append(m)
	_vignette.modulate.a = 0.0
	_vignette.visible = true
	for i in 3:
		await get_tree().process_frame
	_clear_overlay(meshes)
	_vignette.visible = false
	for fx in warmed:
		if is_instance_valid(fx):
			fx.stop()


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func hit_stop(nodes: Array, duration: float) -> void:
	for n in nodes:
		if is_instance_valid(n) and n.has_method("freeze_for"):
			n.freeze_for(duration)


func flash(target: Node3D, color := ENEMY_FLASH, duration := FLASH_TIME, hold := FLASH_HOLD) -> void:
	if not is_instance_valid(target):
		return
	var mat := _flash_material(target)
	var targets: Array = target.get_meta(&"vfx_flash_meshes")
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("amount", 1.0)
	for m in targets:
		if is_instance_valid(m):
			m.material_overlay = mat
	if target.has_meta(&"vfx_flash_tween"):
		var old: Tween = target.get_meta(&"vfx_flash_tween")
		if old and old.is_valid():
			old.kill()
	var tw := target.create_tween()
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_method(_set_flash_amount.bind(mat), 1.0, 0.0, duration)
	tw.tween_callback(_clear_overlay.bind(targets))
	target.set_meta(&"vfx_flash_tween", tw)


func _flash_material(target: Node3D) -> ShaderMaterial:
	if target.has_meta(&"vfx_flash_mat"):
		return target.get_meta(&"vfx_flash_mat")
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	target.set_meta(&"vfx_flash_mat", mat)
	var meshes: Array = []
	for m in target.find_children("*", "MeshInstance3D", true, false):
		if m.mesh != null and m.material_override == null:
			meshes.append(m)
	target.set_meta(&"vfx_flash_meshes", meshes)
	return mat


func active_bursts() -> int:
	var n := 0
	for scene in _pools:
		for fx in _pools[scene]:
			if fx.busy:
				n += 1
	return n


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != _shake_cam:
		_reset_camera()
		_shake_cam = cam
	if cam == null:
		_trauma = 0.0
		return
	_shake_time += delta
	_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
	var s := _trauma * _trauma
	var t := _shake_time * SHAKE_FREQUENCY
	cam.h_offset = SHAKE_MAX_OFFSET.x * s * _noise.get_noise_2d(t, 0.0)
	cam.v_offset = SHAKE_MAX_OFFSET.y * s * _noise.get_noise_2d(0.0, t + 100.0)
	if _trauma <= 0.0:
		_reset_camera()


func _reset_camera() -> void:
	if is_instance_valid(_shake_cam):
		_shake_cam.h_offset = 0.0
		_shake_cam.v_offset = 0.0


func _spawn(scene: PackedScene, at: Vector3, facing: Vector3, tint: Color) -> void:
	var chosen = _acquire(scene, profile()["max_bursts"])
	var cam := get_viewport().get_camera_3d()
	if cam:
		at += cam.global_basis.z * CAMERA_PULL
	chosen.play(at, facing, tint)


func _acquire(key: Resource, cap: int) -> Node3D:
	var pool: Array = _pools[key]
	var oldest: Node3D = null
	for i in mini(pool.size(), cap):
		var fx = pool[i]
		if not fx.busy:
			return fx
		if oldest == null or fx.time_left < oldest.time_left:
			oldest = fx
	if pool.size() < cap or oldest == null:
		return _add_to_pool(key)
	return oldest


func _add_to_pool(key: Resource) -> Node3D:
	var fx: Node3D
	if key is PackedScene:
		fx = (key as PackedScene).instantiate() as Node3D
	else:
		fx = (key as GDScript).new() as Node3D
	add_child(fx)
	if fx.has_method("set_density"):
		fx.set_density(profile()["burst"])
	_pools[key].append(fx)
	return fx


func _ground_below(at: Vector3) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state if get_viewport().world_3d else null
	if space == null:
		return at
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, at + Vector3.DOWN * GROUND_PROBE, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return at
	return hit["position"] + Vector3.UP * 0.04


func _set_flash_amount(v: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("amount", v)


func _clear_overlay(meshes: Array) -> void:
	for m in meshes:
		if is_instance_valid(m):
			m.material_overlay = null


func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0.6, 0.02, 0.02, 0.0), Color(0.6, 0.02, 0.02, 0.0), Color(0.55, 0.0, 0.0, 0.75)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.visible = false
	layer.add_child(_vignette)


func _pulse_vignette() -> void:
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_vignette.visible = true
	_vignette.modulate.a = 1.0
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_vignette, "modulate:a", 0.0, VIGNETTE_TIME).set_ease(Tween.EASE_OUT)
	_vignette_tween.tween_callback(_vignette.hide)


func _load_quality() -> int:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	return clampi(int(cfg.get_value("video", "quality", default_quality())), Quality.LOW, Quality.HIGH)


func _apply_quality() -> void:
	var p := profile()
	var root := get_tree().root
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = p["render_scale"]
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_size"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if quality == Quality.HIGH else RenderingServer.SHADOW_QUALITY_HARD)
	for scene in [HIT_SPARK, DEATH_BURST]:
		for fx in _pools[scene]:
			fx.set_density(p["burst"])
		while _pools[scene].size() < p["max_bursts"]:
			_add_to_pool(scene)
	while _pools[IMPACT_RING].size() < p["max_rings"]:
		_add_to_pool(IMPACT_RING)
	while _pools[DAMAGE_NUMBER].size() < p["max_numbers"]:
		_add_to_pool(DAMAGE_NUMBER)
	_apply_tree(root)


func _apply_tree(node: Node) -> void:
	_apply_node(node)
	for c in node.get_children():
		_apply_tree(c)


func _on_node_added(node: Node) -> void:
	_apply_node(node)


func _apply_node(node: Node) -> void:
	var p := profile()
	if node is GPUParticles3D:
		node.amount_ratio = p["ambient"]
	elif node is DirectionalLight3D:
		if not node.has_meta(&"vfx_shadow"):
			node.set_meta(&"vfx_shadow", node.shadow_enabled)
		node.shadow_enabled = node.get_meta(&"vfx_shadow") and p["shadows"]
	elif node is WorldEnvironment:
		var env: Environment = node.environment
		if env:
			if not env.has_meta(&"vfx_glow"):
				env.set_meta(&"vfx_glow", env.glow_enabled)
			env.glow_enabled = env.get_meta(&"vfx_glow") and p["glow"]
	elif node is GeometryInstance3D:
		var mat := (node as GeometryInstance3D).material_override as ShaderMaterial
		if mat and mat.shader == MIST_SHADER:
			mat.set_shader_parameter("octaves", p["mist_octaves"])
