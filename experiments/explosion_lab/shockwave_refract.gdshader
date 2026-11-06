// Explosion lab: expanding refraction ring over everything already drawn this frame.
// Opt-in (key F). Under Compatibility on llvmpipe the screen copy came back brighter than
// the screen and a pow(2.2) fix overshot, so check it on a real device before use.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float progress = 0.0;   // 0 = birth, 1 = gone
uniform float strength = 0.018; // peak offset in screen UV
uniform float thickness = 0.14; // ring width in quad radii

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float ring = 1.0 - smoothstep(0.0, thickness, abs(r - progress));
	float life = 1.0 - progress;
	vec2 dir = p / max(length(p), 0.0001);
	vec2 offset = dir * ring * strength * life;
	vec4 behind = texture(screen_tex, SCREEN_UV - offset);
	behind.rgb += vec3(1.0, 0.9, 0.75) * ring * life * 0.12;
	// Only the ring band is drawn; the rest of the quad would just copy the screen back.
	COLOR = vec4(behind.rgb, r < 1.0 ? clamp(ring * 2.0, 0.0, 1.0) : 0.0);
}
