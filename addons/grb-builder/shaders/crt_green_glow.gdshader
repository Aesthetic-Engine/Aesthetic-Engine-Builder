shader_type canvas_item;

// CRT Green Phosphor Glow — P39 phosphor display
// Split output: sharp CORE + soft HALO with living phosphor scintillation.
// Beam refresh band, micro-flicker, slow breathing drift.

varying vec4 v_modulate;

uniform float u_time = 0.0;

// --- Phosphor colour ---
uniform vec3 core_green : source_color = vec3(0.2, 1.0, 0.2);
uniform vec3 halo_green : source_color = vec3(0.0, 1.0, 0.0);

// --- Core / halo balance ---
uniform float core_gain : hint_range(0.0, 3.0) = 1.6;
uniform float halo_gain : hint_range(0.0, 4.0) = 0.2;
uniform float glow_radius_px : hint_range(0.0, 8.0) = 0.7;
uniform float glow_threshold : hint_range(0.0, 1.0) = 0.30;

// --- Scintillation (phosphor "lightning bugs") ---
uniform float speck_density : hint_range(0.0, 1.0) = 0.6;
uniform float speck_brightness : hint_range(0.0, 3.0) = 1.4;
uniform float speck_flicker_rate : hint_range(1.0, 30.0) = 8.0;

// --- Beam refresh band ---
uniform float beam_strength : hint_range(0.0, 1.0) = 0.25;
uniform float beam_width : hint_range(0.005, 0.1) = 0.025;
uniform float refresh_rate : hint_range(0.05, 2.0) = 0.15;

// --- Micro-flicker (60 Hz + harmonic) ---
uniform float flicker_amp : hint_range(0.0, 0.06) = 0.015;

// --- Slow breathing gain drift ---
uniform float breathe_amp : hint_range(0.0, 0.15) = 0.08;
uniform float breathe_hz : hint_range(0.01, 1.0) = 0.11;

// --- Phosphor pulse ---
uniform float glow_pulse_amp : hint_range(0.0, 0.6) = 0.22;
uniform float glow_pulse_hz : hint_range(0.05, 2.0) = 0.38;
uniform float core_pulse_amp : hint_range(0.0, 0.4) = 0.12;

// --- Scanlines / noise / vignette / barrel ---
uniform float scanline_amount : hint_range(0.0, 0.5) = 0.22;
uniform float noise_amount : hint_range(0.0, 0.1) = 0.024;
uniform float vignette_amount : hint_range(0.0, 0.5) = 0.08;
uniform float barrel_amount : hint_range(0.0, 0.3) = 0.036;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


void vertex() {
	v_modulate = COLOR;
}


void fragment() {
	vec2 uv = UV;
	float t = u_time;

	// Barrel distortion
	vec2 d = uv * 2.0 - 1.0;
	d *= 1.0 + dot(d, d) * barrel_amount;
	uv = d * 0.5 + 0.5;

	bool oob = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
	if (oob) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec2 src_res = 1.0 / px;

		// Slow breathing drift
		float breathe = 1.0
			+ sin(t * breathe_hz * 6.2832) * breathe_amp * 0.6
			+ sin(t * breathe_hz * 2.73 * 6.2832 + 1.3) * breathe_amp * 0.4;

		// Micro-flicker (60 Hz + 120 Hz harmonic)
		float flick60 = sin(t * 60.0 * 6.2832) * 0.6;
		float flick120 = sin(t * 120.0 * 6.2832) * 0.4;
		float flicker = 1.0 + (flick60 + flick120) * flicker_amp;

		// Sample core
		vec4 tex = texture(TEXTURE, uv);
		float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		float core = smoothstep(glow_threshold, glow_threshold + 0.06, luma) * core_gain;

		// Halo (8-tap cheap blur)
		vec2 off = px * glow_radius_px;
		float h = 0.0;
		h += dot(texture(TEXTURE, uv + vec2(-off.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
		h += dot(texture(TEXTURE, uv + vec2( off.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
		h += dot(texture(TEXTURE, uv + vec2(0.0, -off.y)).rgb, vec3(0.299, 0.587, 0.114));
		h += dot(texture(TEXTURE, uv + vec2(0.0,  off.y)).rgb, vec3(0.299, 0.587, 0.114));
		h += dot(texture(TEXTURE, uv + vec2(-off.x, -off.y) * 0.707).rgb, vec3(0.299, 0.587, 0.114));
		h += dot(texture(TEXTURE, uv + vec2( off.x, -off.y) * 0.707).rgb, vec3(0.299, 0.587, 0.114));
		h += dot(texture(TEXTURE, uv + vec2(-off.x,  off.y) * 0.707).rgb, vec3(0.299, 0.587, 0.114));
		h += dot(texture(TEXTURE, uv + vec2( off.x,  off.y) * 0.707).rgb, vec3(0.299, 0.587, 0.114));
		h /= 8.0;
		float halo = smoothstep(0.08, 0.5, h) * halo_gain;

		// Scintillation
		vec2 cell = floor(uv * src_res);
		float tick = floor(t * speck_flicker_rate);
		float speck_phase = hash21(cell + tick * 0.137);
		float flicker_cell = mix(1.0, speck_phase, speck_density);
		float shimmer = 1.0 + (flicker_cell - 0.5) * speck_brightness;
		float scint_gate = step(0.001, core);
		float scintillation = mix(1.0, shimmer, scint_gate);

		// Beam refresh band
		float beam_y = fract(t * refresh_rate);
		float beam_dist = abs(uv.y - beam_y);
		beam_dist = min(beam_dist, 1.0 - beam_dist);
		float beam = exp(-beam_dist / beam_width) * beam_strength;
		float beam_boost = 1.0 + beam * smoothstep(glow_threshold * 0.5, glow_threshold, luma);

		// Phosphor pulse
		float pulse_wave = sin(t * glow_pulse_hz * 6.2832);
		float halo_pulse = 1.0 + pulse_wave * glow_pulse_amp;
		float core_pulse = 1.0 + sin(t * glow_pulse_hz * 6.2832 + 0.7) * core_pulse_amp;

		// Compose
		float core_mod = core * core_pulse;
		float halo_mod = halo * halo_pulse;
		vec3 col = core_mod * core_green + halo_mod * halo_green;
		col *= scintillation * breathe * flicker * beam_boost;

		// Scanlines
		float scan = 1.0 - sin(uv.y * src_res.y * 3.14159) * scanline_amount;
		col *= scan;

		// Noise grain on lit pixels
		float n = fract(sin(dot(uv * 1000.0 + t, vec2(12.9898, 78.233))) * 43758.5453);
		col += (n - 0.5) * noise_amount * step(0.001, core);

		// Vignette
		vec2 vuv = uv * 2.0 - 1.0;
		float vig = 1.0 - dot(vuv, vuv) * vignette_amount;
		col *= vig;

		COLOR = vec4(col, tex.a) * v_modulate;
	}
}
