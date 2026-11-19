extends Autoplay
## The other two samples, through real input: cycle the touch layouts by tapping, press the
## on-screen A in each and watch the action fire; then walk the 3D character with the stick and
## wave.
##   tools/verify.sh samples-tour res://samples/samples_tour_demo.tscn --touch-sim --frames 900

func run() -> void:
	await goto("res://samples/samples_menu.tscn")
	await wait(0.6)
	await tap_button("Touch control layouts")
	await wait(0.8)
	for i in 4:
		var name: String = TouchControls.Layout.keys()[TouchControls.layout]
		var a: Array = TouchControls.controls().filter(func(c): return c.label == "A")
		if check(a.size() == 1, "%s has an A button" % name):
			_touch(a[0].center, true)
			await wait_frames(3)
			check(Input.is_action_pressed("action_a"), "%s: tapping A fires action_a" % name)
			_touch(a[0].center, false)
			_mark(a[0].center)
		await wait(0.9)
		if i < 3:
			await tap_button("Next layout")
			await wait(0.4)
	await tap_button("Back")
	await wait(0.8)
	await tap_button("3D scene")
	await wait(1.0)
	var s := scene()
	check(s != null and s.name == "Scene3D", "the 3D scene opens")
	var start: Vector3 = s.character.position
	await stick(Vector2(0.0, -1.0), 1.6)
	await stick(Vector2(1.0, 0.0), 1.2)
	check(s.character.position.distance_to(start) > 3.0, "the stick walks the character (%.1f m)" % s.character.position.distance_to(start))
	await wait(0.4)
	await press("action_a")
	await wait(0.3)
	check(s.anim.current_animation.ends_with("Wave"), "A plays the wave animation")
	await wait(1.5)
