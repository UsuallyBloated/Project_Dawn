// The zone's ground (scripts/terrain_mesh.gd). Low-poly by construction: every
// triangle gets its own face normal from screen-space derivatives, so the mesh
// shares its vertices and carries no per-face data. Colour is layered: a height
// tint (grass low, grey-brown high), bare rock on anything too steep to stand
// on (so a face reads as a face), then the zone's paint texture (roads, farms,
// forest floor, camp clearings; tools/author_terrain.gd writes it), then a
// little noise so a kilometre of grass is not one flat colour.
shader_type spatial;

uniform vec3 low_color : source_color = vec3(0.40, 0.47, 0.25);
uniform vec3 high_color : source_color = vec3(0.53, 0.49, 0.38);
// Where the coarse noise runs high the grass dries towards this.
uniform vec3 dry_color : source_color = vec3(0.52, 0.50, 0.29);
uniform vec3 rock_color : source_color = vec3(0.47, 0.45, 0.42);
uniform vec3 rock_dark : source_color = vec3(0.33, 0.32, 0.31);
// The height tint runs from low_color at 0 to high_color at tint_top metres.
uniform float tint_top = 110.0;
// The paint texture covers the whole plate, centred on the terrain's origin.
uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_disable;
uniform float paint_strength = 1.0;
uniform float zone_size = 4000.0;
uniform sampler2D detail_noise : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The triangle's own normal, in view space, then in world space for the
	// slope. Front faces only (cull_back), so the sign is fixed.
	vec3 flat_normal = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	NORMAL = flat_normal;
	vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(flat_normal, 0.0)).xyz);

	vec2 xz = world_pos.xz;
	float coarse = texture(detail_noise, xz * 0.004).r;
	float fine = texture(detail_noise, xz * 0.06).r;
	float grain = texture(detail_noise, xz * 0.37 + vec2(0.31, 0.67)).r;

	vec3 grass = mix(low_color, dry_color, smoothstep(0.5, 0.85, coarse) * 0.35);
	vec3 ground = mix(grass, high_color, clamp(world_pos.y / tint_top, 0.0, 1.0));
	vec4 painted = texture(paint, xz / zone_size + vec2(0.5));
	ground = mix(ground, painted.rgb, painted.a * paint_strength);
	ground *= mix(0.88, 1.10, coarse) * mix(0.90, 1.10, fine) * mix(0.90, 1.10, grain);

	// world_normal.y is the cosine of the slope: 0.82 at 35 degrees, 0.57 at
	// 55 (the steepest floor), 0.5 at 60 (a face).
	float rock = smoothstep(0.80, 0.60, world_normal.y);
	// Rock: mottled by the noise at two scales, with faint horizontal bands
	// (strata) that fade out where they would be thinner than a pixel.
	float patchy = texture(detail_noise, xz * 0.0013 + vec2(world_pos.y * 0.002)).r;
	vec3 stone = mix(rock_dark, rock_color, clamp(fine * 0.5 + patchy * 0.9 - 0.1, 0.0, 1.0));
	float band = world_pos.y * 0.09 + coarse * 0.7;
	float band_fade = clamp(1.0 - fwidth(band) * 2.5, 0.0, 1.0);
	stone *= mix(1.0, mix(0.91, 1.04, step(0.5, fract(band))), band_fade);

	ALBEDO = mix(ground, stone, rock);
	ROUGHNESS = 0.95;
	SPECULAR = 0.08;
}
