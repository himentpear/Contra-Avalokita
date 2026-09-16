shader_type canvas_item;
render_mode unshaded;

// Pure emissive unshaded shader for eyes, cores, and energy components.
// Remains completely readable in dark environments, but obeys 2D z-ordering
// and world foreground occlusion.

uniform vec4 emissive_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emissive_energy : hint_range(0.0, 5.0) = 1.0;
uniform float emissive_dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 status_tint : source_color = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
	vec4 base_color = COLOR;
	vec4 tex_color = texture(TEXTURE, UV);
	if (tex_color.a > 0.001) {
		base_color *= tex_color;
	}
	if (base_color.a < 0.005) {
		discard;
	}

	if (emissive_dissolve > 0.001) {
		float noise = fract(sin(dot(floor(UV * 48.0), vec2(15.71, 33.19))) * 65123.789);
		if (noise < emissive_dissolve) {
			discard;
		}
	}

	vec3 out_rgb = base_color.rgb * emissive_tint.rgb * emissive_energy;

	if (status_tint.a > 0.001) {
		out_rgb = mix(out_rgb, status_tint.rgb, status_tint.a);
	}

	COLOR = vec4(out_rgb, base_color.a * emissive_tint.a);
}
