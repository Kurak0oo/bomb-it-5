// Flash blend modes for a piece drawn over what lies below it (premultiplied art).
// Modes follow flash.display.BlendMode: the blended colour B(src, dst) replaces dst where
// the piece is opaque: out = dst * (1 - a) + B * a.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int mode = 0; // 1 multiply, 2 screen, 3 lighten, 4 darken, 5 difference, 6 add, 7 subtract, 8 overlay, 9 hardlight

void fragment() {
	vec4 s = texture(TEXTURE, UV) * COLOR;
	vec3 src = s.a > 0.0 ? s.rgb / s.a : vec3(0.0);
	vec3 dst = texture(screen_tex, SCREEN_UV).rgb;
	vec3 b = src;
	if (mode == 1) b = src * dst;
	else if (mode == 2) b = 1.0 - (1.0 - src) * (1.0 - dst);
	else if (mode == 3) b = max(src, dst);
	else if (mode == 4) b = min(src, dst);
	else if (mode == 5) b = abs(src - dst);
	else if (mode == 6) b = min(src + dst, vec3(1.0));
	else if (mode == 7) b = max(dst - src, vec3(0.0));
	else if (mode == 8) b = mix(2.0 * src * dst, 1.0 - 2.0 * (1.0 - src) * (1.0 - dst), step(0.5, dst));
	else if (mode == 9) b = mix(2.0 * src * dst, 1.0 - 2.0 * (1.0 - src) * (1.0 - dst), step(0.5, src));
	COLOR = vec4(mix(dst, b, s.a), 1.0);
}
