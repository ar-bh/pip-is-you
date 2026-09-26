shader_type canvas_item;

// Soft wind streaks that sweep across the whole screen.

uniform float speed : hint_range(0.1, 4.0) = 1.35;
uniform float density : hint_range(2.0, 40.0) = 14.0;
uniform float opacity : hint_range(0.0, 0.5) = 0.14;
uniform vec4 streak_color : source_color = vec4(1.0, 0.92, 0.72, 1.0);

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// Two diagonal bands at different speeds so it feels like layered wind.
	float a = fract((uv.x * 0.85 + uv.y * 1.25) * density - t);
	float b = fract((uv.x * 1.1 - uv.y * 0.6) * (density * 0.55) - t * 0.65);
	float streak_a = smoothstep(0.0, 0.05, a) * (1.0 - smoothstep(0.05, 0.18, a));
	float streak_b = smoothstep(0.0, 0.04, b) * (1.0 - smoothstep(0.04, 0.14, b));
	float streak = max(streak_a, streak_b * 0.65);

	// Fade a bit at the edges so UI corners stay readable.
	float edge = smoothstep(0.0, 0.08, uv.x) * smoothstep(0.0, 0.08, uv.y)
			* smoothstep(0.0, 0.08, 1.0 - uv.x) * smoothstep(0.0, 0.08, 1.0 - uv.y);

	COLOR = vec4(streak_color.rgb, streak * opacity * edge);
}
