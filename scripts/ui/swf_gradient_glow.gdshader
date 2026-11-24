// flash.filters.GradientGlowFilter on a CanvasGroup (a run-time node, SwfScreen.set_node_filter):
// the invincible robot's colour cycle (CountInvincibilityCommand.execute). The reference player
// draws no GradientGlowFilter (Ruffle's wgpu backend skips it), so this follows the filter's
// documented model on the same parts as GlowFilter (swf_glow.gdshader):
// - the source's alpha moved by (distance, angle) and blurred by `quality` passes of a box
//   `blurX` x `blurY` wide (SwfScreen._glow_kernel, sampled every `stride` screen pixels);
// - INNER takes the inverted alpha; strength scales it; the result picks the gradient's entry
//   (256 entries from colors/alphas/ratios, SwfScreen._gradient_table);
// - composited as GlowFilter's inner / outer / knockout cases (render/wgpu/shaders/filter/glow.wgsl).
// The group's backbuffer holds the robot premultiplied; the output is straight alpha.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D gradient : repeat_disable, filter_nearest;
uniform vec2 offset_px = vec2(0.0);
uniform float stride = 1.0;
uniform float strength = 1.0;
uniform bool inner = false;
uniform bool knockout = false;
uniform int nx = 1;
uniform int ny = 1;
uniform float wx[64];
uniform float wy[64];

void fragment() {
	vec4 dest = textureLod(screen_tex, SCREEN_UV, 0.0);
	vec2 from = SCREEN_UV - offset_px * SCREEN_PIXEL_SIZE;
	int hx = nx / 2;
	int hy = ny / 2;
	float blur = 0.0;
	for (int j = 0; j < ny; j++) {
		float row = 0.0;
		for (int i = 0; i < nx; i++) {
			vec2 at = from + vec2(float(i - hx), float(j - hy)) * stride * SCREEN_PIXEL_SIZE;
			row += wx[i] * textureLod(screen_tex, at, 0.0).a;
		}
		blur += wy[j] * row;
	}
	blur = floor(blur * 255.0) / 255.0;
	if (inner) {
		blur = 1.0 - blur;
	}
	float v = clamp(blur * strength, 0.0, 1.0);
	vec4 g = textureLod(gradient, vec2((floor(v * 255.0) + 0.5) / 256.0, 0.5), 0.0);
	vec4 color = vec4(g.rgb * g.a, g.a);
	if (inner) {
		color = knockout ? color * dest.a : color * dest.a + dest * (1.0 - g.a);
	} else {
		color = knockout ? color * (1.0 - dest.a) : color * (1.0 - dest.a) + dest;
	}
	COLOR = color.a > 0.0 ? vec4(color.rgb / color.a, color.a) : vec4(0.0);
}
