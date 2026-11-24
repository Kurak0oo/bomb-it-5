// flash.filters.GlowFilter on a CanvasGroup (live TextField text, SwfScreen._make_label),
// as the reference player (Ruffle) draws it:
// - blur: `quality` passes of a box `blurX` x `blurY` screen pixels wide with fractional end
//   taps (render/wgpu/src/filters/blur.rs, BlurFilter::apply); SwfScreen._glow_kernel
//   builds the passes' combined 1-D weights, applied here per axis;
// - glow: alpha = colour alpha * saturate(blurred alpha * strength), composited by the
//   inner / knockout / compositeSource flags (render/wgpu/shaders/filter/glow.wgsl).
// The group's backbuffer holds the text premultiplied; the output is straight alpha.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 glow_color = vec4(1.0);
uniform float strength = 2.0;
uniform bool inner = false;
uniform bool knockout = false;
uniform bool composite_source = true;
uniform int nx = 1;
uniform int ny = 1;
uniform float wx[64];
uniform float wy[64];

void fragment() {
	vec4 dest = textureLod(screen_tex, SCREEN_UV, 0.0);
	int hx = nx / 2;
	int hy = ny / 2;
	float blur = 0.0;
	for (int j = 0; j < ny; j++) {
		float row = 0.0;
		for (int i = 0; i < nx; i++) {
			vec2 at = SCREEN_UV + vec2(float(i - hx), float(j - hy)) * SCREEN_PIXEL_SIZE;
			row += wx[i] * textureLod(screen_tex, at, 0.0).a;
		}
		blur += wy[j] * row;
	}
	// Each blur pass rounds to 1/255 (fixed point in Flash Player); once here.
	blur = floor(blur * 255.0) / 255.0;
	vec4 color = vec4(glow_color.rgb, 1.0);
	if (inner) {
		float a = glow_color.a * clamp((1.0 - blur) * strength, 0.0, 1.0);
		if (knockout || !composite_source) {
			color = color * a * dest.a;
		} else {
			color = color * a * dest.a + dest * (1.0 - a);
		}
	} else {
		float a = glow_color.a * clamp(blur * strength, 0.0, 1.0);
		if (knockout) {
			color = color * a * (1.0 - dest.a);
		} else if (composite_source) {
			color = color * a * (1.0 - dest.a) + dest;
		} else {
			color = color * a;
		}
	}
	COLOR = color.a > 0.0 ? vec4(color.rgb / color.a, color.a) : vec4(0.0);
}
