shader_type canvas_item;

// CRT Screen Shader — monochrome green phosphor display
// Curvature, scanlines, glow, phosphor shimmer, breathing, beam refresh.

uniform float u_time = 0.0;
uniform bool u_extra_effects = true;

// --- Phosphor color ---
uniform vec3 phosphor_bright : source_color = vec3(0.2, 1.0, 0.2);
uniform vec3 phosphor_mid : source_color = vec3(0.06, 0.4, 0.06);

// --- Curvature ---
uniform float curvature : hint_range(0.0, 0.5) = 0.025;
uniform float corner_radius : hint_range(0.0, 0.15) = 0.035;

// --- Scanlines ---
uniform float scanline_strength : hint_range(0.0, 0.6) = 0.12;
uniform float scanline_count : hint_range(100.0, 600.0) = 200.0;

// --- Phosphor glow ---
uniform float glow_strength : hint_range(0.0, 1.0) = 0.15;
uniform float glow_radius : hint_range(0.5, 4.0) = 1.0;

// --- Breathing ---
uniform float breathe_amp : hint_range(0.0, 0.25) = 0.10;
uniform float breathe_speed : hint_range(0.02, 1.0) = 0.13;

// --- AC hum flicker ---
uniform float flicker_amp : hint_range(0.0, 0.08) = 0.025;

// --- Phosphor shimmer ---
uniform float shimmer_strength : hint_range(0.0, 0.5) = 0.18;
uniform float shimmer_speed : hint_range(1.0, 20.0) = 7.0;

// --- Beam refresh band ---
uniform float beam_strength : hint_range(0.0, 0.4) = 0.12;
uniform float beam_width : hint_range(0.005, 0.08) = 0.02;
uniform float refresh_rate : hint_range(0.05, 2.0) = 0.15;

// --- Vignette ---
uniform float vignette_strength : hint_range(0.0, 0.6) = 0.12;
uniform float vignette_softness : hint_range(0.1, 2.0) = 0.7;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 curve_uv(vec2 uv) {
	vec2 d = uv * 2.0 - 1.0;
	float r2 = dot(d, d);
	d *= 1.0 + r2 * curvature;
	return d * 0.5 + 0.5;
}

float screen_mask(vec2 uv) {
	vec2 d = abs(uv * 2.0 - 1.0);
	vec2 edge = max(d - (1.0 - corner_radius), 0.0);
	float dist = length(edge) / corner_radius;
	return 1.0 - smoothstep(0.85, 1.0, dist);
}


void fragment() {
	float t = u_time;
	vec2 uv = curve_uv(UV);
	float mask = screen_mask(uv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { mask = 0.0; }

	vec4 tex = texture(TEXTURE, uv);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	// Phosphor glow
	vec2 px = TEXTURE_PIXEL_SIZE * glow_radius;
	float bloom = 0.0;
	bloom += dot(texture(TEXTURE, uv + vec2(px.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	bloom += dot(texture(TEXTURE, uv - vec2(px.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	bloom += dot(texture(TEXTURE, uv + vec2(0.0, px.y)).rgb, vec3(0.299, 0.587, 0.114));
	bloom += dot(texture(TEXTURE, uv - vec2(0.0, px.y)).rgb, vec3(0.299, 0.587, 0.114));
	bloom *= 0.25;
	float glow = bloom * glow_strength * step(0.12, bloom);

	float intensity = luma + glow;
	float lit = step(0.02, intensity);
	intensity *= lit;

	vec3 col;
	if (u_extra_effects) {
		col = mix(phosphor_mid, phosphor_bright, smoothstep(0.15, 0.8, intensity));
	} else {
		col = phosphor_bright;
	}
	col *= intensity;

	if (u_extra_effects) {
		// Per-pixel phosphor shimmer
		vec2 src_res = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 cell = floor(uv * src_res);
		float tick = floor(t * shimmer_speed);
		float shimmer_val = hash21(cell + tick * 0.173);
		float shimmer = 1.0 + (shimmer_val - 0.5) * shimmer_strength * lit;

		// Breathing
		float breathe = 1.0
			+ sin(t * breathe_speed * 6.2832) * breathe_amp * 0.5
			+ sin(t * breathe_speed * 2.37 * 6.2832 + 1.1) * breathe_amp * 0.3
			+ sin(t * breathe_speed * 0.61 * 6.2832 + 2.7) * breathe_amp * 0.2;

		// AC hum flicker
		float flick = 1.0
			+ sin(t * 60.0 * 6.2832) * flicker_amp * 0.65
			+ sin(t * 120.0 * 6.2832) * flicker_amp * 0.35;

		// Beam refresh band
		float beam_y = fract(t * refresh_rate);
		float beam_dist = abs(uv.y - beam_y);
		beam_dist = min(beam_dist, 1.0 - beam_dist);
		float beam = exp(-beam_dist / beam_width) * beam_strength;
		float beam_boost = 1.0 + beam * lit;

		col *= shimmer * breathe * flick * beam_boost;
	}

	// Scanlines
	float scan_pos = uv.y * scanline_count;
	float scan = 1.0 - sin(scan_pos * 3.14159) * scanline_strength * lit;
	col *= scan;

	// Vignette
	vec2 vuv = uv * 2.0 - 1.0;
	float vig = 1.0 - dot(vuv, vuv) * vignette_strength;
	vig = smoothstep(0.0, vignette_softness, vig);
	col *= vig;

	col *= mask;
	COLOR = vec4(col, mask);
}
