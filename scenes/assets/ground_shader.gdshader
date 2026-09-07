shader_type spatial;
render_mode unshaded;

uniform sampler2D ground_texture : source_color;
uniform float tile_scale = 16.;

void fragment() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = UV / tile_scale;
    ALBEDO = texture(ground_texture, uv).rgb;
}