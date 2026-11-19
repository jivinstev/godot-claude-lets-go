extends Autoplay
## The template's own end-to-end check: title → Play → placeholder → Back → title.

func run() -> void:
	await goto("res://scenes/title_screen.tscn")
	await wait(1.0)
	await tap_button("Play")
	await wait(1.0)
	check(scene().scene_file_path == "res://scenes/game.tscn", "Play opens scenes/game.tscn")
	await tap_button("Back")
	await wait(1.0)
	check(scene().scene_file_path == "res://scenes/title_screen.tscn", "Back returns to the title")
