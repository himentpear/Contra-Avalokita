shader_type canvas_item;
render_mode unshaded;

const int MAX_SEGMENTS = 40;
uniform vec4 endpoints[MAX_SEGMENTS];
uniform vec4 properties[MAX_SEGMENTS]; // radius a, radius b, fusion width, depth
uniform int segment_count = 0;
uniform vec2 bounds_size = vec2(160.0, 128.0);
uniform vec2 bounds_origin = vec2(-80.0, -104.0);
uniform vec4 mud_color : source_color = vec4(0.42, 0.49, 0.27, 1.0);
uniform float edge_width : hint_range(0.5, 2.0) = 1.0;
uniform float noise_strength : hint_range(0.0, 0.05) = 0.025;

float capsule(vec2 p, vec4 ab, vec2 radii) {
	vec2 axis = ab.zw - ab.xy;
	float h = clamp(dot(p - ab.xy, axis) / max(dot(axis, axis), 0.001), 0.0, 1.0);
	return length(p - ab.xy - axis * h) - mix(radii.x, radii.y, h);
}

void fragment() {
	vec2 p = UV * bounds_size + bounds_origin;
	float d = 1000.0;
	float owner_depth = -1.0;
	float surface = 0.0;
	vec2 gradient = vec2(0.0);
	for (int i = 0; i < MAX_SEGMENTS; i++) {
		if (i >= segment_count) { break; }
		float s = capsule(p, endpoints[i], properties[i].xy);
		float k = max(properties[i].z, 0.01);
		float h = clamp(0.5 + 0.5 * (s - d) / k, 0.0, 1.0);
		vec2 axis = endpoints[i].zw - endpoints[i].xy;
		float t = clamp(dot(p - endpoints[i].xy, axis) / max(dot(axis, axis), 0.001), 0.0, 1.0);
		vec2 radial = p - mix(endpoints[i].xy, endpoints[i].zw, t);
		gradient = mix(radial / max(length(radial), 0.001), gradient, h);
		d = mix(s, d, h) - k * h * (1.0 - h);
		// Front surfaces win overlaps; union still has one continuous silhouette.
		if (s < 0.0 && properties[i].w >= owner_depth) {
			owner_depth = properties[i].w;
		}
	}
	if (d > 0.0) { discard; }
	surface = 0.60 + dot(gradient, vec2(-0.25, -0.35));
	float noise = fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
	float light = surface + (noise - 0.5) * noise_strength;
	vec3 shade = mud_color.rgb;
	if (light < 0.30) { shade *= 0.55; }
	else if (light < 0.50) { shade *= 0.77; }
	else if (light > 0.79) { shade = mix(shade, vec3(0.82, 0.87, 0.55), 0.62); }
	if (owner_depth < -0.5) { shade *= 0.73; }
	if (light > 0.94 && noise > 0.94 && d < -2.0) { shade = vec3(0.85, 0.9, 0.65); }
	if (d > -edge_width) { shade = mud_color.rgb * 0.36; }
	COLOR = vec4(shade, 1.0);
}
