shader_type canvas_item;
render_mode unshaded;
uniform int depth_pass = 2; // 2 = unsplit; -1/0/1 = rear/body/front surfaces.

const int MAX_SEGMENTS = 40;
uniform vec4 endpoints[MAX_SEGMENTS];
uniform vec4 properties[MAX_SEGMENTS]; // radius a, radius b, fusion width, depth
uniform float arm_flags[MAX_SEGMENTS]; // 1 for anatomical arm/hand capsules.
uniform int segment_count = 0;
const int MAX_MODIFIERS = 16;
uniform vec4 modifier_a[MAX_MODIFIERS]; // start xy, radius, softness
uniform vec4 modifier_b[MAX_MODIFIERS]; // end xy, end radius, depth
uniform vec4 modifier_meta[MAX_MODIFIERS]; // operation, shape, depth, enabled
uniform int modifier_count = 0;
uniform vec2 bounds_size = vec2(160.0, 128.0);
uniform vec2 bounds_origin = vec2(-80.0, -104.0);
uniform vec4 mud_color : source_color = vec4(0.42, 0.49, 0.27, 1.0);
uniform vec4 hit_flash_color : source_color = vec4(1.0);
uniform float hit_flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.5, 2.0) = 1.0;
uniform float arm_edge_width : hint_range(0.5, 3.0) = 1.6;
uniform float macro_breakup_strength : hint_range(0.0, 0.3) = 0.09;
uniform float medium_breakup_strength : hint_range(0.0, 0.2) = 0.055;
uniform float grain_strength : hint_range(0.0, 0.1) = 0.025;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.36;
uniform float key_threshold : hint_range(0.0, 1.0) = 0.68;
uniform float band_softness : hint_range(0.0, 0.1) = 0.025;
uniform float cavity_strength : hint_range(0.0, 0.4) = 0.15;
uniform float wetness : hint_range(0.0, 1.0) = 0.10;
uniform float wet_threshold : hint_range(0.5, 1.0) = 0.84;
uniform float wet_highlight_strength : hint_range(0.0, 0.3) = 0.08;
uniform float rim_breakup_strength : hint_range(0.0, 1.0) = 0.70;
uniform vec4 impact_params = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 impact_bulge = vec4(0.0, 0.0, 0.0, 0.0);
uniform float impact_ripple_phase = 0.0;
uniform float death_dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec2 light_direction = vec2(-0.25, -0.35);
uniform vec4 light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float light_energy = 1.0;
uniform float minimum_ambient : hint_range(0.0, 1.0) = 0.55;
uniform float mid_level : hint_range(0.0, 1.5) = 0.82;
uniform float key_level : hint_range(0.0, 2.0) = 1.10;
uniform vec4 shadow_color : source_color = vec4(0.40, 0.45, 0.52, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 key_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.12;
uniform float rim_width : hint_range(0.0, 1.0) = 0.12;
uniform vec4 status_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);

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

// Stable character-local value noise stays attached to the deforming mud body.
float hash21(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 coord) {
	vec2 cell = floor(coord);
	vec2 f = fract(coord);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float e = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, e, f.x), f.y);
}

void fragment() {
	vec2 p = UV * bounds_size + bounds_origin;
	float d = 1000.0;
	float owner_depth = -2.0;
	float owner_is_arm = 0.0;
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
			owner_is_arm = arm_flags[i];
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
			owner_is_arm = 0.0;
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
	vec2 l_dir = length(light_direction) > 0.001 ? normalize(light_direction) : vec2(0.0, -1.0);
	float gradient_len = length(gradient);
	vec2 macro_normal = gradient / max(gradient_len, 0.001);
	float n_dot_l = dot(macro_normal, l_dir);
	surface = 0.50 + n_dot_l * 0.50;

	// Break up the macro lighting before quantization. Scales are about 8 px,
	// 3 px and 1 px respectively and never perturb the SDF silhouette.
	float macro_sample = value_noise(p / 8.0);
	float medium_sample = value_noise((p + vec2(19.0, -7.0)) / 3.0);
	float detail_sample = value_noise((p + vec2(71.0, -29.0)) / 1.6);
	float grain_sample = hash21(floor(p) + vec2(43.0, 17.0));
	float macro_breakup = (macro_sample - 0.5) * macro_breakup_strength;
	float medium_breakup = (medium_sample - 0.5) * medium_breakup_strength;
	float grain = (grain_sample - 0.5) * grain_strength;
	float material_light = clamp(surface + macro_breakup + medium_breakup + grain, 0.0, 1.0);
	float softness = max(band_softness, 0.001);
	float shadow_to_mid = smoothstep(shadow_threshold - softness, shadow_threshold + softness, material_light);
	float mid_to_key = smoothstep(key_threshold - softness, key_threshold + softness, material_light);

	vec3 shadow_tone = shadow_color.rgb * minimum_ambient;
	vec3 mid_tone = mid_color.rgb * mid_level;
	vec3 key_tone = key_color.rgb * key_level;
	vec3 tonal_level = mix(shadow_tone, mid_tone, shadow_to_mid);
	tonal_level = mix(tonal_level, key_tone, mid_to_key);
	float bounded_energy = clamp(light_energy, 0.0, 1.5);
	vec3 subtle_light_tint = mix(vec3(1.0), light_color.rgb, min(bounded_energy, 1.0) * 0.18);
	vec3 shade = mud_color.rgb * tonal_level * subtle_light_tint;
	shade *= 1.0 + mid_to_key * bounded_energy * 0.06;

	// Low gradient coherence occurs at smooth-union junctions. Treat it as
	// compressed, dirty mud rather than an expensive second SDF/AO pass.
	float cavity = clamp(1.0 - gradient_len, 0.0, 1.0);
	cavity *= cavity;
	shade *= 1.0 - cavity * cavity_strength;
	if (owner_depth < -0.5) { shade *= 0.73; }
	if (rim_strength > 0.001 && light_energy > 0.05 && d > -rim_width * 12.0 && n_dot_l < 0.1) {
		float rim_edge = smoothstep(-rim_width * 12.0, 0.0, d);
		float rim_angle = clamp(1.0 - n_dot_l, 0.0, 1.0);
		float rim_noise = fract(detail_sample + grain_sample * 0.37);
		float broken_rim = step(rim_breakup_strength, rim_noise);
		float rim = rim_edge * rim_angle * rim_strength * bounded_energy * broken_rim * 0.25;
		shade += rim * light_color.rgb;
	}
	// Rare 1-3 px wet fragments appear only on lit interior material.
	float wet_density = clamp(wetness * 4.0, 0.0, 1.0);
	float wet_mask = step(wet_threshold, detail_sample) * wet_density;
	float interior = 1.0 - smoothstep(-3.0, -1.25, d);
	float wet_candidate = mid_to_key * smoothstep(0.15, 0.65, bounded_energy) * wet_mask * interior;
	shade += mud_color.rgb * subtle_light_tint * wet_candidate * wet_highlight_strength;
	float local_edge_width = mix(edge_width, arm_edge_width, owner_is_arm);
	if (d > -local_edge_width) { shade = mud_color.rgb * 0.36; }
	if (hit_flash_amount > 0.001) {
		shade = mix(shade, hit_flash_color.rgb, hit_flash_amount);
	}
	if (status_tint.a > 0.001) {
		shade = mix(shade, status_tint.rgb, status_tint.a);
	}
	COLOR = vec4(shade, 1.0);
}
