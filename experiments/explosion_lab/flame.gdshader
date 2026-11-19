// Explosion lab: cartoon flame, one quad per cell, in the flat gradient look of the
// original's blast (white-hot block, coloured band, soft rim; no noise).
// Per-sprite parameters arrive packed in the modulate colour so every flame cell of one
// robot shares one material: r = age 0..1, g = kind (0 centre, 0.5 arm, 1 tip),
// b = seed, a = colour layer. Each cell is drawn three times, rim under band under core
// (lab.gd puts them on rising z), so overlapping cells and crossing blasts merge into
// one shape: one cell's rim can never cut across another cell's white middle.
//
// The danger contract is the same for every robot (README, "Bomb profiles"): the shape
// covers its cell at full width with a white-hot core until the morph (age 0.42-0.68),
// then shrinks to a small "spent" shape and is gone at age 1. `style` (BombStyles
// index, Session.ROBOTS order) only changes the pop, the edge motion, the centre shape,
// the pattern inside the bands and the spent shape.
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec3 hot_colour : source_color = vec3(1.0, 1.0, 0.96);
uniform vec3 mid_colour : source_color = vec3(1.0, 0.92, 0.22);
uniform vec3 rim_colour : source_color = vec3(1.0, 0.52, 0.04);
uniform int style = 3;
// Board cell size in world units: edge patterns run in cells along the ray, so they
// line up across neighbouring cells.
uniform float cell = 48.0;

const int BLUE = 0;
const int RUBY = 1;
const int LIME = 2;
const int GOLD = 3;
const int VIOLET = 4;
const int SLATE = 5;
const int MINT = 6;
const int SNOW = 7;

varying float along;      // position along the ray in cells, continuous across cells
varying vec2 local_down;  // world down in the quad's own (rotated) frame
varying vec2 ray_axis;    // the quad's x axis in world space

void vertex() {
	vec2 axis_x = normalize(MODEL_MATRIX[0].xy);
	vec2 axis_y = vec2(-axis_x.y, axis_x.x);
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	along = dot(world, axis_x) / cell;
	local_down = vec2(axis_x.y, axis_y.y);
	ray_axis = axis_x;
}

float round_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// A streak along x that tapers to a point at +-len, and stops there.
float streak(vec2 p, float len, float thickness) {
	return max(abs(p.y) - thickness * clamp(1.0 - abs(p.x) / len, 0.0, 1.0), abs(p.x) - len);
}

// Triangle wave in -1..1.
float tri(float x) {
	return abs(fract(x) - 0.5) * 4.0 - 1.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Heart of about `size` cells across, centred on the origin, point down (y down).
float heart(vec2 p, float size) {
	vec2 q = vec2(abs(p.x) / size, 0.55 - p.y / size);
	float d;
	if (q.y + q.x > 1.0) {
		d = length(q - vec2(0.25, 0.75)) - 0.35355;
	} else {
		vec2 a = q - vec2(0.0, 1.0);
		vec2 b = q - 0.5 * max(q.x + q.y, 0.0);
		d = sqrt(min(dot(a, a), dot(b, b))) * sign(q.x - q.y);
	}
	return d * size;
}

// Five-petal flower of radius `radius`.
float flower(vec2 p, float radius, float turn) {
	float angle = atan(p.y, p.x) + turn;
	return length(p) - radius * (0.74 + 0.26 * cos(5.0 * angle));
}

// Four-point twinkle star of radius `radius`, turned by `turn`.
float twinkle(vec2 p, float radius, float thickness, float turn) {
	float c = cos(turn);
	float s = sin(turn);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	return min(min(streak(q, radius, thickness), streak(q.yx, radius, thickness)), length(q) - thickness * 0.9);
}

void fragment() {
	float age = COLOR.r;
	float kind = COLOR.g;
	float seed = COLOR.b;
	float layer = COLOR.a;
	bool centre = kind < 0.25;
	bool tip = kind > 0.75;
	// Quad sizes in cells; keep in step with lab.gd `_add_flame`.
	vec2 quad = centre ? vec2(1.45) : vec2(1.02, 1.45);
	vec2 p = (UV - 0.5) * quad;
	float t = TIME;

	// --- Pop: how the shape arrives -------------------------------------------------
	float over = 1.12;
	float pop_len = 0.1;
	if (style == GOLD) over = 1.24;                   // the biggest punch
	if (style == SLATE) { over = 1.06; pop_len = 0.05; } // a hard clank, little give
	if (style == MINT) { over = 1.04; pop_len = 0.18; }  // unfurls softly
	if (style == SNOW) { over = 1.0; pop_len = 0.04; }   // instant, no wind-up
	float pop = age < pop_len ? mix(0.45, over, age / pop_len) : mix(over, 1.0, smoothstep(pop_len, pop_len * 2.0, age));
	if (style == RUBY) {
		// Throbs like a speaker cone: two beats while the cell is live.
		pop *= 1.0 + 0.08 * max(sin(age * 6.2832 * 3.2), 0.0) * (1.0 - smoothstep(0.38, 0.5, age));
	}

	// --- Body: the edge's motion ----------------------------------------------------
	if (style == MINT) {
		p.y += 0.035 * sin(along * 5.0 + t * 3.5);       // sways like a stem
	}
	float edge = 0.015 * sin(t * 38.0 + seed * 6.283); // the original's two-frame flicker
	if (style == BLUE) edge = 0.04 * tri(along * 2.6 + floor(t * 20.0) * 0.37); // crackle
	if (style == LIME) edge = 0.045 * sin(along * 8.0 - t * 9.0);                // goo wave
	if (style == SLATE) edge = 0.0;                                              // dead straight
	float half_width = 0.38 * pop + edge;

	float block;
	if (centre) {
		if (style == RUBY) {
			block = heart(p, 1.08 * pop);
		} else if (style == LIME) {
			float angle = atan(p.y, p.x);
			block = length(p) - (0.5 * pop + 0.05 * sin(angle * 5.0 + t * 7.0));
		} else if (style == VIOLET) {
			block = min(round_box(p, vec2(0.44 * pop), 0.16), twinkle(p, 0.62 * pop, 0.22, 0.785));
		} else if (style == SLATE) {
			block = round_box(p, vec2(0.5 * pop), 0.04);
		} else if (style == MINT) {
			block = flower(p, 0.6 * pop, t * 0.8);
		} else if (style == BLUE || style == SNOW) {
			block = round_box(p, vec2(0.48 * pop), 0.09) + (style == BLUE ? 0.6 * edge : 0.0);
		} else {
			block = round_box(p, vec2(0.49 * pop), 0.16);
		}
	} else if (!tip || p.x < 0.0) {
		block = abs(p.y) - half_width;
	} else if (style == SNOW) {
		// Arrow-nosed tip: the width runs out to a point.
		block = abs(p.y) - half_width * clamp(1.0 - p.x / (0.42 * pop), 0.0, 1.0);
	} else if (style == SLATE) {
		block = round_box(p, vec2(0.36 * pop, half_width), 0.04);
	} else {
		block = round_box(p, vec2(0.34 * pop, half_width), min(half_width, 0.22));
	}

	// --- Spent shape: what each cell shrinks to once it no longer looks live --------
	float shrink = smoothstep(0.62, 1.0, age);
	float spent;
	if (style == BLUE) {
		// A thin bolt that keeps crackling until it goes out.
		float width = mix(0.07, 0.015, shrink);
		float jag = 0.09 * tri(along * 2.4 + floor(t * 24.0) * 0.31);
		spent = abs(p.y - jag) - width;
		if (centre) spent = min(spent, abs(p.x - jag) - width);
	} else if (style == RUBY) {
		// Hearts stand upright whichever way the ray runs.
		vec2 upright = p.x * ray_axis + p.y * vec2(-ray_axis.y, ray_axis.x);
		spent = heart(upright, mix(0.5, 0.14, shrink));
	} else if (style == LIME) {
		// A blob that sags toward the floor as it shrinks.
		spent = length(p - local_down * 0.14 * shrink) - mix(0.28, 0.08, shrink);
	} else if (style == VIOLET) {
		spent = twinkle(p, mix(0.34, 0.1, shrink), mix(0.14, 0.045, shrink), seed * 6.283);
	} else if (style == SLATE) {
		spent = round_box(p, vec2(mix(0.25, 0.07, shrink)), 0.03);
	} else if (style == MINT) {
		spent = flower(p, mix(0.32, 0.1, shrink), t * 1.5 + seed * 6.283);
	} else if (style == SNOW) {
		// A long speed line that slides outward along the ray.
		spent = streak(p - vec2(0.25 * shrink, 0.0), 0.62, mix(0.07, 0.015, shrink));
		if (centre) spent = min(spent, streak(p.yx, 0.62, mix(0.07, 0.015, shrink)));
	} else {
		// The original's end: a glowing ball with pointed streaks along the ray.
		float thickness = mix(0.085, 0.02, shrink);
		spent = length(p) - mix(0.27, 0.07, shrink);
		if (!tip || p.x < 0.0) spent = min(spent, streak(p, 0.52, thickness));
		if (centre) spent = min(spent, streak(p.yx, 0.52, thickness));
	}

	float morph = smoothstep(0.42, 0.68, age);
	float d = mix(block, spent, morph);
	float band = mix(1.0, 0.55, morph); // the colour bands narrow with the shape
	float live = 1.0 - morph;

	vec3 colour;
	float alpha;
	if (layer > 0.8) {
		colour = rim_colour;
		alpha = 1.0 - smoothstep(0.0, 0.11 * band, d);
	} else if (layer > 0.5) {
		colour = mid_colour;
		alpha = smoothstep(-0.02 * band, 0.05 * band, -d);
		if (style == SLATE && !centre) {
			// Riveted plates: the dark rim shows through in bars across the arm.
			alpha *= 1.0 - live * step(0.82, fract(along * 3.0));
		}
	} else {
		colour = hot_colour;
		alpha = smoothstep(0.05 * band, 0.14 * band, -d);
		if (style == BLUE) {
			alpha *= 0.8 + 0.2 * step(0.5, fract(t * 12.0)); // the core buzzes
		}
		if (style == VIOLET) {
			// Glitter: white specks twinkle on the lilac band.
			vec2 grid = vec2(along * 5.0, p.y * 5.0);
			float speck = hash(floor(grid));
			float twinkling = step(0.72, speck) * step(0.5, fract(t * 3.0 + speck * 7.0));
			float in_band = smoothstep(-0.02, 0.03, -d) * (1.0 - smoothstep(0.06, 0.12, -d));
			float dot_shape = 1.0 - smoothstep(0.12, 0.2, length(fract(grid) - 0.5));
			alpha = max(alpha, twinkling * in_band * dot_shape * live);
		}
	}
	if (style == SNOW && layer < 0.8 && !centre) {
		// Racing stripes: red lines run down the arm, dashes streaming outward.
		float lane = 1.0 - smoothstep(0.018, 0.032, abs(abs(p.y) - 0.17));
		float dash = step(0.45, fract(along * 2.0 - t * 7.0));
		alpha *= 1.0 - live * lane * dash;
	}
	COLOR = vec4(colour, alpha * (1.0 - smoothstep(0.92, 1.0, age)));
}
