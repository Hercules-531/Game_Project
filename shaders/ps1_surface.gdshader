shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D surface_texture : source_color, filter_nearest, repeat_enable;
uniform bool use_texture = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform bool box_projection = false;
uniform float emission_strength : hint_range(0.0, 8.0) = 0.0;
// Diagnostic switches; production materials retain both requirements enabled.
uniform bool vertex_snap = true;
uniform bool affine_mapping = true;
uniform vec2 snap_resolution = vec2(320.0, 240.0);
varying vec3 affine_uv;

void vertex() {
	if (box_projection) {
		vec3 n = abs(NORMAL);
		UV = n.y > 0.5 ? VERTEX.xz * 0.5 : (n.x > 0.5 ? VERTEX.zy * 0.5 : VERTEX.xy * 0.5);
	}
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Do not divide near/behind the eye. Clipping still uses the original Z/W.
	if (vertex_snap && clip.w > 0.001 && !IN_SHADOW_PASS) {
		vec2 pixel = (clip.xy / clip.w * 0.5 + 0.5) * snap_resolution;
		clip.xy = ((floor(pixel + 0.5) / snap_resolution) * 2.0 - 1.0) * clip.w;
	}
	POSITION = clip;
	// Cancels the rasterizer's reciprocal-W weighting in fragment().
	affine_uv = vec3(UV * uv_scale * clip.w, clip.w);
}

void fragment() {
	vec2 surface_uv = UV * uv_scale;
	if (affine_mapping && abs(affine_uv.z) > 0.00001) {
		surface_uv = affine_uv.xy / affine_uv.z;
	}
	vec3 color = tint.rgb;
	if (use_texture) {
		color *= texture(surface_texture, surface_uv).rgb;
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = color * emission_strength;
}
