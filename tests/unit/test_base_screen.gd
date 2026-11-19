extends GutTest
## Long menus must scroll by finger (Godot's own touch scrolling is off here) and keep the way out.

class LongScreen extends BaseScreen:
	func build() -> void:
		add_title("Long")
		for i in 30:
			add_button("Item %d" % i, Callable())
		add_pinned_button("Back", Callable())


var _s: LongScreen


func before_all() -> void:
	RealWindow.use(self)


func before_each() -> void:
	_s = LongScreen.new()
	_s.size = Vector2(1280, 720)
	add_child_autofree(_s)
	await wait_frames(3)


func test_overflowing_screen_scrolls_on_drag() -> void:
	assert_true(_s.has_overflow())
	var start := _s._scroll.scroll_vertical
	var t := InputEventScreenTouch.new(); t.pressed = true; t.position = Vector2(640, 500)
	Input.parse_input_event(t)
	var d := InputEventScreenDrag.new(); d.position = Vector2(640, 300); d.relative = Vector2(0, -200)
	Input.parse_input_event(d)
	await wait_frames(2)
	assert_gt(_s._scroll.scroll_vertical, start, "a finger drag scrolls the menu")


func test_pinned_button_is_outside_the_scroller() -> void:
	var back: Button = null
	for b in _s.buttons():
		if b.text == "Back":
			back = b
	assert_not_null(back)
	assert_false(_s._scroll.is_ancestor_of(back), "the way out can never scroll off-screen")
