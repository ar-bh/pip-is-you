shader_type canvas_item;

uniform float wind_speed : hint_range(0.0, 3.0) = 0.55;
uniform float wind_strength : hint_range(0.0, 0.08) = 0.025;
uniform float gust_scale : hint_range(0.5, 8.0) = 2.4;
uniform float phase : hint_range(0.0, 6.28318) = 0.0;

void vertex() {
	float t = TIME * wind_speed + phase;
	float sway = sin(t) * 0.65 + sin(t * gust_scale + 1.7) * 0.35;
	float height = 1.0 - UV.y;
	VERTEX.x += sway * wind_strength * height * 64.0;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
}
