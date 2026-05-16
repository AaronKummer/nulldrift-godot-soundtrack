extends Node

## One-shot screenshot tool — loads a scene, waits N frames, writes PNG to
## res://_renders/, quits. Used for verifying lighting/composition before
## handing off to a human.
##
## Usage:
##   godot --path . res://scenes/_capture.tscn -- <scene_path> <out_name>
## Example:
##   godot --path . res://scenes/_capture.tscn -- res://scenes/title.tscn title

const WAIT_FRAMES := 45

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/title.tscn"
	var out_name := args[1] if args.size() > 1 else "render"

	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("Failed to load scene: ", scene_path)
		get_tree().quit(1)
		return
	var inst := packed.instantiate()
	add_child(inst)

	# Let the renderer settle (bloom + emissive prepass)
	for i in range(WAIT_FRAMES):
		await RenderingServer.frame_post_draw

	# Optional 3rd arg: open the phone overlay before the final shot
	if args.size() > 2 and args[2] == "with_phone":
		var phone := get_node_or_null("/root/Phone")
		if phone:
			phone.open(args[3] if args.size() > 3 else "home")
		for j in range(10):
			await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var dir := "res://_renders"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out_path := "%s/%s.png" % [dir, out_name]
	var err := img.save_png(out_path)
	if err != OK:
		printerr("Failed to save PNG: ", err)
		get_tree().quit(1)
		return
	print("Saved: ", ProjectSettings.globalize_path(out_path))
	get_tree().quit(0)
