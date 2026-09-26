shader_type canvas_item;

uniform sampler2D grass_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.965, 0.627, 0.412, 1.0);
uniform float tiles_x : hint_range(1.0, 40.0) = 16.0;
uniform float tiles_y : hint_range(1.0, 40.0) = 11.0;
uniform float wind_speed : hint_range(0.0, 2.0) = 0.4;
uniform float wind_strength_px : hint_range(0.0, 8.0) = 1.5;
uniform float wind_scale : hint_range(2.0, 60.0) = 14.0;
uniform float texture_mix : hint_range(0.0, 1.0) = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 tex_px = vec2(textureSize(grass_tex, 0));
	vec2 tiled = UV * vec2(tiles_x, tiles_y);
	vec2 local_px = floor(fract(tiled) * tex_px);
	vec2 world_px = floor(tiled * tex_px);

	float t = TIME * wind_speed;
	float gust = value_noise(world_px / wind_scale + vec2(t * 1.1, t * 0.25)) * 2.0 - 1.0;
	float offset_x = round(gust * wind_strength_px);
	float offset_y = round(sin(t * 0.9 + world_px.x * 0.02) * wind_strength_px * 0.35);
	vec2 sample_local = mod(local_px + vec2(offset_x, offset_y) + tex_px, tex_px);

	vec4 grass = texture(grass_tex, (sample_local + 0.5) / tex_px);
	vec3 soft = mix(base_color.rgb, grass.rgb, texture_mix);
	COLOR = vec4(soft, 1.0);
}
