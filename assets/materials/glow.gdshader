// Unlit, and brighter than white: the vertex colour times `energy`, so the
// world's glow blooms it. Fire, the Wraith Gate's light, the barrow's door
// (scripts/zone/low_poly.gd builds the meshes that wear it).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float energy = 3.0;

void fragment() {
	// The builder writes sRGB colours; light adds up in linear.
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * energy;
}
