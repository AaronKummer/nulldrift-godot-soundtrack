extends Node

## One-shot screenshot tool — loads a scene, waits N frames, writes PNG to
## res://_renders/, quits. Used for verifying lighting/composition before
## handing off to a human.
##
## Usage:
##   godot --path . res://scenes/_capture.tscn -- <scene_path> <out_name>
## Example:
##   godot --path . res://scenes/_capture.tscn -- res://scenes/title.tscn title
## Optional extras after <out_name>:
##   with_phone [app]   open the phone overlay before the shot
##   at <x,z>           teleport the scene's player there first (streets etc.)

const WAIT_FRAMES := 45

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/title.tscn"
	var out_name := args[1] if args.size() > 1 else "render"

	# Optional "flag <name>" / "item <id>" pairs anywhere in the args:
	# set story flags / grant items before the scene builds
	for i in range(2, args.size() - 1):
		if args[i] == "flag":
			GameState.set_flag(args[i + 1])
		elif args[i] == "item":
			GameState.add_item(args[i + 1])
		elif args[i] == "equip":
			GameState.add_item(args[i + 1])
			if not GameState.equip_weapon(args[i + 1]):
				GameState.toggle_gear(args[i + 1])
		elif args[i] == "dungeon":
			GameState.pending_dungeon = args[i + 1]
		elif args[i] == "floor":
			GameState.dungeon_floor = int(args[i + 1])
		elif args[i] == "phonelight":
			GameState.phone_light = args[i + 1] == "on"
		elif args[i] == "skill":
			GameState.hack_skill = int(args[i + 1])
		elif args[i] == "vohlfloor":
			GameState.vohl_floor = int(args[i + 1])
		elif args[i] == "heat":
			GameState.heat = float(args[i + 1])

	var packed := load(scene_path) as PackedScene
	if packed == null:
		printerr("Failed to load scene: ", scene_path)
		get_tree().quit(1)
		return
	var inst := packed.instantiate()
	add_child(inst)

	# Optional: teleport the player so the camera settles on a specific spot
	var at_i := args.find("at")
	if at_i >= 2 and at_i + 1 < args.size():
		await RenderingServer.frame_post_draw
		var parts := (args[at_i + 1] as String).split(",")
		if parts.size() == 2:
			var player := _find_player(inst)
			if player:
				player.global_position = Vector3(parts[0].to_float(), 0.9,
					parts[1].to_float())

	# Optional "copshot": force a pursuing cop into frame near the player so a
	# static render shows the police chase (they otherwise spawn on a timer).
	if args.has("copshot") and inst.has_method("_spawn_cop"):
		await RenderingServer.frame_post_draw
		inst._spawn_cop()
		var pl := _find_player(inst)
		if pl and not inst._cops.is_empty():
			inst._cops[0].node.position = pl.global_position + Vector3(7.0, 0, 3.0)

	# Optional "siege": go loud + stage a firefight (guards hostile + the laser
	# bot in frame) so a static render shows the combat.
	if args.has("siege") and "_siege" in inst and inst._siege != null:
		await RenderingServer.frame_post_draw
		inst._siege.go_loud()
		var pl2 := _find_player(inst)
		if pl2:
			inst._siege.debug_spawn("laser_bot", pl2.global_position + Vector3(5.0, 0, 2.0))
			inst._siege.debug_spawn("ninja", pl2.global_position + Vector3(-4.0, 0, 3.0))

	# Let the renderer settle (bloom + emissive prepass)
	for i in range(WAIT_FRAMES):
		await RenderingServer.frame_post_draw

	# Optional 3rd arg: open the phone overlay before the final shot.
	# A 5th arg opens a specific MSGS conversation and waits out the
	# typing reveal (e.g. ... with_phone messages Nyx).
	var hk_i := args.find("hack")
	if hk_i >= 2:
		var hk := get_node_or_null("/root/HackOverlay")
		if hk:
			hk.open(int(args[hk_i + 1]) if hk_i + 1 < args.size() else 1, true)
			for j in range(6):
				await RenderingServer.frame_post_draw
	var net_i := args.find("net")
	if net_i >= 2:
		var no := get_node_or_null("/root/NetOverlay")
		if no:
			no.open(args[net_i + 1] if net_i + 1 < args.size() else "atm_branch")
			# Optional "crack N" — auto-crack N reachable nodes to show a
			# populated, pivoted graph instead of just the entry node.
			var cr_i := args.find("crack")
			if cr_i >= 2 and cr_i + 1 < args.size():
				var steps := int(args[cr_i + 1])
				for s in range(steps):
					await RenderingServer.frame_post_draw
					var target := -1
					for n in no._net.revealed_nodes():
						if no._net.can_attempt(n.uid):
							target = n.uid
							break
					if target < 0:
						break
					no._on_node_pressed(target)
			for j in range(8):
				await RenderingServer.frame_post_draw
	var wp_i := args.find("with_phone")
	if wp_i >= 2:
		var phone := get_node_or_null("/root/Phone")
		if phone:
			phone.open(args[wp_i + 1] if wp_i + 1 < args.size() else "home")
			if wp_i + 2 < args.size() and phone.has_method("_open_convo"):
				await RenderingServer.frame_post_draw
				phone._open_convo(args[wp_i + 2])
				await get_tree().create_timer(9.0).timeout
		for j in range(10):
			await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	# HDR-2D viewports hand back linear float data — convert or the PNG
	# reads far darker than the live window.
	if get_viewport().use_hdr_2d:
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
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

func _find_player(root: Node) -> CharacterBody3D:
	if root is CharacterBody3D:
		return root
	for child in root.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null
