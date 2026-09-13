extends RefCounted
## Shared material factory for all world meshes. Surface art stays in Textures/.

const SURFACE_SHADER = preload("res://shaders/ps1_surface.gdshader")


static func make_surface(color: Color, texture: Texture2D = null,
		uv_scale: Vector2 = Vector2.ONE, emission: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("uv_scale", uv_scale)
	material.set_shader_parameter("emission_strength", emission)
	if texture != null:
		assert(texture.resource_path.begins_with("res://Textures/"), "Unverified texture source")
		assert(maxi(texture.get_width(), texture.get_height()) <= 64, "Surface texture exceeds 64px")
		assert(not texture.get_image().has_mipmaps(), "Surface texture has mipmaps")
		material.set_shader_parameter("surface_texture", texture)
		material.set_shader_parameter("use_texture", true)
	return material


static func apply_tree(root: Node) -> void:
	if root is MeshInstance3D and root.mesh != null:
		for index in root.mesh.get_surface_count():
			var source: Material = root.get_active_material(index)
			if source is ShaderMaterial:
				continue
			var color := Color.WHITE
			var texture: Texture2D
			if source is StandardMaterial3D:
				color = source.albedo_color
				texture = source.albedo_texture
			root.set_surface_override_material(index, make_surface(color, texture))
		root.material_override = null
	for child in root.get_children():
		apply_tree(child)
