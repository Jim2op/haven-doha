@tool
extends EditorScript
## Rebuild from the editor: open this file in the Script editor and use File > Run (Ctrl+Shift+X).
## Overwrites only res://environment/forest_biome/forest_biome.tscn and its generated resources.
func _run() -> void:
	var builder = load("res://environment/forest_biome/tools/forest_biome_builder.gd").new()
	if builder.build() == OK:
		EditorInterface.get_resource_filesystem().scan()
		print("Forest biome rebuilt.")
