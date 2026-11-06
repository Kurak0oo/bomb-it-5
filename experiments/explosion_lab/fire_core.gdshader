// Explosion lab: bright additive core laid over the flame body (fake HDR without HDR 2D).
shader_type canvas_item;
render_mode unshaded, blend_add;

#include "res://experiments/explosion_lab/fire_shape.gdshaderinc"

uniform float intensity = 1.1;
uniform vec3 core_colour : source_color = vec3(1.0, 0.86, 0.55);

void fragment() {
	vec3 f = flame_field(UV, COLOR, TIME, 0.55);
	float alpha = smoothstep(0.0, 0.08, f.x) * f.y;
	COLOR = vec4(core_colour * intensity, alpha);
}
