extends Node2D

# Only impassable mountain faces enter the entity depth order. Walkable ground
# stays below units, so a unit's own cell cannot cover its feet. Each original
# triangle is split into four coplanar pieces for more precise depth sorting.
const FOG_SHADER = preload("res://scripts/world/terrain_occlusion.gdshader")
var shared_material: ShaderMaterial
var pieces: Array[MeshInstance2D] = []

func rebuild(groups: Dictionary, white: Texture2D, fog_texture: Texture2D) -> void:
	if shared_material == null:
		shared_material = ShaderMaterial.new()
		shared_material.shader = FOG_SHADER
	set_fog(fog_texture)
	var depths: Array = groups.keys()
	depths.sort()
	for index in depths.size():
		if index == pieces.size():
			var piece := MeshInstance2D.new()
			piece.z_as_relative = false
			piece.material = shared_material
			piece.texture = white
			add_child(piece)
			pieces.append(piece)
		var piece := pieces[index]
		piece.z_index = depths[index]
		piece.mesh = groups[depths[index]].finish()
		piece.show()
	for index in range(depths.size(), pieces.size()):
		pieces[index].hide()
		pieces[index].mesh = null
	show()

func set_fog(texture: Texture2D) -> void:
	if shared_material == null: return
	shared_material.set_shader_parameter("fog_enabled", texture != null)
	shared_material.set_shader_parameter("visibility_mask", texture)
