// Explosion lab: shared flame field for fire_body / fire_core.
// Quads are larger than the flame (see lab.gd) so noisy edges never hit the quad border.
// Per-sprite parameters arrive packed in the modulate colour so every flame cell can
// share one material and batch: r = age 0..1, g = kind (0 centre, 0.5 arm, 1 tip),
// b = random seed. Noise is sampled in world space so neighbouring cells join seamlessly.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform sampler2D ramp_tex : repeat_disable, filter_linear;
uniform float noise_scale = 0.012;
uniform float flow_speed = 1.3;

varying vec2 world_pos;
varying vec2 flow_dir;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 axis = MODEL_MATRIX[0].xy;
	flow_dir = length(axis) > 0.0 ? normalize(axis) : vec2(1.0, 0.0);
}

// x: signed field (> 0 inside), y: heat 0..1 (1 on the spine), z: fake volume depth 0..1.
vec3 flame_field(vec2 uv, vec4 params, float time, float width_scale) {
	float age = params.r;
	float kind = params.g;
	float seed = params.b;
	vec2 p = uv - 0.5;
	float grow = smoothstep(0.0, 0.14, age);
	float fade = 1.0 - smoothstep(0.35, 1.0, age);
	float width = 0.30 * width_scale * grow * mix(0.12, 1.0, fade);
	float d;
	if (kind < 0.25) {
		d = length(p) * 0.7;                                    // round fireball, overlaps the arms
	} else if (kind < 0.75) {
		d = abs(p.y);                                           // straight arm
	} else {
		d = p.x < 0.0 ? abs(p.y) : length(vec2(p.x * 1.3, p.y)); // rounded tip
	}
	// Flow outward along the arm, with a slight upward drift: fire "rises" toward the camera.
	vec2 q = world_pos * noise_scale;
	float n1 = texture(noise_tex, q - flow_dir * time * flow_speed + vec2(seed * 5.0, time * 0.25)).r;
	float n2 = texture(noise_tex, q * 2.1 + vec2(seed * 3.0, -time * flow_speed * 1.7)).r;
	float n = n1 * 0.65 + n2 * 0.35;
	float field = width - d + (n - 0.5) * 0.2 * grow;
	float heat = clamp(field / max(width, 0.001), 0.0, 1.0);
	// Treat the cross-section as a cylinder: depth peaks on the spine, falls to the rim.
	float volume = sqrt(clamp(1.0 - (1.0 - heat) * (1.0 - heat), 0.0, 1.0));
	return vec3(field, heat * fade, volume);
}
