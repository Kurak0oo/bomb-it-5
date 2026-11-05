// Flash ColorTransform offsets on premultiplied art (InvincibilityCommand's blink, +50 on
// red, green and blue): the offset is added to the colour before alpha, so in premultiplied
// terms it scales with the pixel's alpha.
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec3 offset = vec3(0.0);

void fragment() {
	COLOR.rgb = min(COLOR.rgb + offset * COLOR.a, vec3(COLOR.a));
}
