extends BaseScreen
## THE STARTING POINT. Rename the title, point "Play" at your game, delete what you don't need.
##
## "Samples" only appears while samples/ exists — delete that folder and it disappears.

const GAME_SCENE := "res://scenes/game.tscn"
const SAMPLES_MENU := "res://samples/samples_menu.tscn"


func build() -> void:
	add_spacer(20)
	add_title(ProjectSettings.get_setting("application/config/name", "My Game"))
	add_text("Built with Godot + Claude Code", true)
	add_spacer(24)
	add_button("Play", func(): goto(GAME_SCENE))
	if ResourceLoader.exists(SAMPLES_MENU):
		add_button("Samples", func(): goto(SAMPLES_MENU))
	if OS.get_name() != "Web" and OS.get_name() != "iOS":
		add_button("Quit", SceneDirector.quit)
