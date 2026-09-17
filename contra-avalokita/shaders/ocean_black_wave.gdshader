shader_type canvas_item;
render_mode unshaded;

// Front-facing procedural ocean for the 640x360 pixel-oriented viewport.
// The shader keeps the sky transparent, renders a near-black body of water,
// and builds depth from stacked wave ridges instead of a perspective plane.

uniform vec2 virtual_size = vec2(640.0, 360.0);
uniform float horizon_y : hint_range(0.35, 0.85) = 0.60;
uniform float amplitude_px : hint_range(0.0, 24.0) = 8.0;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.65;
uniform float wave_scale : hint_range(0.25, 4.0) = 1.0;
uniform float roughness : hint_range(0.0, 2.0) = 0.75;
uniform float foam_px : hint_range(0.0, 8.0) = 2.0;
uniform float highlight_intensity : hint_range(0.0, 2.0) = 0.90;
uniform float pixel_step : hint_range(1.0, 4.0, 1.0) = 1.0;
uniform float u_time = 0.0;

uniform vec4 shallow_color : source_color = vec4(0.055, 0.060, 0.068, 1.0);
uniform vec4 deep_color : source_color = vec4(0.004, 0.005, 0.008, 1.0);
uniform vec4 ridge_color : source_color = vec4(0.32, 0.34, 0.37, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.86, 0.87, 0.90, 1.0);

// Local disturbance format: x = normalized screen X, y = age in seconds,
// z = strength in pixels, w = radius in normalized screen space.
uniform vec4 impact0 = vec4(-10.0, 99.0, 0.0, 0.08);
uniform vec4 impact1 = vec4(-10.0, 99.0, 0.0, 0.08);
uniform vec4 impact2 = vec4(-10.0, 99.0, 0.0, 0.08);
uniform vec4 impact3 = vec4(-10.0, 99.0, 0.0, 0.08);

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float macro_wave(float x, float t) {
	float w1 = sin(x * TAU * (1.05 * wave_scale) + t * 0.74);
	float w2 = sin(x * TAU * (1.95 * wave_scale) - t * 1.03 + 1.24);
	float w3 = sin(x * TAU * (3.75 * wave_scale) + t * 1.37 + 2.17);
	float w4 = sin(x * TAU * (6.80 * wave_scale) - t * 1.82 + 0.51);
	return w1 * 0.50 + w2 * 0.28 + w3 * 0.15 + w4 * 0.07 * roughness;
}

float impact_wave(float x, vec4 p) {
	if (p.y > 4.0 || p.z <= 0.0) {
		return 0.0;
	}

	float d = abs(x - p.x);
	float radius = max(p.w, 0.001);
	float spatial = exp(-(d * d) / (2.0 * radius * radius));
	float temporal = exp(-p.y * 1.85);
	float oscillation = sin(d * 112.0 - p.y * 15.0);
	return oscillation * p.z * spatial * temporal;
}

float ridge_line(float x_px, float depth_px, float t, float spacing_px, float seed) {
	float band_position = depth_px / spacing_px;
	float band_id = floor(band_position);
	float within_band = fract(band_position);

	// Each depth band gets a slightly different lateral phase. This makes the
	// wave layers cross and separate rather than sliding as one texture.
	float phase = x_px * (0.038 + seed * 0.006)
		+ t * (0.65 + seed * 0.17)
		+ band_id * (1.31 + seed * 0.29);
	float center = 0.24
		+ sin(phase) * (0.10 + roughness * 0.025)
		+ sin(phase * 0.47 + 1.70) * 0.055;
	float distance_to_ridge = abs(within_band - center);
	return 1.0 - smoothstep(0.035, 0.105, distance_to_ridge);
}

void fragment() {
	float step_px = max(pixel_step, 1.0);
	vec2 pixel = floor((UV * virtual_size) / step_px) * step_px;
	vec2 uv = pixel / virtual_size;
	float t = u_time * wave_speed;

	float base_wave = macro_wave(uv.x, t);
	float impacts = impact_wave(uv.x, impact0)
		+ impact_wave(uv.x, impact1)
		+ impact_wave(uv.x, impact2)
		+ impact_wave(uv.x, impact3);
	float height_px = base_wave * amplitude_px + impacts;

	float surface = horizon_y - height_px / virtual_size.y;
	surface = floor((surface * virtual_size.y) / step_px) * step_px / virtual_size.y;

	if (uv.y < surface) {
		discard;
	}

	float depth_px = max((uv.y - surface) * virtual_size.y, 0.0);
	float available_depth = max((1.0 - horizon_y) * virtual_size.y, 1.0);
	float depth_norm = clamp(depth_px / available_depth, 0.0, 1.0);

	// Keep the sea almost black. Depth changes in discrete bands so that the
	// water remains readable under the project's nearest-neighbour rendering.
	float tone_band = floor(depth_norm * 7.0) / 7.0;
	vec4 water = mix(shallow_color, deep_color, tone_band);

	float ridge_a = ridge_line(pixel.x, depth_px, t, 12.0, 0.0);
	float ridge_b = ridge_line(pixel.x, depth_px + 5.0, -t * 0.82, 17.0, 1.0);
	float ridge_c = ridge_line(pixel.x, depth_px + 2.0, t * 0.53, 25.0, 2.0);
	float ridge = max(ridge_a * 0.72, max(ridge_b * 0.46, ridge_c * 0.30));

	// Break long continuous lines into silver fragments. The fragments become
	// rarer with depth, matching low-light highlights on a black night sea.
	float segment_id = floor(pixel.x / 9.0) + floor(depth_px / 6.0) * 17.0;
	float fragment_mask = smoothstep(0.34, 0.72, hash11(segment_id + floor(t * 1.5) * 0.07));
	float ridge_visibility = ridge * fragment_mask * (1.0 - depth_norm * 0.58);
	water = mix(water, ridge_color, ridge_visibility * highlight_intensity);

	// Surface crest light is sparse and stronger on upward crests. It should
	// read as reflected silver rather than white foam in ordinary conditions.
	float surface_band = 1.0 - smoothstep(0.0, max(foam_px, 0.001), depth_px);
	float crest = smoothstep(0.28, 0.82, base_wave + abs(impacts) * 0.08);
	float crest_break = smoothstep(0.28, 0.74,
		hash11(floor(pixel.x / 7.0) + floor(t * 2.0) * 19.0));
	float specular = surface_band * crest * crest_break * highlight_intensity;
	water = mix(water, highlight_color, clamp(specular, 0.0, 1.0));

	// Very shallow micro-ripples prevent the silhouette from looking like a
	// single animated curve without turning the whole sea into noisy static.
	float micro = sin(pixel.x * 0.19 + t * 2.35 + floor(depth_px / 5.0) * 1.43);
	float micro_mask = smoothstep(0.70, 0.96, micro * 0.5 + 0.5);
	float near_surface = 1.0 - smoothstep(12.0, 30.0, depth_px);
	water.rgb += vec3(0.035) * micro_mask * near_surface * roughness;

	COLOR = vec4(clamp(water.rgb, vec3(0.0), vec3(1.0)), 1.0);
}
