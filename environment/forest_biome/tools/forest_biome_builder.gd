@tool
class_name ForestBiomeBuilder
extends RefCounted
## Builds res://environment/forest_biome/forest_biome.tscn from the Kytric "Voxel Path and Terrain" pack.
##
## The layout is authored data (paths, clearings, ponds, landmarks, vista windows, tree clusters) and
## only small-scale jitter is randomised with a fixed seed, so the result is deterministic and art-directed.
## Re-run from the editor (tools/build_forest_biome_editor.gd -> File > Run) or headless:
##   godot --headless --path . -s res://environment/forest_biome/tools/build_forest_biome_cli.gd
##
## Asset packs (all only read, never modified):
##   res://assets/voxel_path_terrain  Kytric "Voxel Path and Terrain": terrain tiles, paths, cliffs, stones, bones
##   res://assets/tree_bush_pack      "Tree & Bush pack v1" (MagicaVoxel OBJ): primary trees and bushes
##   res://assets/ruins_glb           "RuinsGLB": walls, gate, pillars, stairs, fences/headstones, moss, accessories

const S := 4.0                      # world scale applied to every asset (tile = 12.8 m, path ~2 m wide)
const T := 3.2 * S                  # tile size in metres
const GROUND_Y := -0.2 * S          # ground tiles are 0.2 units thick -> walkable surface at y = 0
const ASSETS := "res://assets/voxel_path_terrain/"
const BIOME := "res://environment/forest_biome/"
const MESH_DIR := BIOME + "meshes/"
const MAT_DIR := BIOME + "materials/"
const OUT_SCENE := BIOME + "forest_biome.tscn"
const SEED := 20261113
const TBP := "res://assets/tree_bush_pack/"
const RUINS := "res://assets/ruins_glb/"
## Tree & Bush pack heights (model units) used to match the art-directed heights of the layout.
const TBP_TREE_H := {"tree1": 2.6, "tree2": 2.5, "tree3": 3.1}
const TBP_BUSH_H := {"bush1": 1.5, "bush2": 1.3, "bush3": 1.6}
## Layout material -> Tree & Bush pack material.
const TBP_MAT := {"canopy": "tbp_canopy", "canopy_edge": "tbp_edge", "canopy_valley": "tbp_valley", "canopy_fg": "tbp_fg", "blight": "tbp_blight", "silhouette": "tbp_silhouette", "fern": "tbp_bush", "fern_fg": "tbp_bush_fg"}
## Areas where a few "spirit-touched" blue-berried trees grow (shrine, graveyard, temple).
const SPIRIT_ZONES := [Vector3(-19.2, -18.0, 22.0), Vector3(-57.0, -24.0, 18.0), Vector3(61.0, -36.0, 18.0)]
## MultiMeshes are split into X chunks so off-screen chunks are frustum-culled and distant ones
## can use the auto-generated mesh LODs (a single level-wide MultiMesh is never culled).
const CHUNK := 48.0

# ---------------------------------------------------------------- authored layout
## Walkable belt (2.5D lane). The camera scrolls along X; Z is the shallow depth lane.
const BELT_MIN := Vector2(-104.0, -16.0)
const BELT_MAX := Vector2(104.0, 6.0)
## Path cells on the tile grid (i, j) -> world (i*T, j*T). Connections are inferred from neighbours.
const PATH_CELLS := [
	Vector2i(-8, -2), Vector2i(-8, -1), Vector2i(-8, 0), Vector2i(-7, 0), Vector2i(-6, 0),
	Vector2i(-6, -1), Vector2i(-5, -1), Vector2i(-4, -1), Vector2i(-4, 0), Vector2i(-3, 0),
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
	Vector2i(6, 0), Vector2i(7, 0), Vector2i(7, -1), Vector2i(7, -2),
]
## Clearings / ponds are marching-squares fields on tile corners; an ellipse marks corners as dirt/water.
const CLEARINGS := [
	{"name": "HollowGateClearing", "center": Vector2(-96.0, -19.2), "radii": Vector2(4.0, 4.0)},
	{"name": "ShrineClearing", "center": Vector2(-19.2, -6.4), "radii": Vector2(14.0, 4.0)},
	{"name": "BoneHollowClearing", "center": Vector2(70.4, -6.4), "radii": Vector2(4.0, 4.0)},
	{"name": "CryptForecourt", "center": Vector2(89.6, -32.0), "radii": Vector2(7.0, 4.0)},
]
const PONDS := [
	{"name": "DrownedGlade", "center": Vector2(38.4, -19.2), "radii": Vector2(7.0, 4.0)},
]
## X ranges kept free of tall trees at the forest edge so the misty valley and mountains show through.
const VISTA_WINDOWS := [Vector2(-70.0, -44.0), Vector2(-12.0, -2.0), Vector2(30.0, 47.0), Vector2(51.0, 71.0), Vector2(82.0, 97.0)]

var rng := RandomNumberGenerator.new()
var root: Node3D
var _meshes := {}
var _mats := {}
var _buckets := {}
var _bucket_order := []
var _colliders := []     # [{pos, radius, height}]
var _path_segments := [] # [[Vector2, Vector2]]
var _keepouts := []      # [{c: Vector2, r: float}] landmark footprints
var _layers := {}

# ================================================================ entry point
func build() -> Error:
	rng.seed = SEED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESH_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	_make_materials()
	_make_environment()
	root = Node3D.new()
	root.name = "ForestBiome"
	for l in ["Terrain", "Terrain/Ground", "Terrain/Paths", "Terrain/Cliffs",
			"Vegetation", "Vegetation/Foreground", "Vegetation/Playfield", "Vegetation/ForestEdge",
			"Landmarks", "Background", "Background/Valley", "FarBackground", "Atmosphere",
			"Atmosphere/Mist", "Atmosphere/Particles", "Atmosphere/LightShafts", "Collision", "Markers"]:
		_layer(l)
	_build_path_segments()
	_build_ground()
	_build_paths()
	_build_cliffs()
	_build_landmarks()
	_build_forest_edge()
	_build_playfield_dressing()
	_build_foreground()
	_build_grass()
	_build_valley()
	_build_far_background()
	_build_atmosphere()
	_build_collision()
	_build_markers()
	_flush_multimeshes()
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed %s" % err)
		return err
	err = ResourceSaver.save(packed, OUT_SCENE)
	root.free()
	print("ForestBiomeBuilder: saved ", OUT_SCENE, " (", _instance_count(), " multimesh instances)")
	return err

# ================================================================ helpers
func _layer(path: String) -> Node3D:
	if _layers.has(path):
		return _layers[path]
	var parent: Node = root
	var parts := path.split("/")
	if parts.size() > 1:
		parent = _layer("/".join(parts.slice(0, parts.size() - 1)))
	var n := Node3D.new()
	n.name = parts[parts.size() - 1]
	_add(parent, n)
	_layers[path] = n
	return n

func _add(parent: Node, n: Node) -> Node:
	parent.add_child(n)
	n.owner = root
	return n

func _mesh(rel: String) -> Mesh:
	if _meshes.has(rel):
		return _meshes[rel]
	var src := rel if rel.begins_with("res://") else ASSETS + rel
	var base := rel.get_file().get_basename()
	if src.begins_with(TBP):
		base = "tbp_" + base
	elif src.begins_with(RUINS):
		base = "ruins_" + base.to_lower()
	var out_path := MESH_DIR + base + ".res"
	if not ResourceLoader.exists(out_path):
		var r: Resource = load(src)
		var m: Mesh
		if r is Mesh:
			m = (r as Mesh).duplicate(true)
		else:
			var inst := (r as PackedScene).instantiate()
			var mis := inst.find_children("*", "MeshInstance3D", true, false)
			m = (mis[0] as MeshInstance3D).mesh.duplicate(true)
			inst.free()
		ResourceSaver.save(m, out_path, ResourceSaver.FLAG_COMPRESS)
	var loaded: Mesh = load(out_path)
	_meshes[rel] = loaded
	return loaded

## Tree & Bush pack OBJs are exported 2 units above their origin and off-centre: re-pivot them to the
## centre of their footprint at ground level (applied in the instance transform, the mesh is untouched).
func _pivot(rel: String) -> Vector3:
	if not rel.begins_with(TBP):
		return Vector3.ZERO
	var a := _mesh(rel).get_aabb()
	return Vector3(a.get_center().x, a.position.y, a.get_center().z)

func _xf(pos: Vector3, rot_y: float = 0.0, scale: Vector3 = Vector3.ONE * S) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y) * Basis.from_scale(scale), pos)

## Queue a MultiMesh instance. Identical (layer, mesh, material) instances are batched into one draw.
func _inst(layer: String, rel: String, mat: String, xf: Transform3D, shadows := true) -> void:
	xf.origin -= xf.basis * _pivot(rel)
	var cx := 0 if layer.begins_with("FarBackground") else int(floor(xf.origin.x / CHUNK))
	var key := "%s|%s|%s|%s|%d" % [layer, rel, mat, shadows, cx]
	if not _buckets.has(key):
		_buckets[key] = {"layer": layer, "rel": rel, "mat": mat, "shadows": shadows, "xfs": [], "chunk": cx}
		_bucket_order.append(key)
	_buckets[key]["xfs"].append(xf)

func _flush_multimeshes() -> void:
	for key in _bucket_order:
		var b: Dictionary = _buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(b["rel"])
		mm.instance_count = b["xfs"].size()
		for k in b["xfs"].size():
			mm.set_instance_transform(k, b["xfs"][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%s_c%d" % [String(b["rel"]).get_file().get_basename().to_pascal_case(), String(b["mat"]).to_pascal_case(), b["chunk"]]
		mmi.multimesh = mm
		mmi.material_override = _mats[b["mat"]] if _mats.has(b["mat"]) else _ruin_mat(b["rel"], b["mat"].trim_prefix("ruin_"))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if b["shadows"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(_layer(b["layer"]), mmi)

func _instance_count() -> int:
	var c := 0
	for k in _buckets:
		c += _buckets[k]["xfs"].size()
	return c

## A single hand-placed, individually editable prop.
func _prop(parent: Node, name: String, rel: String, mat: String, xf: Transform3D, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = _mesh(rel)
	mi.material_override = _mats[mat]
	xf.origin -= xf.basis * _pivot(rel)
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, mi)
	return mi

func _rot90() -> float:
	return rng.randi_range(0, 3) * PI * 0.5

func _pick(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]

## Rotation (multiple of 90 deg) that maps the set of base directions onto the target set.
func _find_rot(base: Array, target: Array) -> float:
	for k in 4:
		var r := k * PI * 0.5
		var b := Basis(Vector3.UP, r)
		var ok := true
		for d in base:
			var v: Vector3 = b * Vector3(d.x, 0, d.y)
			var hit := false
			for t in target:
				if Vector2(v.x, v.z).distance_to(t) < 0.01:
					hit = true
					break
			if not hit:
				ok = false
				break
		if ok and base.size() == target.size():
			return r
	return 0.0

# ================================================================ materials
func _palette(name: String) -> Texture2D:
	return load(BIOME + "palettes/" + name + ".png")

func _make_materials() -> void:
	var shader: Shader = load(BIOME + "shaders/voxel_palette.gdshader")
	var defs := {
		# key: [palette, params]
		"ground": ["forest_dusk_palette", {"brightness": 0.9, "value_variation": 0.05, "hue_variation": 0.015, "ao_strength": 0.0, "roughness_value": 1.0, "specular_value": 0.1}],
		"path": ["forest_dusk_palette", {"brightness": 1.2, "value_variation": 0.03, "ao_strength": 0.0, "roughness_value": 1.0}],
		"canopy": ["forest_dusk_palette", {"brightness": 0.9, "value_variation": 0.16, "hue_variation": 0.05, "ao_height": 1.1, "ao_strength": 0.6, "sway_amount": 0.006, "sway_start": 0.25}],
		"canopy_edge": ["forest_dusk_palette", {"brightness": 0.72, "value_variation": 0.18, "hue_variation": 0.06, "ao_height": 1.4, "ao_strength": 0.65, "sway_amount": 0.004, "sway_start": 0.3}],
		"canopy_valley": ["forest_dusk_palette", {"brightness": 0.55, "value_variation": 0.2, "hue_variation": 0.05, "ao_height": 1.2, "ao_strength": 0.5}],
		"canopy_fg": ["forest_dusk_palette", {"brightness": 0.32, "value_variation": 0.1, "ao_height": 0.8, "ao_strength": 0.5, "sway_amount": 0.01, "sway_start": 0.2}],
		"blight": ["forest_blight_palette", {"brightness": 0.85, "value_variation": 0.15, "hue_variation": 0.04, "ao_height": 1.2, "ao_strength": 0.6, "sway_amount": 0.005, "sway_start": 0.25}],
		"ancient": ["forest_ancient_palette", {"brightness": 0.95, "value_variation": 0.0, "ao_height": 1.6, "ao_strength": 0.7, "sway_amount": 0.002, "sway_start": 0.6}],
		"fern": ["forest_fern_palette", {"value_variation": 0.18, "hue_variation": 0.04, "ao_height": 0.4, "ao_strength": 0.55, "sway_amount": 0.12, "sway_start": 0.05, "sway_speed": 1.3}],
		"fern_fg": ["forest_fern_palette", {"brightness": 0.4, "value_variation": 0.15, "ao_height": 0.4, "ao_strength": 0.5, "sway_amount": 0.12, "sway_start": 0.05, "sway_speed": 1.1}],
		"bramble": ["forest_deadwood_palette", {"brightness": 0.75, "value_variation": 0.15, "ao_height": 0.4, "ao_strength": 0.5}],
		"stone": ["forest_dusk_palette", {"value_variation": 0.12, "ao_height": 0.35, "ao_strength": 0.45, "roughness_value": 0.85, "specular_value": 0.3}],
		"stone_fg": ["forest_dusk_palette", {"brightness": 0.45, "value_variation": 0.1, "ao_height": 0.35, "ao_strength": 0.4}],
		"rune_stone": ["forest_dusk_palette", {"brightness": 0.62, "ao_height": 0.7, "ao_strength": 0.6, "emission_color": Color(0.25, 0.85, 0.95), "emission_energy": 0.13, "roughness_value": 0.6}],
		"cliff": ["forest_dusk_palette", {"brightness": 0.72, "value_variation": 0.06, "ao_height": 3.0, "ao_strength": 0.6, "roughness_value": 0.9}],
		"bone": ["forest_dusk_palette", {"brightness": 0.58, "value_variation": 0.1, "ao_height": 0.3, "ao_strength": 0.5, "roughness_value": 0.7, "specular_value": 0.35}],
		"log": ["forest_deadwood_palette", {"brightness": 1.0, "value_variation": 0.1, "ao_strength": 0.0, "roughness_value": 1.0}],
		"deadwood": ["forest_deadwood_palette", {"brightness": 0.85, "value_variation": 0.12, "ao_height": 1.0, "ao_strength": 0.45}],
		"water": ["forest_dusk_palette", {"brightness": 0.7, "value_variation": 0.0, "ao_strength": 0.0, "roughness_value": 0.05, "specular_value": 0.9, "emission_color": Color(0.1, 0.3, 0.35), "emission_energy": 0.06}],
	}
	for key in defs:
		var path: String = MAT_DIR + "mat_%s.tres" % key
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("palette", _palette(defs[key][0]))
		for p in defs[key][1]:
			m.set_shader_parameter(p, defs[key][1][p])
		ResourceSaver.save(m, path)
		_mats[key] = load(path)
	# Tree & Bush pack: all variants share one MagicaVoxel palette (tree1.png). The pack's bright greens are
	# graded into the biome's dusk palette with tint/brightness only (no new textures).
	var tbp_pal: Texture2D = load(TBP + "tree1.png")
	var tbp_defs := {
		"tbp_canopy": {"brightness": 1.0, "tint": Color(0.4, 0.49, 0.54), "value_variation": 0.16, "hue_variation": 0.05, "ao_base": 2.0, "ao_height": 1.2, "ao_strength": 0.55, "sway_amount": 0.006, "sway_start": 2.6},
		"tbp_edge": {"brightness": 0.82, "tint": Color(0.4, 0.49, 0.54), "value_variation": 0.18, "hue_variation": 0.06, "ao_base": 2.0, "ao_height": 1.4, "ao_strength": 0.6, "sway_amount": 0.004, "sway_start": 2.6},
		"tbp_valley": {"brightness": 0.62, "tint": Color(0.4, 0.49, 0.54), "value_variation": 0.2, "hue_variation": 0.05, "ao_base": 2.0, "ao_height": 1.2, "ao_strength": 0.5},
		"tbp_fg": {"brightness": 0.36, "tint": Color(0.4, 0.49, 0.54), "value_variation": 0.1, "ao_base": 2.0, "ao_height": 0.8, "ao_strength": 0.5, "sway_amount": 0.01, "sway_start": 2.4},
		"tbp_blight": {"brightness": 0.85, "tint": Color(0.55, 0.44, 0.66), "value_variation": 0.15, "hue_variation": 0.04, "ao_base": 2.0, "ao_height": 1.2, "ao_strength": 0.6, "sway_amount": 0.005, "sway_start": 2.6},
		"tbp_spirit": {"brightness": 1.0, "tint": Color(0.42, 0.55, 0.62), "value_variation": 0.12, "ao_base": 2.0, "ao_height": 1.2, "ao_strength": 0.55, "sway_amount": 0.006, "sway_start": 2.6},
		"tbp_ancient": {"brightness": 1.05, "tint": Color(0.48, 0.58, 0.56), "value_variation": 0.0, "ao_base": 2.0, "ao_height": 1.6, "ao_strength": 0.7, "sway_amount": 0.002, "sway_start": 3.0},
		"tbp_bush": {"brightness": 0.95, "tint": Color(0.42, 0.52, 0.52), "value_variation": 0.18, "hue_variation": 0.04, "ao_base": 2.0, "ao_height": 0.6, "ao_strength": 0.55, "sway_amount": 0.05, "sway_start": 2.1, "sway_speed": 1.3},
		"tbp_bush_fg": {"brightness": 0.4, "tint": Color(0.42, 0.52, 0.52), "value_variation": 0.15, "ao_base": 2.0, "ao_height": 0.6, "ao_strength": 0.5, "sway_amount": 0.05, "sway_start": 2.1, "sway_speed": 1.1},
	}
	for key in tbp_defs:
		var path: String = MAT_DIR + "mat_%s.tres" % key
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("palette", tbp_pal)
		for p in tbp_defs[key]:
			m.set_shader_parameter(p, tbp_defs[key][p])
		ResourceSaver.save(m, path)
		_mats[key] = load(path)
	# Ruins materials that are shared by MultiMesh batches (headstones, grass).
	_mats["ruin_headstone"] = _ruin_mat(RUINS + "Fences/Slope.glb", "pale")
	_mats["ruin_grass"] = _ruin_mat(RUINS + "Moss/GroundMossXS.glb", "moss")
	# Far layers: own distance haze instead of scene fog (see voxel_palette_far.gdshader).
	var far_shader: Shader = load(BIOME + "shaders/voxel_palette_far.gdshader")
	var far_defs := {
		"cliff_far": {"brightness": 0.5, "haze_color": Color(0.21, 0.31, 0.37), "haze_density": 0.0045, "haze_max": 0.86, "peak_clarity": 0.28, "peak_height": 200.0},
		"ridge_far": {"brightness": 0.4, "haze_color": Color(0.19, 0.28, 0.33), "haze_density": 0.006, "haze_max": 0.82, "peak_clarity": 0.2, "peak_height": 30.0},
		"silhouette": {"brightness": 0.36, "haze_color": Color(0.19, 0.28, 0.33), "haze_density": 0.006, "haze_max": 0.8, "peak_clarity": 0.25, "peak_height": 40.0},
	}
	for key in far_defs:
		var path: String = MAT_DIR + "mat_%s.tres" % key
		var m := ShaderMaterial.new()
		m.shader = far_shader
		m.set_shader_parameter("palette", _palette("forest_dusk_palette"))
		for p in far_defs[key]:
			m.set_shader_parameter(p, far_defs[key][p])
		ResourceSaver.save(m, path)
		_mats[key] = load(path)
	var tsil := (_mats["silhouette"] as ShaderMaterial).duplicate() as ShaderMaterial
	tsil.set_shader_parameter("palette", tbp_pal)
	tsil.set_shader_parameter("brightness", 0.3)
	ResourceSaver.save(tsil, MAT_DIR + "mat_tbp_silhouette.tres")
	_mats["tbp_silhouette"] = load(MAT_DIR + "mat_tbp_silhouette.tres")

# ================================================================ environment resource
func _make_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(BIOME + "shaders/forest_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_color = Color(0.26, 0.40, 0.46)
	e.ambient_light_sky_contribution = 0.35
	e.ambient_light_energy = 0.6
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_strength = 1.0
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 0.9
	e.fog_enabled = true
	e.fog_light_color = Color(0.19, 0.29, 0.33)
	e.fog_light_energy = 1.0
	e.fog_density = 0.0075
	e.fog_aerial_perspective = 0.5
	e.fog_sky_affect = 0.15
	e.fog_height = -5.0
	e.fog_height_density = 0.12
	# Forward+ only extras (ignored by the Compatibility renderer).
	e.ssao_enabled = true
	e.ssao_radius = 1.5
	e.ssao_intensity = 1.6
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 0.95
	ResourceSaver.save(e, BIOME + "forest_environment.tres")

# ================================================================ terrain
func _corner_field(defs: Array, vx: int, vz: int) -> bool:
	var p := Vector2((vx + 0.5) * T, (vz + 0.5) * T)
	for d in defs:
		var q: Vector2 = (p - d["center"]) / d["radii"]
		if q.length() <= 1.0:
			return true
	return false

## Marching-squares tile choice. Returns [mesh_rel, rot] or [] when no corner is set.
## Base orientations of the pack (measured from renders):
##   inner: field in (-X,+Z) corner | outer: missing (+X,-Z) corner | side: field on +Z half.
func _transition_tile(defs: Array, i: int, j: int, prefix: String, full_tiles: Array) -> Array:
	var corners := {
		Vector2(-1, -1): _corner_field(defs, i - 1, j - 1), Vector2(1, -1): _corner_field(defs, i, j - 1),
		Vector2(1, 1): _corner_field(defs, i, j), Vector2(-1, 1): _corner_field(defs, i - 1, j),
	}
	var on := []
	var off := []
	for c in corners:
		if corners[c]:
			on.append(c)
		else:
			off.append(c)
	var v := rng.randi_range(1, 4)
	match on.size():
		0:
			return []
		4:
			return [_pick(full_tiles), _rot90()]
		1:
			return ["%s-rounded-edge-inner-%d.gltf" % [prefix, v], _find_rot([Vector2(-1, 1)], on)]
		3:
			return ["%s-rounded-edge-outer-%d.gltf" % [prefix, v], _find_rot([Vector2(1, -1)], off)]
		2:
			var s: Vector2 = (on[0] + on[1]) * 0.5
			if s.length() < 0.01: # diagonal corners: rare, fall back to an inner corner
				return ["%s-rounded-edge-inner-%d.gltf" % [prefix, v], _find_rot([Vector2(-1, 1)], [on[0]])]
			return ["%s-side-%d.gltf" % [prefix, v], _find_rot([Vector2(0, 1)], [s])]
	return []

func _build_ground() -> void:
	for i in range(-11, 12):
		for j in range(-3, 2):
			var pos := Vector3(i * T, GROUND_Y, j * T)
			var w := _transition_tile(PONDS, i, j, "ForestWater/forest-water", ["Water/water-1.gltf", "Water/water-2.gltf", "Water/water-3.gltf", "Water/water-4.gltf"])
			if not w.is_empty():
				_inst("Terrain/Ground", w[0], "ground" if not String(w[0]).begins_with("Water/") else "water", _xf(pos, w[1]), false)
				continue
			var d := _transition_tile(CLEARINGS, i, j, "ForestDirt/forest-dirt", ["Dirt/dirt-1.gltf", "Dirt/dirt-2.gltf", "Dirt/dirt-3.gltf", "Dirt/dirt-4.gltf"])
			if not d.is_empty():
				_inst("Terrain/Ground", d[0], "ground", _xf(pos, d[1]), false)
				continue
			var rel := "Forest/forest-%d.gltf" % rng.randi_range(1, 4)
			# Gentle voxel undulation outside the walkable belt (behind it and in the foreground strip).
			var flat_zone := (i * T > -76.0 and i * T < -40.0) or (i * T > 48.0 and i * T < 100.0)
			if (j <= -2 or j >= 1) and rng.randf() < 0.45 and not (j <= -2 and flat_zone):
				rel = "Forest/forest-uneven-side-%d.gltf" % rng.randi_range(1, 4)
			_inst("Terrain/Ground", rel, "ground", _xf(pos, _rot90()), false)
	# Valley floor far below the plateau: a cheap plane, hidden by canopy + mist.
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "ValleyFloor"
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 200)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.07, 0.12, 0.10)
	fm.roughness = 1.0
	floor_mi.material_override = fm
	floor_mi.position = Vector3(0, -12.8, -150)
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(_layer("Background/Valley"), floor_mi)
	# Ground skirt: a cheap plane just under the tile tops so a higher/wider camera never sees void.
	var skirt := MeshInstance3D.new()
	skirt.name = "GroundSkirt"
	var sp := PlaneMesh.new()
	sp.size = Vector2(700, 200)
	skirt.mesh = sp
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.11, 0.19, 0.15)
	sm.roughness = 1.0
	skirt.material_override = sm
	skirt.position = Vector3(0, -0.06, 60)
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(_layer("Terrain/Ground"), skirt)

func _path_dirs(c: Vector2i) -> Array:
	var out := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if PATH_CELLS.has(c + d):
			out.append(Vector2(d))
	return out

func _build_paths() -> void:
	for c in PATH_CELLS:
		var dirs := _path_dirs(c)
		var rel := ""
		var base := []
		var v := rng.randi_range(1, 4)
		match dirs.size():
			1:
				rel = "Paths/path-dead-end.gltf"; base = [Vector2(1, 0)]
			2:
				if (dirs[0] + dirs[1]).length() < 0.01:
					rel = "Paths/path-straight-%d.gltf" % v; base = [Vector2(1, 0), Vector2(-1, 0)]
				else:
					rel = "Paths/path-curve-%d.gltf" % v; base = [Vector2(1, 0), Vector2(0, 1)]
			3:
				rel = "Paths/path-3-way-crossing-%d.gltf" % rng.randi_range(1, 2); base = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]
			4:
				rel = "Paths/path-4-way-crossing-%d.gltf" % rng.randi_range(1, 2); base = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]
		# Path slabs are 0.1 units tall: sink them so only a ~0.18 m worn lip shows above the floor.
		_inst("Terrain/Paths", rel, "path", _xf(Vector3(c.x * T, -0.22, c.y * T), _find_rot(base, dirs)), false)

func _build_path_segments() -> void:
	for c in PATH_CELLS:
		for d in _path_dirs(c):
			var a := Vector2(c.x * T, c.y * T)
			_path_segments.append([a, a + d * T * 0.5])

func _dist_to_path(p: Vector2) -> float:
	var best := 1e9
	for s in _path_segments:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p))
	return best

func _in_field(defs: Array, p: Vector2, grow := 0.0) -> bool:
	for d in defs:
		# Corner ellipses produce roughly round patches of radius ~0.55 tile around each set corner.
		var r: Vector2 = d["radii"] + Vector2.ONE * (T * 0.55 + grow)
		if ((p - d["center"]) / r).length() <= 1.0:
			return true
	return false

func _blocked(p: Vector2, path_clear := 3.2, field_grow := 1.0) -> bool:
	if _dist_to_path(p) < path_clear:
		return true
	if _in_field(CLEARINGS, p, field_grow) or _in_field(PONDS, p, field_grow):
		return true
	for k in _keepouts:
		if p.distance_to(k["c"]) < k["r"]:
			return true
	return false

func _in_vista(x: float) -> bool:
	for w in VISTA_WINDOWS:
		if x > w.x and x < w.y:
			return true
	return false

# ================================================================ cliffs (left gate, right boundary)
func _crown(layer: String, center: Vector3, half: Vector2, count: int) -> void:
	# Dark trees growing on top of a rock block: breaks the flat cliff tops into a forest silhouette.
	for k in count:
		var p := center + Vector3(rng.randf_range(-half.x, half.x), 0, rng.randf_range(-half.y, half.y))
		_tree(layer, "canopy_edge", p, [4, 5, 6, 7], Vector2(0.9, 1.25), true, 1.2, 0.4)

func _build_cliffs() -> void:
	var L := "Terrain/Cliffs"
	var side := "Mountains/mountain-side-%d.gltf"
	var face_px := _find_rot([Vector2(0, 1)], [Vector2(1, 0)])   # side tile turned to face +X
	var face_nx := _find_rot([Vector2(0, 1)], [Vector2(-1, 0)])  # side tile turned to face -X
	var corner_pxpz := _find_rot([Vector2(-1, 0), Vector2(0, 1)], [Vector2(1, 0), Vector2(0, 1)])
	# LEFT WALL: a rock shelf stepping down toward the camera, each step crowned with trees.
	var tops := {-1: 1.0, 0: 0.8, 1: 0.6, 2: 0.45}
	for j in tops:
		var top: float = tops[j] * T
		_inst(L, side % rng.randi_range(1, 4), "cliff", _xf(Vector3(-9 * T, top - T, j * T), face_px))
		_inst(L, "Mountains/mountain-1.gltf", "cliff", _xf(Vector3(-10 * T, top - T + 2.5, j * T)))
		_crown(L, Vector3(-9 * T - 2.4, top, j * T), Vector2(2.5, 5.0), 2)
		_crown(L, Vector3(-10 * T, top + 2.5, j * T), Vector2(5.0, 5.0), 2)
	# HOLLOW GATE MASSIF around the cave (the cave itself is a landmark prop).
	_inst(L, side % 2, "cliff", _xf(Vector3(-9 * T, 0, -2 * T)))
	_inst(L, "Mountains/mountain-edge-outer-2.gltf", "cliff", _xf(Vector3(-7 * T, -0.25 * T, -2 * T), corner_pxpz))
	_inst(L, "Mountains/mountain-edge-outer-3.gltf", "cliff", _xf(Vector3(-6 * T, -0.55 * T, -3 * T), corner_pxpz))
	for i in [-10, -9, -8, -7]:
		_inst(L, "Mountains/mountain-1.gltf", "cliff", _xf(Vector3(i * T, 0.0 if i > -9 else 0.25 * T, -3 * T)))
	for i in [-10, -9, -8]:
		_inst(L, side % rng.randi_range(1, 4), "cliff", _xf(Vector3(i * T, 0.55 * T, -4 * T)))
	_inst(L, "Mountains/mountain-1.gltf", "cliff", _xf(Vector3(-10 * T, 0.25 * T, -2 * T)))
	_crown(L, Vector3(-8 * T, T, -2 * T - 4.0), Vector2(4.5, 2.5), 3)       # trees on the cave roof
	_crown(L, Vector3(-9 * T, T, -2 * T - 3.0), Vector2(4.5, 3.0), 2)
	_crown(L, Vector3(-7 * T + 1.5, 0.75 * T, -2 * T - 2.0), Vector2(3.5, 3.0), 2)
	_crown(L, Vector3(-6 * T + 1.5, 0.45 * T, -3 * T - 1.0), Vector2(3.5, 3.0), 2)
	_crown(L, Vector3(-8.5 * T, 1.25 * T, -3 * T), Vector2(9.0, 4.0), 4)
	_crown(L, Vector3(-9 * T, 1.55 * T, -4 * T - 2.0), Vector2(14.0, 3.0), 5)
	# RIGHT BOUNDARY: a broken rock spur half-buried in the forest wall.
	_inst(L, side % 3, "cliff", _xf(Vector3(10 * T, -0.35 * T, -1 * T), face_nx))
	_inst(L, side % 1, "cliff", _xf(Vector3(10 * T, -0.15 * T, -2 * T), face_nx))
	_inst(L, "Mountains/mountain-1.gltf", "cliff", _xf(Vector3(11 * T, -0.1 * T, -2 * T)))
	_inst(L, "Mountains/mountain-1.gltf", "cliff", _xf(Vector3(11 * T, -0.3 * T, -1 * T)))
	_crown(L, Vector3(10 * T + 2.0, 0.65 * T, -1 * T), Vector2(3.0, 5.0), 2)
	_crown(L, Vector3(10.5 * T, 0.85 * T, -2 * T), Vector2(6.0, 5.0), 3)

# ================================================================ landmarks
func _omni(parent: Node, name: String, pos: Vector3, color: Color, energy: float, rng_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = name
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.6
	l.shadow_enabled = false
	_add(parent, l)
	return l

func _landmark(name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	_add(_layer("Landmarks"), n)
	return n

func _build_landmarks() -> void:
	# 1. HOLLOW GATE - a cave mouth in the left cliff, lit from within by an ember glow. Spawn faces it.
	var gate := _landmark("HollowGate", Vector3(-8 * T, 0, -2 * T))
	_prop(gate, "Cave", "Mountains/mountain-cave.gltf", "cliff", _xf(Vector3(0, -0.1, 0)))
	_omni(gate, "EmberGlow", Vector3(0.5, 2.5, 1.5), Color(1.0, 0.52, 0.2), 4.0, 16.0)
	_prop(gate, "SkullLeft", "Bones/bones-1.gltf", "bone", _xf(Vector3(-3.5, 0, 6.8), 0.6))
	_prop(gate, "BoulderRight", "Stones/stone-5.gltf", "stone", _xf(Vector3(5.6, 0, 7.5), 0.3))
	_prop(gate, "BoulderSmall", "Stones/stone-3.gltf", "stone", _xf(Vector3(4.0, 0, 9.6), 1.1))
	_keepouts.append({"c": Vector2(-8 * T, -2 * T + 7), "r": 6.0})

	# 2. SPIRIT SHRINE - standing rune stones in an arc at the back of the moonlit clearing.
	#    Front half of the clearing stays empty: it is the arena (controlled negative space).
	var shrine := _landmark("SpiritShrine", Vector3(-19.2, 0, -6.4))
	var arc := [[-11.5, -3.2, "stone-6", 1.7], [-6.8, -6.6, "stone-5", 2.1], [0.0, -8.0, "stone-6", 2.5],
		[6.8, -6.6, "stone-5", 2.0], [11.5, -3.2, "stone-4", 1.6]]
	for k in arc.size():
		var a: Array = arc[k]
		var sc := Vector3(S * 0.8, S * a[3], S * 0.8)
		_prop(shrine, "Monolith%d" % (k + 1), "Stones/%s.gltf" % a[2], "rune_stone", _xf(Vector3(a[0], -0.2, a[1]), k * 1.3, sc))
		_colliders.append({"pos": Vector3(shrine.position.x + a[0], 0, shrine.position.z + a[1]), "radius": 2.2, "height": 5.0})
	_prop(shrine, "AltarStone", "Stones/stone-4.gltf", "stone", _xf(Vector3(0, -0.4, -4.2), 0.4, Vector3(S * 1.3, S * 0.55, S * 1.0)))
	_prop(shrine, "OfferingSkull", "Bones/bones-1.gltf", "bone", _xf(Vector3(0.2, 0.92, -4.3), 0.15, Vector3.ONE * S * 0.8))
	_prop(shrine, "ScatteredBones", "Bones/bones-3.gltf", "bone", _xf(Vector3(-4.0, 0, -1.5), 2.1))
	_omni(shrine, "SpiritLight", Vector3(0, 3.2, -4.0), Color(0.35, 0.95, 1.0), 1.6, 18.0)
	_colliders.append({"pos": Vector3(shrine.position.x, 0, shrine.position.z - 4.2), "radius": 2.6, "height": 2.0})

	# 3. ELDER TREE - the colossal ancient tree behind the shrine. Frames the clearing; readable silhouette.
	var elder := _landmark("ElderTree", Vector3(-24.0, 0, -31.0))
	_prop(elder, "Tree", TBP + "tree3.obj", "tbp_ancient", _xf(Vector3.ZERO, 0.0, Vector3(5.2, 6.0, 5.2)))
	for k in 5:
		var ang := k * TAU / 5.0 + 0.4
		_prop(elder, "Root%d" % (k + 1), "Wood/wood-2.gltf", "log", Transform3D(Basis(Vector3.UP, ang) * Basis(Vector3.FORWARD, 0.35) * Basis.from_scale(Vector3(S * 0.7, S * 1.3, S * 1.3)), Vector3(cos(ang) * 3.0, 0.2, sin(ang) * 3.0)))
	_prop(elder, "BushA", TBP + "bush3.obj", "tbp_bush", _xf(Vector3(4.5, 0, 3.0), 0.0, Vector3.ONE * 1.4))
	_prop(elder, "BushB", TBP + "bush2.obj", "tbp_bush", _xf(Vector3(-4.0, 0, 3.5), PI * 0.5, Vector3.ONE * 1.3))
	_keepouts.append({"c": Vector2(-24.0, -29.0), "r": 7.0})

	# 4. DROWNED GLADE - a black-mirror pond; a fallen trunk slides into the water.
	var glade := _landmark("DrownedGlade", Vector3(38.4, 0, -19.2))
	_fallen_tree(glade, "SunkenDeadTree", "Trees/tree-7.gltf", Vector3(-15.0, -0.4, 2.5), 0.35, 1.0)
	_prop(glade, "WaterStoneA", "Stones/stone-4.gltf", "stone", _xf(Vector3(6.0, -0.9, -1.0), 0.7))
	_prop(glade, "WaterStoneB", "Stones/stone-2.gltf", "stone", _xf(Vector3(9.0, -0.5, 1.5), 2.0))
	_prop(glade, "DrownedSkull", "Bones/bones-2.gltf", "bone", _xf(Vector3(-3.0, -0.3, -3.5), 1.2, Vector3.ONE * S * 0.9))
	for k in 7:
		var a := k * TAU / 7.0 + 0.3
		var p := Vector3(cos(a) * 19.0, 0, sin(a) * 9.5 - 1.0)
		if p.z > 3.5:
			continue
		_prop(glade, "Reeds%d" % (k + 1), "Bushes/bush-%d.gltf" % (1 + k % 3), "fern", _xf(p, k * 0.8, Vector3(S * 1.1, S * 1.6, S * 1.1)), false)
	_colliders.append({"pos": Vector3(38.4, 0, -19.2), "radius": 13.0, "height": 1.0, "box": Vector3(30.0, 1.0, 13.0)})

	# 5. BONE HOLLOW - the ribcage of something enormous, under cursed violet trees.
	var hollow := _landmark("BoneHollow", Vector3(70.4, 0, -6.4))
	_prop(hollow, "Ribcage", "Bones/bones-2.gltf", "bone", _xf(Vector3(1.0, -0.2, -8.0), 0.25, Vector3.ONE * S * 3.2))
	_prop(hollow, "GiantSkull", "Bones/bones-1.gltf", "bone", _xf(Vector3(-9.5, -0.2, -7.5), -0.4, Vector3.ONE * S * 2.4))
	_prop(hollow, "Femur", "Bones/bones-4.gltf", "bone", _xf(Vector3(8.5, 0, -2.5), 0.9, Vector3.ONE * S * 2.0))
	_prop(hollow, "Shard", "Bones/bones-3.gltf", "bone", _xf(Vector3(-4.0, 0, 1.5), 2.6))
	_omni(hollow, "CurseLight", Vector3(0, 4.0, -6.0), Color(0.7, 0.35, 1.0), 1.6, 16.0)
	_colliders.append({"pos": Vector3(71.4, 0, -14.4), "radius": 4.0, "height": 4.0})
	_colliders.append({"pos": Vector3(60.9, 0, -13.9), "radius": 2.6, "height": 3.0})
	_keepouts.append({"c": Vector2(71.0, -14.0), "r": 7.0})

	# 6. THE DARK EXIT - two leaning blighted giants form a gateway where the path is swallowed.
	var exit_ := _landmark("DarkExit", Vector3(9 * T, 0, -1 * T))
	_prop(exit_, "GateTreeNorth", TBP + "purple_tree3.obj", "tbp_blight", _xf(Vector3(-2.0, 0, -7.0), 0.0, Vector3(4.6, 4.8, 4.6)))
	_prop(exit_, "GateTreeSouth", TBP + "purple_tree1.obj", "tbp_blight", _xf(Vector3(0.5, 0, 7.5), PI * 0.5, Vector3(4.4, 4.4, 4.4)))
	_prop(exit_, "WarningBones", "Bones/bones-4.gltf", "bone", _xf(Vector3(-8.0, 0, 3.0), 2.4))
	_keepouts.append({"c": Vector2(9 * T, -1 * T), "r": 9.0})

	# Fallen trees / logs placed by hand along the route (environmental storytelling + framing).
	var logs := _layer("Landmarks")
	_fallen_tree(logs, "FallenDeadTreeWest", "Trees/tree-6.gltf", Vector3(-78.0, 0, -17.5), 0.12, 1.0)
	_fallen_tree(logs, "FallenDeadTreeEast", "Trees/tree-7.gltf", Vector3(102.0, 0, -18.5), -0.2, 0.95)
	_build_ruins()
	_prop(logs, "MossyLogFront", "Wood/wood-2.gltf", "log", Transform3D(Basis(Vector3.UP, 0.08) * Basis.from_scale(Vector3(S * 1.2, S * 1.4, S * 1.4)), Vector3(-44.0, 0.1, 11.5)), false)
	_prop(logs, "MossyLogFrontFerns", TBP + "bush3.obj", "tbp_bush_fg", _xf(Vector3(-40.0, 0, 11.0), 0.0, Vector3.ONE * 1.0), false)

func _fallen_tree(parent: Node, name: String, rel: String, pos: Vector3, yaw: float, size: float) -> void:
	# A tree tipped onto its side: trunk base on the ground, crown resting on the floor, dead palette.
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, deg_to_rad(-80.0)) * Basis.from_scale(Vector3.ONE * S * size)
	_prop(parent, name, rel, "deadwood", Transform3D(b, pos + Vector3(0, -0.7, 0)))
	_colliders.append({"pos": pos + Basis(Vector3.UP, yaw) * Vector3(4.0 * size, 0, 0), "radius": 2.5 * size, "height": 2.5})

# ================================================================ vegetation
const TREE_HEIGHTS := [0.5, 0.8, 1.0, 1.3, 1.5, 1.8, 2.2, 2.6] # unscaled heights of tree-1..8

func _in_spirit_zone(p: Vector3) -> bool:
	for z in SPIRIT_ZONES:
		if Vector2(p.x, p.z).distance_to(Vector2(z.x, z.y)) < z.z:
			return true
	return false

## Places a Tree & Bush pack tree. `sizes` are the layout's size classes (1-8, heights in TREE_HEIGHTS),
## so every grove keeps the art-directed silhouette while the mesh variant, width and rotation vary.
func _tree(layer: String, mat: String, p: Vector3, sizes: Array, scale_rng: Vector2, shadows := true, stretch := 1.0, tier_chance := 0.0) -> void:
	var t: int = _pick(sizes)
	var s := rng.randf_range(scale_rng.x, scale_rng.y) * S
	var target_h: float = TREE_HEIGHTS[t - 1] * s * rng.randf_range(1.0, stretch)
	var variant := "tree3" if t >= 7 or (t >= 5 and rng.randf() < 0.4) else ("tree1" if rng.randf() < 0.5 else "tree2")
	var prefix := ""
	var tmat: String = TBP_MAT.get(mat, mat)
	if mat == "blight":
		prefix = "purple_"
	elif (mat == "canopy" or mat == "canopy_edge") and p.z < -24.0 and _in_spirit_zone(p) and rng.randf() < 0.35:
		prefix = "blue_"
		tmat = "tbp_spirit"
	var k: float = target_h / TBP_TREE_H[variant]
	var w := k * rng.randf_range(0.85, 1.12)
	_inst(layer, TBP + prefix + variant + ".obj", tmat, _xf(p, _rot90() + rng.randf_range(-0.12, 0.12), Vector3(w, k, w)), shadows)
	# Occasional twin: a younger tree leaning into the crown of an older one -> irregular canopy line.
	if t >= 5 and rng.randf() < tier_chance * 0.6:
		var o := Vector3(rng.randf_range(-1.8, 1.8), 0, rng.randf_range(-1.8, 1.8))
		var k2 := k * rng.randf_range(0.55, 0.75)
		_inst(layer, TBP + prefix + ("tree1" if variant != "tree1" else "tree2") + ".obj", tmat, _xf(p + o, _rot90(), Vector3(k2, k2, k2)), shadows)
	if p.z > BELT_MIN.y - 6.0 and p.z < BELT_MAX.y + 3.0:
		_colliders.append({"pos": p, "radius": 0.12 * s + 0.25, "height": 3.0})

func _bush(layer: String, mat: String, p: Vector3, target_h: float, shadows := false) -> void:
	var b := "bush%d" % rng.randi_range(1, 3)
	var k: float = target_h / TBP_BUSH_H[b]
	_inst(layer, TBP + b + ".obj", mat, _xf(p, _rot90(), Vector3(k * rng.randf_range(0.9, 1.15), k, k * rng.randf_range(0.9, 1.15))), shadows)

func _undergrowth(layer: String, c: Vector3, count: int, radius: float, fern_bias := 0.7) -> void:
	for k in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var p := c + Vector3(cos(a) * d, 0, sin(a) * d)
		if _blocked(Vector2(p.x, p.z), 2.6, 0.0):
			continue
		var fern := rng.randf() < fern_bias
		var b := rng.randi_range(1, 3)
		var s := rng.randf_range(0.8, 1.3) * S
		if p.z > -12.0 and p.z < BELT_MAX.y + 3.0:
			b = 1
			s = rng.randf_range(0.4, 0.55) * S
			_inst(layer, "Bushes/bush-%d.gltf" % b, "fern", _xf(p, _rot90(), Vector3(s, s * rng.randf_range(0.9, 1.4), s)), false)
		elif fern:
			_bush(layer, "tbp_bush", p, rng.randf_range(1.4, 2.6))
		else:
			_inst(layer, "Bushes/bush-%d.gltf" % b, "bramble", _xf(p, _rot90(), Vector3(s, s * rng.randf_range(0.9, 1.4), s)), false)

func _build_forest_edge() -> void:
	# Clustered groves behind the belt (z -19 .. -44): one dominant tree, companions, undergrowth.
	# Vista windows stay low so the valley and mountains read through them.
	var L := "Vegetation/ForestEdge"
	var x := BELT_MIN.x - 30.0
	while x < BELT_MAX.x + 34.0:
		x += rng.randf_range(8.0, 13.0)
		for row in 3:
			var z := -21.0 - row * 8.5 + rng.randf_range(-3.0, 3.0)
			var c := Vector3(x + rng.randf_range(-4.0, 4.0) + row * 3.0, 0, z)
			if c.x < -96.0 and c.z > -36.0:
				continue # cave cliff
			if _blocked(Vector2(c.x, c.z), 4.0, 2.0):
				continue
			var vista := _in_vista(c.x)
			if vista and row < 2:
				_undergrowth(L, c, 4, 4.0, 0.6)
				continue
			_tree(L, "canopy_edge" if row > 0 else "canopy", c, [6, 7, 8] if not vista else [3, 4], Vector2(1.0, 1.35), row < 2, 1.2, 0.45 if not vista else 0.0)
			for k in rng.randi_range(1, 3):
				var o := Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-5, 4))
				if not _blocked(Vector2(c.x + o.x, c.z + o.z), 3.5, 1.0):
					_tree(L, "canopy_edge", c + o, [3, 4, 5, 6], Vector2(0.9, 1.25), row < 2, 1.2, 0.3)
			if row == 0:
				_undergrowth(L, c + Vector3(0, 0, 3.5), rng.randi_range(2, 4), 4.5, 0.75)
				if rng.randf() < 0.35:
					_inst(L, "Stones/stone-%d.gltf" % rng.randi_range(3, 5), "stone", _xf(c + Vector3(rng.randf_range(-4, 4), -0.1, 3.0), rng.randf() * TAU))
	# Blighted grove around the Bone Hollow and the exit: colour accent + sense of danger.
	for k in 9:
		var p := Vector3(rng.randf_range(54.0, 112.0), 0, rng.randf_range(-34.0, -19.0))
		if not _blocked(Vector2(p.x, p.z), 4.0, 1.0):
			_tree(L, "blight", p, [5, 6, 7], Vector2(1.0, 1.3), true, 1.3, 0.5)
	# Right forest wall (beyond the exit).
	for k in 26:
		var p := Vector3(rng.randf_range(106.0, 140.0), 0, rng.randf_range(-40.0, 16.0))
		if Vector2(p.x, p.z).distance_to(Vector2(9 * T, -1 * T)) < 7.0:
			continue
		_tree(L, "blight" if rng.randf() < 0.35 else "canopy_edge", p, [6, 7, 8], Vector2(1.1, 1.5), true, 1.3, 0.5)

func _build_playfield_dressing() -> void:
	var L := "Vegetation/Playfield"
	# Rhythm of ferns & pebbles along the path edges (alternating sides, never on the path itself).
	for s in _path_segments:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		for t in [0.25, 0.75]:
			if rng.randf() < 0.45:
				continue
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var p := a.lerp(b, t) + n * side * rng.randf_range(3.4, 5.0)
			if _blocked(p, 3.0, 0.0) or p.y < BELT_MIN.y or p.y > BELT_MAX.y + 2.0:
				continue
			# Inside the lane, anything in front of the path is capped at ~0.6 m so it never hides feet.
			var low := p.y > -12.0
			if rng.randf() < 0.65:
				var sc := (rng.randf_range(0.35, 0.45) if low else rng.randf_range(0.7, 1.0)) * S
				_inst(L, "Bushes/bush-%d.gltf" % rng.randi_range(1, 2), "fern", _xf(Vector3(p.x, 0, p.y), _rot90(), Vector3.ONE * sc), false)
			else:
				var sc := (0.7 if low else 1.0) * S
				_inst(L, "Stones/stone-1.gltf", "stone", _xf(Vector3(p.x, -0.05, p.y), rng.randf() * TAU, Vector3.ONE * sc), false)
	# Belt back margin (z -13 .. -18): small trees & brush that frame without blocking.
	var x := BELT_MIN.x
	while x < BELT_MAX.x:
		x += rng.randf_range(7.0, 12.0)
		var p := Vector3(x, 0, rng.randf_range(-18.0, -14.5))
		if _blocked(Vector2(p.x, p.z), 4.0, 1.5):
			continue
		if rng.randf() < 0.45:
			_tree(L, "canopy", p, [2, 3, 4], Vector2(0.9, 1.15), true, 1.15)
		_undergrowth(L, p, rng.randi_range(1, 3), 3.0, 0.7)
	# Shrine clearing edge stones and leaf-litter of small rocks.
	for k in 10:
		var a := rng.randf() * TAU
		var p := Vector2(-19.2, -6.4) + Vector2(cos(a) * rng.randf_range(15.0, 19.0), sin(a) * rng.randf_range(8.5, 10.0))
		if not _blocked(p, 3.0, -2.0) and p.y > BELT_MIN.y and p.y < BELT_MAX.y + 3.0:
			_inst(L, "Stones/stone-%d.gltf" % rng.randi_range(1, 3), "stone", _xf(Vector3(p.x, -0.05, p.y), rng.randf() * TAU), false)
	# Bone litter in the hollow.
	for k in 8:
		var p := Vector2(70.4, -6.4) + Vector2(rng.randf_range(-11, 11), rng.randf_range(-6, 5))
		if _dist_to_path(p) > 2.6:
			_inst(L, "Bones/bones-%d.gltf" % rng.randi_range(3, 4), "bone", _xf(Vector3(p.x, 0, p.y), rng.randf() * TAU), false)

func _build_foreground() -> void:
	# Foreground framing (z 10 .. 16): dark, low silhouettes (ferns, rocks, saplings) that crop
	# against the bottom of the frame. Height stays below the camera->lane sight line, so the
	# player's feet are never hidden even at the front edge of the lane.
	var L := "Vegetation/Foreground"
	var x := BELT_MIN.x - 20.0
	while x < BELT_MAX.x + 20.0:
		x += rng.randf_range(6.0, 11.0)
		var c := Vector3(x, 0, rng.randf_range(10.5, 13.5))
		for k in rng.randi_range(3, 6):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 3.6
			var p := c + Vector3(cos(a) * d, 0, sin(a) * d * 0.6)
			_bush(L, "tbp_bush_fg", p, rng.randf_range(0.9, 1.7))
		var r := rng.randf()
		if r < 0.3:
			_inst(L, "Stones/stone-%d.gltf" % rng.randi_range(3, 5), "stone_fg", _xf(c + Vector3(rng.randf_range(-2, 2), -0.3, 1.0), rng.randf() * TAU), false)
		elif r < 0.5:
			_tree(L, "canopy_fg", c + Vector3(rng.randf_range(-2, 2), 0, 3.0), [1, 2], Vector2(0.9, 1.1), false)

func _build_grass() -> void:
	# Grass/fern tufts break up the large ground tiles. Sparse in the lane centre, denser at the margins.
	var L := "Vegetation/Playfield"
	for k in 950:
		var p := Vector2(rng.randf_range(-120.0, 120.0), rng.randf_range(-34.0, 10.0))
		if _dist_to_path(p) < 1.8 or _in_field(CLEARINGS, p, -5.0) or _in_field(PONDS, p, -1.0):
			continue
		var lane := p.y > -12.0 and p.y < BELT_MAX.y + 2.0
		if lane and rng.randf() < 0.55:
			continue
		var sc := (rng.randf_range(0.25, 0.38) if lane else rng.randf_range(0.32, 0.55)) * S
		_inst(L, "Bushes/bush-%d.gltf" % rng.randi_range(1, 2), "fern", _xf(Vector3(p.x, 0, p.y), _rot90(), Vector3(sc, sc * rng.randf_range(0.8, 1.3), sc)), false)

func _build_valley() -> void:
	# The sea of canopy in the misty valley below the plateau. Cheap meshes, no shadows, darker grade.
	var L := "Background/Valley"
	var z := -48.0
	while z > -175.0:
		var step := lerpf(9.0, 14.0, inverse_lerp(-48.0, -175.0, z))
		var x := -210.0 + rng.randf_range(0.0, step)
		while x < 210.0:
			if rng.randf() < 0.84:
				var y := -12.8 + sin(x * 0.021 + z * 0.05) * 2.5 + rng.randf_range(-0.5, 0.5)
				var p := Vector3(x + rng.randf_range(-step, step) * 0.4, y, z + rng.randf_range(-step, step) * 0.4)
				_tree(L, "canopy_valley", p, [3, 4, 5, 6], Vector2(1.6, 2.6), false, 1.2)
			x += step
		z -= step * 0.85

func _build_far_background() -> void:
	# Parallax layers: these follow the camera on X by a factor so the far world never runs out.
	var parallax: Script = load(BIOME + "scripts/parallax_follow_3d.gd")
	var ridges := Node3D.new()
	ridges.name = "Ridges"
	ridges.set_script(parallax)
	ridges.set("follow_x", 0.35)
	_add(_layer("FarBackground"), ridges)
	var mountains := Node3D.new()
	mountains.name = "Mountains"
	mountains.set_script(parallax)
	mountains.set("follow_x", 0.8)
	_add(_layer("FarBackground"), mountains)
	_layers["FarBackground/Ridges"] = ridges
	_layers["FarBackground/Mountains"] = mountains

	# Forested ridges (~200 m): terraced voxel hills; every terrace is crowned with silhouette trees
	# so the skyline reads as forest on rolling hills rather than as blocks.
	var bs := S * 1.5
	var bt := 3.2 * bs
	var hx := -330.0
	while hx < 330.0:
		var levels := rng.randi_range(2, 4)
		var hz := -195.0 + rng.randf_range(-15.0, 15.0)
		for lv in levels:
			var width := levels - lv + 1
			for b in width:
				var bx := hx + (b - (width - 1) * 0.5) * bt * 0.9 + rng.randf_range(-3.0, 3.0)
				var top := -16.0 + (lv + 1) * 7.0 + rng.randf_range(-1.5, 1.5)
				var bz := hz - lv * 6.0
				_inst("FarBackground/Ridges", "Mountains/mountain-1.gltf", "ridge_far", _xf(Vector3(bx, top - bt, bz), 0.0, Vector3.ONE * bs), false)
				for k in 2:
					var tp := Vector3(bx + rng.randf_range(-bt * 0.4, bt * 0.4), top, bz + rng.randf_range(-bt * 0.4, bt * 0.4))
					_inst("FarBackground/Ridges", TBP + "tree%d.obj" % rng.randi_range(1, 3), "tbp_silhouette", _xf(tp, _rot90(), Vector3.ONE * rng.randf_range(4.0, 6.5)), false)
		hx += (levels + 1) * bt * 0.9 + rng.randf_range(5.0, 25.0)
	# Mountains (~470 m): stepped voxel massifs. Each peak is a pyramid of blocks whose levels narrow
	# upward and recede slightly, so the skyline steps like a voxel mountain instead of ending in flat slabs.
	var ms := S * 2.6
	var mt := 3.2 * ms
	var peaks := [[-440.0, 4], [-340.0, 6], [-240.0, 3], [-150.0, 7], [-45.0, 4], [50.0, 6], [150.0, 8], [265.0, 5], [360.0, 6], [450.0, 3]]
	for pk in peaks:
		var levels: int = pk[1]
		var pz := -470.0 + rng.randf_range(-35.0, 35.0)
		for lv in levels:
			var width := levels - lv
			for b in width:
				var bx: float = pk[0] + (b - (width - 1) * 0.5) * mt * 0.7 + rng.randf_range(-6.0, 6.0)
				var by := -30.0 + lv * mt * 0.62 - rng.randf_range(0.0, 6.0)
				var top := lv == levels - 1
				var rel := "Mountains/mountain-1.gltf"
				if top or rng.randf() < 0.35:
					rel = "Mountains/mountain-edge-outer-%d.gltf" % rng.randi_range(1, 4) if rng.randf() < 0.5 else "Mountains/mountain-side-%d.gltf" % rng.randi_range(1, 4)
				_inst("FarBackground/Mountains", rel, "cliff_far", _xf(Vector3(bx, by, pz - lv * 9.0), _rot90(), Vector3.ONE * ms), false)

# ================================================================ atmosphere
func _mist_card(parent: Node, name: String, pos: Vector3, size: Vector2, color: Color, density: float, near_fade := 14.0) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load(BIOME + "shaders/mist_card.gdshader")
	m.set_shader_parameter("mist_color", color)
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("near_fade_distance", near_fade)
	m.set_shader_parameter("noise_scale", size.x / 120.0 + 1.5)
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, mi)

func _particle_box(name: String, pos: Vector3, extents: Vector3, amount: int, color: Color, size: float, vel: Vector2, up: float, lifetime: float, energy: float) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = name
	gp.position = pos
	gp.amount = amount
	gp.lifetime = lifetime
	gp.preprocess = lifetime
	gp.randomness = 0.6
	gp.visibility_aabb = AABB(-extents - Vector3.ONE * 4.0, (extents + Vector3.ONE * 4.0) * 2.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = Vector3(0, up, 0)
	pm.damping_min = 0.05
	pm.damping_max = 0.2
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0); ramp.set_color(0, Color(color, 0.0))
	ramp.set_offset(1, 1.0); ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.25, Color(color, 1.0))
	ramp.add_point(0.7, Color(color, 0.8))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	gp.process_material = pm
	var box := BoxMesh.new() # voxel-shaped motes keep the art style consistent
	box.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	box.material = mat
	gp.draw_pass_1 = box
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(_layer("Atmosphere/Particles"), gp)
	return gp

func _light_shaft(name: String, pos: Vector3, height: float, width: float, color: Color, intensity: float, tilt: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = name
	holder.position = pos
	holder.rotation = tilt
	_add(_layer("Atmosphere/LightShafts"), holder)
	var m := ShaderMaterial.new()
	m.shader = load(BIOME + "shaders/light_shaft.gdshader")
	m.set_shader_parameter("shaft_color", color)
	m.set_shader_parameter("intensity", intensity)
	var mi := MeshInstance3D.new()
	mi.name = "Shaft"
	var q := QuadMesh.new()
	q.size = Vector2(width, height)
	mi.mesh = q
	mi.material_override = m
	mi.position = Vector3(0, height * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-height, -height, -height), Vector3.ONE * height * 2.0)
	_add(holder, mi)

func _build_atmosphere() -> void:
	var A := _layer("Atmosphere")
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = load(BIOME + "forest_environment.tres")
	_add(A, we)

	var key := DirectionalLight3D.new()
	key.name = "MoonKey"
	key.rotation_degrees = Vector3(-42, -32, 0)    # from front-left, so faces toward the camera are lit
	key.light_color = Color(0.78, 0.86, 1.0)
	key.light_energy = 1.05
	key.shadow_enabled = true
	key.shadow_opacity = 0.82
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 90.0
	key.directional_shadow_blend_splits = true
	key.light_angular_distance = 0.6
	_add(A, key)
	var rim := DirectionalLight3D.new()
	rim.name = "MoonRim"
	rim.rotation_degrees = Vector3(-22, 165, 0)    # from behind (where the moon hangs): cyan rim on silhouettes
	rim.light_color = Color(0.45, 0.85, 0.95)
	rim.light_energy = 0.55
	rim.shadow_enabled = false
	rim.light_specular = 0.8
	_add(A, rim)

	var M := _layer("Atmosphere/Mist")
	_mist_card(M, "BeltBackMist", Vector3(0, 1.6, -21.5), Vector2(300, 4.5), Color(0.50, 0.66, 0.70), 0.22, 10.0)
	_mist_card(M, "PlateauEdgeMist", Vector3(0, -1.0, -44.0), Vector2(420, 11), Color(0.45, 0.60, 0.65), 0.45)
	_mist_card(M, "ValleyMistNear", Vector3(0, -7.0, -70.0), Vector2(520, 16), Color(0.42, 0.57, 0.62), 0.55)
	_mist_card(M, "ValleyMistFar", Vector3(0, -4.0, -130.0), Vector2(640, 22), Color(0.40, 0.54, 0.60), 0.6)
	var ridges: Node3D = _layers["FarBackground/Ridges"]
	_mist_card(ridges, "RidgeMist", Vector3(0, 2.0, -205.0), Vector2(800, 40), Color(0.36, 0.50, 0.56), 0.55)
	var mountains: Node3D = _layers["FarBackground/Mountains"]
	_mist_card(mountains, "MountainBaseMist", Vector3(0, 10.0, -400.0), Vector2(1400, 90), Color(0.33, 0.46, 0.52), 0.65)

	_particle_box("Fireflies", Vector3(0, 2.2, -5.0), Vector3(110, 2.0, 16), 160, Color(0.8, 1.0, 0.45), 0.09, Vector2(0.15, 0.45), 0.0, 7.0, 4.0)
	_particle_box("ShrineWisps", Vector3(-19.2, 1.5, -10.0), Vector3(9, 1.2, 4), 36, Color(0.4, 0.95, 1.0), 0.13, Vector2(0.05, 0.2), 0.25, 6.0, 5.0)
	_particle_box("CaveEmbers", Vector3(-8 * T + 0.5, 1.0, -2 * T + 3.5), Vector3(2.0, 0.5, 1.5), 18, Color(1.0, 0.55, 0.2), 0.08, Vector2(0.1, 0.4), 0.5, 4.0, 5.0)
	_particle_box("CryptEmbers", Vector3(7 * T, 4.0, -26.2), Vector3(3.2, 0.4, 0.4), 22, Color(1.0, 0.55, 0.2), 0.08, Vector2(0.1, 0.35), 0.6, 3.0, 6.0)
	_particle_box("GraveWisps", Vector3(-57.0, 1.4, -23.0), Vector3(10.0, 1.0, 4.0), 22, Color(0.5, 1.0, 0.8), 0.12, Vector2(0.05, 0.2), 0.2, 6.0, 4.5)
	_particle_box("CurseMotes", Vector3(70.4, 1.5, -12.0), Vector3(10, 1.5, 4), 26, Color(0.75, 0.4, 1.0), 0.1, Vector2(0.05, 0.25), 0.15, 6.0, 4.0)

	_light_shaft("ShrineMoonShaft", Vector3(-19.2, 0, -10.5), 40.0, 7.0, Color(0.55, 0.85, 0.92), 0.08, Vector3(deg_to_rad(-20), 0, deg_to_rad(16)))

# ================================================================ collision & markers
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "ForestCollision"
	_add(_layer("Collision"), body)
	var ground := CollisionShape3D.new()
	ground.name = "Ground"
	var gb := BoxShape3D.new()
	gb.size = Vector3(T * 22, 2.0, T * 6)
	ground.shape = gb
	ground.position = Vector3(0, -1.0, -T)
	_add(body, ground)
	# Lane boundaries (thin invisible walls).
	var walls := {
		"WallBack": [Vector3(0, 3, BELT_MIN.y - 0.5), Vector3(BELT_MAX.x - BELT_MIN.x, 6, 1)],
		"WallFront": [Vector3(0, 3, BELT_MAX.y + 0.5), Vector3(BELT_MAX.x - BELT_MIN.x, 6, 1)],
		"WallLeft": [Vector3(BELT_MIN.x - 0.5, 3, (BELT_MIN.y + BELT_MAX.y) * 0.5), Vector3(1, 6, BELT_MAX.y - BELT_MIN.y)],
		"WallRight": [Vector3(BELT_MAX.x + 0.5, 3, (BELT_MIN.y + BELT_MAX.y) * 0.5), Vector3(1, 6, BELT_MAX.y - BELT_MIN.y)],
	}
	for n in walls:
		var cs := CollisionShape3D.new()
		cs.name = n
		var b := BoxShape3D.new()
		b.size = walls[n][1]
		cs.shape = b
		cs.position = walls[n][0]
		_add(body, cs)
	# Obstacles inside / at the edge of the lane: tree trunks, monoliths, pond, ribcage.
	var k := 0
	for c in _colliders:
		var p: Vector3 = c["pos"]
		if p.x < BELT_MIN.x - 2 or p.x > BELT_MAX.x + 2 or p.z < BELT_MIN.y - c["radius"] or p.z > BELT_MAX.y + c["radius"]:
			continue
		var cs := CollisionShape3D.new()
		k += 1
		cs.name = "Obstacle%d" % k
		if c.has("box"):
			var bx := BoxShape3D.new()
			bx.size = c["box"]
			cs.shape = bx
		else:
			var cy := CylinderShape3D.new()
			cy.radius = c["radius"]
			cy.height = c["height"]
			cs.shape = cy
		cs.position = p + Vector3(0, c["height"] * 0.5, 0)
		_add(body, cs)

func _build_markers() -> void:
	var m := _layer("Markers")
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(-88.0, 0, 1.0)
	_add(m, spawn)
	var shrine := Marker3D.new()
	shrine.name = "ArenaShrineCenter"
	shrine.position = Vector3(-19.2, 0, -3.0)
	_add(m, shrine)
	var hollow := Marker3D.new()
	hollow.name = "ArenaBoneHollowCenter"
	hollow.position = Vector3(70.4, 0, -2.0)
	_add(m, hollow)
	var bounds := Marker3D.new()
	bounds.name = "LaneMin"
	bounds.position = Vector3(BELT_MIN.x, 0, BELT_MIN.y)
	_add(m, bounds)
	var bounds2 := Marker3D.new()
	bounds2.name = "LaneMax"
	bounds2.position = Vector3(BELT_MAX.x, 0, BELT_MAX.y)
	_add(m, bounds2)

# ================================================================ ruins, graveyard & crypt (Ruins GLB pack)
## Places one Ruins-pack piece as an editable MeshInstance3D. kind: stone | pale | moss | bone.
func _ruin(parent: Node, name: String, file: String, xf: Transform3D, kind := "stone", shadows := true) -> MeshInstance3D:
	var rel := RUINS + file + ".glb"
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = _mesh(rel)
	mi.material_override = _ruin_mat(rel, kind)
	mi.transform = xf
	# Background ruins skip the shadow pass: they sit in shade/fog and are the heaviest meshes (web budget).
	if parent.name in ["SunkenTemple", "SealedCrypt", "DrownedBridge", "ForgottenGraveyard"] and not name.begins_with("Rail") and not name.begins_with("Obelisk"):
		shadows = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, mi)
	return mi

## Ruins pieces each carry their own small texture; it is fed to the shared voxel shader so the
## stone gets the same grading, per-instance variation and contact darkening as the rest of the biome.
func _ruin_mat(rel: String, kind: String) -> Material:
	var key := "ruin_%s_%s" % [kind, rel.get_file().get_basename().to_lower()]
	if _mats.has(key):
		return _mats[key]
	var src: Material = _mesh(rel).surface_get_material(0)
	var tex: Texture2D = (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
	var params := {
		"stone": {"brightness": 0.62, "tint": Color(0.86, 0.95, 1.0), "value_variation": 0.08, "ao_height": 2.2, "ao_strength": 0.5, "roughness_value": 0.9, "specular_value": 0.15},
		"pale": {"brightness": 0.5, "tint": Color(0.84, 0.93, 0.98), "value_variation": 0.12, "ao_height": 0.7, "ao_strength": 0.5, "roughness_value": 0.85},
		"moss": {"brightness": 0.62, "tint": Color(0.62, 0.82, 0.76), "value_variation": 0.12, "ao_strength": 0.0, "sway_amount": 0.01, "sway_start": 0.0},
		"bone": {"brightness": 0.5, "tint": Color(0.92, 0.95, 0.95), "value_variation": 0.06, "ao_height": 0.8, "ao_strength": 0.5, "roughness_value": 0.7},
	}
	var m := ShaderMaterial.new()
	m.shader = load(BIOME + "shaders/voxel_palette.gdshader")
	m.set_shader_parameter("palette", tex)
	for p in params[kind]:
		m.set_shader_parameter(p, params[kind][p])
	var path := MAT_DIR + "ruins/" + key + ".tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR + "ruins/"))
	ResourceSaver.save(m, path)
	_mats[key] = load(path)
	return _mats[key]

func _rx(pos: Vector3, yaw := 0.0, s := 1.0, tilt := Vector2.ZERO) -> Transform3D:
	# Ruins pieces are authored at ~1 unit = 1 m, so they use scale 1 by default.
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt.x) * Basis(Vector3.BACK, tilt.y) * Basis.from_scale(Vector3.ONE * s)
	return Transform3D(b, pos)

const ALONG_X := PI * 0.5 # walls/fences/gate are authored running along Z; this turns them to run along X

func _build_ruins() -> void:
	# A. RUINED OUTER GATE at the spawn: the path from the cave passes under the remains of an old gate.
	var og := _landmark("RuinedOuterGate", Vector3(-102.4, 0, -17.6))
	_ruin(og, "Gate", "Walls/Gate", _rx(Vector3.ZERO, ALONG_X))
	_ruin(og, "WallStubWest", "Walls/WallEnd", _rx(Vector3(-5.6, 0, 0.2), ALONG_X))
	_ruin(og, "WallBrokenEast", "Walls/WallBrokenMD", _rx(Vector3(6.6, 0, 0.3), ALONG_X))
	_ruin(og, "RubbleEast", "Walls/WallBrokenXS", _rx(Vector3(12.2, -0.2, 1.0), ALONG_X + 0.2))
	_ruin(og, "VinesGate", "Moss/MossMD", _rx(Vector3(1.6, 4.4, 0.7)), "moss", false)
	_ruin(og, "VinesWall", "Moss/MossXL", _rx(Vector3(5.0, 0.5, 0.75)), "moss", false)
	_ruin(og, "GrassA", "Moss/GroundMossMD", _rx(Vector3(-3.2, 0, 1.4), 0.4), "moss", false)
	_ruin(og, "GrassB", "Moss/GroundMossXS", _rx(Vector3(3.4, 0, 1.2), 1.1), "moss", false)
	_keepouts.append({"c": Vector2(-98.0, -17.6), "r": 7.0})

	# B. FORGOTTEN GRAVEYARD behind the Whispering Path: broken railings, leaning headstones in loose
	#    rows, two obelisks, a ruined chapel wall with a lantern. Sits in the vista window so it reads.
	var gy := _landmark("ForgottenGraveyard", Vector3(-57.0, 0, -22.6))
	var front := [-10.0, -7.2, -4.4, 0.0, 4.4, 7.2, 10.0]  # gap in the middle = the old entrance
	for k in front.size():
		var fx: float = front[k]
		if k == 5:
			_ruin(gy, "RailBroken%d" % k, "Fences/Line", _rx(Vector3(fx, 0, 6.0), ALONG_X + 0.12, 1.0, Vector2(0.0, 0.08)), "pale")
		else:
			_ruin(gy, "Rail%d" % k, "Fences/Fence", _rx(Vector3(fx, 0, 6.0), ALONG_X + rng.randf_range(-0.04, 0.04)), "pale")
	_ruin(gy, "RailCornerW", "Fences/CornerTight", _rx(Vector3(-12.4, 0, 6.0)), "pale")
	_ruin(gy, "RailCornerE", "Fences/CornerTight", _rx(Vector3(12.4, 0, 6.0), PI * 0.5), "pale")
	for k in 3:
		if k != 1:
			_ruin(gy, "RailWest%d" % k, "Fences/Fence", _rx(Vector3(-12.4, 0, 3.0 - k * 2.8), rng.randf_range(-0.05, 0.05)), "pale")
		_ruin(gy, "RailEast%d" % k, "Fences/Fence", _rx(Vector3(12.4, 0, 3.0 - k * 2.8), rng.randf_range(-0.05, 0.05), 1.0, Vector2(0.0, -0.1 if k == 2 else 0.0)), "pale")
	# Headstones: loose rows, uneven spacing, every stone leans a little differently; a few are missing.
	var gi := 0
	for row in 3:
		var hz := 3.2 - row * 2.9
		var hx := -10.2 + rng.randf_range(0.0, 1.0)
		while hx < 10.5:
			if rng.randf() > 0.22 and absf(hx) > 1.2:
				var tilt := Vector2(rng.randf_range(-0.16, 0.12), rng.randf_range(-0.14, 0.14))
				var sc := rng.randf_range(1.0, 1.3)
				var xf := _rx(Vector3(hx + rng.randf_range(-0.3, 0.3), -rng.randf_range(0.05, 0.3), hz + rng.randf_range(-0.3, 0.3)), PI * 0.5 + rng.randf_range(-0.25, 0.25), sc, tilt)
				_inst("Landmarks/GraveyardHeadstones", RUINS + "Fences/Slope.glb", "ruin_headstone", Transform3D(xf.basis, gy.position + xf.origin), true)
				gi += 1
				if rng.randf() < 0.35:
					_inst("Landmarks/GraveyardHeadstones", RUINS + "Moss/GroundMossXS.glb", "ruin_grass", _xf(gy.position + Vector3(hx + rng.randf_range(-0.9, 0.9), 0, hz + 0.6), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.6, 0.9)), false)
			hx += rng.randf_range(2.2, 3.1)
	_ruin(gy, "ObeliskWest", "Accessories/Altar", _rx(Vector3(-5.5, 0, -4.6), 0.3, 2.0), "pale")
	_ruin(gy, "ObeliskEast", "Accessories/Altar", _rx(Vector3(5.2, 0, -1.4), 1.0, 1.7, Vector2(0.06, 0.0)), "pale")
	_ruin(gy, "ChapelWall", "Walls/WallBrokenMD", _rx(Vector3(-2.0, 0, -7.4), ALONG_X))
	_ruin(gy, "ChapelWallEnd", "Walls/WallEnd2", _rx(Vector3(5.4, 0, -7.0), ALONG_X - 0.15))
	_ruin(gy, "ChapelVines", "Moss/MossXL", _rx(Vector3(-4.0, 0.4, -6.75)), "moss", false)
	_ruin(gy, "Lantern", "Accessories/WallLight", _rx(Vector3(0.8, 2.3, -6.75)), "stone", false)
	_ruin(gy, "SkullOnGrave", "Accessories/SkullCracked", _rx(Vector3(-7.6, -0.05, 3.9), 0.6, 0.32), "bone")
	_ruin(gy, "SkullByObelisk", "Accessories/Skull", _rx(Vector3(-4.4, -0.05, -3.4), -0.5, 0.28), "bone")
	for k in 6:
		_ruin(gy, "OvergrowthGrass%d" % k, "Moss/GroundMossMD", _rx(Vector3(rng.randf_range(-11.5, 11.5), 0, rng.randf_range(-6.0, 5.4)), rng.randf() * TAU, rng.randf_range(0.7, 1.0)), "moss", false)
	_omni(gy, "GhostLantern", Vector3(0.8, 2.9, -5.6), Color(0.5, 1.0, 0.82), 2.0, 15.0)
	_keepouts.append({"c": Vector2(-57.0, -22.0), "r": 13.5})

	# C. SHRINE COLUMNS: two surviving columns of an older temple flank the rune circle (outside the lane).
	var sc_ := _landmark("ShrineColumns", Vector3(-19.2, 0, -18.4))
	_ruin(sc_, "ColumnWest", "Pillars/PillarRound", _rx(Vector3(-14.6, 0, 0.0), 0.2))
	_ruin(sc_, "ColumnEastBroken", "Pillars/PillarRoundCut", _rx(Vector3(14.2, 0, 0.4), 1.1, 1.0, Vector2(0.0, 0.05)))
	_ruin(sc_, "ColumnWestVines", "Moss/MossMD", _rx(Vector3(-14.6, 4.3, 0.85)), "moss", false)
	_ruin(sc_, "FallenDrum", "Pillars/PillarRoundCut", Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3.ONE * 0.75), Vector3(10.0, 0.6, 1.4)))

	# D. DROWNED GLADE: an old stair-bridge sinks into the pond; wall stubs at the far shore.
	var gl := _landmark("DrownedBridge", Vector3(38.4, 0, -23.0))
	_ruin(gl, "StairBridge", "Stairs/StairBridge", _rx(Vector3(0, -0.55, 0), ALONG_X + 0.08))
	_ruin(gl, "ShoreWallWest", "Walls/WallBrokenXS", _rx(Vector3(-11.0, -0.3, -3.6), ALONG_X - 0.2))
	_ruin(gl, "ShoreWallEast", "Walls/WallBrokenXS", _rx(Vector3(11.5, -0.3, -3.0), ALONG_X + 0.25))
	_ruin(gl, "BridgeVines", "Moss/MossMD", _rx(Vector3(2.0, -0.5, 1.2)), "moss", false)

	# E. SUNKEN TEMPLE: a colonnade on a mossy plinth deep in the background, behind the Bone Hollow.
	var tp := _landmark("SunkenTemple", Vector3(61.0, 0, -37.0))
	for k in 3:
		_ruin(tp, "Plinth%d" % k, "Blocks/BlockMossMD", _rx(Vector3(-6.9 + k * 6.9, 0, 0), 0.0, 1.0))
	_ruin(tp, "Steps", "Stairs/StairsXL", _rx(Vector3(0, 0, 4.9), 0.0, 1.0))
	var cols := [["Pillars/PillarSquare", -8.2], ["Pillars/PillarRound", -3.0], ["Pillars/PillarRoundCut", 2.6], ["Pillars/PillarSquareCut", 8.0]]
	for k in cols.size():
		_ruin(tp, "Column%d" % k, cols[k][0], _rx(Vector3(cols[k][1], 2.0, 1.6), k * 0.4))
	_ruin(tp, "BackWall", "Walls/WallBrokenXl", _rx(Vector3(-4.0, 2.0, -2.6), ALONG_X))
	_ruin(tp, "BackWallEnd", "Walls/WallEnd2", _rx(Vector3(5.2, 2.0, -2.4), ALONG_X + 0.1))
	_ruin(tp, "TempleVinesA", "Moss/MossXL", _rx(Vector3(-6.0, 4.0, -1.9)), "moss", false)
	_ruin(tp, "TempleVinesB", "Moss/MossMD", _rx(Vector3(-8.2, 5.2, 2.6)), "moss", false)
	_ruin(tp, "TempleGrassA", "Moss/GroundMossMD", _rx(Vector3(-9.5, 2.0, 2.8), 0.5), "moss", false)
	_ruin(tp, "TempleGrassB", "Moss/GroundMossXL", _rx(Vector3(9.4, 2.0, -1.0), 2.0), "moss", false)
	_keepouts.append({"c": Vector2(61.0, -36.0), "r": 13.0})

	# F. THE SEALED CRYPT (dungeon-inspired): the path ends at a torch-lit gate sealed into a ruined facade.
	var cr := _landmark("SealedCrypt", Vector3(7 * T, 0, -27.6))
	_ruin(cr, "Gate", "Walls/Gate", _rx(Vector3.ZERO, ALONG_X))
	_ruin(cr, "Seal", "Walls/WallNormalXL", _rx(Vector3(0, 0, -1.3), ALONG_X))
	_ruin(cr, "FacadeWest", "Walls/WallNormalXL", _rx(Vector3(-6.6, 0, -0.3), ALONG_X))
	_ruin(cr, "FacadeEast", "Walls/WallBrokenXl", _rx(Vector3(6.6, 0, -0.3), ALONG_X))
	_ruin(cr, "FacadeEndWest", "Walls/WallEnd2", _rx(Vector3(-11.6, 0, 0.4), ALONG_X + 0.3))
	_ruin(cr, "GuardColumnWest", "Pillars/PillarSquareCut", _rx(Vector3(-4.0, 0, 1.9), 0.0))
	_ruin(cr, "GuardColumnEast", "Pillars/PillarSquareCut", _rx(Vector3(4.0, 0, 1.9), PI * 0.5))
	_ruin(cr, "Steps", "Stairs/StairsMD", _rx(Vector3(0, 0, 2.6), 0.0))
	_ruin(cr, "SconceWest", "Accessories/WallLight", _rx(Vector3(-2.6, 3.2, 0.7), 0.0, 1.4), "stone", false)
	_ruin(cr, "SconceEast", "Accessories/WallLight", _rx(Vector3(2.6, 3.2, 0.7), 0.0, 1.4), "stone", false)
	_ruin(cr, "CryptVines", "Moss/MossXL", _rx(Vector3(-7.5, 1.2, 0.6)), "moss", false)
	_ruin(cr, "GuardianSkull", "Accessories/Skull", _rx(Vector3(-2.8, 0, 4.4), 0.5, 0.36), "bone")
	_ruin(cr, "CrackedSkull", "Accessories/SkullCracked", _rx(Vector3(3.2, 0, 4.9), -0.7, 0.3), "bone")
	for k in 4:
		_ruin(cr, "CryptGrass%d" % k, "Moss/GroundMossMD", _rx(Vector3([-8.0, -5.5, 6.0, 9.0][k], 0, 1.6 + k * 0.4), k * 1.7, 0.85), "moss", false)
	_omni(cr, "TorchGlow", Vector3(0, 2.8, 1.6), Color(1.0, 0.5, 0.18), 7.0, 16.0)
	_keepouts.append({"c": Vector2(7 * T, -27.0), "r": 13.5})
