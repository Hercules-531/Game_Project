shader_type canvas_item;
uniform float frame_tick = 0.0;
uniform float interference = 0.0;
uniform float lens_efficiency = 1.0;
uniform bool clean_feed = false;

float noise(vec2 p) {
	return fract(sin(dot(p,vec2(12.9898,78.233)) + frame_tick * 0.713) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 resolution = vec2(240.0,180.0) * min(lens_efficiency,1.0);
	uv = floor(uv * resolution) / resolution;
	float static_noise = noise(floor(uv * vec2(240.0,180.0)));
	uv.x += (noise(vec2(floor(uv.y * 180.0),1.0)) - 0.5) * interference * 0.04;
	vec3 image = texture(TEXTURE,uv).rgb;
	float luma = dot(image,vec3(0.299,0.587,0.114));
	// Suppressed shadows, blown highlights and scanline/static loss are feed-only.
	float signal = pow(max(luma - 0.06,0.0),1.4) * 1.6;
	signal += smoothstep(0.55,0.9,luma) * 0.3;
	float scanline = mod(floor(uv.y * 180.0),2.0) < 1.0 ? 0.68 : 1.0;
	signal = signal * scanline + (static_noise - 0.5) * (0.16 / max(lens_efficiency,0.1) + interference * 0.4);
	COLOR = vec4(vec3(clamp(signal,0.0,1.0)),1.0);
	if (clean_feed) COLOR = texture(TEXTURE,UV);
}
