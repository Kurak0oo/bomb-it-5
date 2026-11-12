// Explosion lab: expanding light ring, additive. Reads nothing from the screen, so it
// looks the same on every renderer; the default shockwave style.
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float progress = 0.0;  // 0 = birth, 1 = gone
uniform float strength = 0.018; // shared with the refraction style; scales brightness here
uniform float thickness = 0.06; // ring width in quad radii
uniform vec3 ring_colour : source_color = vec3(1.0, 1.0, 0.82);

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float band = 1.0 - smoothstep(0.0, thickness * (1.0 + progress), abs(r - progress));
	// Bright leading edge, softer trailing side: reads as air pushed outward.
	float trail = smoothstep(progress - 0.35, progress, r) * step(r, progress);
	float life = pow(1.0 - progress, 1.5);
	float a = (band * 0.9 + trail * 0.06) * life * clamp(strength * 40.0, 0.3, 1.0);
	COLOR = vec4(ring_colour, r < 1.0 ? a : 0.0);
}
