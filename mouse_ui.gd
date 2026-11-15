extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().node_added.connect(_on_node_added)
	_hook_tree(get_tree().root)


func _hook_tree(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_tree(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton or node is Range:
		var c := node as Control
		if not c.mouse_entered.is_connected(_on_hover.bind(c)):
			c.mouse_entered.connect(_on_hover.bind(c))
	if node is CanvasItem and (node as Node).name in ["PauseRoot", "EndRoot"]:
		var ci := node as CanvasItem
		if not ci.visibility_changed.is_connected(_on_menu_visibility.bind(ci)):
			ci.visibility_changed.connect(_on_menu_visibility.bind(ci))


func _on_hover(c: Control) -> void:
	if c.focus_mode != Control.FOCUS_NONE and c.is_visible_in_tree() and not (c is BaseButton and c.disabled):
		c.grab_focus()


func _on_menu_visibility(ci: CanvasItem) -> void:
	if ci.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
