extends SceneTree
## Headless rebuild:  godot --headless --path . -s res://environment/forest_biome/tools/build_forest_biome_cli.gd
func _initialize() -> void:
	var builder = load("res://environment/forest_biome/tools/forest_biome_builder.gd").new()
	var err: int = builder.build()
	quit(0 if err == OK else 1)
