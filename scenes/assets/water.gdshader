shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, blend_mix;

// --- Depth & Screen textures for SSR and edge detection ---
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;

const float z_near = 0.05;
const float z_far = 4000.0;

// --- Gerstner Wave: (amplitude, frequency, speed, phase) ---
uniform vec4 wave_0 = vec4(0.3, 2.0, 1.0, 0.0);
uniform vec4 wave_1 = vec4(0.2, 1.5, 0.8, 2.5);
uniform vec4 wave_2 = vec4(0.15, 1.0, 1.2, 5.0);
uniform vec4 wave_3 = vec4(0.1, 0.8, 0.6, 8.0);

// --- Noise control ---
uniform float noise_scale : hint_range(0.0, 10.0) = 1.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.3;

// --- PBR ---
uniform vec4 albedo : source_color = vec4(0.76, 0.94, 0.93, 0.8);
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.5;

// --- Water control ---
uniform float water_level : hint_range(-5.0, 5.0, 0.01) = 0.0;
uniform float scale : hint_range(0.1, 100.0) = 1.0;

// --- Edge foam ---
uniform float edge_threshold : hint_range(0.0, 2.0, 0.01) = 0.1;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- SSR settings ---
group_uniforms SSRSetting;
uniform int ssr_max_travel = 24;
uniform float depth_tolerance = 0.2;
uniform float ssr_fresnel_power : hint_range(0.1, 10.0) = 3.0;

varying vec3 v_view_pos;
varying vec3 v_world_pos;

// ============================================================
// Noise functions
// ============================================================
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

// ============================================================
// Gerstner wave
// ============================================================
vec3 calculate_wave(vec3 position_ws, float amplitude, float frequency, float speed, float phase_offset) {
	float phase = TIME * speed + phase_offset;
	float wave_input = position_ws.x * 0.5 + position_ws.z * 0.3;
	float y = amplitude * sin(wave_input * frequency + phase);
	return vec3(0.0, y, 0.0);
}

// ============================================================
// SSR helper functions
// ============================================================
vec3 uv_to_view(vec2 uv, float depth, mat4 inv_proj_m) {
	vec4 position_ndc = vec4((uv * 2.0) - 1.0, depth, 1.0);
	vec4 view_position = inv_proj_m * position_ndc;
	return view_position.xyz / view_position.w;
}

vec3 view_to_uv(vec3 position_view_space, mat4 proj_m, out float w) {
	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
	vec3 position_ndc = position_clip_space.xyz / position_clip_space.w;
	w = position_clip_space.w;
	return vec3(position_ndc.xy * 0.5 + 0.5, position_ndc.z);
}

vec4 get_depth_tested_color(vec4 pos, vec4 advance, vec2 viewport_size, mat4 inv_mat) {
	vec2 pixel_size = 1.0 / viewport_size;
	float z_from = pos.z / pos.w;
	float z_to = z_from;
	vec2 uv;
	float depth;
	for (int i = 0; i < ssr_max_travel; i++) {
		pos += advance;
		uv = (pos.xy - 0.5) * pixel_size;
		depth = uv_to_view(uv, texture(depth_texture, uv).r, inv_mat).z;

		z_from = z_to;
		z_to = pos.z / pos.w;

		if (depth > z_to && depth <= max(z_to, z_from) + depth_tolerance && -depth < z_far * 1.0) {
			if (any(bvec4(lessThan(pos.xy, vec2(1.0, 1.0)), greaterThan(pos.xy, viewport_size))) == false) {
				return vec4(texture(screen_texture, (pos.xy - 0.5) * pixel_size).rgb, 1.0);
			}
		}
	}
	return vec4(0.0);
}

// ============================================================
// Vertex: Gerstner wave displacement
// ============================================================
void vertex() {
	vec3 pos = VERTEX * vec3(scale, 1.0, scale);
	vec3 raw = VERTEX;

	vec3 offset = vec3(0.0);
	offset += calculate_wave(raw, wave_0.x, wave_0.y, wave_0.z, wave_0.w);
	offset += calculate_wave(raw, wave_1.x, wave_1.y, wave_1.z, wave_1.w);
	offset += calculate_wave(raw, wave_2.x, wave_2.y, wave_2.z, wave_2.w);
	offset += calculate_wave(raw, wave_3.x, wave_3.y, wave_3.z, wave_3.w);

	float noise_val = fbm(raw.xz * noise_scale + TIME * 0.5);
	offset.y += noise_val * noise_strength * (wave_0.x + wave_1.x);

	VERTEX = pos + offset + vec3(0.0, water_level, 0.0);
	v_view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// ============================================================
// Fragment: flat normals + SSR + edge foam
// ============================================================
void fragment() {
	// --- Flat normal for low-poly look ---
	vec3 ddx = dFdx(v_view_pos);
	vec3 ddy = dFdy(v_view_pos);
	vec3 flat_normal_vs = normalize(cross(ddx, ddy));

	if (dot(flat_normal_vs, NORMAL) < 0.0) {
		flat_normal_vs = -flat_normal_vs;
	}

	// --- Edge foam via depth comparison ---
	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 scene_pos = uv_to_view(SCREEN_UV, scene_depth, INV_PROJECTION_MATRIX);

	float water_depth = FRAGCOORD.z;
	vec3 water_pos = uv_to_view(SCREEN_UV, water_depth, INV_PROJECTION_MATRIX);

	float depth_diff = water_pos.z - scene_pos.z;
	float foam = 1.0 - smoothstep(0.0, edge_threshold, depth_diff);
	foam = pow(foam, edge_softness);

	// --- SSR ray marching ---
	vec2 pixel_size = 1.0 / VIEWPORT_SIZE;
	vec3 vertex = VERTEX;

	vec3 view_dir = normalize(vertex);
	vec3 ray_dir = normalize(reflect(view_dir, flat_normal_vs));

	float ray_len = (vertex.z + ray_dir.z * z_far) > -z_near ? (-z_near - vertex.z) / ray_dir.z : z_far;
	vec3 ray_end = vertex + ray_dir * ray_len;

	float w_begin;
	vec3 vp_line_begin = view_to_uv(vertex, PROJECTION_MATRIX, w_begin);
	float w_end;
	vec3 vp_line_end = view_to_uv(ray_end, PROJECTION_MATRIX, w_end);
	vec2 vp_line_dir = vp_line_end.xy - vp_line_begin.xy;

	w_begin = 1.0 / w_begin;
	w_end = 1.0 / w_end;

	float z_begin = vertex.z * w_begin;
	float z_end = ray_end.z * w_end;

	vec2 line_begin = vp_line_begin.xy / pixel_size;
	vec2 line_dir = vp_line_dir / pixel_size;
	float z_dir = z_end - z_begin;
	float w_dir = w_end - w_begin;

	float scale_max_x = min(1.0, 0.99 * (1.0 - vp_line_begin.x) / max(1e-5, vp_line_dir.x));
	float scale_max_y = min(1.0, 0.99 * (1.0 - vp_line_begin.y) / max(1e-5, vp_line_dir.y));
	float scale_min_x = min(1.0, 0.99 * vp_line_begin.x / max(1e-5, -vp_line_dir.x));
	float scale_min_y = min(1.0, 0.99 * vp_line_begin.y / max(1e-5, -vp_line_dir.y));
	float line_clip = min(scale_max_x, scale_max_y) * min(scale_min_x, scale_min_y);

	line_dir *= line_clip;
	z_dir *= line_clip;
	w_dir *= line_clip;

	float line_length = length(line_dir);

	float dist = length(CAMERA_POSITION_WORLD - v_world_pos);
	float linear_dist = clamp(dist / 200.0, 0.0, 1.0);
	float dynamic_step_size = mix(2.0, 8.0, linear_dist);

	float advance_angle_adj = 1.0 / max(abs(normalize(line_dir).x), abs(normalize(line_dir).y));
	vec4 line_advance = vec4(line_dir, z_dir, w_dir) * advance_angle_adj * (dynamic_step_size / line_length);
	vec4 init_pos = vec4(line_begin, z_begin, w_begin);

	// --- Get SSR color ---
	vec4 reflect_color;
	float reflect_amount;
	if (ray_dir.z > 0.0 || ray_len < 0.1) {
		reflect_color = vec4(0.0);
		reflect_amount = 0.0;
	} else {
		reflect_color = get_depth_tested_color(init_pos, line_advance, VIEWPORT_SIZE, INV_PROJECTION_MATRIX);
		reflect_amount = reflect_color.a * pow(1.0 - dot(flat_normal_vs, VIEW), ssr_fresnel_power);
	}

	// --- Final compositing ---
	vec3 base_color = mix(albedo.rgb, foam_color.rgb, foam * foam_color.a);
	vec3 final_color = mix(base_color, reflect_color.rgb, reflect_amount);

	NORMAL = flat_normal_vs;
	ALBEDO = final_color;
	ALPHA = albedo.a;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	EMISSION = reflect_color.rgb * reflect_amount;
}
