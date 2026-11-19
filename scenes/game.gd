extends BaseScreen
## Placeholder for YOUR game. Ask Claude to replace this scene — see README → Starter prompts.


func build() -> void:
	add_title("Your game goes here")
	add_text("This is scenes/game.tscn. Replace it with your gameplay, or open the samples from the title screen to see working examples.", true)
	add_pinned_button("Back", on_cancel)


func on_cancel() -> void:
	goto("res://scenes/title_screen.tscn")
