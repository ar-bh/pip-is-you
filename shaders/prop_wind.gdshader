shader_type canvas_item;

uniform float wind_speed : hint_range(0.0, 3.0) = 0.75;
uniform float wind_strength : hint_range(0.0, 0.16) = 0.055;
uniform float gust_scale : hint_range(0.5, 8.0) = 2.4;
uniform float phase : hint_range(0.0, 6.28318) = 0.0;
uniform float height_power : hint_range(0.2, 2.0) = 1.0;

void vertex() {
	float t = TIME * wind_speed + phase;
	float sway = sin(t) * 0.55 + sin(t * gust_scale + 1.7) * 0.30 + sin(t * 0.37 + 0.9) * 0.15;
	float height = pow(clamp(1.0 - UV.y, 0.0, 1.0), height_power);
	VERTEX.x += sway * wind_strength * height * 96.0;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
}
