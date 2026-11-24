// Flash ColorTransform.color on a bitmap (FallSnow's confetti, scripts/ui/fall_snow.gd):
// the colour multipliers become 0 and the offsets the colour, so every pixel takes the
// colour and keeps its own alpha.
shader_type canvas_item;

uniform vec3 offset = vec3(1.0);

void fragment() {
	// COLOR is the texture colour times the modulate; only its alpha is kept.
	COLOR = vec4(offset, COLOR.a);
}
