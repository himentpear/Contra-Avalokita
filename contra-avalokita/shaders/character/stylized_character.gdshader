shader_type canvas_item;
render_mode unshaded;

// Stylized 2D Character Lighting Shader
// Stepped ramp: Shadow (~0.55), Mid (~0.82), Key (1.00 ~ 1.15)
// Unshaded to guarantee readable minimum ambient floor under dark CanvasModulate

uniform vec2 light_direction = vec2(0.0, -1.0);
uniform vec4 light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float light_energy = 1.0;

uniform float minimum_ambient : hint_range(0.0, 1.0) = 0.55;
uniform float mid_level : hint_range(0.0, 1.5) = 0.82;
uniform float key_level : hint_range(0.0, 2.0) = 1.10;

uniform vec4 shadow_color : source_color = vec4(0.40, 0.45, 0.52, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 key_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float rim_width : hint_range(0.0, 1.0) = 0.12;

uniform float weapon_highlight_strength : hint_range(0.0, 3.0) = 0.0;
uniform float metal_highlight_width : hint_range(0.0, 1.0) = 0.08;

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hit_flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform vec4 status_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	if (base_color.a < 0.01) {
		discard;
	}

	// 1. Dissolve / Death Mask
	if (dissolve_amount > 0.001) {
		float noise = fract(sin(dot(floor(UV * 64.0), vec2(12.9898, 78.233))) * 43758.5453);
		if (noise < dissolve_amount) {
			discard;
		}
	}

	// 2. 2D Pseudo-Normal
	vec2 center_offset = UV - vec2(0.5);
	float dist_from_center = length(center_offset);
	vec2 pseudo_normal = dist_from_center > 0.001 ? center_offset / dist_from_center : vec2(0.0, -1.0);

	vec2 l_dir = length(light_direction) > 0.001 ? normalize(light_direction) : vec2(0.0, -1.0);
	float n_dot_l = dot(pseudo_normal, l_dir);

	// 3. Stylized Stepped Ramp: Shadow (0.55), Mid (0.82), Key (1.10)
	float ramp = mid_level;
	vec3 ramp_tint = mid_color.rgb;

	if (n_dot_l < -0.20) {
		float t = smoothstep(-0.60, -0.20, n_dot_l);
		ramp = mix(minimum_ambient, mid_level, t);
		ramp_tint = mix(shadow_color.rgb, mid_color.rgb, t);
	} else if (n_dot_l > 0.35) {
		float t = smoothstep(0.35, 0.80, n_dot_l);
		ramp = mix(mid_level, key_level, t);
		ramp_tint = mix(mid_color.rgb, key_color.rgb, t);
	}

	// Guaranteed minimum ambient floor
	ramp = max(ramp, minimum_ambient);

	// Light color and energy influence on key areas (smooth C1 continuity)
	vec3 lit_rgb = base_color.rgb * ramp * ramp_tint;
	if (light_energy > 0.0001) {
		float direct_influence = clamp(n_dot_l * 0.5 + 0.5, 0.0, 1.0);
		float energy_factor = clamp(light_energy, 0.0, 1.5);
		vec3 lit_tint = mix(vec3(1.0), light_color.rgb, clamp(energy_factor, 0.0, 1.0) * direct_influence * 0.40);
		lit_rgb *= lit_tint;
		lit_rgb += lit_rgb * (light_color.rgb * energy_factor * direct_influence * 0.25);
	}

	// 4. Rim Light (Backlight enhancement, edge-focused, energy clamped, smooth to 0)
	if (rim_strength > 0.001) {
		float edge = smoothstep(0.5 - rim_width, 0.5, dist_from_center);
		float backlight = clamp(-n_dot_l, 0.0, 1.0);
		float rim_energy = clamp(light_energy, 0.0, 1.5);
		float rim = edge * backlight * rim_strength * rim_energy * 0.35;
		lit_rgb += rim * light_color.rgb;
	}

	// 5. Metal / Equipment Highlight
	if (weapon_highlight_strength > 0.001) {
		float metal_peak = smoothstep(1.0 - metal_highlight_width, 1.0, n_dot_l);
		float sharp_spec = pow(metal_peak, 4.0) * weapon_highlight_strength;
		lit_rgb += sharp_spec * vec3(1.0);
	}

	// 6. Gameplay Reaction (Hit Flash)
	if (hit_flash > 0.001) {
		lit_rgb = mix(lit_rgb, hit_flash_color.rgb, hit_flash);
	}

	// 7. Status Tint
	if (status_tint.a > 0.001) {
		lit_rgb = mix(lit_rgb, status_tint.rgb, status_tint.a);
	}

	COLOR = vec4(lit_rgb, base_color.a);
}
