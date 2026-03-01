shader_type canvas_item;

// P39 phosphor decay — non-linear persistence for green CRT.
// Feedback loop: previous_frame is this viewport's own prior render.
// Values below floor_threshold snap to zero to prevent green accumulation.

uniform sampler2D current_frame;
uniform sampler2D previous_frame;
uniform float decay_fast : hint_range(0.5, 0.98) = 0.72;
uniform float decay_tail : hint_range(0.85, 0.999) = 0.85;
uniform float tail_threshold : hint_range(0.0, 0.3) = 0.04;
uniform float floor_threshold : hint_range(0.0, 0.05) = 0.018;

void fragment() {
	vec4 curr = texture(current_frame, UV);
	vec4 prev = texture(previous_frame, UV);

	float prev_luma = dot(prev.rgb, vec3(0.299, 0.587, 0.114));

	float decay = mix(decay_fast, decay_tail, smoothstep(0.0, tail_threshold, prev_luma));
	vec4 decayed = prev * decay;

	float decayed_luma = dot(decayed.rgb, vec3(0.299, 0.587, 0.114));
	decayed *= step(floor_threshold, decayed_luma);

	COLOR = max(curr, decayed);
}
