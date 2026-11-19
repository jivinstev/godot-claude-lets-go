class_name RealWindow
## Headless Godot opens a 64x64 window and stretches the 1280x720 viewport over it, so a touch
## event at viewport coordinates lands 20x off target and "nothing responds". Any test that pushes
## touch/mouse positions through Input must call this first.

static func use(node: Node, size: Vector2i = Vector2i(1280, 720)) -> void:
	node.get_window().size = size
	node.get_window().content_scale_size = size
