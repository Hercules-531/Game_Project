#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform readonly image2D source_image;
layout(rgba16f, set = 0, binding = 1) uniform writeonly image2D target_image;
layout(push_constant, std430) uniform Params {
	vec2 size;
	float phase;
	float pass_index;
	float dither;
	float chroma;
	float grain;
	float levels;
} params;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + params.phase * 1.731) * 43758.5453);
}

void main() {
	ivec2 p = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.size);
	if (any(greaterThanEqual(p, size))) { return; }
	vec4 original = imageLoad(source_image, p);
	if (params.pass_index < 0.5) {
		imageStore(target_image, p, original);
		return;
	}
	vec3 color = original.rgb;
	int direction = p.x < size.x / 2 ? -1 : 1;
	ivec2 red_p = clamp(p + ivec2(direction, 0), ivec2(0), size - 1);
	ivec2 blue_p = clamp(p - ivec2(direction, 0), ivec2(0), size - 1);
	float edge = abs(float(p.x) / params.size.x * 2.0 - 1.0);
	color.r = mix(color.r, imageLoad(source_image, red_p).r, params.chroma * edge);
	color.b = mix(color.b, imageLoad(source_image, blue_p).b, params.chroma * edge);
	// Quantize perceptual brightness, then return to the linear HDR buffer.
	color = pow(max(color, vec3(0.0)), vec3(1.0 / 2.2));
	const int bayer[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	float threshold = (float(bayer[(p.y % 4) * 4 + p.x % 4]) + 0.5) / 16.0 - 0.5;
	if (params.dither > 0.0) {
		color = floor(color * params.levels + 0.5 + threshold * params.dither) / params.levels;
	}
	color += (noise(vec2(p)) - 0.5) * params.grain;
	color = pow(max(color, vec3(0.0)), vec3(2.2));
	imageStore(target_image, p, vec4(color, original.a));
}
