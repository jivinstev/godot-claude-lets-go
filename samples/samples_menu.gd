extends BaseScreen
## Working examples of each building block. Delete samples/ to remove them all; the title
## screen's "Samples" button disappears with it.


func build() -> void:
	add_title("Samples")
	add_text("Each one is small, self-contained and covered by tests and a verification demo.", true)
	add_button("Orb Run — a tiny game", func(): goto("res://samples/cutscene/intro_cutscene.tscn"))
	add_button("Touch control layouts", func(): goto("res://samples/touch_layouts/touch_layouts.tscn"))
	add_button("3D scene", func(): goto("res://samples/scene_3d/scene_3d.tscn"))
	add_pinned_button("Back", on_cancel)


func on_cancel() -> void:
	goto("res://scenes/title_screen.tscn")
