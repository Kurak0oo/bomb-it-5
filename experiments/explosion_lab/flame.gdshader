// Explosion lab: cartoon flame, one quad per cell, in the flat gradient look of the
// original's blast (white-hot block, yellow band, soft orange rim; no noise). Late in
// its life each cell shrinks to a glowing ball with pointed streaks along the ray, as
// in the reference captures (docs/evidence/reference-2026-10-19/chains/).
// Per-sprite parameters arrive packed in the modulate colour so every flame cell shares
// one material: r = age 0..1, g = kind (0 centre, 0.5 arm, 1 tip), b = seed, a = colour
// layer. Each cell is drawn three times, rim under band under core (lab.gd puts them on
// rising z), so overlapping cells and crossing blasts merge into one shape: one cell's
// rim can never cut across another cell's white middle.
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec3 hot_colour : source_color = vec3(1.0, 1.0, 0.96);
uniform vec3 mid_colour : source_color = vec3(1.0, 0.92, 0.22);
uniform vec3 rim_colour : source_color = vec3(1.0, 0.52, 0.04);

float round_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// A streak along x that tapers to a point at +-len.
float streak(vec2 p, float len, float thickness) {
	return abs(p.y) - thickness * clamp(1.0 - abs(p.x) / len, 0.0, 1.0);
}

void fragment() {
	float age = COLOR.r;
	float kind = COLOR.g;
	float seed = COLOR.b;
	// Quad sizes in cells; keep in step with lab.gd `_add_flame`.
	vec2 quad = kind < 0.25 ? vec2(1.45) : vec2(1.02, 1.45);
	vec2 p = (UV - 0.5) * quad;

	// Pop in with a small overshoot, then a two-frame style flicker instead of noise.
	float pop = age < 0.1 ? mix(0.45, 1.12, age / 0.1) : mix(1.12, 1.0, smoothstep(0.1, 0.2, age));
	float half_width = 0.38 * pop + 0.015 * sin(TIME * 38.0 + seed * 6.283);

	float block;
	if (kind < 0.25) {
		block = round_box(p, vec2(0.49 * pop), 0.16);
	} else if (kind < 0.75 || p.x < 0.0) {
		block = abs(p.y) - half_width;
	} else {
		block = round_box(p, vec2(0.34 * pop, half_width), min(half_width, 0.22));
	}

	float shrink = smoothstep(0.62, 1.0, age);
	float thickness = mix(0.085, 0.02, shrink);
	float ball = length(p) - mix(0.27, 0.07, shrink);
	if (kind < 0.75 || p.x < 0.0) {
		ball = min(ball, streak(p, 0.52, thickness));
	}
	if (kind < 0.25) {
		ball = min(ball, streak(p.yx, 0.52, thickness));
	}

	float morph = smoothstep(0.42, 0.68, age);
	float d = mix(block, ball, morph);
	float band = mix(1.0, 0.55, morph); // the colour bands narrow with the shape
	vec3 colour;
	float alpha;
	if (COLOR.a > 0.8) {
		colour = rim_colour;
		alpha = 1.0 - smoothstep(0.0, 0.11 * band, d);
	} else if (COLOR.a > 0.5) {
		colour = mid_colour;
		alpha = smoothstep(-0.02 * band, 0.05 * band, -d);
	} else {
		colour = hot_colour;
		alpha = smoothstep(0.05 * band, 0.14 * band, -d);
	}
	COLOR = vec4(colour, alpha * (1.0 - smoothstep(0.92, 1.0, age)));
}
