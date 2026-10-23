shader_type spatial;
render_mode unshaded;
uniform sampler2D surface_texture : source_color, filter_nearest, repeat_enable;
uniform int roof_count = 0;
uniform vec4 roof_rects[16];
uniform vec4 roof_planes[16];
varying vec3 world_at;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	for (int i=0; i<16; i++) {
		if (i>=roof_count) break;
		vec4 r = roof_rects[i];
		if (world_at.x>=r.x && world_at.x<=r.z && world_at.z>=r.y && world_at.z<=r.w && world_at.y<=roof_planes[i].x*world_at.x+roof_planes[i].y) discard;
	}
	ALBEDO = texture(surface_texture,UV).rgb*vec3(0.48,0.54,0.49);
}
