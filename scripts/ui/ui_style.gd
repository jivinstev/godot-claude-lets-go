class_name UiStyle
## The look of every menu in one place. Change these and every screen follows.
## Fonts are SIL OFL (licences next to them in assets/fonts/), so they can ship commercially.

const FONT_DISPLAY := preload("res://assets/fonts/Anton-Regular.ttf")
const FONT_BODY := preload("res://assets/fonts/Oswald-Variable.ttf")

const BG := Color(0.07, 0.08, 0.16)
const TITLE := Color(1.0, 0.8, 0.2)
const TEXT := Color(0.93, 0.93, 0.96)
const DIM := Color(0.62, 0.64, 0.72)
const ACCENT := Color(0.35, 0.75, 1.0)

const TITLE_SIZE := 64
const TEXT_SIZE := 24
const BUTTON_SIZE := 28
## Big enough for a thumb: Android's guideline is 48dp minimum; this is comfortably over.
const BUTTON_MIN := Vector2(420, 60)


static func style_button(b: Button, font_size: int = BUTTON_SIZE) -> void:
	b.add_theme_font_override(&"font", FONT_BODY)
	b.add_theme_font_size_override(&"font_size", font_size)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		match state:
			"normal": sb.bg_color = Color(1, 1, 1, 0.08)
			"hover": sb.bg_color = Color(1, 1, 1, 0.16)
			"pressed": sb.bg_color = ACCENT.darkened(0.3)
			"focus":
				sb.bg_color = Color(0, 0, 0, 0)
				sb.draw_center = false
				sb.set_border_width_all(3)
				sb.border_color = ACCENT
			"disabled": sb.bg_color = Color(1, 1, 1, 0.03)
		b.add_theme_stylebox_override(state, sb)
