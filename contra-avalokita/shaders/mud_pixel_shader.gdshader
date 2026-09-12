shader_type canvas_item;
render_mode unshaded;
uniform int depth_pass = 2; // 2 = unsplit; -1/0/1 = rear/body/front surfaces.

const int MAX_SEGMENTS = 40;
uniform vec4 endpoints[MAX_SEGMENTS];
uniform vec4 properties[MAX_SEGMENTS]; // radius a, radius b, fusion width, depth
uniform int segment_count = 0;
const int MAX_MODIFIERS = 16;
uniform vec4 modifier_a[MAX_MODIFIERS]; // start xy, radius, softness
uniform vec4 modifier_b[MAX_MODIFIERS]; // end xy, end radius, depth
uniform vec4 modifier_meta[MAX_MODIFIERS]; // operation, shape, depth, enabled
uniform int modifier_count = 0;
uniform vec2 bounds_size = vec2(160.0, 128.0);
uniform vec2 bounds_origin = vec2(-80.0, -104.0);
uniform vec4 mud_color : source_color = vec4(0.42, 0.49, 0.27, 1.0);
uniform float edge_width : hint_range(0.5, 2.0) = 1.0;
uniform float noise_strength : hint_range(0.0, 0.05) = 0.025;
uniform vec4 impact_params = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 impact_bulge = vec4(0.0, 0.0, 0.0, 0.0);
uniform float impact_ripple_phase = 0.0;
uniform float death_dissolve : hint_range(0.0, 1.0) = 0.0;

float capsule(vec2 p, vec4 ab, vec2 radii) {
	vec2 axis = ab.zw - ab.xy;
	float h = clamp(dot(p - ab.xy, axis) / max(dot(axis, axis), 0.001), 0.0, 1.0);
	return length(p - ab.xy - axis * h) - mix(radii.x, radii.y, h);
}

float modifier_sdf(vec2 p, vec4 data_a, vec4 data_b, int shape) {
	if (shape == 0) {
		return length(p - data_a.xy) - data_a.z;
	}
	return capsule(p, vec4(data_a.xy, data_b.xy), vec2(data_a.z, data_b.z));
}

vec2 modifier_gradient(vec2 p, vec4 data_a, vec4 data_b, int shape) {
	vec2 center = data_a.xy;
	if (shape != 0) {
		vec2 axis = data_b.xy - data_a.xy;
		float t = clamp(dot(p - data_a.xy, axis) / max(dot(axis, axis), 0.001), 0.0, 1.0);
		center = mix(data_a.xy, data_b.xy, t);
	}
	vec2 radial = p - center;
	return radial / max(length(radial), 0.001);
}

float smooth_subtract(float body, float cutter, float softness) {
	float k = max(softness, 0.001);
	float h = clamp(0.5 + 0.5 * (body + cutter) / k, 0.0, 1.0);
	return mix(-cutter, body, h) + k * h * (1.0 - h);
}

void fragment() {
	vec2 p = UV * bounds_size + bounds_origin;
	float d = 1000.0;
	float owner_depth = -2.0;
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
	// Biological growth is unioned after the base anatomy so it inherits the
	// same lighting, noise, wet highlights and outline.
	for (int i = 0; i < MAX_MODIFIERS; i++) {
		if (i >= modifier_count) { break; }
		if (modifier_meta[i].w < 0.5 || int(round(modifier_meta[i].x)) != 0) { continue; }
		int shape = int(round(modifier_meta[i].y));
		float m = modifier_sdf(p, modifier_a[i], modifier_b[i], shape);
		float k = max(modifier_a[i].w, 0.01);
		float h = clamp(0.5 + 0.5 * (m - d) / k, 0.0, 1.0);
		vec2 m_gradient = modifier_gradient(p, modifier_a[i], modifier_b[i], shape);
		gradient = mix(m_gradient, gradient, h);
		d = mix(m, d, h) - k * h * (1.0 - h);
		if (m < 0.0 && modifier_meta[i].z >= owner_depth) {
			owner_depth = modifier_meta[i].z;
		}
	}
	if (owner_depth < -1.5) {
		owner_depth = 0.0;
	}
	// Cutters operate only on the surface depth they own. This keeps a rear
	// mutation from punching through a front arm or equipment silhouette.
	for (int i = 0; i < MAX_MODIFIERS; i++) {
		if (i >= modifier_count) { break; }
		if (modifier_meta[i].w < 0.5 || int(round(modifier_meta[i].x)) != 1) { continue; }
		if (abs(owner_depth - modifier_meta[i].z) > 0.25) { continue; }
		int shape = int(round(modifier_meta[i].y));
		float cutter = modifier_sdf(p, modifier_a[i], modifier_b[i], shape);
		float previous_d = d;
		d = smooth_subtract(d, cutter, modifier_a[i].w);
		if (-cutter > previous_d) {
			gradient = -modifier_gradient(p, modifier_a[i], modifier_b[i], shape);
		}
	}
	if (impact_params.w > 0.001) {
		float dist_to_impact = length(p - impact_params.xy);
		if (dist_to_impact < impact_params.z) {
			float dent = smoothstep(impact_params.z, 0.0, dist_to_impact) * impact_params.w;
			d += dent;
		}
	}
	if (impact_bulge.w > 0.001) {
		float dist_to_bulge = length(p - impact_bulge.xy);
		if (dist_to_bulge < impact_bulge.z) {
			float bulge = smoothstep(impact_bulge.z, 0.0, dist_to_bulge) * impact_bulge.w;
			d -= bulge;
		}
	}
	if (impact_params.w > 0.001) {
		vec2 mid = (impact_params.xy + impact_bulge.xy) * 0.5;
		float dist_mid = length(p - mid);
		if (dist_mid < impact_params.z * 1.6) {
			float ripple = sin(dist_mid * 0.70 - impact_ripple_phase * 6.283) * exp(-dist_mid * 0.15) * (impact_params.w * 0.25);
			d += ripple;
		}
	}
	if (d > 0.0) { discard; }
	// Peel stable, integer-sized islands from the upper body while preserving
	// the residue at floor level. Matching CPU particles use these SDF capsules.
	if (death_dissolve > 0.001 && p.y < -5.0) {
		float dissolve_noise = fract(sin(dot(floor(p * 0.5), vec2(41.37, 19.73))) * 951.1357);
		float height_lead = clamp((-p.y - 5.0) / 72.0, 0.0, 1.0) * 0.18;
		if (dissolve_noise < clamp(death_dissolve + height_lead, 0.0, 1.0)) { discard; }
	}
	int visible_depth = owner_depth < -0.5 ? -1 : (owner_depth > 0.5 ? 1 : 0);
	if (depth_pass != 2 && visible_depth != depth_pass) { discard; }
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
