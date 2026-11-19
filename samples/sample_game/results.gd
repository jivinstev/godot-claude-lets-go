extends BaseScreen
## Orb Run's end screen. Reads OrbRun.last_result.

const ORB_RUN := preload("res://samples/sample_game/orb_run.gd")


func build() -> void:
	var r: Dictionary = ORB_RUN.last_result
	var won: bool = r.get("won", false)
	add_title("You got them all!" if won else "Time's up")
	add_text("Orbs %d / %d   ·   %.1f s" % [r.get("collected", 0), ORB_RUN.GOAL, r.get("time", 0.0)])
	var best: float = r.get("best", 0.0)
	if r.get("new_best", false):
		add_text("New best time!", false, 30)
	elif best > 0.0:
		add_text("Best time %.1f s" % best, true)
	add_spacer(12)
	add_button("Play again", func(): goto("res://samples/sample_game/orb_run.tscn"))
	add_button("Back to samples", on_cancel)


func on_cancel() -> void:
	goto("res://samples/samples_menu.tscn")
