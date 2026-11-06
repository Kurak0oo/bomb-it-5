// Explosion lab: flame body, normal blend so the shape reads on any background.
shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "res://experiments/explosion_lab/fire_shape.gdshaderinc"

uniform float rim_strength = 0.9;
uniform vec3 rim_colour : source_color = vec3(1.0, 0.3, 0.05);

void fragment() {
	vec3 f = flame_field(UV, COLOR, TIME, 1.0);
	float age = COLOR.r;
	float alpha = smoothstep(0.0, 0.05, f.x) * (1.0 - smoothstep(0.85, 1.0, age));
	vec3 colour = texture(ramp_tex, vec2(clamp(f.y * 0.85 + 0.1, 0.0, 1.0), 0.5)).rgb;
	colour *= mix(0.55, 1.15, f.z);                         // darker toward the silhouette
	colour += rim_colour * pow(1.0 - f.z, 4.0) * rim_strength; // hot rim, like back-lit gas
	COLOR = vec4(colour, alpha);
}
