## NPCSpawner — static helper. Reads NPCs.for_scene(scene_id, flags) and
## instantiates a billboard sprite (or color cube fallback) per NPC. Registers
## each interactable NPC with the Interaction autoload so the prompt + E-key
## flow is automatic.
##
## NPCs themselves still live in res://data/npcs.gd. This class just turns
## that data into nodes.
class_name NPCSpawner
extends Object

static func spawn_for_scene(root: Node3D, scene_id: String, flags: Dictionary) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	for npc in NPCs.for_scene(scene_id, flags):
		var node := _spawn_one(root, npc)
		spawned.append(node)
		if npc.get("interactable", false):
			Interaction.register(
				"npc:" + npc["id"],
				npc["position"] + Vector3(0, 0.3, 0),
				npc.get("interact_radius", 1.5),
				npc.get("prompt", "[E] TALK"),
				{ "action": "talk", "dialogue_id": npc.get("dialogue_id", npc["id"]) })
	return spawned

static func _spawn_one(root: Node3D, npc: Dictionary) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = npc["position"]
	root.add_child(pivot)

	var sprite_path: String = npc.get("sprite", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var sprite := Sprite3D.new()
		sprite.texture = load(sprite_path)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.04
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		sprite.scale = Vector3.ONE * npc.get("scale", 0.55)
		pivot.add_child(sprite)
	else:
		# Fallback: tinted cube. Lets the NPC exist visually until a sprite
		# is hooked up. Color comes from the npc def so each character is
		# still readable.
		var mesh := BoxMesh.new()
		var size: float = 0.6 * float(npc.get("scale", 1.0))
		mesh.size = Vector3(size, size * 1.4, size)
		var mat := StandardMaterial3D.new()
		var color: Color = npc.get("color", Color(0.8, 0.8, 0.8))
		mat.albedo_color = color
		mat.metallic = 0.0
		mat.roughness = 0.4
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.5
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(0, mesh.size.y / 2.0, 0)
		pivot.add_child(mi)
	return pivot
