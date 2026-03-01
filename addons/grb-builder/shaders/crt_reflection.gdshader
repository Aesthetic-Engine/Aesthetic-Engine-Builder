shader_type canvas_item;

// CRT Glass Reflection — subtle animated highlight simulating light on curved glass.
// Rendered as overlay above screen content. Keep opacity low (3-10%).

uniform float u_time = 0.0;
uniform float opacity : hint_range(0.0, 0.25) = 0.045;
uniform float drift_speed : hint_range(0.001, 0.1) = 0.012;
uniform float highlight_size : hint_range(0.1, 1.0) = 0.4;
uniform float highlight_softness : hint_range(0.1, 2.0) = 0.8;


float noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = noise(i);
	float b = noise(i + vec2(1.0, 0.0));
	float c = noise(i + vec2(0.0, 1.0));
	float d = noise(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float t = u_time;
	vec2 uv = UV;

	// Slowly drifting highlight center
	vec2 center = vec2(
		0.35 + sin(t * drift_speed * 6.2832) * 0.15,
		0.3 + cos(t * drift_speed * 4.71 + 0.5) * 0.12
	);

	vec2 d = (uv - center) / highlight_size;
	d.x *= 1.4;
	float highlight = exp(-dot(d, d) * highlight_softness);

	// Secondary smaller highlight
	vec2 center2 = vec2(0.65, 0.25) + vec2(
		sin(t * drift_speed * 3.5 + 2.0) * 0.08,
		cos(t * drift_speed * 5.1 + 1.3) * 0.06
	);
	vec2 d2 = (uv - center2) / (highlight_size * 0.5);
	d2.y *= 1.6;
	float highlight2 = exp(-dot(d2, d2) * highlight_softness * 1.2) * 0.5;

	float n = smooth_noise(uv * 4.0 + t * drift_speed * 0.5);
	float variation = 0.85 + n * 0.15;

	float total = (highlight + highlight2) * variation * opacity;

	COLOR = vec4(1.0, 1.0, 1.0, total);
}
