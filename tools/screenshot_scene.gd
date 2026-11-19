extends Node
## Load a scene, let it run N frames, save the viewport as a PNG, quit. Use via tools/render.sh shot.
## Args after `--`: <scene res:// path> <out.png> [settle_frames]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var target := args[0] if args.size() > 0 else "res://scenes/title_screen.tscn"
	var out := args[1] if args.size() > 1 else "user://shot.png"
	var settle := int(args[2]) if args.size() > 2 else 40
	if OS.get_environment("TOUCH_SIM") == "1":
		TouchControls.simulate_touchscreen(true)
	var packed: PackedScene = load(target)
	if packed == null:
		push_error("screenshot: cannot load %s" % target)
		get_tree().quit(1)
		return
	# Become the current scene's sibling, then hand the scene over so it behaves as if run directly.
	var inst := packed.instantiate()
	get_tree().root.add_child.call_deferred(inst)
	await get_tree().process_frame
	get_tree().current_scene = inst
	for i in maxi(1, settle):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT_RESULT target=%s err=%d size=%s out=%s" % [target, err, img.get_size(), out])
	get_tree().quit(0 if err == OK else 1)
